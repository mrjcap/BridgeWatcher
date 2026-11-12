BeforeAll {
    $script:ModuleRoot = Join-Path $PSScriptRoot '../BridgeWatcher'
    foreach ($relativePath in @(
        'Private/New-BridgeConfiguration.ps1'
        'Private/Write-BridgeLog.ps1'
        'Private/Export-BridgeStatusJson.ps1'
        'Private/Resolve-BridgeStateForChange.ps1'
        'Private/Invoke-BridgeOpenedNotification.ps1'
        'Private/Invoke-BridgeClosedNotification.ps1'
        'Public/Get-BridgeStatus.ps1'
        'Public/Get-BridgePreviousStatus.ps1'
        'Public/Invoke-BridgeStatusComparison.ps1'
        'Public/Update-BridgeStatus.ps1'
    )) {
        . (Join-Path $script:ModuleRoot $relativePath)
    }
}

Describe 'Per-bridge notification checkpoints' {
    BeforeEach {
        $script:Config = New-BridgeConfiguration -LogDirectory (Join-Path $TestDrive 'logs')
        $script:OutputFile = Join-Path $TestDrive 'status.json'
        Mock Write-BridgeLog { }
        $previous = foreach ($location in @('poseidonia', 'isthmia')) {
            [pscustomobject]@{
                GefyraName = $script:Config.BridgeNames.$location
                GefyraStatus = $script:Config.Statuses.ClosedForMaintenance
                ImageUrl = "https://www.topvision.gr/dioriga/$location.php"
                ImageHash = $null
                Timestamp = '2026-11-12T10:00:00Z'
            }
        }
        $null = Export-BridgeStatusJson -Data $previous -Path $script:OutputFile -Configuration $script:Config -Confirm:$false
        $script:Current = foreach ($entry in $previous) {
            [pscustomobject]@{
                GefyraName = $entry.GefyraName
                GefyraStatus = $script:Config.Statuses.Open
                ImageUrl = $entry.ImageUrl
                ImageHash = $null
                Timestamp = '2026-11-12T10:05:00Z'
            }
        }
        $script:Update = @{
            OutputFile = $script:OutputFile
            Configuration = $script:Config
            ApiKey = 'test'
            PoUserKey = 'test'
            PoApiKey = 'test'
            Confirm = $false
        }
        Mock Get-BridgeStatus { $script:Current }
        Mock Invoke-BridgeOpenedNotification { }
        Mock Invoke-BridgeClosedNotification { }
    }

    It 'Does not replay a delivered alert when a later bridge keeps failing' {
        Mock Invoke-BridgeOpenedNotification {
            param($CurrentState)
            if ($CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia) {
                throw 'Synthetic delivery failure'
            }
        }
        foreach ($poll in 1..3) {
            { Update-BridgeStatus @script:Update } | Should -Throw '*delivery failure*'
        }
        Should -Invoke Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.poseidonia
        }
        Should -Invoke Invoke-BridgeOpenedNotification -Times 3 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia
        }
        $saved = @(Get-BridgePreviousStatus -InputFile $script:OutputFile -Configuration $script:Config)
        ($saved | Where-Object GefyraName -EQ $script:Config.BridgeNames.poseidonia).GefyraStatus | Should -Be $script:Config.Statuses.Open
        ($saved | Where-Object GefyraName -EQ $script:Config.BridgeNames.isthmia).GefyraStatus | Should -Be $script:Config.Statuses.ClosedForMaintenance
    }

    It 'Continues with the other bridge after the first notification fails' {
        Mock Invoke-BridgeOpenedNotification {
            param($CurrentState)
            if ($CurrentState[0].GefyraName -eq $script:Config.BridgeNames.poseidonia) {
                throw 'Synthetic delivery failure'
            }
        }
        { Update-BridgeStatus @script:Update } | Should -Throw '*delivery failure*'
        Should -Invoke Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia
        }
        $saved = @(Get-BridgePreviousStatus -InputFile $script:OutputFile -Configuration $script:Config)
        ($saved | Where-Object GefyraName -EQ $script:Config.BridgeNames.isthmia).GefyraStatus | Should -Be $script:Config.Statuses.Open
        ($saved | Where-Object GefyraName -EQ $script:Config.BridgeNames.poseidonia).GefyraStatus | Should -Be $script:Config.Statuses.ClosedForMaintenance
    }

    It 'Retries only the failed bridge when delivery recovers' {
        $script:FailSecond = $true
        Mock Invoke-BridgeOpenedNotification {
            param($CurrentState)
            if ($script:FailSecond -and $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia) {
                throw 'Synthetic delivery failure'
            }
        }
        { Update-BridgeStatus @script:Update } | Should -Throw '*delivery failure*'
        $script:FailSecond = $false
        $null = Update-BridgeStatus @script:Update
        Should -Invoke Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.poseidonia
        }
        Should -Invoke Invoke-BridgeOpenedNotification -Times 2 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia
        }
        $saved = @(Get-BridgePreviousStatus -InputFile $script:OutputFile -Configuration $script:Config)
        @($saved | Where-Object GefyraStatus -EQ $script:Config.Statuses.Open).Count | Should -Be 2
    }

    It 'Stops sending when a successful notification cannot be checkpointed' {
        Mock Export-BridgeStatusJson {
            [pscustomobject]@{Success=$false; ErrorCode='JSON_EXPORT_FAILURE'; ErrorMessage='Synthetic disk failure'}
        }
        { Update-BridgeStatus @script:Update } | Should -Throw '*disk failure*'
        Should -Invoke Invoke-BridgeOpenedNotification -Times 1 -Exactly
    }

    It 'Keeps cold-start progress across a failed first broadcast' {
        Remove-Item -LiteralPath $script:OutputFile -Confirm:$false
        $script:FailSecond = $true
        Mock Invoke-BridgeOpenedNotification {
            param($CurrentState)
            if ($script:FailSecond -and $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia) {
                throw 'Synthetic delivery failure'
            }
        }
        { Update-BridgeStatus @script:Update } | Should -Throw '*delivery failure*'
        $script:FailSecond = $false
        $null = Update-BridgeStatus @script:Update
        Should -Invoke Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.poseidonia
        }
        Should -Invoke Invoke-BridgeOpenedNotification -Times 2 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia
        }
    }
}
