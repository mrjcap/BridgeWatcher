Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Invoke-BridgeOpenedNotification' {

    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOpenedNotification.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"
        $script:Config = New-BridgeConfiguration
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

                    @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }

                )

                PoUserKey            = 'dummy'

                PoApiKey = 'dummy'; Configuration = $script:Config

                NotificationProvider = $mockProvider

            }

            Invoke-BridgeOpenedNotification @params -Configuration $script:Config

            $script:providerCalled | Should -Be $true

        }



        It 'Στέλνει Pushover ειδοποίηση και γράφει log' {

            Mock -CommandName Send-BridgePushover -MockWith { }

            Mock -CommandName Write-BridgeLog -MockWith { }

            $params = @{

                CurrentState = @(

                    @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }

                )

                PoUserKey    = 'dummy'

                PoApiKey = 'dummy'; Configuration = $script:Config

            }

            Invoke-BridgeOpenedNotification @params -Configuration $script:Config

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly

            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly

        }



        It 'Γράφει error log και ρίχνει terminating error όταν αποτυγχάνει η αποστολή Pushover' {

            Mock -CommandName Send-BridgePushover -MockWith { throw 'Pushover API failure' }

            Mock -CommandName Write-BridgeLog -MockWith { }

            $params = @{

                CurrentState = @(

                    @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }

                )

                PoUserKey    = 'dummy'

                PoApiKey = 'dummy'; Configuration = $script:Config

            }



            { Invoke-BridgeOpenedNotification @params -Configuration $script:Config } | Should -Throw '*Αποτυχία αποστολής ειδοποίησης ανοίγματος*'

            Should -Invoke -CommandName Write-BridgeLog -Times 2 -Exactly -Scope It

            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {

                $Stage -eq 'Σφάλμα' -and $Message -like '*Αποτυχία αποστολής ειδοποίησης ανοίγματος για Ισθμία*'

            } -Times 1 -Exactly -Scope It

        }

    }

}

