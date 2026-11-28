Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'Δοκιμές Get-BridgeStatusAdvice' -Fixture {
    BeforeAll -Scriptblock {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusAdvice.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It -Name 'πρέπει να επιστρέφει "Είναι προτιμότερο να μην περιμένεις" when more than 12 minutes until open' -Test {
        $result = Get-BridgeStatusAdvice -Configuration $script:Config -MinutesUntilOpen 15
        $result | Should -Be -ExpectedValue 'Είναι προτιμότερο να μην περιμένεις'
    }
    It -Name 'πρέπει να επιστρέφει "Είναι προτιμότερο να μην περιμένεις" when minutes until open is negative' -Test {
        $result = Get-BridgeStatusAdvice -Configuration $script:Config -MinutesUntilOpen -5
        $result | Should -Be -ExpectedValue 'Είναι προτιμότερο να μην περιμένεις'
    }
    It -Name 'πρέπει να επιστρέφει "Είναι προτιμότερο να μην περιμένεις" when minutes until open is zero' -Test {
        $result = Get-BridgeStatusAdvice -Configuration $script:Config -MinutesUntilOpen 0
        $result | Should -Be -ExpectedValue 'Είναι προτιμότερο να μην περιμένεις'
    }
    It -Name 'πρέπει να επιστρέφει "Είναι προτιμότερο να περιμένεις" when 12 minutes or less until open' -Test {
        $result = Get-BridgeStatusAdvice -Configuration $script:Config -MinutesUntilOpen 12
        $result | Should -Be -ExpectedValue 'Είναι προτιμότερο να περιμένεις'
        $result = Get-BridgeStatusAdvice -Configuration $script:Config -MinutesUntilOpen 5
        $result | Should -Be -ExpectedValue 'Είναι προτιμότερο να περιμένεις'
    }

    Context -Name 'Configuration Coverage Δοκιμές' -Fixture {
        It -Name 'Καλύπτει Configuration.DefaultMaxWaitTimeMinutes path' -Test {
            $baseConfig = New-BridgeConfiguration
            $config = [PSCustomObject]@{
                Defaults       = [PSCustomObject]@{
                    MaxWaitTimeMinutes = 15
                }
                AdviceMessages = $baseConfig.AdviceMessages
                LoggingConfig  = $baseConfig.LoggingConfig
            }

            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 20 -Configuration $config
            $result | Should -Be -ExpectedValue 'Είναι προτιμότερο να μην περιμένεις'

            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 15 -Configuration $config
            $result | Should -Be -ExpectedValue 'Είναι προτιμότερο να περιμένεις'
        }

        It -Name 'Καλύπτει Configuration.AdviceMessages.DoNotWait path' -Test {
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
            $result | Should -Be -ExpectedValue 'Custom message - do not wait'
        }

        It -Name 'Καλύπτει Configuration.AdviceMessages.Wait path' -Test {
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
            $result | Should -Be -ExpectedValue 'Custom message - wait'
        }

        It -Name 'Καλύπτει όλες τις configuration paths μαζί' -Test {
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

            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 10 -Configuration $config
            $result | Should -Be -ExpectedValue 'Custom do not wait'

            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 6 -Configuration $config
            $result | Should -Be -ExpectedValue 'Custom wait'
        }
    }
}
