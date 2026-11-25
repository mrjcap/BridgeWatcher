BeforeAll {
    Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force
}

Describe 'Adversarial Regression and Security Tests' {

    Context 'C-01: StrictMode PropertyNotFoundException on unchanged poll comparison & empty JSON array' {
        It 'C-01a: Invoke-BridgeStatusComparison should handle unchanged bridge state without PropertyNotFoundException under StrictMode' {
            $cfg = New-BridgeConfiguration
            $prevJson = '[{"GefyraName":"Ποσειδωνία","GefyraStatus":"Ανοιχτή","Timestamp":"2026-11-10T17:00:00Z","ImageUrl":"https://www.topvision.gr/dioriga/image-bridge-open-no-schedule.php?111","ImageHash":null}]'
            $prev = $prevJson | ConvertFrom-Json
            $curr = @(
                [pscustomobject]@{
                    PSTypeName   = 'Bridge.Status'
                    GefyraName   = 'Ποσειδωνία'
                    GefyraStatus = 'Ανοιχτή'
                    Timestamp    = '2026-11-10T17:05:00Z'
                    ImageUrl     = 'https://www.topvision.gr/dioriga/image-bridge-open-no-schedule.php?111'
                    ImageHash    = $null
                }
            )

            { Invoke-BridgeStatusComparison -PreviousState @($prev) -CurrentState $curr -Configuration $cfg } | Should -Not -Throw
        }

        It 'C-01b: Get-BridgePreviousStatus should parse empty JSON array [] without throwing PropertyNotFoundException under StrictMode' {
            $cfg = New-BridgeConfiguration
            $emptyJsonPath = Join-Path $TestDrive 'empty_status.json'
            '[]' | Set-Content -LiteralPath $emptyJsonPath -Encoding utf8BOM

            { Get-BridgePreviousStatus -InputFile $emptyJsonPath -Configuration $cfg } | Should -Not -Throw
        }
    }

    Context 'C-02: StrictMode PropertyNotFoundException on missing .Response and missing hashtable properties' {
        It 'C-02a: Invoke-BridgeOCRRequest should retry without crashing on missing .Response property when network fails' {
            $cfg = New-BridgeConfiguration
            Mock -ModuleName BridgeWatcher Invoke-RestMethod {
                throw [System.Net.Http.HttpRequestException]::new('Network connection failed')
            }
            Mock -ModuleName BridgeWatcher Start-Sleep {}

            # The function should throw an OCR failure error record, NOT a PropertyNotFoundException on 'Response'
            $err = $null
            try {
                & (Get-Module BridgeWatcher) {
                    param($c)
                    Invoke-BridgeOCRRequest -ApiKey 'key' -RequestBody '{}' -Configuration $c
                } $cfg
            } catch {
                $err = $_
            }

            $err | Should -Not -BeNullOrEmpty
            $err.Exception.GetType().FullName | Should -Not -Be 'System.Management.Automation.PropertyNotFoundException'
            $err.Exception.Message | Should -Not -Match "The property 'Response' cannot be found"
        }

        It 'C-02b: Send-BridgePushover should send messages when Title parameter is omitted without missing title property crash' {
            $cfg = New-BridgeConfiguration
            Mock -ModuleName BridgeWatcher Invoke-RestMethod {
                return [PSCustomObject]@{ status = 1 }
            }

            { Send-BridgePushover -Configuration $cfg -PoUserKey 'user' -PoApiKey 'token' -Message 'test message' } | Should -Not -Throw
        }

        It 'C-02c: ConvertFrom-BridgeOCRResult should handle empty responses objects without throwing PropertyNotFoundException' {
            $cfg = New-BridgeConfiguration
            $emptyApiResp = '{"responses":[{}]}' | ConvertFrom-Json

            $result = InModuleScope -ModuleName BridgeWatcher -Parameters @{ Config = $cfg; Response = $emptyApiResp } -ScriptBlock {
                param($Config, $Response)
                ConvertFrom-BridgeOCRResult -Configuration $Config -ApiResponse $Response -ErrorAction Stop
            }

            $result | Should -BeNullOrEmpty
        }

        It 'C-02d: New-BridgeConfiguration should support partial ConfigurationPath JSON without PropertyNotFoundException' {
            $partialJson = Join-Path $TestDrive 'partial_cfg.json'
            '{"Urls":{"Source":"https://example.com/dioriga/"}}' | Set-Content -LiteralPath $partialJson -Encoding utf8

            { New-BridgeConfiguration -ConfigurationPath $partialJson } | Should -Not -Throw
        }
    }

    Context 'C-03: Real module exception handling fidelity in Invoke-BridgeOpenedNotification' {
        It 'C-03: Invoke-BridgeOpenedNotification should catch System.Exception from Send-BridgePushover' {
            $cfg = New-BridgeConfiguration
            $entry = [pscustomobject]@{
                PSTypeName   = 'Bridge.Status'
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Ανοιχτή'
                Timestamp    = '2026-11-10T17:00:00Z'
                ImageUrl     = 'https://www.topvision.gr/dioriga/image-bridge-open-no-schedule.php?123'
                ImageHash    = $null
            }

            # Send-BridgePushover wraps errors in [System.Exception] with FullyQualifiedErrorId PushoverSendError
            Mock -ModuleName BridgeWatcher Send-BridgePushover {
                $err = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Pushover failed"),
                    'PushoverSendError',
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $null
                )
                $PSCmdlet.ThrowTerminatingError($err)
            }

            # If caught properly by Invoke-BridgeOpenedNotification, it throws NotificationFailed ErrorRecord
            $thrown = $null
            try {
                & (Get-Module BridgeWatcher) {
                    param($c, $e)
                    Invoke-BridgeOpenedNotification -Configuration $c -CurrentState @($e) -PoUserKey 'u' -PoApiKey 'k'
                } $cfg $entry
            } catch {
                $thrown = $_
            }

            $thrown | Should -Not -BeNullOrEmpty
            ($thrown.FullyQualifiedErrorId -split ',')[0] | Should -BeExactly 'NotificationFailed'
            $thrown.Exception.InnerException.Message | Should -Match 'Pushover failed'
        }
    }

    Context 'C-04: Error isolation and state hash poisoning during OCR failures' {
        It 'C-04a: Invoke-BridgeClosedNotification should not treat Send-Notification failures as OCR errors' {
            $cfg = New-BridgeConfiguration
            $entry = [pscustomobject]@{
                PSTypeName   = 'Bridge.Status'
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                timestamp    = '2026-11-10T17:00:00Z'
                imageUrl     = 'https://www.topvision.gr/dioriga/image-bridge-open-with-schedule-isthmia.php?123'
                ImageHash    = 'ABCDEF'
            }

            # Mock OCR to succeed with valid schedule content
            Mock -ModuleName BridgeWatcher Invoke-BridgeOCRGoogleCloud {
                return [pscustomobject]@{
                    From      = '10/11/2026 23:00'
                    To        = '10/11/2026 23:45'
                    ClosedFor = '45 λεπτά'
                    OpensIn   = '15 λεπτά'
                    Note1     = 'Wait'
                    Note2     = 'Will close'
                }
            }

            # Provider mock that throws a transport error
            $failingProvider = {
                throw [System.Net.Http.HttpRequestException]::new("Transport failure to notification provider")
            }

            # Track warnings logged
            $warningsLogged = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName BridgeWatcher Write-BridgeLog {
                param($Message, $Level)
                if ($Level -eq 'Warning') {
                    $warningsLogged.Add($Message)
                }
            }

            {
                & (Get-Module -Name BridgeWatcher) {
                    param($c, $e, $p)
                    Invoke-BridgeClosedNotification -Configuration $c -CurrentState @($e) -ApiKey 'k' -NotificationProvider $p
                } $cfg $entry $failingProvider
            } | Should -Throw -ExpectedMessage '*Transport failure to notification provider*'

            # When notification fails after OCR succeeds, it must NOT log "Απέτυχε η OCR"
            $ocrFailureWarning = $warningsLogged | Where-Object { $_ -like "*Απέτυχε η OCR*" }
            $ocrFailureWarning | Should -BeNullOrEmpty
        }

        It 'C-04b: Update-BridgeStatus should not retain ImageHash in state when OCR fails' {
            $outDir = Join-Path $TestDrive 'c04_test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $outFile = Join-Path $outDir 'bridge_status.json'
            $cfg = New-BridgeConfiguration -LogDirectory $outDir

            Mock -ModuleName BridgeWatcher Invoke-WebRequest {
                param($Uri)
                if ($Uri -like '*image-bridge-open-with-schedule-posidonia*') {
                    return [PSCustomObject]@{ Content = [byte[]]@(1, 2, 3, 4) }
                }
                $html = @'
<div class="panel-primary"><h2>Ποσειδωνία</h2><img src="image-bridge-open-with-schedule-posidonia.php?1"></div>
<div class="panel-primary"><h2>Ισθμία</h2><img src="image-bridge-open-no-schedule.php?1"></div>
'@
                return [PSCustomObject]@{ Content = $html }
            }

            Mock -ModuleName BridgeWatcher Invoke-BridgeOCRGoogleCloud {
                throw [System.Exception]::new("Google Vision OCR 503 Service Unavailable")
            }
            Mock -ModuleName BridgeWatcher Send-BridgePushover {}

            Update-BridgeStatus -OutputFile $outFile -ApiKey 'k' -PoUserKey 'u' -PoApiKey 'p' -Configuration $cfg

            $savedState = Get-Content $outFile -Raw | ConvertFrom-Json
            $posidonia = $savedState | Where-Object { $_.GefyraName -eq 'Ποσειδωνία' }
            # ImageHash should be cleared so the next polling cycle can re-attempt OCR
            $posidonia.GefyraStatus | Should -Be $cfg.Statuses.ClosedWithSchedule
            $posidonia.ImageHash | Should -BeNullOrEmpty
            Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOCRGoogleCloud -Times 1 -Exactly

            $null = Update-BridgeStatus -OutputFile $outFile -ApiKey 'k' -PoUserKey 'u' -PoApiKey 'p' -Configuration $cfg
            Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOCRGoogleCloud -Times 2 -Exactly
        }
    }

    Context 'C-05: Missing schedule image handling in Get-BridgeStatus' {
        It 'C-05: Get-BridgeStatusObject should handle 404 image retrieval gracefully without failing status parsing' {
            $cfg = New-BridgeConfiguration
            Mock -ModuleName BridgeWatcher Invoke-WebRequest {
                param($Uri)
                if ($Uri -like '*image-bridge-open-with-schedule*') {
                    throw [System.Net.WebException]::new("The remote server returned an error: (404) Not Found.")
                }
            }

            # Should not throw terminating IMAGE_DOWNLOAD_FAILED error, but return object with ImageHash = $null
            $res = InModuleScope -ModuleName BridgeWatcher -Parameters @{ Config = $cfg } -ScriptBlock {
                param($Config)
                Get-BridgeStatusObject -Location 'poseidonia' -Status $Config.Statuses.ClosedWithSchedule -Timestamp '2026-11-10T17:00:00Z' -ImageSrc 'image-bridge-open-with-schedule-posidonia.php' -Configuration $Config -ErrorAction Stop
            }
            Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-WebRequest -Times 1 -Exactly
            $res | Should -Not -BeNullOrEmpty
            $res.ImageHash | Should -BeNullOrEmpty
        }
    }

    Context 'C-06: Strict origin and HTTPS validation for image URLs' {
        It 'C-06: rejects <ImageSrc> before fetching the image' -ForEach @(
            @{ ImageSrc = 'http://example.com/image.png' }
            @{ ImageSrc = 'https://other.example/image.png' }
            @{ ImageSrc = 'https://example.com:444/image.png' }
        ) {
            Mock -ModuleName BridgeWatcher -CommandName Get-BridgeImageBuffer { throw 'Unexpected download' }
            InModuleScope -ModuleName BridgeWatcher -Parameters @{ Source = $ImageSrc } -ScriptBlock {
                param($Source)
                $cfg = New-BridgeConfiguration
                $params = @{
                    Location = 'poseidonia'; Status = $cfg.Statuses.ClosedWithSchedule; Configuration = $cfg
                    Timestamp = '2026-11-10T17:00:00Z'; BaseUrl = 'https://example.com'; ImageSrc = $Source
                }
                { Get-BridgeStatusObject @params } | Should -Throw -ErrorId 'INVALID_IMAGE_HOST,*'
                Should -Invoke -CommandName Get-BridgeImageBuffer -Times 0 -Exactly
            }
        }
    }

    Context 'C-07: Safe git workflow in powershell-docs.yml' {
        It 'C-07: powershell-docs.yml must not use || true after git pull --rebase' {
            $docsWf = Get-Content -LiteralPath "$PSScriptRoot/../.github/workflows/powershell-docs.yml" -Raw
            $docsWf | Should -Not -Match 'git pull --rebase.*\|\|\s*true'
        }
    }

    Context 'C-08: Dry run safety in release and publish workflows' {
        It 'C-08a: release.yml must not commit or push changelog when dry_run is true' {
            $releaseWf = Get-Content -LiteralPath "$PSScriptRoot/../.github/workflows/release.yml" -Raw
            # Step 'Commit and Push Changelog' should check dry_run
            $releaseWf | Should -Match 'Commit and Push Changelog[\s\S]*?!inputs\.dry_run'
        }

        It 'C-08b: publish.yml must not push git commits when dry_run is true' {
            $publishWf = Get-Content -LiteralPath "$PSScriptRoot/../.github/workflows/publish.yml" -Raw
            # Step 'Push changes' should check inputs.dry_run
            $publishWf | Should -Match 'name: Push changes[\s\S]*?!inputs\.dry_run'
        }
    }

    Context 'C-09: Supply chain & container security hardening' {
        It 'C-09a: Dockerfile base image must be pinned with a SHA256 digest' {
            $dockerfile = Get-Content -LiteralPath "$PSScriptRoot/../Docker/Dockerfile" -Raw
            $dockerfile | Should -Match '^FROM\s+[^\s]+@sha256:[a-f0-9]{64}'
        }

        It 'C-09b: Dockerfile must verify PowerShell download hash with sha256sum' {
            $dockerfile = Get-Content -LiteralPath "$PSScriptRoot/../Docker/Dockerfile" -Raw
            $dockerfile | Should -Match 'sha256sum\s+-c'
        }

        It 'C-09c: docker-build.yml Trivy step must fail build on Critical vulnerabilities' {
            $dockerWf = Get-Content -LiteralPath "$PSScriptRoot/../.github/workflows/docker-build.yml" -Raw
            $dockerWf | Should -Match 'exit-code:\s*[''"]?1[''"]?'
        }

        It 'C-09d: .semgrepignore must not ignore PowerShell module source files' {
            $semgrepIgnore = Get-Content -LiteralPath "$PSScriptRoot/../.semgrepignore" -Raw
            $semgrepIgnore | Should -Not -Match '(?m)^\*\.ps1\s*$'
            $semgrepIgnore | Should -Not -Match '(?m)^\*\.psm1\s*$'
        }
    }
}
