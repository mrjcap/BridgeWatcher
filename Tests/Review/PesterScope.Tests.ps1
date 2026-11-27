$AutomaticVariables = @(
    '_', 'input', 'args', 'this', 'true', 'false', 'null', 'MyInvocation',
    'PSScriptRoot', 'PSCommandPath', 'ExecutionContext', 'Host', 'PID', 'Home',
    'Error', 'EventError', 'foreach', 'LastExitCode', 'NestedPromptLevel',
    'Profile', 'PSBoundParameters', 'PSCulture', 'PSDebugContext',
    'PSHome', 'PSSenderInfo', 'PSUICulture', 'PSVersionTable', 'Pwd',
    'ShellId', 'StackTrace', 'Matches'
)

$TestFiles = Get-ChildItem -Path "$PSScriptRoot/.." -Filter *.Tests.ps1 -Recurse | Where-Object {
    $_.FullName -notlike "*Review*"
}

Describe "Pester 5 Scope Rule Compliance" {
    BeforeAll {
        function Get-BeforeAllScriptBlock {
            <#
            .SYNOPSIS
            Extracts the direct ScriptBlockExpressionAst argument from a BeforeAll CommandAst.

            .PARAMETER CommandAst
            The CommandAst representing a BeforeAll invocation.
            #>
            [CmdletBinding()]
            [OutputType([System.Management.Automation.Language.ScriptBlockExpressionAst])]
            param(
                [Parameter(Mandatory)]
                [System.Management.Automation.Language.CommandAst]$CommandAst
            )

            $elements = $CommandAst.CommandElements
            for ($i = 1; $i -lt $elements.Count; $i++) {
                $element = $elements[$i]
                if ($element -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) {
                    return $element
                }
                if ($element -is [System.Management.Automation.Language.CommandParameterAst] -and
                    $element.ParameterName -eq 'ScriptBlock' -and
                    $element.Argument -is [System.Management.Automation.Language.ScriptBlockExpressionAst]) {
                    return $element.Argument
                }
            }
            return $null
        }
    }

    It "Should use `$script:` scope for variables initialized inside BeforeAll blocks in <Name>" -ForEach $TestFiles {
        $file = $_
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

        $beforeAlls = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'BeforeAll'
        }, $true)

        $violations = [System.Collections.Generic.List[PSCustomObject]]::new()

        foreach ($ba in $beforeAlls) {
            $sb = Get-BeforeAllScriptBlock -CommandAst $ba
            if (-not $sb) { continue }

            $assignments = $sb.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst]
            }, $true)

            foreach ($assign in $assignments) {
                $parent = $assign.Parent
                $isNestedScope = $false
                while ($parent -and $parent -ne $sb) {
                    if ($parent -is [System.Management.Automation.Language.ScriptBlockExpressionAst] -or
                        $parent -is [System.Management.Automation.Language.FunctionDefinitionAst]) {
                        $isNestedScope = $true
                        break
                    }
                    $parent = $parent.Parent
                }
                if ($isNestedScope) { continue }

                $left = $assign.Left
                if ($left -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    $varPath = $left.VariablePath
                    $varName = $varPath.UserPath

                    if (-not ($varPath.IsScript -or $varPath.IsGlobal) -and $varName -notin $AutomaticVariables) {
                        $violations.Add([PSCustomObject]@{
                            Variable = $varName
                            Line     = $assign.Extent.StartLineNumber
                            Code     = $assign.Extent.Text.Trim()
                        })
                    }
                }
            }
        }

        $violationMessage = ""
        if ($violations.Count -gt 0) {
            $violationMessage = $violations | ForEach-Object { "Line $($_.Line): Variable '$($_.Variable)' is unscoped. Code: '$($_.Code)'" } | Out-String
        }

        $violationMessage | Should -BeNullOrEmpty
    }

    Context 'Verification of BeforeAll CommandElements extraction' {
        It 'Extracts positional and named -ScriptBlock arguments directly' {
            foreach ($snippet in @(
                'BeforeAll { $script:a = 1 }',
                'BeforeAll -ScriptBlock { $script:a = 1 }',
                'BeforeAll -ScriptBlock:{ $script:a = 1 }'
            )) {
                $ast = [System.Management.Automation.Language.Parser]::ParseInput($snippet, [ref]$null, [ref]$null)
                $cmd = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
                $sb = Get-BeforeAllScriptBlock -CommandAst $cmd
                $sb | Should -Not -BeNullOrEmpty
                $sb.Extent.Text | Should -Be '{ $script:a = 1 }'
            }
        }

        It 'Does not recursively match nested script blocks inside non-ScriptBlock arguments' {
            $ast = [System.Management.Automation.Language.Parser]::ParseInput('BeforeAll (Get-Item | Where-Object { $x = 1 })', [ref]$null, [ref]$null)
            $cmd = $ast.Find({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
            $sb = Get-BeforeAllScriptBlock -CommandAst $cmd
            $sb | Should -BeNullOrEmpty
        }
    }
}

