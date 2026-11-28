Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe -Name 'Invoke-BridgeOpenedNotification' -Fixture {

    BeforeAll -Scriptblock {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgeNotification.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOpenedNotification.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeHttpExceptionInfo.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"
        $script:Config = New-BridgeConfiguration
    }

    Context -Name 'Όταν η γέφυρα είναι ανοιχτή' -Fixture {



        It -Name 'Εκτελεί custom NotificationProvider αντί για Send-BridgePushover' -Test {

            $providerCalled = $false

            $mockProvider = {

                $script:providerCalled = $true

            }

            Mock -CommandName Write-BridgeLog -MockWith { }

            $params = @{

                CurrentState         = @(

                    @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }

                )

                Configuration = $script:Config

                NotificationProvider = $mockProvider

            }

            Invoke-BridgeOpenedNotification @params -Configuration $script:Config

            $script:providerCalled | Should -Be -ExpectedValue $true

        }



        It -Name 'Στέλνει Pushover ειδοποίηση και γράφει log' -Test {

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



        It -Name 'Γράφει error log και ρίχνει terminating error όταν αποτυγχάνει η αποστολή Pushover' -Test {

            Mock -CommandName Send-BridgePushover -MockWith { throw [System.Net.WebException]::new('Pushover API failure') }

            Mock -CommandName Write-BridgeLog -MockWith { }

            $params = @{

                CurrentState = @(

                    @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }

                )

                PoUserKey    = 'dummy'

                PoApiKey = 'dummy'; Configuration = $script:Config

            }



            { Invoke-BridgeOpenedNotification @params -Configuration $script:Config } | Should -Throw -ExpectedMessage '*Αποτυχία αποστολής ειδοποίησης ανοίγματος*'

            Should -Invoke -CommandName Write-BridgeLog -Times 2 -Exactly -Scope It

            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {

                $Stage -eq 'Σφάλμα' -and $Message -like '*Αποτυχία αποστολής ειδοποίησης ανοίγματος για Ισθμία*'

            } -Times 1 -Exactly -Scope It

        }

    }

}

