Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Invoke-BridgeOpenedNotification' {
        Context 'Όταν η γέφυρα είναι ανοιχτή' {
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

                # Επιβεβαίωση ότι καλέστηκε το error logging
                Assert-MockCalled -CommandName Write-BridgeLog -Exactly 2 -Scope It
                Assert-MockCalled -CommandName Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and $Message -like '*Αποτυχία αποστολής ειδοποίησης ανοίγματος για Ισθμία*'
                } -Exactly 1 -Scope It
            }
        }
    }
}
