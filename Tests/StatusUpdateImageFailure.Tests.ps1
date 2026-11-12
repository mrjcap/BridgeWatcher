BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '../BridgeWatcher'
    foreach ($relativePath in @(
        'Private/New-BridgeConfiguration.ps1'
        'Private/Write-BridgeLog.ps1'
        'Private/Get-BridgeImage.ps1'
        'Private/Get-BridgeStatusObject.ps1'
        'Private/Get-BridgeStatusFromHtml.ps1'
        'Private/Resolve-BridgeStateForChange.ps1'
        'Private/Export-BridgeStatusJson.ps1'
        'Private/Invoke-BridgeClosedNotification.ps1'
        'Private/Invoke-BridgeOpenedNotification.ps1'
        'Public/Get-BridgeStatus.ps1'
        'Public/Get-BridgePreviousStatus.ps1'
        'Public/Invoke-BridgeStatusComparison.ps1'
        'Public/Update-BridgeStatus.ps1'
    )) {
        . (Join-Path $script:ModuleRoot $relativePath)
    }
}

Describe 'Status update with an unavailable schedule image' {
    It 'Notifies the healthy bridge and keeps the other bridge schedule until its image recovers' {
        $config = New-BridgeConfiguration -LogDirectory (Join-Path $TestDrive 'logs')
        $path = Join-Path $TestDrive 'status.json'
        $previous = @(
            [pscustomobject]@{
                GefyraName = $config.BridgeNames.poseidonia
                GefyraStatus = $config.Statuses.ClosedForMaintenance
                ImageUrl = "$($config.Urls.BaseImage)/image-bridge-close-for-maintenance.php?1"
                ImageHash = $null
            }
            [pscustomobject]@{
                GefyraName = $config.BridgeNames.isthmia
                GefyraStatus = $config.Statuses.ClosedWithSchedule
                ImageUrl = "$($config.Urls.BaseImage)/image-bridge-open-with-schedule-isthmia.php?1"
                ImageHash = 'previous-verified-hash'
                From = '12/11/2026 10:00'
                To = '12/11/2026 12:00'
            }
        )
        Mock Write-BridgeLog { }
        $null = Export-BridgeStatusJson -Data $previous -Path $path -Configuration $config -Confirm:$false
        Mock Invoke-WebRequest {
            param($Uri)
            if ($Uri -like '*image-bridge*') {
                throw [System.Net.WebException]::new('404: schedule image missing')
            }
            [pscustomobject]@{ Content = @'
<div class="panel-primary"><h2>Ποσειδωνία</h2><img src="image-bridge-open-no-schedule.php?2"></div>
<div class="panel-primary"><h2>Ισθμία</h2><img src="image-bridge-open-with-schedule-isthmia.php?2"></div>
'@ }
        }
        Mock Invoke-BridgeOpenedNotification { }
        Mock Invoke-BridgeClosedNotification { }

        $null = Update-BridgeStatus -OutputFile $path -ApiKey 'test' -PoUserKey 'test' -PoApiKey 'test' -Configuration $config -Confirm:$false

        Should -Invoke Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $config.BridgeNames.poseidonia
        }
        Should -Not -Invoke Invoke-BridgeClosedNotification
        $saved = @(Get-BridgePreviousStatus -InputFile $path -Configuration $config)
        ($saved | Where-Object GefyraName -EQ $config.BridgeNames.poseidonia).GefyraStatus | Should -Be $config.Statuses.Open
        $scheduled = $saved | Where-Object GefyraName -EQ $config.BridgeNames.isthmia
        $scheduled.ImageHash | Should -Be 'previous-verified-hash'
        $scheduled.From | Should -Be '12/11/2026 10:00'
        $scheduled.To | Should -Be '12/11/2026 12:00'

        Mock Get-BridgeImageBuffer { return ,([byte[]](1, 2, 3, 4)) }
        $null = Update-BridgeStatus -OutputFile $path -ApiKey 'test' -PoUserKey 'test' -PoApiKey 'test' -Configuration $config -Confirm:$false
        $null = Update-BridgeStatus -OutputFile $path -ApiKey 'test' -PoUserKey 'test' -PoApiKey 'test' -Configuration $config -Confirm:$false
        Should -Invoke Invoke-BridgeClosedNotification -Times 1 -Exactly
        $recovered = Get-BridgePreviousStatus -InputFile $path -Configuration $config | Where-Object GefyraName -EQ $config.BridgeNames.isthmia
        $recovered.ImageHash | Should -Not -BeNullOrEmpty
        $recovered.ImageHash | Should -Not -Be 'previous-verified-hash'
    }

    Context 'Outages without a previously verified image' {
        BeforeEach {
            $script:Config = New-BridgeConfiguration -LogDirectory (Join-Path $TestDrive 'logs')
            $script:Path = Join-Path $TestDrive 'status.json'
            $script:ScheduleSuffix = '?1'
            $script:ImageAvailable = $false
            $script:Previous = foreach ($location in @('poseidonia', 'isthmia')) {
                [pscustomobject]@{
                    GefyraName = $script:Config.BridgeNames.$location
                    GefyraStatus = $script:Config.Statuses.Open
                    ImageUrl = "$($script:Config.Urls.BaseImage)/image-bridge-open-no-schedule.php?1"
                    ImageHash = $null
                }
            }
            Mock Write-BridgeLog { }
            $null = Export-BridgeStatusJson -Data $script:Previous -Path $script:Path -Configuration $script:Config -Confirm:$false
            Mock Invoke-WebRequest {
                [pscustomobject]@{ Content = @"
<div class="panel-primary"><h2>Ποσειδωνία</h2><img src="image-bridge-open-no-schedule.php?1"></div>
<div class="panel-primary"><h2>Ισθμία</h2><img src="image-bridge-open-with-schedule-isthmia.php$script:ScheduleSuffix"></div>
"@ }
            }
            Mock Get-BridgeImageBuffer {
                if (-not $script:ImageAvailable) { throw 'Synthetic HTTP404' }
                return ,([byte[]](1, 2, 3, 4))
            }
            Mock Invoke-BridgeClosedNotification { }
            Mock Invoke-BridgeOpenedNotification { }
            $script:Update = @{
                OutputFile = $script:Path
                Configuration = $script:Config
                ApiKey = 'test'
                PoUserKey = 'test'
                PoApiKey = 'test'
                Confirm = $false
            }
        }

        It 'Does not replay a missing-image alert on rotating URLs (cold start: <ColdStart>)' -TestCases @(
            @{ ColdStart = $false }
            @{ ColdStart = $true }
        ) {
            param([bool]$ColdStart)
            if ($ColdStart) { Remove-Item -LiteralPath $script:Path -Confirm:$false }
            foreach ($poll in 1..3) {
                $script:ScheduleSuffix = "?$poll"
                $null = Update-BridgeStatus @script:Update
            }
            Should -Invoke Invoke-BridgeClosedNotification -Times 1 -Exactly
            $saved = Get-BridgePreviousStatus -InputFile $script:Path -Configuration $script:Config | Where-Object GefyraName -EQ $script:Config.BridgeNames.isthmia
            $saved.ImageHash | Should -BeNullOrEmpty
        }

        It 'Notifies once when the image recovers at the unchanged URL suffix <Suffix>' -TestCases @(
            @{ Suffix = '' }
            @{ Suffix = '?1' }
        ) {
            param([string]$Suffix)
            $script:ScheduleSuffix = $Suffix
            $null = Update-BridgeStatus @script:Update
            $script:ImageAvailable = $true
            $null = Update-BridgeStatus @script:Update
            $null = Update-BridgeStatus @script:Update
            Should -Invoke Invoke-BridgeClosedNotification -Times 2 -Exactly
            $saved = Get-BridgePreviousStatus -InputFile $script:Path -Configuration $script:Config | Where-Object GefyraName -EQ $script:Config.BridgeNames.isthmia
            $saved.ImageHash | Should -Not -BeNullOrEmpty
        }
    }
}
