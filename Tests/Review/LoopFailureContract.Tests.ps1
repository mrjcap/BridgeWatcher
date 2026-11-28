Import-Module -Name "$PSScriptRoot/../../BridgeWatcher/BridgeWatcher.psd1" -Force

$script:PublicPath = Resolve-Path -Path "$PSScriptRoot/../../BridgeWatcher/Public"
$script:PrivatePath = Resolve-Path -Path "$PSScriptRoot/../../BridgeWatcher/Private"
$script:Files = Get-ChildItem -Path $script:PublicPath, $script:PrivatePath -Filter *.ps1 -Recurse | ForEach-Object -Process {
    [PSCustomObject]@{
        Name     = $_.Name
        FullName = $_.FullName
    }
}

Describe -Name "Loop Failure Contract Review" -Fixture {
    BeforeAll -Scriptblock {
        <#
        .SYNOPSIS
        Checks if an AST node is a throw or ThrowTerminatingError invocation.

        .DESCRIPTION
        Recognizes both a throw statement and a call to ThrowTerminatingError.

        .PARAMETER Node
        The AST node to inspect or use as the starting point of the search.
        #>
        function Test-AstNodeIsThrow {
            param($Node)
            if ($Node -is [System.Management.Automation.Language.ThrowStatementAst]) { return $true }
            if ($Node -is [System.Management.Automation.Language.CommandAst] -and $Node.GetCommandName() -like '*ThrowTerminatingError*') { return $true }
            return ($Node -is [System.Management.Automation.Language.MemberExpressionAst] -and $Node.Member.Extent.Text -eq 'ThrowTerminatingError')
        }

        <#
        .SYNOPSIS
        Checks if a loop contains or is followed by a throw or terminating error.

        .DESCRIPTION
        Searches the loop and subsequent code for an explicit terminating failure path.

        .PARAMETER Loop
        The loop AST to inspect.
        #>
        function Test-LoopHasFailureThrow {
            param($Loop)
            $hasThrowInside = $Loop.FindAll({ param($node) Test-AstNodeIsThrow -Node $node }, $true).Count -gt 0
            if ($hasThrowInside) { return $true }

            if (-not $Loop.Parent) { return $false }
            return $Loop.Parent.FindAll({
                param($node)
                (Test-AstNodeIsThrow -Node $node) -and ($node.Extent.StartOffset -gt $Loop.Extent.EndOffset)
            }, $true).Count -gt 0
        }

        <#
        .SYNOPSIS
        Checks PowerShell code content for Loop Failure Contract violations.

        .DESCRIPTION
        Parses the supplied source and reports retry loops with no terminating failure path.

        .PARAMETER Content
        The source text to inspect.
        #>
        function Get-LoopFailureContractViolation {
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
                $isRetryOrPolling = $loop.FindAll({
                    param($node)
                    $node -is [System.Management.Automation.Language.CommandAst] -and
                    $node.GetCommandName() -in @('Start-Sleep', 'Invoke-WebRequest', 'Invoke-RestMethod')
                }, $true).Count -gt 0

                if (-not $isRetryOrPolling) {
                    continue
                }

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

                if (-not (Test-LoopHasFailureThrow -Loop $loop)) {
                    $violations.Add("Loop at line $($loop.Extent.StartLineNumber) lacks a throw or terminating error when all iterations fail.")
                }
            }

            return $violations
        }
    }

    Context -Name "Static Analysis Check (Codebase Loop Failure Contract)" -Fixture {
        It -Name "Should follow Loop Failure Contract in <Name>" -ForEach $script:Files -Test {
            $file = $_
            $content = Get-Content -Path $file.FullName -Raw
            $violations = @(Get-LoopFailureContractViolation -Content $content)

            if ($violations.Count -gt 0) {
                $err = $violations -join "`n"
                throw "File $($file.Name) violates the Loop Failure Contract: `n$err"
            }

            $violations.Count | Should -Be -ExpectedValue 0
        }
    }

    Context -Name "Behavioral Verification" -Fixture {
        BeforeAll -Scriptblock {
            $LocalPublicPath = Resolve-Path -Path "$PSScriptRoot/../../BridgeWatcher/Public"
            $LocalPrivatePath = Resolve-Path -Path "$PSScriptRoot/../../BridgeWatcher/Private"
            . "$LocalPrivatePath\New-BridgeConfiguration.ps1"
            . "$LocalPrivatePath\Write-BridgeLog.ps1"
            . "$LocalPrivatePath\Get-BridgeHttpExceptionInfo.ps1"
            . "$LocalPrivatePath\Send-BridgePushoverRequest.ps1"
            . "$LocalPrivatePath\Invoke-BridgeOCRRequest.ps1"
            . "$LocalPublicPath\Get-BridgeStatus.ps1"
            . "$LocalPublicPath\Get-BridgeStatusMonitor.ps1"
            $script:Config = New-BridgeConfiguration
        }

        It -Name "Get-BridgeStatus: Throws terminating error when Invoke-WebRequest fails all retries" -Test {
            Mock -CommandName Invoke-WebRequest -MockWith { throw "Simulated Network Timeout" }
            Mock -CommandName Write-BridgeLog -MockWith {}
            Mock -CommandName Start-Sleep -MockWith {}

            { Get-BridgeStatus -Configuration $script:Config } | Should -Throw -ExpectedMessage "*Simulated Network Timeout*"
        }

        It -Name "Get-BridgeStatusMonitor: Throws terminating error when Update-BridgeStatus fails all iterations" -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { throw "Simulated Monitor Action Failure" }
            Mock -CommandName Start-Sleep -MockWith {}
            Mock -CommandName Write-BridgeLog -MockWith {}

            $monitorParams = @{
                OutputFile    = 'dummy.json'
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
                Configuration = $script:Config
                MaxIterations = 3
            }

            { Get-BridgeStatusMonitor @monitorParams } | Should -Throw -ExpectedMessage "*All monitoring iterations failed*"
        }

        It -Name "Invoke-BridgeOCRRequest: Throws terminating error when Invoke-RestMethod fails all retries" -Test {
            Mock -CommandName Invoke-RestMethod -MockWith { throw "Simulated OCR API Failure" }
            Mock -CommandName Write-BridgeLog -MockWith {}
            Mock -CommandName Start-Sleep -MockWith {}

            $ocrParams = @{
                ApiKey        = 'dummy'
                RequestBody   = '{}'
                Configuration = $script:Config
            }

            { Invoke-BridgeOCRRequest @ocrParams } | Should -Throw -ExpectedMessage "*Αποτυχία OCR*"
        }

        It -Name "Send-BridgePushoverRequest: Throws terminating error when Invoke-RestMethod fails all retries" -Test {
            Mock -CommandName Invoke-RestMethod -MockWith { throw "Simulated Pushover API Failure" }
            Mock -CommandName Write-BridgeLog -MockWith {}
            Mock -CommandName Start-Sleep -MockWith {}

            $pushoverParams = @{
                Payload       = @{ title = 'test'; message = 'test' }
                Configuration = $script:Config
            }

            { Send-BridgePushoverRequest @pushoverParams } | Should -Throw -ExpectedMessage "*Simulated Pushover API Failure*"
        }
    }

    Context -Name "Parser Validation (Adversarial Tests)" -Fixture {
        It -Name "Fails on code that sleeps but never throws or reports failure" -Test {
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
            $violations.Count | Should -BeGreaterThan -ExpectedValue 0
            $violations[0] | Should -Match -RegularExpression "lacks a throw or terminating error"
        }

        It -Name "Fails on code that sleeps but has no iteration or failure tracking variable updates" -Test {
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
            $violations.Count | Should -BeGreaterThan -ExpectedValue 0
        }

        It -Name "Passes on compliant code (like Get-BridgeStatus pattern)" -Test {
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
            $violations.Count | Should -Be -ExpectedValue 0
        }
    }
}