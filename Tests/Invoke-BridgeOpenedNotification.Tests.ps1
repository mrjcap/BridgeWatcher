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
                Assert-MockCalled -CommandName Write-BridgeLog -Exactly 4
            }
        }
    }
}