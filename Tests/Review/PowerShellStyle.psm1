using namespace System.Management.Automation.Language

<#
.SYNOPSIS
Finds help violations using the tokens immediately before each function.
.DESCRIPTION
Checks placement before reading headings and parameter entries from the block. A body comment is never used as a fallback.
.PARAMETER Functions
Function definitions, including those in nested script blocks.
.PARAMETER Tokens
Tokens from the same parsed source.
#>
function Get-FunctionHelpFinding {
    param([array]$Functions, [Token[]]$Tokens)

    $previousByOffset = @{}
    $previous = $null
    foreach ($token in $Tokens) {
        if ($token.Kind -eq [TokenKind]::NewLine) { continue }
        if ($token.Kind -eq [TokenKind]::Function -or $token.Kind -eq [TokenKind]::Filter) {
            $previousByOffset[$token.Extent.StartOffset] = $previous
        }
        $previous = $token
    }

    foreach ($function in $Functions) {
        $line = $function.Extent.StartLineNumber
        $block = $previousByOffset[$function.Extent.StartOffset]
        if ($block.Kind -ne [TokenKind]::Comment -or -not $block.Text.StartsWith('<#') -or
            $block.Extent.EndLineNumber -ne ($line - 1)) {
            [pscustomobject]@{ Line = $line; Rule = 'HelpPlacement'; Message = "$($function.Name) needs a block comment immediately above its definition." }
            continue
        }

        $body = $block.Text.Substring(2, $block.Text.Length - 4)
        $sections = @{}
        foreach ($section in ($body -split '(?m)^[\t ]*\.(?=\w+(?:[\t \r\n]|$))' | Select-Object -Skip 1)) {
            $header, $content = $section -split '\r?\n', 2
            $key = $header.Trim() -replace '[\t ]+', ' '
            $sections[$key] += @(-not [string]::IsNullOrWhiteSpace($content))
        }
        foreach ($heading in 'SYNOPSIS', 'DESCRIPTION') {
            if ($true -notin $sections[$heading]) {
                [pscustomobject]@{ Line = $line; Rule = 'HelpSection'; Message = "$($function.Name) needs nonblank .$heading text in its help block." }
            }
        }
        foreach ($parameter in @($function.Parameters) + @($function.Body.ParamBlock.Parameters)) {
            if ($null -eq $parameter) { continue }
            $name = $parameter.Name.VariablePath.UserPath
            $entries = $sections["PARAMETER $name"]
            if ($entries.Count -ne 1 -or -not $entries[0]) {
                [pscustomobject]@{ Line = $line; Rule = 'HelpParameter'; Message = "$($function.Name) needs exactly one nonblank .PARAMETER $name entry." }
            }
        }
    }
}

