Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Δοκιμές Get-BridgeStatusAdvice' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusAdvice.ps1"
    }

    It 'πρέπει να επιστρέφει "Είναι προτιμότερο να μην περιμένεις" when more than 12 minutes until open' {
        # Καλέστε τη συνάρτηση με τιμή πάνω από 12 λεπτά
        $result = Get-BridgeStatusAdvice -MinutesUntilOpen 15
        $result | Should -Be 'Είναι προτιμότερο να μην περιμένεις'
    }
    It 'πρέπει να επιστρέφει "Είναι προτιμότερο να μην περιμένεις" when minutes until open is negative' {
        $result = Get-BridgeStatusAdvice -MinutesUntilOpen -5
        $result | Should -Be 'Είναι προτιμότερο να μην περιμένεις'
    }
    It 'πρέπει να επιστρέφει "Είναι προτιμότερο να μην περιμένεις" when minutes until open is zero' {
        $result = Get-BridgeStatusAdvice -MinutesUntilOpen 0
        $result | Should -Be 'Είναι προτιμότερο να μην περιμένεις'
    }
    It 'πρέπει να επιστρέφει "Είναι προτιμότερο να περιμένεις" when 12 minutes or less until open' {
        # Καλέστε τη συνάρτηση με τιμή 12 ή λιγότερο
        $result = Get-BridgeStatusAdvice -MinutesUntilOpen 12
        $result | Should -Be 'Είναι προτιμότερο να περιμένεις'
        # Επιπλέον έλεγχος για τιμή 5 λεπτών
        $result = Get-BridgeStatusAdvice -MinutesUntilOpen 5
        $result | Should -Be 'Είναι προτιμότερο να περιμένεις'
    }

    Context 'Configuration Coverage Δοκιμές' {
        It 'Καλύπτει Configuration.DefaultMaxWaitTimeMinutes path' {
            $baseConfig = New-BridgeConfiguration
            $config = [PSCustomObject]@{
                Defaults       = [PSCustomObject]@{
                    MaxWaitTimeMinutes = 15
                }
                AdviceMessages = $baseConfig.AdviceMessages
                LoggingConfig  = $baseConfig.LoggingConfig
            }

            # Test with minutes above custom threshold
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 20 -Configuration $config
            $result | Should -Be 'Είναι προτιμότερο να μην περιμένεις'

            # Test with minutes at custom threshold
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 15 -Configuration $config
            $result | Should -Be 'Είναι προτιμότερο να περιμένεις'
        }

        It 'Καλύπτει Configuration.AdviceMessages.DoNotWait path' {
            $baseConfig = New-BridgeConfiguration
            $config = [PSCustomObject]@{
                Defaults       = $baseConfig.Defaults
                AdviceMessages = @{
                    DoNotWait = 'Custom message - do not wait'
                    Wait      = $baseConfig.AdviceMessages.Wait
                }
                LoggingConfig  = $baseConfig.LoggingConfig
            }

            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 20 -Configuration $config
            $result | Should -Be 'Custom message - do not wait'
        }

        It 'Καλύπτει Configuration.AdviceMessages.Wait path' {
            $baseConfig = New-BridgeConfiguration
            $config = [PSCustomObject]@{
                Defaults       = $baseConfig.Defaults
                AdviceMessages = @{
                    DoNotWait = $baseConfig.AdviceMessages.DoNotWait
                    Wait      = 'Custom message - wait'
                }
                LoggingConfig  = $baseConfig.LoggingConfig
            }

            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 5 -Configuration $config
            $result | Should -Be 'Custom message - wait'
        }

        It 'Καλύπτει όλες τις configuration paths μαζί' {
            $baseConfig = New-BridgeConfiguration
            $config = [PSCustomObject]@{
                Defaults       = [PSCustomObject]@{
                    MaxWaitTimeMinutes = 8
                }
                AdviceMessages = @{
                    DoNotWait = 'Custom do not wait'
                    Wait      = 'Custom wait'
                }
                LoggingConfig  = $baseConfig.LoggingConfig
            }

            # Test do not wait with custom threshold and message
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 10 -Configuration $config
            $result | Should -Be 'Custom do not wait'

            # Test wait with custom threshold and message
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 6 -Configuration $config
            $result | Should -Be 'Custom wait'
        }
    }
}
