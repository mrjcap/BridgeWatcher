Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'New-BridgeConfiguration' -Fixture {
    BeforeAll -Scriptblock {
        $script:Config = New-BridgeConfiguration
    }

    BeforeEach -Scriptblock {
        $script:SavedOutEnv = $Env:BRIDGEWATCHER_OUT
        $Env:BRIDGEWATCHER_OUT = $null
    }

    AfterEach -Scriptblock {
        $Env:BRIDGEWATCHER_OUT = $script:SavedOutEnv
    }

    Context -Name 'Default Instantiation' -Fixture {
        It -Name 'Returns an object with the correct type name' -Test {
            $config = New-BridgeConfiguration
            $config.PSObject.TypeNames | Should -Contain -ExpectedValue 'BridgeWatcher.Configuration'
        }

        It -Name 'Has default intervals and iterations configured' -Test {
            $config = New-BridgeConfiguration
            $config.Defaults.IntervalSeconds | Should -Be -ExpectedValue 300
            $config.Defaults.MaxIterations | Should -Be -ExpectedValue 100
        }

        It -Name 'Normalizes URLs' -Test {
            $config = New-BridgeConfiguration -BaseUrl 'https://example.com'
            $config.Urls.Source | Should -Be -ExpectedValue 'https://example.com/'
            $config.Urls.BaseImage | Should -Be -ExpectedValue 'https://example.com'
        }

        It -Name 'Defaults LogDirectory to BRIDGEWATCHER_OUT when set' -Test {
            $Env:BRIDGEWATCHER_OUT = '/app/logs'
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory | Should -Be -ExpectedValue '/app/logs'
        }

        It -Name 'Defaults LogDirectory to TestDrive:\logs when running in Pester' -Test {
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory | Should -Be -ExpectedValue 'TestDrive:\logs'
        }

        It -Name 'Χρησιμοποιεί το PSScriptRoot όταν δεν υπάρχει TestDrive' -Test {
            Mock -ModuleName BridgeWatcher -CommandName Test-Path -MockWith { return $false } -ParameterFilter { $Path -eq 'TestDrive:\' }
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory | Should -Match -RegularExpression 'logs$'
        }

        It -Name 'Contains a unified Statuses dictionary with Greek translations' -Test {
            $config = New-BridgeConfiguration
            $config.Statuses | Should -Not -BeNullOrEmpty
            $config.Statuses.Open | Should -Be -ExpectedValue 'Ανοιχτή'
            $config.Statuses.Closed | Should -Be -ExpectedValue 'Κλειστή'
            $config.Statuses.ClosedForMaintenance | Should -Be -ExpectedValue 'Κλειστή για συντήρηση'
            $config.Statuses.ClosedWithSchedule | Should -Be -ExpectedValue 'Κλειστή με πρόγραμμα'
            $config.Statuses.PermanentlyClosed | Should -Be -ExpectedValue 'Μόνιμα κλειστή'
            $config.Statuses.Unknown | Should -Be -ExpectedValue 'Άγνωστη'
        }

        It -Name 'Defines only LoggingConfig stages and levels accepted by Write-BridgeLog ValidateSet' -Test {
            $config = New-BridgeConfiguration
            $validSets = InModuleScope -ModuleName BridgeWatcher -ScriptBlock {
                $cmd = Get-Command -Name Write-BridgeLog -CommandType Function
                $stageAttr = $cmd.Parameters['Stage'].Attributes |
                    Where-Object -FilterScript { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
                    Select-Object -First 1
                $levelAttr = $cmd.Parameters['Level'].Attributes |
                    Where-Object -FilterScript { $_ -is [System.Management.Automation.ValidateSetAttribute] } |
                    Select-Object -First 1
                @{
                    Stages = @($stageAttr.ValidValues)
                    Levels = @($levelAttr.ValidValues)
                }
            }

            $stageKeys = @($config.LoggingConfig.Keys | Where-Object -FilterScript { $_ -like '*Stage' })
            $levelKeys = @($config.LoggingConfig.Keys | Where-Object -FilterScript { $_ -like '*Level' })

            $stageKeys.Count | Should -BeGreaterThan -ExpectedValue 0
            $levelKeys.Count | Should -BeGreaterThan -ExpectedValue 0
            ($stageKeys.Count + $levelKeys.Count) | Should -Be -ExpectedValue $config.LoggingConfig.Keys.Count

            foreach ($key in $stageKeys) {
                $validSets.Stages | Should -Contain -ExpectedValue $config.LoggingConfig[$key]
            }
            foreach ($key in $levelKeys) {
                $validSets.Levels | Should -Contain -ExpectedValue $config.LoggingConfig[$key]
            }

            $config.LoggingConfig.Keys | Should -Not -Contain -ExpectedValue 'DebugStage'
            $config.LoggingConfig.Keys | Should -Not -Contain -ExpectedValue 'ErrorLevel'
            $config.LoggingConfig.Keys | Should -Not -Contain -ExpectedValue 'InfoLevel'
        }
    }

    Context -Name 'Optional ConfigurationPath parameter' -Fixture {
        It -Name 'Loads and overlays settings when valid JSON path is provided' -Test {
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
            $config.Urls.Source | Should -Be -ExpectedValue 'https://custom.example.com'
            $config.Urls.CustomUrl | Should -Be -ExpectedValue 'https://custom.example.com/extra'
            $config.Defaults.IntervalSeconds | Should -Be -ExpectedValue 60
            $config.Defaults.CustomFlag | Should -Be -ExpectedValue $true
        }

        It -Name 'Throws FileNotFoundException when configuration path does not exist' -Test {
            { New-BridgeConfiguration -ConfigurationPath 'TestDrive:\missing.json' } | Should -Throw
        }

        It -Name 'Loads partial JSON override containing only Defaults without Urls under strict mode' -Test {
            $partialDefaultsPath = 'TestDrive:\partial-defaults.json'
            Set-Content -Path $partialDefaultsPath -Value '{"Defaults":{"IntervalSeconds":60}}' -Encoding utf8
            $config = New-BridgeConfiguration -ConfigurationPath $partialDefaultsPath
            $config.Defaults.IntervalSeconds | Should -Be -ExpectedValue 60
            $config.Urls.Source | Should -Be -ExpectedValue 'https://www.topvision.gr/dioriga/'
        }

        It -Name 'Loads partial JSON override containing only Urls without Defaults under strict mode' -Test {
            $partialUrlsPath = 'TestDrive:\partial-urls.json'
            Set-Content -Path $partialUrlsPath -Value '{"Urls":{"Source":"https://partial.example.com/"}}' -Encoding utf8
            $config = New-BridgeConfiguration -ConfigurationPath $partialUrlsPath
            $config.Urls.Source | Should -Be -ExpectedValue 'https://partial.example.com/'
            $config.Defaults.IntervalSeconds | Should -Be -ExpectedValue 300
        }
    }

    Context -Name 'Parameter overrides' -Fixture {
        It -Name 'Χρησιμοποιεί DefaultMaxIterations αν παρασχεθεί' -Test {
            $config = New-BridgeConfiguration -BaseUrl 'https://test.com' -OCRApiUrl 'https://ocr.com' -PushoverApiUrl 'https://po.com' -DefaultMaxIterations 500
            $config.Defaults.MaxIterations | Should -Be -ExpectedValue 500
        }

        It -Name 'Θέτει MaxConsecutiveFailures αν παρασχεθεί' -Test {
            $config = New-BridgeConfiguration -BaseUrl 'https://test.com' -OCRApiUrl 'https://ocr.com' -PushoverApiUrl 'https://po.com' -MaxConsecutiveFailures 20
            $config.Defaults.MaxConsecutiveFailures | Should -Be -ExpectedValue 20
        }

        It -Name 'Allows overriding default intervals and iterations' -Test {
            $config = New-BridgeConfiguration -DefaultIntervalSeconds 120 -DefaultMaxIterations 50
            $config.Defaults.IntervalSeconds | Should -Be -ExpectedValue 120
            $config.Defaults.MaxIterations | Should -Be -ExpectedValue 50
        }

        It -Name 'Applies ValidateRange constraint on DefaultIntervalSeconds' -Test {
            { New-BridgeConfiguration -DefaultIntervalSeconds 0 } | Should -Throw
            { New-BridgeConfiguration -DefaultIntervalSeconds 3601 } | Should -Throw
        }

        It -Name 'Applies ValidateRange constraint on DefaultMaxIterations' -Test {
            { New-BridgeConfiguration -DefaultMaxIterations -1 } | Should -Throw
            { New-BridgeConfiguration -DefaultMaxIterations 1001 } | Should -Throw
        }

        It -Name 'Allows overriding PushoverApiUrl' -Test {
            $config = New-BridgeConfiguration -PushoverApiUrl 'https://custom.pushover.example/messages'
            $config.Urls.PushoverApi | Should -Be -ExpectedValue 'https://custom.pushover.example/messages'
        }

        It -Name 'Uses default PushoverApiUrl when not specified' -Test {
            $config = New-BridgeConfiguration
            $config.Urls.PushoverApi | Should -Be -ExpectedValue 'https://api.pushover.net/1/messages.json'
        }
    }
}
