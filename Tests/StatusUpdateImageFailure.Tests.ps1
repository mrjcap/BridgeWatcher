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
    }
}
