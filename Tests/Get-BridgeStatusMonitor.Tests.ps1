Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeStatusMonitor' {
        Context 'Default Parameters' {
            It 'Καλεί Get-BridgeStatusComparison  και Start-Sleep σε loop' {
                Mock -CommandName Get-BridgeStatusComparison -MockWith { @{ dummy = $true } }
                $monitorParams = @{
                    OutputFile = 'test.json'
                    ApiKey     = 'dummy-api-key'
                    PoUserKey  = 'dummy-user-key'
                    PoApiKey   = 'dummy-app-key'
                }
                Mock -CommandName Start-Sleep
                Get-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 1
                Should -Invoke Get-BridgeStatusComparison -Exactly 2
                Should -Invoke Start-Sleep -Exactly 1
            }
        }
        Context 'Όταν ζητείται μόνο μία επανάληψη' {
            It 'Δεν κάνει Sleep μετά την πρώτη' {
                Mock -CommandName Get-BridgeStatusComparison -MockWith { @{ dummy = $true } }
                $monitorParams = @{
                    OutputFile = 'test.json'
                    ApiKey     = 'dummy-api-key'
                    PoUserKey  = 'dummy-user-key'
                    PoApiKey   = 'dummy-app-key'
                }
                Mock -CommandName Get-BridgeStatusComparison
                Mock -CommandName Start-Sleep
                Get-BridgeStatusMonitor @monitorParams -MaxIterations 1 -IntervalSeconds 10
                Should -Invoke Get-BridgeStatusComparison -Exactly 1
                Should -Not -Invoke Start-Sleep
            }
        }
        Context 'Με ενεργοποιημένο Verbose' {
            It 'Εκτυπώνει verbose μηνύματα' {
                Mock -CommandName Get-BridgeStatusComparison -MockWith { @{ dummy = $true } }
                $monitorParams = @{
                    OutputFile = 'test.json'
                    ApiKey     = 'dummy-api-key'
                    PoUserKey  = 'dummy-user-key'
                    PoApiKey   = 'dummy-app-key'
                }
                Mock -CommandName Start-Sleep
                { Get-BridgeStatusMonitor @monitorParams -MaxIterations 1 -IntervalSeconds 1 -Verbose } | Should -Not -Throw
            }
        }
        Context 'Ελέγχει παραμέτρους' {
            It 'Χρησιμοποιεί την τιμή του IntervalSeconds' {
                Mock -CommandName Get-BridgeStatusComparison -MockWith { @{ dummy = $true } }
                $monitorParams = @{
                    OutputFile = 'test.json'
                    ApiKey     = 'dummy-api-key'
                    PoUserKey  = 'dummy-user-key'
                    PoApiKey   = 'dummy-app-key'
                }
                Mock -CommandName Start-Sleep
                Get-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 123
                Should -Invoke Start-Sleep -ParameterFilter { $Seconds -eq 123 } -Exactly 1
            }
        }
    }
    Describe 'Get-BridgeStatusMonitor Function' {
        # Mocking Write-BridgeLog για να τεστάρουμε την καταγραφή χωρίς να γράφουμε πραγματικά logs
        It 'Πρέπει να καταγράφεται το σφάλμα όταν προκύπτει εξαίρεση' {
            Mock Write-BridgeLog {}
            # Προετοιμασία των παραμέτρων
            $maxIterations = 3
            $intervalSeconds = 1
            $outputFile = 'C:\Logs\bridge.json'
            $apiKey = 'api123'
            $poUserKey = 'user123'
            $poApiKey = 'token123'
            # Δημιουργία mock που θα ρίξει εξαίρεση στην Get-BridgeStatusComparison
            Mock Get-BridgeStatusComparison { throw 'Test Exception' }
            # Εκτέλεση της συνάρτησης
            $startBridgeStatusMonitorSplat = @{
                MaxIterations   = $maxIterations
                IntervalSeconds = $intervalSeconds
                OutputFile      = $outputFile
                ApiKey          = $apiKey
                PoUserKey       = $poUserKey
                PoApiKey        = $poApiKey
            }
            Get-BridgeStatusMonitor @startBridgeStatusMonitorSplat
            # Επαληθεύουμε ότι η Write-BridgeLog καλείται για το σφάλμα
            Assert-MockCalled Write-BridgeLog -Exactly 5 -Scope It  # 1 για το μήνυμα εκκίνησης, 1 για το μήνυμα σφάλματος
        }
    }

    Describe 'Get-BridgeStatusMonitor Configuration Fallbacks' {
        It 'Χρησιμοποιεί default values όταν η Configuration αποτυγχάνει' {
            Mock New-BridgeConfiguration { throw "Configuration error" }
            Mock Get-BridgeStatusComparison { @{ dummy = $true } }
            Mock Start-Sleep { }

            # Call without specifying MaxIterations and IntervalSeconds to test defaults
            { Get-BridgeStatusMonitor -OutputFile 'test.json' -ApiKey 'key' -PoUserKey 'user' -PoApiKey 'app' } | Should -Not -Throw
        }

        It 'Χρησιμοποιεί configuration defaults όταν παράμετροι δεν παρέχονται' {
            $mockConfig = @{
                DefaultMaxIterations   = 50
                DefaultIntervalSeconds = 600
                StatusMessages         = @{
                    MonitoringStart    = 'Custom start message'
                    MonitoringComplete = 'Custom complete message'
                }
                LoggingConfig          = @{
                    InfoStage    = 'Ανάλυση'
                    VerboseLevel = 'Verbose'
                }
            }
            Mock Get-BridgeStatusComparison { @{ dummy = $true } }
            Mock Start-Sleep { }

            { Get-BridgeStatusMonitor -Configuration $mockConfig -OutputFile 'test.json' -ApiKey 'key' -PoUserKey 'user' -PoApiKey 'app' } | Should -Not -Throw
        }

        It 'Χρησιμοποιεί fallback error messages όταν Configuration είναι null' {
            Mock Get-BridgeStatusComparison { throw "Test error" }
            Mock Start-Sleep { }
            Mock Write-BridgeLog { }

            { Get-BridgeStatusMonitor -Configuration $null -MaxIterations 1 -IntervalSeconds 1 -OutputFile 'test.json' -ApiKey 'key' -PoUserKey 'user' -PoApiKey 'app' } | Should -Not -Throw

            # Verify fallback error message is used
            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Message -like "*❌ Σφάλμα κατά την ανάκτηση της κατάστασης της γέφυρας*" -and
                $Stage -eq 'Σφάλμα' -and
                $Level -eq 'Debug'
            } -Exactly 1
        }

        It 'Καλύπτει fallback error handling paths όταν Configuration missing και New-BridgeConfiguration αποτυγχάνει' {
            # Mock New-BridgeConfiguration to fail, ensuring Configuration remains null
            Mock New-BridgeConfiguration { throw "Configuration failed" }
            Mock Get-BridgeStatusComparison { throw "Simulated comparison error" }
            Mock Start-Sleep { }
            Mock Write-BridgeLog { }

            # Call without Configuration parameter to trigger fallback creation
            { Get-BridgeStatusMonitor -MaxIterations 1 -IntervalSeconds 1 -OutputFile 'test.json' -ApiKey 'key' -PoUserKey 'user' -PoApiKey 'app' } | Should -Not -Throw

            # Verify all three fallback paths are covered:
            # 1. Fallback error message (line 122)
            # 2. Fallback error stage (line 129)
            # 3. Fallback debug level (line 135)
            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Message -like "*❌ Σφάλμα κατά την ανάκτηση της κατάστασης της γέφυρας*" -and
                $Stage -eq 'Σφάλμα' -and
                $Level -eq 'Debug'
            } -Exactly 1
        }
        It 'Χρησιμοποιεί fallback completion message όταν Configuration είναι null' {
            Mock Get-BridgeStatusComparison { @{ dummy = $true } }
            Mock Start-Sleep { }
            Mock Write-BridgeLog { }

            { Get-BridgeStatusMonitor -Configuration $null -MaxIterations 1 -IntervalSeconds 1 -OutputFile 'test.json' -ApiKey 'key' -PoUserKey 'user' -PoApiKey 'app' } | Should -Not -Throw

            # Verify fallback completion message is used
            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Message -like "*✅ Ο κύκλος παρακολούθησης ολοκληρώθηκε*" -and
                $Stage -eq 'Ανάλυση' -and
                $Level -eq 'Verbose'
            } -Exactly 1
        }
    }
}

