BeforeAll -Scriptblock {
    Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force
}

Describe -Name 'Per-bridge notification checkpoints' -Fixture {
    BeforeEach -Scriptblock {
        $script:Config = New-BridgeConfiguration -LogDirectory (Join-Path -Path $TestDrive -ChildPath 'logs')
        $script:OutputFile = Join-Path -Path $TestDrive -ChildPath 'status.json'
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith { }
        $previous = foreach ($location in @('poseidonia', 'isthmia')) {
            [pscustomobject]@{
                GefyraName = $script:Config.BridgeNames.$location
                GefyraStatus = $script:Config.Statuses.ClosedForMaintenance
                ImageUrl = "https://www.topvision.gr/dioriga/$location.php"
                ImageHash = $null
                Timestamp = '2026-11-12T10:00:00Z'
            }
        }
        InModuleScope -ModuleName BridgeWatcher -Parameters @{ Prev = $previous; Out = $script:OutputFile; Cfg = $script:Config } -ScriptBlock {
            $null = Export-BridgeStatusJson -Data $Prev -Path $Out -Configuration $Cfg -Confirm:$false
        }
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
        Mock -ModuleName BridgeWatcher -CommandName Get-BridgeStatus -MockWith { $script:Current }
        Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -MockWith { }
        Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeClosedNotification -MockWith { }
    }

    It -Name 'Does not replay a delivered alert when a later bridge keeps failing' -Test {
        Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -MockWith {
            param($CurrentState)
            if ($CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia) {
                throw 'Synthetic delivery failure'
            }
        }
        foreach ($poll in 1..3) {
            { Update-BridgeStatus @script:Update } | Should -Throw -ExpectedMessage '*delivery failure*'
        }
        Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.poseidonia
        }
        Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -Times 3 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia
        }
        $saved = @(Get-BridgePreviousStatus -InputFile $script:OutputFile -Configuration $script:Config)
        ($saved | Where-Object -Property GefyraName -EQ -Value $script:Config.BridgeNames.poseidonia).GefyraStatus | Should -Be -ExpectedValue $script:Config.Statuses.Open
        ($saved | Where-Object -Property GefyraName -EQ -Value $script:Config.BridgeNames.isthmia).GefyraStatus | Should -Be -ExpectedValue $script:Config.Statuses.ClosedForMaintenance
    }

    It -Name 'Continues with the other bridge after the first notification fails' -Test {
        Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -MockWith {
            param($CurrentState)
            if ($CurrentState[0].GefyraName -eq $script:Config.BridgeNames.poseidonia) {
                throw 'Synthetic delivery failure'
            }
        }
        { Update-BridgeStatus @script:Update } | Should -Throw -ExpectedMessage '*delivery failure*'
        Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia
        }
        $saved = @(Get-BridgePreviousStatus -InputFile $script:OutputFile -Configuration $script:Config)
        ($saved | Where-Object -Property GefyraName -EQ -Value $script:Config.BridgeNames.isthmia).GefyraStatus | Should -Be -ExpectedValue $script:Config.Statuses.Open
        ($saved | Where-Object -Property GefyraName -EQ -Value $script:Config.BridgeNames.poseidonia).GefyraStatus | Should -Be -ExpectedValue $script:Config.Statuses.ClosedForMaintenance
    }

    It -Name 'Retries only the failed bridge when delivery recovers' -Test {
        $script:FailSecond = $true
        Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -MockWith {
            param($CurrentState)
            if ($script:FailSecond -and $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia) {
                throw 'Synthetic delivery failure'
            }
        }
        { Update-BridgeStatus @script:Update } | Should -Throw -ExpectedMessage '*delivery failure*'
        $script:FailSecond = $false
        $null = Update-BridgeStatus @script:Update
        Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.poseidonia
        }
        Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -Times 2 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia
        }
        $saved = @(Get-BridgePreviousStatus -InputFile $script:OutputFile -Configuration $script:Config)
        @($saved | Where-Object -Property GefyraStatus -EQ -Value $script:Config.Statuses.Open).Count | Should -Be -ExpectedValue 2
    }

    It -Name 'Stops sending when a successful notification cannot be checkpointed' -Test {
        Mock -ModuleName BridgeWatcher -CommandName Export-BridgeStatusJson -MockWith {
            [pscustomobject]@{Success=$false; ErrorCode='JSON_EXPORT_FAILURE'; ErrorMessage='Synthetic disk failure'}
        }
        { Update-BridgeStatus @script:Update } | Should -Throw -ExpectedMessage '*disk failure*'
        Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -Times 1 -Exactly
    }

    It -Name 'Keeps cold-start progress across a failed first broadcast' -Test {
        Remove-Item -LiteralPath $script:OutputFile -Confirm:$false
        $script:FailSecond = $true
        Mock -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -MockWith {
            param($CurrentState)
            if ($script:FailSecond -and $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia) {
                throw 'Synthetic delivery failure'
            }
        }
        { Update-BridgeStatus @script:Update } | Should -Throw -ExpectedMessage '*delivery failure*'
        $script:FailSecond = $false
        $null = Update-BridgeStatus @script:Update
        Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -Times 1 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.poseidonia
        }
        Should -Invoke -ModuleName BridgeWatcher -CommandName Invoke-BridgeOpenedNotification -Times 2 -Exactly -ParameterFilter {
            $CurrentState[0].GefyraName -eq $script:Config.BridgeNames.isthmia
        }
    }
}
