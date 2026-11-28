using namespace System.Management.Automation.Language

<#
.SYNOPSIS
Maps each function or filter token offset to the immediately preceding non-newline token.
.DESCRIPTION
Walks parsed tokens in order so help placement checks can inspect the adjacent comment block without scanning backward.
.PARAMETER Tokens
Tokens from the parsed PowerShell source.
#>
function Get-PreviousTokenByFunctionOffset {
    param([Token[]]$Tokens)

    $previousByOffset = @{}
    $previous = $null
    foreach ($token in $Tokens) {
        if ($token.Kind -eq [TokenKind]::NewLine) { continue }
        if ($token.Kind -eq [TokenKind]::Function -or $token.Kind -eq [TokenKind]::Filter) {
            $previousByOffset[$token.Extent.StartOffset] = $previous
        }
        $previous = $token
    }
    return $previousByOffset
}

<#
.SYNOPSIS
Tests whether a token is a block comment immediately above a function line.
.DESCRIPTION
Verifies the token kind is Comment, starts with a block comment marker, and ends on the line preceding the function definition.
.PARAMETER Block
Candidate token immediately before the function definition.
.PARAMETER StartLine
Starting line number of the function definition.
#>
function Test-AdjacentHelpBlock {
    param($Block, [int]$StartLine)

    if ($null -eq $Block) { return $false }
    return (
        $Block.Kind -eq [TokenKind]::Comment -and
        $Block.Text.StartsWith('<#') -and
        $Block.Extent.EndLineNumber -eq ($StartLine - 1)
    )
}

<#
.SYNOPSIS
Parses comment-based help sections from a block comment string.
.DESCRIPTION
Splits the block comment body on dot-prefixed help headings and records whether each heading has nonblank content.
.PARAMETER BlockText
Full text of the block comment token including delimiters.
#>
function Get-HelpCommentSectionMap {
    param([string]$BlockText)

    $body = $BlockText.Substring(2, $BlockText.Length - 4)
    $sections = @{}
    foreach ($section in ($body -split '(?m)^[\t ]*\.(?=\w+(?:[\t \r\n]|$))' | Select-Object -Skip 1)) {
        $header, $content = $section -split '\r?\n', 2
        $key = $header.Trim() -replace '[\t ]+', ' '
        $sections[$key] += @(-not [string]::IsNullOrWhiteSpace($content))
    }
    return $sections
}

<#
.SYNOPSIS
Evaluates comment-based help rules for a single function definition.
.DESCRIPTION
Checks adjacent block comment placement, required SYNOPSIS and DESCRIPTION headings, and exact nonblank PARAMETER entries.
.PARAMETER Function
Function definition AST to inspect.
.PARAMETER Block
Token immediately preceding the function definition.
#>
function Get-SingleFunctionHelpFinding {
    param([FunctionDefinitionAst]$Function, $Block)

    $line = $Function.Extent.StartLineNumber
    if (-not (Test-AdjacentHelpBlock -Block $Block -StartLine $line)) {
        [pscustomobject]@{ Line = $line; Rule = 'HelpPlacement'; Message = "$($Function.Name) needs a block comment immediately above its definition." }
        return
    }

    $sections = Get-HelpCommentSectionMap -BlockText $Block.Text
    foreach ($heading in 'SYNOPSIS', 'DESCRIPTION') {
        if ($true -notin $sections[$heading]) {
            [pscustomobject]@{ Line = $line; Rule = 'HelpSection'; Message = "$($Function.Name) needs nonblank .$heading text in its help block." }
        }
    }
    foreach ($parameter in @($Function.Parameters) + @($Function.Body.ParamBlock.Parameters)) {
        if ($null -eq $parameter) { continue }
        $name = $parameter.Name.VariablePath.UserPath
        $entries = $sections["PARAMETER $name"]
        if ($entries.Count -ne 1 -or -not $entries[0]) {
            [pscustomobject]@{ Line = $line; Rule = 'HelpParameter'; Message = "$($Function.Name) needs exactly one nonblank .PARAMETER $name entry." }
        }
    }
}

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

    $previousByOffset = Get-PreviousTokenByFunctionOffset -Tokens $Tokens
    foreach ($function in $Functions) {
        $block = $previousByOffset[$function.Extent.StartOffset]
        Get-SingleFunctionHelpFinding -Function $function -Block $block
    }
}

