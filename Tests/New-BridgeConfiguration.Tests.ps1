Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'New-BridgeConfiguration' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        $script:Config = New-BridgeConfiguration
    }

    Context 'Default Instantiation' {
        It 'Returns an object with the correct type name' {
            $config = New-BridgeConfiguration
            $config.PSObject.TypeNames | Should -Contain 'BridgeWatcher.Configuration'
        }

        It 'Has default intervals and iterations configured' {
            $config = New-BridgeConfiguration
            $config.Defaults.IntervalSeconds | Should -Be 300
            $config.Defaults.MaxIterations | Should -Be 100
        }

        It 'Normalizes URLs' {
            $config = New-BridgeConfiguration -BaseUrl 'https://example.com'
            $config.Urls.Source | Should -Be 'https://example.com/'
            $config.Urls.BaseImage | Should -Be 'https://example.com'
        }

        It 'Defaults LogDirectory to TestDrive:\logs when running in Pester' {
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory | Should -Be 'TestDrive:\logs'
        }

        It 'Contains a unified Statuses dictionary with Greek translations' {
            $config = New-BridgeConfiguration
            $config.Statuses | Should -Not -BeNullOrEmpty
            $config.Statuses.Open | Should -Be 'Ανοιχτή'
            $config.Statuses.Closed | Should -Be 'Κλειστή'
            $config.Statuses.ClosedForMaintenance | Should -Be 'Κλειστή για συντήρηση'
            $config.Statuses.ClosedWithSchedule | Should -Be 'Κλειστή με πρόγραμμα'
            $config.Statuses.PermanentlyClosed | Should -Be 'Μόνιμα κλειστή'
            $config.Statuses.Unknown | Should -Be 'Άγνωστη'
        }
    }

    Context 'Custom Instantiation' {
        It 'Allows overriding default intervals and iterations' {
            $config = New-BridgeConfiguration -DefaultIntervalSeconds 120 -DefaultMaxIterations 50
            $config.Defaults.IntervalSeconds | Should -Be 120
            $config.Defaults.MaxIterations | Should -Be 50
        }

        It 'Applies ValidateRange constraint on DefaultIntervalSeconds' {
            { New-BridgeConfiguration -DefaultIntervalSeconds 0 } | Should -Throw
            { New-BridgeConfiguration -DefaultIntervalSeconds 3601 } | Should -Throw
        }

        It 'Applies ValidateRange constraint on DefaultMaxIterations' {
            { New-BridgeConfiguration -DefaultMaxIterations -1 } | Should -Throw
            { New-BridgeConfiguration -DefaultMaxIterations 1001 } | Should -Throw
        }
    }
}
