Import-Module "$PSScriptRoot/../../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Retry Jitter Requirement Review' {
    BeforeAll {
        $script:PublicPath = Resolve-Path "$PSScriptRoot/../../BridgeWatcher/Public"
        $script:PrivatePath = Resolve-Path "$PSScriptRoot/../../BridgeWatcher/Private"

        # AST analysis helper function to find retry jitter violations
        function Get-RetryJitterViolation {
            <#
            .SYNOPSIS
                Finds retry jitter violations in AST.
            #>
            param([string]$Content)

            $violations = [System.Collections.Generic.List[string]]::new()
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$errors)

            $loops = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.LoopStatementAst] -or
                $node -is [System.Management.Automation.Language.ForStatementAst] -or
                $node -is [System.Management.Automation.Language.ForEachStatementAst]
            }, $true)

            foreach ($loop in $loops) {
                $sleeps = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Start-Sleep'
                }, $true)

                if ($sleeps.Count -eq 0) {
                    continue
                }

                $hasNetworkCall = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -in @('Invoke-WebRequest', 'Invoke-RestMethod')
                }, $true).Count -gt 0

                $hasCatchSleep = $false
                foreach ($sleep in $sleeps) {
                    $parent = $sleep.Parent
                    while ($null -ne $parent -and $parent -ne $loop) {
                        if ($parent -is [System.Management.Automation.Language.CatchClauseAst]) {
                            $hasCatchSleep = $true
                            break
                        }
                        $parent = $parent.Parent
                    }
                }

                $hasBackoffCalc = $loop.FindAll({
                    param($node)
                    ($node -is [System.Management.Automation.Language.MemberExpressionAst] -and
                     $node.Expression.Extent.Text -eq '[Math]' -and
                     $node.Member.Extent.Text -eq 'Pow') -or
                    ($node -is [System.Management.Automation.Language.BinaryExpressionAst] -and
                     $node.Operator -in @('Multiply', 'Plus') -and
                     $node.Left.Extent.Text -match '\b(i|retry|count|delay)\b')
                }, $true).Count -gt 0

                $isRetryLoop = $hasNetworkCall -or $hasCatchSleep -or $hasBackoffCalc

                if ($isRetryLoop) {
                    $hasJitter = $loop.FindAll({
                        param($node)
                        $node -is [System.Management.Automation.Language.CommandAst] -and
                        $node.GetCommandName() -eq 'Get-Random'
                    }, $true).Count -gt 0

                    if (-not $hasJitter) {
                        $violations.Add("Loop at line $($loop.Extent.StartLineNumber) lacks Get-Random or jitter mechanism.")
                    }
                }
            }
            return $violations
        }
    }

    Context 'Codebase Compliance' {
        It 'Verifies that every retry/backoff loop in the codebase has jitter' {
            $files = Get-ChildItem -Path $script:PublicPath, $script:PrivatePath -Filter *.ps1 -Recurse
            $allViolations = [System.Collections.Generic.List[string]]::new()

            foreach ($file in $files) {
                $content = Get-Content -Path $file.FullName -Raw
                $violations = @(Get-RetryJitterViolation -Content $content)
                foreach ($v in $violations) {
                    $allViolations.Add("[$($file.Name)] $v")
                }
            }

            $allViolations.Count | Should -Be 0
        }
    }

    Context 'Verification of the Rule Checker (Adversarial Tests)' {
        It 'Fails when a loop has a fixed retry schedule without jitter' {
            $badCode = @"
function Test-BadMock {
    for (`$i = 1; `$i -le 3; `$i++) {
        try {
            Invoke-WebRequest -Uri 'http://example.com'
        } catch {
            Start-Sleep -Seconds 5
        }
    }
}
"@
            $violations = @(Get-RetryJitterViolation -Content $badCode)
            $violations.Count | Should -BeGreaterThan 0
            $violations[0] | Should -Match 'lacks Get-Random'
        }

        It 'Fails when a loop has exponential backoff without jitter' {
            $badCode = @"
function Test-BadMock {
    for (`$i = 1; `$i -le 3; `$i++) {
        try {
            Invoke-RestMethod -Uri 'http://example.com'
        } catch {
            `$sleep = [Math]::Pow(2, `$i)
            Start-Sleep -Seconds `$sleep
        }
    }
}
"@
            $violations = @(Get-RetryJitterViolation -Content $badCode)
            $violations.Count | Should -BeGreaterThan 0
            $violations[0] | Should -Match 'lacks Get-Random'
        }

        It 'Passes when a loop has backoff with jitter' {
            $goodCode = @"
function Test-GoodMock {
    for (`$i = 1; `$i -le 3; `$i++) {
        try {
            Invoke-RestMethod -Uri 'http://example.com'
        } catch {
            `$sleep = [Math]::Pow(2, `$i)
            `$jitter = Get-Random -Minimum 0 -Maximum 3
            Start-Sleep -Seconds (`$sleep + `$jitter)
        }
    }
}
"@
            $violations = @(Get-RetryJitterViolation -Content $goodCode)
            $violations.Count | Should -Be 0
        }
    }
}