<#
.SYNOPSIS
Finds repository-defined functions visible at a command call site.
.DESCRIPTION
Walks enclosing script block scopes from innermost to outermost and falls back to top-level definitions.
.PARAMETER Command
Command AST being evaluated.
.PARAMETER CommandName
Name of the invoked command.
.PARAMETER LocalDefinitions
Map from function names to scoped definition entries.
#>
function Resolve-LocalCommandDefinition {
    param([CommandAst]$Command, [string]$CommandName, [hashtable]$LocalDefinitions)

    $key = $CommandName -replace '^(global|script|local|private):'
    $definitions = $LocalDefinitions[$key]
    if (-not $definitions) { return @() }

    for ($scope = $Command.Parent; $scope; $scope = $scope.Parent) {
        if ($scope -isnot [ScriptBlockAst]) { continue }
        $visible = @($definitions | Where-Object -FilterScript { $_.Scope -eq $scope })
        if ($visible.Count -gt 0) { return $visible }
    }
    return @($definitions | Where-Object -FilterScript { $null -eq $_.Scope.Parent })
}

<#
.SYNOPSIS
Resolves and caches parameter switch flags for a runtime command.
.DESCRIPTION
Queries PowerShell command metadata once per command name and records parameter names and aliases with their switch status.
.PARAMETER CommandName
Command name to resolve.
.PARAMETER RuntimeParameters
Cache of resolved runtime parameter maps.
#>
function Get-RuntimeParameterMap {
    param([string]$CommandName, [hashtable]$RuntimeParameters)

    if ($RuntimeParameters.ContainsKey($CommandName)) {
        return $RuntimeParameters[$CommandName]
    }

    $metadata = Get-Command -Name $CommandName -CommandType Alias, Cmdlet, Function, Filter -ErrorAction Ignore |
        Select-Object -First 1
    if ($metadata.CommandType -eq 'Alias') {
        $metadata = $metadata.ResolvedCommand
    }
    if ($metadata.CommandType -notin 'Cmdlet', 'Function', 'Filter') {
        $RuntimeParameters[$CommandName] = $null
        return $null
    }

    $map = @{}
    foreach ($parameter in $metadata.Parameters.Values) {
        $isSwitch = $parameter.ParameterType -eq [switch]
        $map[$parameter.Name] = $isSwitch
        foreach ($alias in $parameter.Aliases) {
            $map[$alias] = $isSwitch
        }
    }
    $RuntimeParameters[$CommandName] = $map
    return $map
}

<#
.SYNOPSIS
Resolves parameter metadata for a command from local or runtime definitions.
.DESCRIPTION
Prefers local lexical definitions, flags ambiguous definitions in the same scope, and falls back to runtime command metadata.
.PARAMETER Command
Command AST being checked.
.PARAMETER CommandName
Static command name extracted from the AST.
.PARAMETER LocalDefinitions
Map from repository function names to definitions with their lexical scope and parameter flags.
.PARAMETER RuntimeParameters
Cache of command metadata and failed lookups for this scan.
#>
function Resolve-CommandParameterMap {
    param([CommandAst]$Command, [string]$CommandName, [hashtable]$LocalDefinitions, [hashtable]$RuntimeParameters)

    $visible = @(Resolve-LocalCommandDefinition -Command $Command -CommandName $CommandName -LocalDefinitions $LocalDefinitions)
    if ($visible.Count -gt 1) {
        return @{ Ambiguous = $true; Parameters = $null }
    }
    if ($visible.Count -eq 1) {
        return @{ Ambiguous = $false; Parameters = $visible[0].Parameters }
    }
    $runtimeMap = Get-RuntimeParameterMap -CommandName $CommandName -RuntimeParameters $RuntimeParameters
    return @{ Ambiguous = $false; Parameters = $runtimeMap }
}

