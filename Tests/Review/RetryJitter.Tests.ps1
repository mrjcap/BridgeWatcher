Import-Module -Name "$PSScriptRoot/../../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'Retry Jitter Requirement Review' -Fixture {
    BeforeAll -Scriptblock {
        $script:PublicPath = Resolve-Path -Path "$PSScriptRoot/../../BridgeWatcher/Public"
        $script:PrivatePath = Resolve-Path -Path "$PSScriptRoot/../../BridgeWatcher/Private"

        <#
        .SYNOPSIS
            Checks if any sleep command is inside a catch block within the loop.

        .DESCRIPTION
        Matches sleep calls to catch clauses in the same retry loop.

        .PARAMETER Loop
        The loop AST to inspect.

        .PARAMETER Sleeps
        The sleep command ASTs associated with the loop.
        #>
        function Test-SleepInsideCatch {
            param($Loop, $Sleeps)
            foreach ($sleep in $Sleeps) {
                $parent = $sleep.Parent
                while ($null -ne $parent -and $parent -ne $Loop) {
                    if ($parent -is [System.Management.Automation.Language.CatchClauseAst]) {
                        return $true
                    }
                    $parent = $parent.Parent
                }
            }
            return $false
        }

        <#
        .SYNOPSIS
            Checks if a loop with Start-Sleep is a network retry or backoff loop.

        .DESCRIPTION
        Uses the sleep and error-handling structure to distinguish network retries from ordinary loops.

        .PARAMETER Loop
        The loop AST to inspect.

        .PARAMETER Sleeps
        The sleep command ASTs associated with the loop.
        #>
        function Test-IsRetryLoop {
            param($Loop, $Sleeps)
            if (Test-SleepInsideCatch -Loop $Loop -Sleeps $Sleeps) {
                return $true
            }

            $hasNetworkCall = $Loop.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -in @('Invoke-WebRequest', 'Invoke-RestMethod')
            }, $true).Count -gt 0
            if ($hasNetworkCall) {
                return $true
            }

            return $Loop.FindAll({
                param($node)
                ($node -is [System.Management.Automation.Language.MemberExpressionAst] -and
                 $node.Expression.Extent.Text -eq '[Math]' -and
                 $node.Member.Extent.Text -eq 'Pow') -or
                ($node -is [System.Management.Automation.Language.BinaryExpressionAst] -and
                 $node.Operator -in @('Multiply', 'Plus') -and
                 $node.Left.Extent.Text -match '\b(i|retry|count|delay)\b')
            }, $true).Count -gt 0
        }

        <#
        .SYNOPSIS
            Finds retry jitter violations in AST.

        .DESCRIPTION
        Parses a script and reports retry sleeps that do not vary their delay.

        .PARAMETER Content
        The source text to inspect.
        #>
        function Get-RetryJitterViolation {
            param([string]$Content)

            $violations = [System.Collections.Generic.List[string]]::new()
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$errors)

            $loops = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.LoopStatementAst]
            }, $true)

            foreach ($loop in $loops) {
                $sleeps = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Start-Sleep'
                }, $true)

                if ($sleeps.Count -eq 0 -or -not (Test-IsRetryLoop -Loop $loop -Sleeps $sleeps)) {
                    continue
                }

                $hasJitter = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Get-Random'
                }, $true).Count -gt 0

                if (-not $hasJitter) {
                    $violations.Add("Loop at line $($loop.Extent.StartLineNumber) lacks Get-Random or jitter mechanism.")
                }
            }
            return $violations
        }
    }

    Context -Name 'Codebase Compliance' -Fixture {
        It -Name 'Verifies that every retry/backoff loop in the codebase has jitter' -Test {
            $files = Get-ChildItem -Path $script:PublicPath, $script:PrivatePath -Filter *.ps1 -Recurse
            $allViolations = [System.Collections.Generic.List[string]]::new()

            foreach ($file in $files) {
                $content = Get-Content -Path $file.FullName -Raw
                $violations = @(Get-RetryJitterViolation -Content $content)
                foreach ($v in $violations) {
                    $allViolations.Add("[$($file.Name)] $v")
                }
            }

            $allViolations.Count | Should -Be -ExpectedValue 0
        }
    }

    Context -Name 'Verification of the Rule Checker (Adversarial Tests)' -Fixture {
        It -Name 'Fails when a loop has a fixed retry schedule without jitter' -Test {
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
            $violations.Count | Should -BeGreaterThan -ExpectedValue 0
            $violations[0] | Should -Match -RegularExpression 'lacks Get-Random'
        }

        It -Name 'Fails when a loop has exponential backoff without jitter' -Test {
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
            $violations.Count | Should -BeGreaterThan -ExpectedValue 0
            $violations[0] | Should -Match -RegularExpression 'lacks Get-Random'
        }

        It -Name 'Passes when a loop has backoff with jitter' -Test {
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
            $violations.Count | Should -Be -ExpectedValue 0
        }
    }
}