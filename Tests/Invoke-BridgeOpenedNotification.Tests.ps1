Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Invoke-BridgeOpenedNotification' {

    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOpenedNotification.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"

    }

    Context 'Όταν η γέφυρα είναι ανοιχτή' {



        It 'Εκτελεί custom NotificationProvider αντί για Send-BridgePushover' {

            $providerCalled = $false

            $mockProvider = {

                $script:providerCalled = $true

            }

            Mock -CommandName Write-BridgeLog -MockWith { }

            $params = @{

                CurrentState         = @(

                    @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }

                )

                PoUserKey            = 'dummy'

                PoApiKey             = 'dummy'

                NotificationProvider = $mockProvider

            }

            Invoke-BridgeOpenedNotification @params

            $script:providerCalled | Should -Be $true

        }



        It 'Στέλνει Pushover ειδοποίηση και γράφει log' {

            Mock -CommandName Send-BridgePushover -MockWith { }

            Mock -CommandName Write-BridgeLog -MockWith { }

            $params = @{

                CurrentState = @(

                    @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }

                )

                PoUserKey    = 'dummy'

                PoApiKey     = 'dummy'

            }

            Invoke-BridgeOpenedNotification @params

            Assert-MockCalled -CommandName Send-BridgePushover -Exactly 1

            Assert-MockCalled -CommandName Write-BridgeLog -Exactly 1

        }



        It 'Γράφει error log και ρίχνει terminating error όταν αποτυγχάνει η αποστολή Pushover' {

            Mock -CommandName Send-BridgePushover -MockWith { throw 'Pushover API failure' }

            Mock -CommandName Write-BridgeLog -MockWith { }

            $params = @{

                CurrentState = @(

                    @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }

                )

                PoUserKey    = 'dummy'

                PoApiKey     = 'dummy'

            }



            { Invoke-BridgeOpenedNotification @params } | Should -Throw '*Αποτυχία αποστολής ειδοποίησης ανοίγματος*'

            Assert-MockCalled -CommandName Write-BridgeLog -Exactly 2 -Scope It

            Assert-MockCalled -CommandName Write-BridgeLog -ParameterFilter {

                $Stage -eq 'Σφάλμα' -and $Message -like '*Αποτυχία αποστολής ειδοποίησης ανοίγματος για Ισθμία*'

            } -Exactly 1 -Scope It

        }

    }

}