<#
.SYNOPSIS
Determines whether a parameter name matches a switch parameter.
.DESCRIPTION
Checks exact parameter names first and falls back to unambiguous prefix matches against the command parameter map.
.PARAMETER Parameters
Map of parameter names and aliases to boolean switch flags.
.PARAMETER ParameterName
Parameter name used at the call site.
#>
function Test-SwitchParameterName {
    param([hashtable]$Parameters, [string]$ParameterName)

    if ($Parameters.ContainsKey($ParameterName)) {
        return [bool]$Parameters[$ParameterName]
    }
    $candidates = @($Parameters.Keys | Where-Object -FilterScript { $_.StartsWith($ParameterName, [StringComparison]::OrdinalIgnoreCase) })
    return ($candidates.Count -eq 1 -and [bool]$Parameters[$candidates[0]])
}

<#
.SYNOPSIS
Tests whether a named parameter element consumes the following command element as its value.
.DESCRIPTION
Returns true when the parameter has no inline argument, is not a switch, and is followed by a non-parameter, non-splatted value.
.PARAMETER Elements
Command element AST array.
.PARAMETER Index
Index of the current parameter element.
.PARAMETER Parameters
Parameter switch map for the invoked command.
.PARAMETER Element
Current command parameter AST element.
#>
function Test-ConsumesParameterValue {
    param([array]$Elements, [int]$Index, [hashtable]$Parameters, [CommandParameterAst]$Element)

    if ($Element.Argument) { return $false }
    if (Test-SwitchParameterName -Parameters $Parameters -ParameterName $Element.ParameterName) { return $false }
    if ($Index + 1 -ge $Elements.Count) { return $false }

    $next = $Elements[$Index + 1]
    if ($next -is [CommandParameterAst]) { return $false }
    return -not ($next -is [VariableExpressionAst] -and $next.Splatted)
}

