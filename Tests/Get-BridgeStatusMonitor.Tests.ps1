Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'Get-BridgeStatusMonitor' -Fixture {
    BeforeAll -Scriptblock {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Update-BridgeStatus.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatusMonitor.ps1"
        $script:Config = New-BridgeConfiguration
    }

    Context -Name 'Default Parameters' -Fixture {
        It -Name 'Καλεί Update-BridgeStatus και Start-Sleep σε loop' -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }
            Mock -CommandName Start-Sleep

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
            }

            Get-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 1 -Configuration $script:Config
            Should -Invoke -CommandName Update-BridgeStatus -Times 2 -Exactly
            Should -Invoke -CommandName Start-Sleep -Times 1 -Exactly
        }
    }

    Context -Name 'Όταν ζητείται μόνο μία επανάληψη' -Fixture {
        It -Name 'Δεν κάνει Sleep μετά την πρώτη' -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }
            Mock -CommandName Start-Sleep

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
            }

            Get-BridgeStatusMonitor @monitorParams -MaxIterations 1 -IntervalSeconds 10 -Configuration $script:Config
            Should -Invoke -CommandName Update-BridgeStatus -Times 1 -Exactly
            Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
        }
    }

    Context -Name 'Με ενεργοποιημένο Verbose' -Fixture {
        It -Name 'Εκτυπώνει verbose μηνύματα' -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }
            Mock -CommandName Start-Sleep

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
            }

            { Get-BridgeStatusMonitor @monitorParams -MaxIterations 1 -IntervalSeconds 1 -Verbose -Configuration $script:Config } | Should -Not -Throw
        }
    }

    Context -Name 'Ελέγχει παραμέτρους' -Fixture {
        It -Name 'Χρησιμοποιεί την τιμή του IntervalSeconds' -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }
            Mock -CommandName Start-Sleep

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
            }

            Get-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 123 -Configuration $script:Config
            Should -Invoke -CommandName Start-Sleep -ParameterFilter { $Seconds -eq 123 } -Times 1 -Exactly
        }
    }

    Context -Name 'Custom Action Parameter' -Fixture {
        It -Name 'Executes custom Action instead of Update-BridgeStatus' -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { }
            Mock -CommandName Start-Sleep

            $tracker = @{ Called = $false }
            $customAction = {
                $tracker.Called = $true
            }

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
                Action     = $customAction
            }

            Get-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 1 -Configuration $script:Config
            $tracker.Called | Should -Be -ExpectedValue $true
            Should -Invoke -CommandName Update-BridgeStatus -Times 0 -Exactly
        }

        It -Name 'Executes custom Action without ApiKey, PoUserKey, or PoApiKey and omits unbound keys from splat' -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { }
            Mock -CommandName Start-Sleep
            Mock -CommandName Write-BridgeLog

            $script:capturedSplat = $null
            $customAction = {
                param($splat)
                $script:capturedSplat = $splat
            }

            { Get-BridgeStatusMonitor -Configuration $script:Config -OutputFile 'test.json' -MaxIterations 1 -IntervalSeconds 1 -Action $customAction } | Should -Not -Throw
            $script:capturedSplat | Should -Not -BeNullOrEmpty
            $script:capturedSplat.OutputFile | Should -Be -ExpectedValue 'test.json'
            $script:capturedSplat.ContainsKey('ApiKey') | Should -BeFalse
            $script:capturedSplat.ContainsKey('PoUserKey') | Should -BeFalse
            $script:capturedSplat.ContainsKey('PoApiKey') | Should -BeFalse
            Should -Invoke -CommandName Update-BridgeStatus -Times 0 -Exactly
        }

        It -Name 'Enforces DefaultAction mandatory keys and CustomAction optional keys via ParameterSets' -Test {
            $cmdInfo = Get-Command -Name Get-BridgeStatusMonitor
            $cmdInfo.DefaultParameterSet | Should -Be -ExpectedValue 'DefaultAction'

            $defaultSet = $cmdInfo.ParameterSets | Where-Object -FilterScript { $_.Name -eq 'DefaultAction' }
            ($defaultSet.Parameters | Where-Object -FilterScript { $_.Name -eq 'ApiKey' }).IsMandatory | Should -BeTrue
            ($defaultSet.Parameters | Where-Object -FilterScript { $_.Name -eq 'PoUserKey' }).IsMandatory | Should -BeTrue
            ($defaultSet.Parameters | Where-Object -FilterScript { $_.Name -eq 'PoApiKey' }).IsMandatory | Should -BeTrue

            $customSet = $cmdInfo.ParameterSets | Where-Object -FilterScript { $_.Name -eq 'CustomAction' }
            ($customSet.Parameters | Where-Object -FilterScript { $_.Name -eq 'Action' }).IsMandatory | Should -BeTrue
            ($customSet.Parameters | Where-Object -FilterScript { $_.Name -eq 'ApiKey' }).IsMandatory | Should -BeFalse
            ($customSet.Parameters | Where-Object -FilterScript { $_.Name -eq 'PoUserKey' }).IsMandatory | Should -BeFalse
            ($customSet.Parameters | Where-Object -FilterScript { $_.Name -eq 'PoApiKey' }).IsMandatory | Should -BeFalse

            { Get-BridgeStatusMonitor -Configuration $script:Config -OutputFile 'test.json' -ApiKey '' -PoUserKey 'u' -PoApiKey 'p' } | Should -Throw
        }
    }

    Context -Name 'Exception Handling' -Fixture {
        It -Name 'Συνεχίζει την εκτέλεση όταν αποτυγχάνει η Update-BridgeStatus αλλά τουλάχιστον μία πετυχαίνει' -Test {
            Mock -CommandName Write-BridgeLog -MockWith {}
            Mock -CommandName Start-Sleep
            $script:callCount = 0
            Mock -CommandName Update-BridgeStatus -MockWith {
                $script:callCount++
                if ($script:callCount -eq 2) {
                    return @{ dummy = $true }
                } else {
                    throw 'Test Exception'
                }
            }

            $startBridgeStatusMonitorSplat = @{
                MaxIterations   = 3
                IntervalSeconds = 1
                OutputFile      = 'C:\Logs\bridge.json'
                ApiKey          = 'api123'
                PoUserKey       = 'user123'
                PoApiKey        = 'token123'
            }

            { Get-BridgeStatusMonitor @startBridgeStatusMonitorSplat -Configuration $script:Config } | Should -Not -Throw
            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -ParameterFilter {
                $Stage -eq $script:Config.LoggingConfig.InfoStage -and
                $Level -eq $script:Config.LoggingConfig.VerboseLevel -and
                $Message -like "$($script:Config.StatusMessages.MonitoringStart)*"
            }
            Should -Invoke -CommandName Write-BridgeLog -Times 2 -Exactly -ParameterFilter {
                $Stage -eq $script:Config.LoggingConfig.ErrorStage -and
                $Level -eq $script:Config.LoggingConfig.WarningLevel -and
                $Message -like "$($script:Config.ErrorMessages.MonitoringError)*Test Exception*"
            }
            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -ParameterFilter {
                $Stage -eq $script:Config.LoggingConfig.InfoStage -and
                $Level -eq $script:Config.LoggingConfig.VerboseLevel -and
                $Message -like "$($script:Config.StatusMessages.MonitoringComplete)*"
            }
        }
    }
    Context -Name 'Προεπιλεγμένες Παράμετροι' -Fixture {
        It -Name 'Χρησιμοποιεί DefaultMaxIterations και DefaultIntervalSeconds αν δεν δοθούν' -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }

            $mockConfig = New-BridgeConfiguration
            $mockConfig.Defaults.MaxIterations = 1
            $mockConfig.Defaults.IntervalSeconds = 1

            Get-BridgeStatusMonitor -Configuration $mockConfig -OutputFile 'test.json' -ApiKey 'dummy' -PoUserKey 'dummy' -PoApiKey 'dummy'
            Should -Invoke -CommandName Update-BridgeStatus -Times 1 -Exactly
        }
    }



    Context -Name 'Loop Failure Contract' -Fixture {
        It -Name 'Throws a terminating error if the maximum consecutive failures are reached' -Test {
            Mock -CommandName Update-BridgeStatus -MockWith { throw "Simulated API Failure" }
            Mock -CommandName Start-Sleep
            Mock -CommandName Write-BridgeLog

            $script:Config.Defaults.MaxConsecutiveFailures = 5

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy'
                PoUserKey  = 'dummy'
                PoApiKey   = 'dummy'
                Configuration = $script:Config
            }

            { Get-BridgeStatusMonitor @monitorParams -MaxIterations 10 -IntervalSeconds 1 -Configuration $script:Config } | Should -Throw -ExpectedMessage "Monitoring failed 5 consecutive times. Halting."
            Should -Invoke -CommandName Update-BridgeStatus -Times 5 -Exactly
        }

        It -Name 'Terminates immediately on iteration 1 with zero Start-Sleep calls on ParameterBindingException' -Test {
            Mock -CommandName Start-Sleep
            Mock -CommandName Write-BridgeLog

            $script:bindingAttemptCount = 0
            $failingAction = {
                $script:bindingAttemptCount++
                Update-BridgeStatus -Configuration $script:Config -OutputFile '' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'p'
            }

            { Get-BridgeStatusMonitor -Configuration $script:Config -OutputFile 'test.json' -MaxIterations 5 -IntervalSeconds 10 -Action $failingAction } | Should -Throw
            $script:bindingAttemptCount | Should -Be -ExpectedValue 1
            Should -Invoke -CommandName Start-Sleep -Times 0 -Exactly
        }
    }
}



