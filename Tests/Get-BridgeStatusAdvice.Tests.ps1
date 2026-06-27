Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeStatusAdvice Tests' {
        It 'should return "Είναι προτιμότερο να μην περιμένεις" when more than 12 minutes until open' {
            # Καλέστε τη συνάρτηση με τιμή πάνω από 12 λεπτά
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 15
            $result | Should -Be 'Είναι προτιμότερο να μην περιμένεις'
        }
        It 'should return "Είναι προτιμότερο να περιμένεις" when 12 minutes or less until open' {
            # Καλέστε τη συνάρτηση με τιμή 12 ή λιγότερο
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 12
            $result | Should -Be 'Είναι προτιμότερο να περιμένεις'
            # Επιπλέον έλεγχος για τιμή 5 λεπτών
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 5
            $result | Should -Be 'Είναι προτιμότερο να περιμένεις'
        }

        Context 'Configuration Coverage Tests' {
            It 'Καλύπτει Configuration.DefaultMaxWaitTimeMinutes path' {
                $config = [PSCustomObject]@{
                    DefaultMaxWaitTimeMinutes    = 15
                }

                # Test with minutes above custom threshold
                $result = Get-BridgeStatusAdvice -MinutesUntilOpen 20 -Configuration $config
                $result | Should -Be 'Είναι προτιμότερο να μην περιμένεις'

                # Test with minutes at custom threshold
                $result = Get-BridgeStatusAdvice -MinutesUntilOpen 15 -Configuration $config
                $result | Should -Be 'Είναι προτιμότερο να περιμένεις'
            }

            It 'Καλύπτει Configuration.AdviceMessages.DoNotWait path' {
                $config = [PSCustomObject]@{
                    AdviceMessages = @{
                        DoNotWait    = 'Custom message - do not wait'
                    }
                }

                $result = Get-BridgeStatusAdvice -MinutesUntilOpen 20 -Configuration $config
                $result | Should -Be 'Custom message - do not wait'
            }

            It 'Καλύπτει Configuration.AdviceMessages.Wait path' {
                $config = [PSCustomObject]@{
                    AdviceMessages = @{
                        Wait    = 'Custom message - wait'
                    }
                }

                $result = Get-BridgeStatusAdvice -MinutesUntilOpen 5 -Configuration $config
                $result | Should -Be 'Custom message - wait'
            }

            It 'Καλύπτει όλες τις configuration paths μαζί' {
                $config = [PSCustomObject]@{
                    DefaultMaxWaitTimeMinutes = 8
                    AdviceMessages            = @{
                        DoNotWait = 'Custom do not wait'
                        Wait      = 'Custom wait'
                    }
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
}

