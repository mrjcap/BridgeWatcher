Import-Module "$PSScriptRoot\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Send-Pushover' {
        It 'Καλεί helper functions και στέλνει μήνυμα' {
            $mockPayload = @{ token = 'T'; user = 'U'; message = 'hello' }
            Mock -CommandName New-BridgePushoverPayload -MockWith { return $mockPayload }
            Mock -CommandName Send-BridgePushoverRequest -MockWith {
                return @{ status = 'ok' }
            }
            $sendPushoverSplat = @{
                PoUserKey = 'U'
                PoApiKey  = 'T'
                Message   = 'hello'
            }
            Send-BridgePushover @sendPushoverSplat
            Assert-MockCalled New-BridgePushoverPayload -Times 1 -Exactly
            Assert-MockCalled Send-BridgePushoverRequest -Times 1 -Exactly
        }
    }
}