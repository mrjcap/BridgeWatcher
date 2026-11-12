Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'New-BridgeConfiguration' {
    BeforeAll {
        $script:Config = New-BridgeConfiguration
    }

    BeforeEach {
        $script:SavedOutEnv = $Env:BRIDGEWATCHER_OUT
        $Env:BRIDGEWATCHER_OUT = $null
    }

    AfterEach {
        $Env:BRIDGEWATCHER_OUT = $script:SavedOutEnv
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

        It 'Defaults LogDirectory to BRIDGEWATCHER_OUT when set' {
            $Env:BRIDGEWATCHER_OUT = '/app/logs'
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory | Should -Be '/app/logs'
        }

        It 'Defaults LogDirectory to TestDrive:\logs when running in Pester' {
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory | Should -Be 'TestDrive:\logs'
        }

        It 'Χρησιμοποιεί το PSScriptRoot όταν δεν υπάρχει TestDrive' {
            Mock -ModuleName BridgeWatcher -CommandName Test-Path -MockWith { return $false } -ParameterFilter { $Path -eq 'TestDrive:\' }
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory | Should -Match 'logs$'
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

    Context 'Optional ConfigurationPath parameter' {
        It 'Loads and overlays settings when valid JSON path is provided' {
            $customConfigPath = 'TestDrive:\custom-config.json'
            $json = @'
{
    "Urls": {
        "Source": "https://custom.example.com",
        "CustomUrl": "https://custom.example.com/extra"
    },
    "Defaults": {
        "IntervalSeconds": 60,
        "CustomFlag": true
    }
}
'@
            Set-Content -Path $customConfigPath -Value $json -Encoding utf8
            $config = New-BridgeConfiguration -ConfigurationPath $customConfigPath
            $config.Urls.Source | Should -Be 'https://custom.example.com'
            $config.Urls.CustomUrl | Should -Be 'https://custom.example.com/extra'
            $config.Defaults.IntervalSeconds | Should -Be 60
            $config.Defaults.CustomFlag | Should -Be $true
        }

        It 'Throws FileNotFoundException when configuration path does not exist' {
            { New-BridgeConfiguration -ConfigurationPath 'TestDrive:\missing.json' } | Should -Throw
        }

        It 'Loads partial JSON override containing only Defaults without Urls under strict mode' {
            $partialDefaultsPath = 'TestDrive:\partial-defaults.json'
            Set-Content -Path $partialDefaultsPath -Value '{"Defaults":{"IntervalSeconds":60}}' -Encoding utf8
            $config = New-BridgeConfiguration -ConfigurationPath $partialDefaultsPath
            $config.Defaults.IntervalSeconds | Should -Be 60
            $config.Urls.Source | Should -Be 'https://www.topvision.gr/dioriga/'
        }

        It 'Loads partial JSON override containing only Urls without Defaults under strict mode' {
            $partialUrlsPath = 'TestDrive:\partial-urls.json'
            Set-Content -Path $partialUrlsPath -Value '{"Urls":{"Source":"https://partial.example.com/"}}' -Encoding utf8
            $config = New-BridgeConfiguration -ConfigurationPath $partialUrlsPath
            $config.Urls.Source | Should -Be 'https://partial.example.com/'
            $config.Defaults.IntervalSeconds | Should -Be 300
        }
    }

    Context 'Parameter overrides' {
        It 'Χρησιμοποιεί DefaultMaxIterations αν παρασχεθεί' {
            $config = New-BridgeConfiguration -BaseUrl 'https://test.com' -OCRApiUrl 'https://ocr.com' -PushoverApiUrl 'https://po.com' -DefaultMaxIterations 500
            $config.Defaults.MaxIterations | Should -Be 500
        }

        It 'Θέτει MaxConsecutiveFailures αν παρασχεθεί' {
            $config = New-BridgeConfiguration -BaseUrl 'https://test.com' -OCRApiUrl 'https://ocr.com' -PushoverApiUrl 'https://po.com' -MaxConsecutiveFailures 20
            $config.Defaults.MaxConsecutiveFailures | Should -Be 20
        }

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

        It 'Allows overriding PushoverApiUrl' {
            $config = New-BridgeConfiguration -PushoverApiUrl 'https://custom.pushover.example/messages'
            $config.Urls.PushoverApi | Should -Be 'https://custom.pushover.example/messages'
        }

        It 'Uses default PushoverApiUrl when not specified' {
            $config = New-BridgeConfiguration
            $config.Urls.PushoverApi | Should -Be 'https://api.pushover.net/1/messages.json'
        }
    }
}