<#
.SYNOPSIS
Finds positional arguments to statically identifiable PowerShell commands.
.DESCRIPTION
Uses command metadata to distinguish switches from named arguments that consume a value. Dynamic invocations are not resolved.
.PARAMETER Commands
Command ASTs from the source being checked.
.PARAMETER LocalDefinitions
Map from repository function names to definitions with their lexical scope and parameter flags.
.PARAMETER RuntimeParameters
Cache of command metadata and failed lookups for this scan.
#>
function Get-PositionalCommandFinding {
    param([array]$Commands, [hashtable]$LocalDefinitions, [hashtable]$RuntimeParameters)

    foreach ($command in $Commands) {
        $elements = $command.CommandElements
        if ($elements.Count -lt 2) { continue }
        $name = $command.GetCommandName()
        if (-not $name -or $name -match '[\[\]*?/]') { continue }
        $key = $name -replace '^(global|script|local|private):'
        $definitions = $LocalDefinitions[$key]
        $visible = @()
        if ($definitions) {
            for ($scope = $command.Parent; $scope; $scope = $scope.Parent) {
                if ($scope -isnot [ScriptBlockAst]) { continue }
                $visible = @($definitions | Where-Object -FilterScript { $_.Scope -eq $scope })
                if ($visible.Count -gt 0) { break }
            }
            if ($visible.Count -eq 0) {
                $visible = @($definitions | Where-Object -FilterScript { $null -eq $_.Scope.Parent })
            }
        }
        if ($visible.Count -gt 1) {
            [pscustomobject]@{ Line = $command.Extent.StartLineNumber; Rule = 'CommandAmbiguity'; Message = "Multiple definitions of $name are in scope; cannot check its arguments." }
            continue
        }
        if ($visible.Count -eq 1) {
            $parameters = $visible[0].Parameters
        } else {
            if (-not $RuntimeParameters.ContainsKey($name)) {
                $metadata = Get-Command -Name $name -CommandType Alias, Cmdlet, Function, Filter -ErrorAction Ignore |
                    Select-Object -First 1
                if ($metadata.CommandType -eq 'Alias') { $metadata = $metadata.ResolvedCommand }
                $map = $null
                if ($metadata.CommandType -in 'Cmdlet', 'Function', 'Filter') {
                    $map = @{}
                    foreach ($parameter in $metadata.Parameters.Values) {
                        $isSwitch = $parameter.ParameterType -eq [switch]
                        $map[$parameter.Name] = $isSwitch
                        foreach ($alias in $parameter.Aliases) { $map[$alias] = $isSwitch }
                    }
                }
                $RuntimeParameters[$name] = $map
            }
            $parameters = $RuntimeParameters[$name]
        }
        if ($null -eq $parameters) { continue }

        for ($index = 1; $index -lt $elements.Count; $index++) {
            $element = $elements[$index]
            if ($element -is [CommandParameterAst]) {
                if ($element.Argument) { continue }
                $parameterName = $element.ParameterName
                $isSwitch = $parameters[$parameterName]
                if (-not $parameters.ContainsKey($parameterName)) {
                    $candidates = @($parameters.Keys | Where-Object -FilterScript { $_.StartsWith($parameterName, [StringComparison]::OrdinalIgnoreCase) })
                    $isSwitch = $candidates.Count -eq 1 -and $parameters[$candidates[0]]
                }
                $next = if ($index + 1 -lt $elements.Count) { $elements[$index + 1] }
                if (-not $isSwitch -and $next -and $next -isnot [CommandParameterAst] -and
                    -not ($next -is [VariableExpressionAst] -and $next.Splatted)) { $index++ }
                continue
            }
            if ($element -is [VariableExpressionAst] -and $element.Splatted) { continue }
            [pscustomobject]@{
                Line = $element.Extent.StartLineNumber
                Rule = 'PositionalArgument'
                Message = "Use a named argument or splat for $name (column $($element.Extent.StartColumnNumber))."
                Command = $command
                Argument = $element
            }
        }
    }
}