<#
.SYNOPSIS
Reports positional argument violations for a single command invocation.
.DESCRIPTION
Walks command elements after the command name, skipping named parameters, their consumed values, and splatted variables.
.PARAMETER Command
Command AST being checked.
.PARAMETER CommandName
Resolved command name for error messages.
.PARAMETER Parameters
Parameter switch map for the command.
#>
function Get-CommandPositionalArgumentFinding {
    param([CommandAst]$Command, [string]$CommandName, [hashtable]$Parameters)

    $elements = $Command.CommandElements
    for ($index = 1; $index -lt $elements.Count; $index++) {
        $element = $elements[$index]
        if ($element -is [CommandParameterAst]) {
            if (Test-ConsumesParameterValue -Elements $elements -Index $index -Parameters $Parameters -Element $element) {
                $index++
            }
            continue
        }
        if ($element -is [VariableExpressionAst] -and $element.Splatted) { continue }
        [pscustomobject]@{
            Line     = $element.Extent.StartLineNumber
            Rule     = 'PositionalArgument'
            Message  = "Use a named argument or splat for $CommandName (column $($element.Extent.StartColumnNumber))."
            Command  = $Command
            Argument = $element
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
        if ($command.CommandElements.Count -lt 2) { continue }
        $name = $command.GetCommandName()
        if (-not $name -or $name -match '[\[\]*?/]') { continue }

        $resolved = Resolve-CommandParameterMap -Command $command -CommandName $name -LocalDefinitions $LocalDefinitions -RuntimeParameters $RuntimeParameters
        if ($resolved.Ambiguous) {
            [pscustomobject]@{ Line = $command.Extent.StartLineNumber; Rule = 'CommandAmbiguity'; Message = "Multiple definitions of $name are in scope; cannot check its arguments." }
            continue
        }
        if ($null -eq $resolved.Parameters) { continue }

        Get-CommandPositionalArgumentFinding -Command $command -CommandName $name -Parameters $resolved.Parameters
    }
}

<#
.SYNOPSIS
Adds parameter alias entries from Alias attributes into a parameter switch map.
.DESCRIPTION
Inspects parameter attributes for Alias declarations and records string constant alias names with the parameter's switch flag.
.PARAMETER Map
Parameter switch map to update.
.PARAMETER Parameter
Parameter AST whose attributes are inspected.
.PARAMETER IsSwitch
Whether the parameter is a switch parameter.
#>
function Add-ParameterAliasEntry {
    param([hashtable]$Map, [ParameterAst]$Parameter, [bool]$IsSwitch)

    foreach ($attribute in $Parameter.Attributes) {
        $isAliasAttribute = $attribute -is [AttributeAst] -and $attribute.TypeName.Name -in 'Alias', 'AliasAttribute'
        if (-not $isAliasAttribute) { continue }
        foreach ($argument in $attribute.PositionalArguments) {
            if ($argument -is [StringConstantExpressionAst]) {
                $Map[$argument.Value] = $IsSwitch
            }
        }
    }
}

<#
.SYNOPSIS
Builds a parameter switch map for a parsed function definition.
.DESCRIPTION
Starts with PowerShell common switch parameters and adds each declared parameter and alias from the function AST.
.PARAMETER Function
Function definition AST to inspect.
#>
function Get-FunctionParameterMap {
    param([FunctionDefinitionAst]$Function)

    $map = @{ Verbose = $true; Debug = $true; WhatIf = $true; Confirm = $true; vb = $true; db = $true; wi = $true; cf = $true }
    foreach ($parameter in @($Function.Parameters) + @($Function.Body.ParamBlock.Parameters)) {
        if ($null -eq $parameter) { continue }
        $isSwitch = $parameter.StaticType -eq [switch]
        $map[$parameter.Name.VariablePath.UserPath] = $isSwitch
        Add-ParameterAliasEntry -Map $map -Parameter $parameter -IsSwitch $isSwitch
    }
    return $map
}

<#
.SYNOPSIS
Registers parsed function definitions in the local scope lookup table.
.DESCRIPTION
Determines each function's lexical script block scope and stores its parameter switch map under its normalized name.
.PARAMETER Functions
Function definition ASTs discovered in the file.
.PARAMETER Ast
Root script block AST of the file.
.PARAMETER LocalDefinitions
Shared map from function names to scoped definition entries.
#>
function Register-FunctionDefinition {
    param([array]$Functions, [ScriptBlockAst]$Ast, [hashtable]$LocalDefinitions)

    foreach ($function in $Functions) {
        $name = $function.Name -replace '^(global|script|local|private):'
        $scope = $function.Parent
        if ($function.Name -match '^(global|script):') {
            $scope = $Ast
        } else {
            while ($scope -isnot [ScriptBlockAst]) { $scope = $scope.Parent }
        }
        $map = Get-FunctionParameterMap -Function $function
        $LocalDefinitions[$name] += @(@{ Scope = $scope; Parameters = $map })
    }
}

<#
.SYNOPSIS
Parses a PowerShell source string or repository file into AST, tokens, and parse errors.
.DESCRIPTION
Dispatches to Parser::ParseInput for inline fixtures or Parser::ParseFile for repository paths without executing code.
.PARAMETER ParameterSetName
Active parameter set name ('Source' or 'Repository').
.PARAMETER Source
Inline PowerShell source text when using the Source parameter set.
.PARAMETER RepositoryRoot
Repository root directory when using the Repository parameter set.
.PARAMETER File
Display path or repository-relative path of the PowerShell source.
#>
function Read-PowerShellSourceFile {
    param([string]$ParameterSetName, [string]$Source, [string]$RepositoryRoot, [string]$File)

    $tokens = $null
    $errors = $null
    $ast = if ($ParameterSetName -eq 'Source') {
        [Parser]::ParseInput($Source, [ref]$tokens, [ref]$errors)
    } else {
        [Parser]::ParseFile((Join-Path -Path $RepositoryRoot -ChildPath $File), [ref]$tokens, [ref]$errors)
    }
    return @{ Path = $File; Ast = $ast; Tokens = $tokens; Errors = $errors }
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
        $parsed = Read-PowerShellSourceFile -ParameterSetName $PSCmdlet.ParameterSetName -Source $Source -RepositoryRoot $RepositoryRoot -File $file
        foreach ($parseError in $parsed.Errors) {
            [pscustomobject]@{ Path = $file; Line = $parseError.Extent.StartLineNumber; Rule = 'ParseError'; Message = $parseError.Message }
        }
        if ($parsed.Errors.Count -gt 0) { continue }

        $functions = $parsed.Ast.FindAll({ $args[0] -is [FunctionDefinitionAst] }, $true)
        $parsedFiles.Add(@{ Path = $file; Ast = $parsed.Ast; Tokens = $parsed.Tokens; Functions = $functions })
        Register-FunctionDefinition -Functions $functions -Ast $parsed.Ast -LocalDefinitions $localDefinitions
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
