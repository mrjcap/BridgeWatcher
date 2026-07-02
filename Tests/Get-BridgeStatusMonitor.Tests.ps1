Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-BridgeStatusMonitor' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Update-BridgeStatus.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatusMonitor.ps1"
    }

    Context 'Default Parameters' {
        It 'Καλεί Update-BridgeStatus και Start-Sleep σε loop' {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }
            Mock -CommandName Start-Sleep

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
            }

            Get-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 1
            Assert-MockCalled Update-BridgeStatus -Exactly 2
            Assert-MockCalled Start-Sleep -Exactly 1
        }
    }

    Context 'Όταν ζητείται μόνο μία επανάληψη' {
        It 'Δεν κάνει Sleep μετά την πρώτη' {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }
            Mock -CommandName Start-Sleep

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
            }

            Get-BridgeStatusMonitor @monitorParams -MaxIterations 1 -IntervalSeconds 10
            Assert-MockCalled Update-BridgeStatus -Exactly 1
            Assert-MockCalled Start-Sleep -Times 0 -Exactly
        }
    }

    Context 'Με ενεργοποιημένο Verbose' {
        It 'Εκτυπώνει verbose μηνύματα' {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }
            Mock -CommandName Start-Sleep

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
            }

            { Get-BridgeStatusMonitor @monitorParams -MaxIterations 1 -IntervalSeconds 1 -Verbose } | Should -Not -Throw
        }
    }

    Context 'Ελέγχει παραμέτρους' {
        It 'Χρησιμοποιεί την τιμή του IntervalSeconds' {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }
            Mock -CommandName Start-Sleep

            $monitorParams = @{
                OutputFile = 'test.json'
                ApiKey     = 'dummy-api-key'
                PoUserKey  = 'dummy-user-key'
                PoApiKey   = 'dummy-app-key'
            }

            Get-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 123
            Assert-MockCalled Start-Sleep -ParameterFilter { $Seconds -eq 123 } -Exactly 1
        }
    }

    Context 'Custom Action Parameter' {
        It 'Executes custom Action instead of Update-BridgeStatus' {
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

            Get-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 1
            $tracker.Called | Should -Be $true
            Assert-MockCalled Update-BridgeStatus -Times 0 -Exactly
        }
    }

    Context 'Exception Handling' {
        It 'Πρέπει να καταγράφεται το σφάλμα όταν προκύπτει εξαίρεση' {
            Mock Write-BridgeLog {}
            Mock Start-Sleep
            Mock Update-BridgeStatus { throw 'Test Exception' }

            $startBridgeStatusMonitorSplat = @{
                MaxIterations   = 3
                IntervalSeconds = 1
                OutputFile      = 'C:\Logs\bridge.json'
                ApiKey          = 'api123'
                PoUserKey       = 'user123'
                PoApiKey        = 'token123'
            }

            Get-BridgeStatusMonitor @startBridgeStatusMonitorSplat
            # 1 για το μήνυμα εκκίνησης, 3 για το μήνυμα σφάλματος σε κάθε επανάληψη, 1 για το μήνυμα ολοκλήρωσης
            Assert-MockCalled Write-BridgeLog -Exactly 5
        }
    }
    Context 'Προεπιλεγμένες Παράμετροι' {
        It 'Χρησιμοποιεί DefaultMaxIterations και DefaultIntervalSeconds αν δεν δοθούν' {
            Mock -CommandName Update-BridgeStatus -MockWith { @{ dummy = $true } }

            # Use real configuration object, which is available because we dot-source New-BridgeConfiguration
            $mockConfig = New-BridgeConfiguration
            $mockConfig.Defaults.MaxIterations = 1
            $mockConfig.Defaults.IntervalSeconds = 1

            # Δεν περνάμε -MaxIterations και -IntervalSeconds, αλλά δίνουμε dummy παραμέτρους για το Update-BridgeStatus
            Get-BridgeStatusMonitor -Configuration $mockConfig -OutputFile 'test.json' -ApiKey 'dummy' -PoUserKey 'dummy' -PoApiKey 'dummy'
            Assert-MockCalled Update-BridgeStatus -Exactly 1
        }
    }

    Context 'Σφάλμα αρχικοποίησης διαμόρφωσης' {
        It 'Ρίχνει terminating error όταν η New-BridgeConfiguration αποτυγχάνει' {
            Mock New-BridgeConfiguration { throw "Configuration error" }

            { Get-BridgeStatusMonitor -OutputFile 'test.json' } | Should -Throw "Η αρχικοποίηση της διαμόρφωσης απέτυχε: Configuration error"
        }
    }
}



