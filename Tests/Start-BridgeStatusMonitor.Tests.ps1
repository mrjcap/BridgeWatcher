Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Start-BridgeStatusMonitor' {
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
                Start-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 1
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
                Start-BridgeStatusMonitor @monitorParams -MaxIterations 1 -IntervalSeconds 10
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
                { Start-BridgeStatusMonitor @monitorParams -MaxIterations 1 -IntervalSeconds 1 -Verbose } | Should -Not -Throw
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
                Start-BridgeStatusMonitor @monitorParams -MaxIterations 2 -IntervalSeconds 123
                Should -Invoke Start-Sleep -ParameterFilter { $Seconds -eq 123 } -Exactly 1
            }
        }
    }
    Describe 'Start-BridgeStatusMonitor Function' {
        # Mocking Write-BridgeLog για να τεστάρουμε την καταγραφή χωρίς να γράφουμε πραγματικά logs
        It 'Πρέπει να καταγράφεται το σφάλμα όταν προκύπτει εξαίρεση' {
            Mock Write-BridgeLog {}
            # Προετοιμασία των παραμέτρων
            $maxIterations      = 3
            $intervalSeconds    = 1
            $outputFile         = 'C:\Logs\bridge.json'
            $apiKey             = 'api123'
            $poUserKey          = 'user123'
            $poApiKey           = 'token123'
            # Δημιουργία mock που θα ρίξει εξαίρεση στην Get-BridgeStatusComparison
            Mock Get-BridgeStatusComparison { throw 'Test Exception' }
            # Εκτέλεση της συνάρτησης
            $startBridgeStatusMonitorSplat = @{
                MaxIterations      = $maxIterations
                IntervalSeconds    = $intervalSeconds
                OutputFile         = $outputFile
                ApiKey             = $apiKey
                PoUserKey          = $poUserKey
                PoApiKey           = $poApiKey
            }
            Start-BridgeStatusMonitor @startBridgeStatusMonitorSplat
            # Επαληθεύουμε ότι η Write-BridgeLog καλείται για το σφάλμα
            Assert-MockCalled Write-BridgeLog -Exactly 3 -Scope It  # 1 για το μήνυμα εκκίνησης, 1 για το μήνυμα σφάλματος
        }
    }
}