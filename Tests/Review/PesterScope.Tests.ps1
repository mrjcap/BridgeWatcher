$AutomaticVariables = @(
    '_', 'input', 'args', 'this', 'true', 'false', 'null', 'MyInvocation',
    'PSScriptRoot', 'PSCommandPath', 'ExecutionContext', 'Host', 'PID', 'Home',
    'Error', 'EventError', 'foreach', 'LastExitCode', 'NestedPromptLevel',
    'Profile', 'PSBoundParameters', 'PSCulture', 'PSDebugContext',
    'PSHome', 'PSSenderInfo', 'PSUICulture', 'PSVersionTable', 'Pwd',
    'ShellId', 'StackTrace', 'Matches'
)

# Find all .Tests.ps1 files in the Tests directory, excluding the Review subdirectory
$TestFiles = Get-ChildItem -Path "$PSScriptRoot/.." -Filter *.Tests.ps1 -Recurse | Where-Object {
    $_.FullName -notlike "*Review*"
}

Describe "Pester 5 Scope Rule Compliance" {
    It "Should use `$script:` scope for variables initialized inside BeforeAll blocks in <Name>" -ForEach $TestFiles {
        $file = $_
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$null, [ref]$null)

        # Find all BeforeAll commands
        $beforeAlls = $ast.FindAll({
            param($node)
            $node -is [System.Management.Automation.Language.CommandAst] -and
            $node.GetCommandName() -eq 'BeforeAll'
        }, $true)

        $violations = [System.Collections.Generic.List[PSCustomObject]]::new()

        foreach ($ba in $beforeAlls) {
            # Find the script block argument of BeforeAll
            $sb = $ba.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.ScriptBlockExpressionAst]
            }, $false) | Select-Object -First 1

            if (-not $sb) {
                # Fallback to search recursively if not found at top level
                $sb = $ba.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.ScriptBlockExpressionAst]
                }, $true) | Select-Object -First 1
            }

            if (-not $sb) { continue }

            # Find all AssignmentStatementAsts inside the BeforeAll script block
            $assignments = $sb.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst]
            }, $true)

            foreach ($assign in $assignments) {
                # Ensure this assignment is not nested inside another scriptblock expression
                # or function definition inside BeforeAll (which would have its own scope)
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

                # Check the target variable of the assignment
                $left = $assign.Left
                if ($left -is [System.Management.Automation.Language.VariableExpressionAst]) {
                    $varPath = $left.VariablePath
                    $varName = $varPath.UserPath

                    # Check if it doesn't use script: or global:
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
    }}

