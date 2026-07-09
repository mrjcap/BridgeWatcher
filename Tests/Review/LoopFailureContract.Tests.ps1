Import-Module "$PSScriptRoot/../../BridgeWatcher/BridgeWatcher.psd1" -Force

$script:PublicPath = Resolve-Path "$PSScriptRoot/../../BridgeWatcher/Public"
$script:PrivatePath = Resolve-Path "$PSScriptRoot/../../BridgeWatcher/Private"
$script:Files = Get-ChildItem -Path $script:PublicPath, $script:PrivatePath -Filter *.ps1 -Recurse | ForEach-Object {
    [PSCustomObject]@{
        Name     = $_.Name
        FullName = $_.FullName
    }
}

Describe "Loop Failure Contract Review" {
    BeforeAll {
        # AST analysis helper to find retry/polling/monitoring loops that violate the contract
        function Get-LoopFailureContractViolation {
            <#
            .SYNOPSIS
            Checks PowerShell code content for Loop Failure Contract violations.
            #>
            param([string]$Content)

            $violations = [System.Collections.Generic.List[string]]::new()
            $tokens = $null
            $errors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseInput($Content, [ref]$tokens, [ref]$errors)

            # Find all loops (while, for, foreach)
            $loops = $ast.FindAll({
                param($node)
                $node -is [System.Management.Automation.Language.LoopStatementAst] -or
                $node -is [System.Management.Automation.Language.ForStatementAst] -or
                $node -is [System.Management.Automation.Language.ForEachStatementAst]
            }, $true)

            foreach ($loop in $loops) {
                # Check if it has retry/polling/monitoring indicators:
                # - Contains 'Start-Sleep'
                # - OR performs HTTP/Web requests (Invoke-WebRequest, Invoke-RestMethod)
                $sleeps = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -eq 'Start-Sleep'
                }, $true)

                $webCalls = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -in @('Invoke-WebRequest', 'Invoke-RestMethod')
                }, $true)

                $isRetryOrPolling = ($sleeps.Count -gt 0) -or ($webCalls.Count -gt 0)

                if (-not $isRetryOrPolling) {
                    continue # Skip normal data-processing iteration loops
                }

                # Verify Requirement 1: Tracks failure count/state/iterations.
                # Must contain update expression (e.g. $i++, $count++), assignment (e.g., $consecutiveFailures = ...),
                # or a binary expression (comparison) checking a loop limit.
                $hasTracking = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.UnaryExpressionAst] -or
                    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -or
                    ($node -is [System.Management.Automation.Language.BinaryExpressionAst] -and
                     $node.Operator -in @('LessThan', 'LessThanOrEqual', 'GreaterThan', 'GreaterThanOrEqual', 'Equals', 'NotEquals'))
                }, $true).Count -gt 0

                if (-not $hasTracking) {
                    $violations.Add("Loop at line $($loop.Extent.StartLineNumber) is a retry/polling loop but lacks failure/iteration tracking.")
                }

                # Verify Requirement 2 & 3: Throws or reports failure when ALL iterations fail, and does not silently succeed.
                # Look for throw statements or ThrowTerminatingError invocations inside the loop or immediately following it.
                $hasThrow = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.ThrowStatementAst] -or
                    ($node -is [System.Management.Automation.Language.CommandAst] -and
                     $node.GetCommandName() -like '*ThrowTerminatingError*') -or
                    ($node -is [System.Management.Automation.Language.MemberExpressionAst] -and
                     $node.Member.Extent.Text -eq 'ThrowTerminatingError')
                }, $true).Count -gt 0

                if (-not $hasThrow) {
                    # Check if there is a throw statement immediately after the loop in the parent block (e.g. for while loops checking error state after)
                    $parent = $loop.Parent
                    if ($parent) {
                        $hasThrowAfter = $parent.FindAll({
                            param($node)
                            ($node -is [System.Management.Automation.Language.ThrowStatementAst] -or
                             ($node -is [System.Management.Automation.Language.CommandAst] -and
                              $node.GetCommandName() -like '*ThrowTerminatingError*') -or
                             ($node -is [System.Management.Automation.Language.MemberExpressionAst] -and
                              $node.Member.Extent.Text -eq 'ThrowTerminatingError')) -and
                            $node.Extent.StartOffset -gt $loop.Extent.EndOffset
                        }, $true).Count -gt 0
                        $hasThrow = $hasThrowAfter
                    }
                }

                if (-not $hasThrow) {
                    $violations.Add("Loop at line $($loop.Extent.StartLineNumber) lacks a throw or terminating error when all iterations fail.")
                }
            }

            return $violations
        }
    }

    Context "Static Analysis Check (Codebase Loop Failure Contract)" {
        It "Should follow Loop Failure Contract in <Name>" -ForEach $script:Files {
            $file = $_
            $content = Get-Content -Path $file.FullName -Raw
            $violations = @(Get-LoopFailureContractViolation -Content $content)

            if ($violations.Count -gt 0) {
                $err = $violations -join "`n"
                throw "File $($file.Name) violates the Loop Failure Contract: `n$err"
            }

            $violations.Count | Should -Be 0
        }
    }

    Context "Behavioral Verification" {
        BeforeAll {
            $LocalPublicPath = Resolve-Path "$PSScriptRoot/../../BridgeWatcher/Public"
            $LocalPrivatePath = Resolve-Path "$PSScriptRoot/../../BridgeWatcher/Private"
            . "$LocalPrivatePath\New-BridgeConfiguration.ps1"
            . "$LocalPrivatePath\Write-BridgeLog.ps1"
            . "$LocalPrivatePath\Send-BridgePushoverRequest.ps1"
            . "$LocalPrivatePath\Invoke-BridgeOCRRequest.ps1"
            . "$LocalPublicPath\Get-BridgeStatus.ps1"
            . "$LocalPublicPath\Get-BridgeStatusMonitor.ps1"
            $script:Config = New-BridgeConfiguration
        }

        It "Get-BridgeStatus: Throws terminating error when Invoke-WebRequest fails all retries" {
            Mock Invoke-WebRequest { throw "Simulated Network Timeout" }
            Mock Write-BridgeLog {}
            Mock Start-Sleep {}

            { Get-BridgeStatus -Configuration $script:Config } | Should -Throw "*Simulated Network Timeout*"
        }

        It "Get-BridgeStatusMonitor: Throws terminating error when Update-BridgeStatus fails all iterations" {
            Mock Update-BridgeStatus { throw "Simulated Monitor Action Failure" }
            Mock Start-Sleep {}
            Mock Write-BridgeLog {}

            $monitorParams = @{
                OutputFile    = 'dummy.json'
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
                Configuration = $script:Config
                MaxIterations = 3
            }

            { Get-BridgeStatusMonitor @monitorParams } | Should -Throw "*All monitoring iterations failed*"
        }

        It "Invoke-BridgeOCRRequest: Throws terminating error when Invoke-RestMethod fails all retries" {
            Mock Invoke-RestMethod { throw "Simulated OCR API Failure" }
            Mock Write-BridgeLog {}
            Mock Start-Sleep {}

            $ocrParams = @{
                ApiKey        = 'dummy'
                RequestBody   = '{}'
                Configuration = $script:Config
            }

            { Invoke-BridgeOCRRequest @ocrParams } | Should -Throw "*Η κλήση του Google Vision API απέτυχε*"
        }

        It "Send-BridgePushoverRequest: Throws terminating error when Invoke-RestMethod fails all retries" {
            Mock Invoke-RestMethod { throw "Simulated Pushover API Failure" }
            Mock Write-BridgeLog {}
            Mock Start-Sleep {}

            $pushoverParams = @{
                Payload       = @{ title = 'test'; message = 'test' }
                Configuration = $script:Config
            }

            { Send-BridgePushoverRequest @pushoverParams } | Should -Throw "*Simulated Pushover API Failure*"
        }
    }

    Context "Parser Validation (Adversarial Tests)" {
        It "Fails on code that sleeps but never throws or reports failure" {
            $badCode = @"
function Test-NonCompliant {
    for (`$i = 1; `$i -le 3; `$i++) {
        try {
            Invoke-RestMethod -Uri 'http://example.com'
        } catch {
            Start-Sleep -Seconds 2
        }
    }
}
"@
            $violations = @(Get-LoopFailureContractViolation -Content $badCode)
            $violations.Count | Should -BeGreaterThan 0
            $violations[0] | Should -Match "lacks a throw or terminating error"
        }

        It "Fails on code that sleeps but has no iteration or failure tracking variable updates" {
            $badCode = @"
function Test-NonCompliant {
    while (`$true) {
        try {
            Invoke-RestMethod -Uri 'http://example.com'
        } catch {
            Start-Sleep -Seconds 2
        }
    }
}
"@
            $violations = @(Get-LoopFailureContractViolation -Content $badCode)
            $violations.Count | Should -BeGreaterThan 0
        }

        It "Passes on compliant code (like Get-BridgeStatus pattern)" {
            $goodCode = @"
function Test-Compliant {
    for (`$i = 1; `$i -le 3; `$i++) {
        try {
            Invoke-RestMethod -Uri 'http://example.com'
            break
        } catch {
            if (`$i -eq 3) {
                throw "Failed all retries"
            }
            Start-Sleep -Seconds 2
        }
    }
}
"@
            $violations = @(Get-LoopFailureContractViolation -Content $goodCode)
            $violations.Count | Should -Be 0
        }
    }
}