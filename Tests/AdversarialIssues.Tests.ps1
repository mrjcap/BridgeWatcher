BeforeAll -Scriptblock {
    Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force
}

Describe -Name 'Adversarial Regression and Security Tests' -Fixture {

    Context -Name 'C-01: StrictMode PropertyNotFoundException on unchanged poll comparison & empty JSON array' -Fixture {
        It -Name 'C-01a: Invoke-BridgeStatusComparison should handle unchanged bridge state without PropertyNotFoundException under StrictMode' -Test {
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

        It -Name 'C-01b: Get-BridgePreviousStatus should parse empty JSON array [] without throwing PropertyNotFoundException under StrictMode' -Test {
            $cfg = New-BridgeConfiguration
            $emptyJsonPath = Join-Path -Path $TestDrive -ChildPath 'empty_status.json'
            '[]' | Set-Content -LiteralPath $emptyJsonPath -Encoding utf8BOM

            { Get-BridgePreviousStatus -InputFile $emptyJsonPath -Configuration $cfg } | Should -Not -Throw
        }
    }

    Context -Name 'C-02: StrictMode PropertyNotFoundException on missing .Response and missing hashtable properties' -Fixture {
        It -Name 'C-02a: Invoke-BridgeOCRRequest should retry without crashing on missing .Response property when network fails' -Test {
            $cfg = New-BridgeConfiguration
            Mock -ModuleName BridgeWatcher -CommandName Invoke-RestMethod -MockWith {
                throw [System.Net.Http.HttpRequestException]::new('Network connection failed')
            }
            Mock -ModuleName BridgeWatcher -CommandName Start-Sleep -MockWith {}

            $err = $null
            try {
                & (Get-Module -Name BridgeWatcher) {
                    param($c)
                    Invoke-BridgeOCRRequest -ApiKey 'key' -RequestBody '{}' -Configuration $c
                } $cfg
            } catch {
                $err = $_
            }

            $err | Should -Not -BeNullOrEmpty
            $err.Exception.GetType().FullName | Should -Not -Be -ExpectedValue 'System.Management.Automation.PropertyNotFoundException'
            $err.Exception.Message | Should -Not -Match -RegularExpression "The property 'Response' cannot be found"
        }

        It -Name 'C-02b: Send-BridgePushover should send messages when Title parameter is omitted without missing title property crash' -Test {
            $cfg = New-BridgeConfiguration
            Mock -ModuleName BridgeWatcher -CommandName Invoke-RestMethod -MockWith {
                return [PSCustomObject]@{ status = 1 }
            }

            { Send-BridgePushover -Configuration $cfg -PoUserKey 'user' -PoApiKey 'token' -Message 'test message' } | Should -Not -Throw
        }

        It -Name 'C-02c: ConvertFrom-BridgeOCRResult should handle empty responses objects without throwing PropertyNotFoundException' -Test {
            $cfg = New-BridgeConfiguration
            $emptyApiResp = '{"responses":[{}]}' | ConvertFrom-Json

            $result = InModuleScope -ModuleName BridgeWatcher -Parameters @{ Config = $cfg; Response = $emptyApiResp } -ScriptBlock {
                param($Config, $Response)
                ConvertFrom-BridgeOCRResult -Configuration $Config -ApiResponse $Response -ErrorAction Stop
            }

            $result | Should -BeNullOrEmpty
        }

        It -Name 'C-02d: New-BridgeConfiguration should support partial ConfigurationPath JSON without PropertyNotFoundException' -Test {
            $partialJson = Join-Path -Path $TestDrive -ChildPath 'partial_cfg.json'
            '{"Urls":{"Source":"https://example.com/dioriga/"}}' | Set-Content -LiteralPath $partialJson -Encoding utf8

            { New-BridgeConfiguration -ConfigurationPath $partialJson } | Should -Not -Throw
        }
    }

    Context -Name 'C-03: Real module exception handling fidelity in Invoke-BridgeOpenedNotification' -Fixture {
        It -Name 'C-03: Invoke-BridgeOpenedNotification should catch System.Exception from Send-BridgePushover' -Test {
            $cfg = New-BridgeConfiguration
            $entry = [pscustomobject]@{
                PSTypeName   = 'Bridge.Status'
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Ανοιχτή'
                Timestamp    = '2026-11-10T17:00:00Z'
                ImageUrl     = 'https://www.topvision.gr/dioriga/image-bridge-open-no-schedule.php?123'
                ImageHash    = $null
            }

            Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushover -MockWith {
                $err = [System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Pushover failed"),
                    'PushoverSendError',
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $null
                )
                $PSCmdlet.ThrowTerminatingError($err)
            }

            $thrown = $null
            try {
                & (Get-Module -Name BridgeWatcher) {
                    param($c, $e)
                    Invoke-BridgeOpenedNotification -Configuration $c -CurrentState @($e) -PoUserKey 'u' -PoApiKey 'k'
                } $cfg $entry
            } catch {
                $thrown = $_
            }

            $thrown | Should -Not -BeNullOrEmpty
            ($thrown.FullyQualifiedErrorId -split ',')[0] | Should -BeExactly -ExpectedValue 'NotificationFailed'
            $thrown.Exception.InnerException.Message | Should -Match -RegularExpression 'Pushover failed'
        }
    }

    Context -Name 'C-04: Error isolation and state hash poisoning during OCR failures' -Fixture {
        It -Name 'C-04a: Invoke-BridgeClosedNotification should not treat Send-Notification failures as OCR errors' -Test {
            $cfg = New-BridgeConfiguration
            $entry = [pscustomobject]@{
                PSTypeName   = 'Bridge.Status'
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                timestamp    = '2026-11-10T17:00:00Z'
                imageUrl     = 'https://www.topvision.gr/dioriga/image-bridge-open-with-schedule-isthmia.php?123'
                ImageHash    = 'ABCDEF'
            }

            Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
                return [pscustomobject]@{
                    From      = '10/11/2026 23:00'
                    To        = '10/11/2026 23:45'
                    ClosedFor = '45 λεπτά'
                    OpensIn   = '15 λεπτά'
                    Note1     = 'Wait'
                    Note2     = 'Will close'
                }
            }

            $failingProvider = {
                throw [System.Net.Http.HttpRequestException]::new("Transport failure to notification provider")
            }

            $warningsLogged = [System.Collections.Generic.List[string]]::new()
            Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith {
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

            $ocrFailureWarning = $warningsLogged | Where-Object -FilterScript { $_ -like "*Απέτυχε η OCR*" }
            $ocrFailureWarning | Should -BeNullOrEmpty
        }

        It -Name 'C-04b: Update-BridgeStatus should not retain ImageHash in state when OCR fails' -Test {
            $outDir = Join-Path -Path $TestDrive -ChildPath 'c04_test'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $outFile = Join-Path -Path $outDir -ChildPath 'bridge_status.json'
            $cfg = New-BridgeConfiguration -LogDirectory $outDir

            Mock -ModuleName BridgeWatcher -CommandName Invoke-WebRequest -MockWith {
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

            Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
                throw [System.Exception]::new("Google Vision OCR 503 Service Unavailable")
            }
            Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushover -MockWith {}

            Update-BridgeStatus -OutputFile $outFile -ApiKey 'k' -PoUserKey 'u' -PoApiKey 'p' -Configuration $cfg

            $savedState = Get-Content -Path $outFile -Raw | ConvertFrom-Json
            $posidonia = $savedState | Where-Object -FilterScript { $_.GefyraName -eq 'Ποσειδωνία' }
            $posidonia.GefyraStatus | Should -Be -ExpectedValue $cfg.Statuses.ClosedWithSchedule
            $posidonia.ImageHash | Should -BeNullOrEmpty
            Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOCRGoogleCloud -Times 1 -Exactly

            $null = Update-BridgeStatus -OutputFile $outFile -ApiKey 'k' -PoUserKey 'u' -PoApiKey 'p' -Configuration $cfg
            Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOCRGoogleCloud -Times 2 -Exactly
        }
    }

    Context -Name 'C-05: Missing schedule image handling in Get-BridgeStatus' -Fixture {
        It -Name 'C-05: Get-BridgeStatusObject should handle 404 image retrieval gracefully without failing status parsing' -Test {
            $cfg = New-BridgeConfiguration
            Mock -ModuleName BridgeWatcher -CommandName Invoke-WebRequest -MockWith {
                param($Uri)
                if ($Uri -like '*image-bridge-open-with-schedule*') {
                    throw [System.Net.WebException]::new("The remote server returned an error: (404) Not Found.")
                }
            }

            $res = InModuleScope -ModuleName BridgeWatcher -Parameters @{ Config = $cfg } -ScriptBlock {
                param($Config)
                Get-BridgeStatusObject -Location 'poseidonia' -Status $Config.Statuses.ClosedWithSchedule -Timestamp '2026-11-10T17:00:00Z' -ImageSrc 'image-bridge-open-with-schedule-posidonia.php' -Configuration $Config -ErrorAction Stop
            }
            Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-WebRequest -Times 1 -Exactly
            $res | Should -Not -BeNullOrEmpty
            $res.ImageHash | Should -BeNullOrEmpty
        }
    }

    Context -Name 'C-06: Strict origin and HTTPS validation for image URLs' -Fixture {
        It -Name 'C-06: rejects <ImageSrc> before fetching the image' -ForEach @(
            @{ ImageSrc = 'http://example.com/image.png' }
            @{ ImageSrc = 'https://other.example/image.png' }
            @{ ImageSrc = 'https://example.com:444/image.png' }
        ) -Test {
            Mock -ModuleName BridgeWatcher -CommandName Get-BridgeImageBuffer -MockWith { throw 'Unexpected download' }
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

    Context -Name 'C-07: Safe git workflow in powershell-docs.yml' -Fixture {
        It -Name 'C-07: powershell-docs.yml must not use || true after git pull --rebase' -Test {
            $docsWf = Get-Content -LiteralPath "$PSScriptRoot/../.github/workflows/powershell-docs.yml" -Raw
            $docsWf | Should -Not -Match -RegularExpression 'git pull --rebase.*\|\|\s*true'
        }
    }

    Context -Name 'C-08: Dry run safety in release and publish workflows' -Fixture {
        It -Name 'C-08a: release.yml must not commit or push changelog when dry_run is true' -Test {
            $releaseWf = Get-Content -LiteralPath "$PSScriptRoot/../.github/workflows/release.yml" -Raw
            $releaseWf | Should -Match -RegularExpression 'Commit and Push Changelog[\s\S]*?!inputs\.dry_run'
        }

        It -Name 'C-08b: publish.yml must not push git commits when dry_run is true' -Test {
            $publishWf = Get-Content -LiteralPath "$PSScriptRoot/../.github/workflows/publish.yml" -Raw
            $publishWf | Should -Match -RegularExpression 'name: Push changes[\s\S]*?!inputs\.dry_run'
        }
    }

    Context -Name 'C-09: Supply chain & container security hardening' -Fixture {
        It -Name 'C-09a: Dockerfile base image must be pinned with a SHA256 digest' -Test {
            $dockerfile = Get-Content -LiteralPath "$PSScriptRoot/../Docker/Dockerfile" -Raw
            $dockerfile | Should -Match -RegularExpression '^FROM\s+[^\s]+@sha256:[a-f0-9]{64}'
        }

        It -Name 'C-09b: Dockerfile must verify PowerShell download hash with sha256sum' -Test {
            $dockerfile = Get-Content -LiteralPath "$PSScriptRoot/../Docker/Dockerfile" -Raw
            $dockerfile | Should -Match -RegularExpression 'sha256sum\s+-c'
        }

        It -Name 'C-09c: docker-build.yml Trivy step must fail build on Critical vulnerabilities' -Test {
            $dockerWf = Get-Content -LiteralPath "$PSScriptRoot/../.github/workflows/docker-build.yml" -Raw
            $dockerWf | Should -Match -RegularExpression 'exit-code:\s*[''"]?1[''"]?'
        }

        It -Name 'C-09d: Semgrep must not ignore PowerShell sources, workflows, or disable rules repository-wide' -Test {
            $root = Join-Path -Path $PSScriptRoot -ChildPath '..'
            $ignorePath = Join-Path -Path $root -ChildPath '.semgrepignore'
            $semgrepIgnore = if (Test-Path -LiteralPath $ignorePath) { Get-Content -LiteralPath $ignorePath -Raw } else { '' }
            $rootFull = (Resolve-Path -LiteralPath $root).Path
            $protected = @(Get-ChildItem -LiteralPath $rootFull -Recurse -File -Force -Include '*.ps1', '*.psm1', '*.psd1', '*.yml', '*.yaml' |
                    ForEach-Object -Process { $_.FullName.Substring($rootFull.Length).TrimStart('/', '\') -replace '\\', '/' } |
                    Where-Object -FilterScript { $_ -notmatch '^(\.git|Pester_[^/]*|node_modules)/' })
            $protected | Should -Contain -ExpectedValue '.github/workflows/publish.yml'
            $protected | Should -Contain -ExpectedValue 'BridgeWatcher/BridgeWatcher.psd1'
            $protected | Should -Contain -ExpectedValue 'Tests/AdversarialIssues.Tests.ps1'
            $patterns = @($semgrepIgnore -split '\r?\n' | ForEach-Object -Process { $_.Trim() } | Where-Object -FilterScript { $_ -and -not $_.StartsWith('!') })
            foreach ($pattern in $patterns) {
                $glob = '^(.*/)?' + (([regex]::Escape($pattern.Trim('/')) -replace '\\\*\\\*', '.*') -replace '\\\*', '[^/]*') + '(/.*)?$'
                foreach ($path in $protected) {
                    $path | Should -Not -Match -RegularExpression $glob -Because "the ignore pattern '$pattern' must not exclude $path"
                }
            }

            $rulesPath = Join-Path -Path $root -ChildPath '.semgrep.yml'
            if (Test-Path -LiteralPath $rulesPath) {
                Get-Content -LiteralPath $rulesPath -Raw | Should -Not -Match -RegularExpression '(?m)^disable:'
            }
        }
    }
}