<#
.SYNOPSIS
Reports PowerShell source style violations.
.DESCRIPTION
Parses source without executing it. Checks comment help and calls to PowerShell functions and cmdlets, including calls to functions defined in other files in the supplied inventory.
.PARAMETER Source
PowerShell text to check.
.PARAMETER Path
Name to display for a source fixture.
.PARAMETER RepositoryRoot
Directory containing the repository files.
.PARAMETER Paths
Repository-relative PowerShell paths.
#>
function Get-PowerShellStyleFinding {
    [CmdletBinding(DefaultParameterSetName = 'Source')]
    param(
        [Parameter(Mandatory, ParameterSetName = 'Source')][AllowEmptyString()][string]$Source,
        [Parameter(Mandatory, ParameterSetName = 'Source')][string]$Path,
        [Parameter(Mandatory, ParameterSetName = 'Repository')][string]$RepositoryRoot,
        [Parameter(Mandatory, ParameterSetName = 'Repository')][string[]]$Paths
    )

    $parsedFiles = [System.Collections.Generic.List[object]]::new()
    $localDefinitions = @{}
    $runtimeParameters = @{}
    foreach ($file in @($Path) + @($Paths)) {
        if (-not $file) { continue }
        $tokens = $null
        $errors = $null
        $ast = if ($PSCmdlet.ParameterSetName -eq 'Source') {
            [Parser]::ParseInput($Source, [ref]$tokens, [ref]$errors)
        } else {
            [Parser]::ParseFile((Join-Path -Path $RepositoryRoot -ChildPath $file), [ref]$tokens, [ref]$errors)
        }
        foreach ($parseError in $errors) {
            [pscustomobject]@{ Path = $file; Line = $parseError.Extent.StartLineNumber; Rule = 'ParseError'; Message = $parseError.Message }
        }
        if ($errors.Count -gt 0) { continue }

        $functions = $ast.FindAll({ $args[0] -is [FunctionDefinitionAst] }, $true)
        $parsedFiles.Add(@{ Path = $file; Ast = $ast; Tokens = $tokens; Functions = $functions })
        foreach ($function in $functions) {
            $name = $function.Name -replace '^(global|script|local|private):'
            $scope = $function.Parent
            if ($function.Name -match '^(global|script):') {
                $scope = $ast
            } else {
                while ($scope -isnot [ScriptBlockAst]) { $scope = $scope.Parent }
            }
            $map = @{ Verbose = $true; Debug = $true; WhatIf = $true; Confirm = $true; vb = $true; db = $true; wi = $true; cf = $true }
            $localDefinitions[$name] += @(@{ Scope = $scope; Parameters = $map })
            foreach ($parameter in @($function.Parameters) + @($function.Body.ParamBlock.Parameters)) {
                if ($null -eq $parameter) { continue }
                $isSwitch = $parameter.StaticType -eq [switch]
                $map[$parameter.Name.VariablePath.UserPath] = $isSwitch
                foreach ($attribute in $parameter.Attributes) {
                    if ($attribute -is [AttributeAst] -and $attribute.TypeName.Name -in 'Alias', 'AliasAttribute') {
                        foreach ($argument in $attribute.PositionalArguments) {
                            if ($argument -is [StringConstantExpressionAst]) { $map[$argument.Value] = $isSwitch }
                        }
                    }
                }
            }
        }
    }

    foreach ($parsed in $parsedFiles) {
        $commands = $parsed.Ast.FindAll({ $args[0] -is [CommandAst] }, $true)
        $findings = @(
            Get-FunctionHelpFinding -Functions $parsed.Functions -Tokens $parsed.Tokens
            Get-PositionalCommandFinding -Commands $commands -LocalDefinitions $localDefinitions -RuntimeParameters $runtimeParameters
        )
        foreach ($finding in $findings) {
            $finding | Add-Member -NotePropertyName Path -NotePropertyValue $parsed.Path -PassThru
        }
    }
}

<#
.SYNOPSIS
Lists the PowerShell files in the repository index.
.DESCRIPTION
Uses the index as the inventory, without reading ignored or untracked paths. Callers read the contents from the supplied checkout.
.PARAMETER RepositoryRoot
Directory at the root of the Git checkout.
#>
function Get-TrackedPowerShellPath {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][string]$RepositoryRoot)

    $paths = @(git -C $RepositoryRoot -c core.quotepath=false ls-files --cached -- '*.ps1' '*.psm1' '*.psd1')
    if ($LASTEXITCODE -ne 0 -or $paths.Count -eq 0) {
        throw 'Could not list tracked PowerShell files.'
    }
    foreach ($path in $paths) {
        [string]$path
    }
}

<#
.SYNOPSIS
Runs PSScriptAnalyzer with BridgeWatcher's path and severity policy.
.DESCRIPTION
Uses the supplied path inventory. Reports Error, Warning, and Information except under scripts/, where only Error and Warning apply.
.PARAMETER RepositoryRoot
Directory containing the files and PSScriptAnalyzer settings.
.PARAMETER Paths
Repository-relative PowerShell files to lint.
#>
function Invoke-PowerShellPolicyLint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RepositoryRoot,
        [Parameter(Mandatory)][string[]]$Paths
    )

    $settings = Join-Path -Path $RepositoryRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
    foreach ($path in $Paths) {
        $severity = if ($path -like 'scripts/*') { 'Error', 'Warning' } else { 'Error', 'Warning', 'Information' }
        $file = Join-Path -Path $RepositoryRoot -ChildPath $path
        Invoke-ScriptAnalyzer -Path $file -Settings $settings -Severity $severity -ErrorAction Stop
    }
}

Export-ModuleMember -Function Get-TrackedPowerShellPath, Get-PowerShellStyleFinding, Invoke-PowerShellPolicyLint
