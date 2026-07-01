Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Send-Pushover' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgePushoverPayload.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"
    }

    It 'Καλεί helper functions και στέλνει μήνυμα' {
        $mockPayload = @{ token = 'T'; user = 'U'; message = 'hello' }
        Mock -CommandName Get-BridgePushoverPayload -MockWith { return $mockPayload }
        Mock -CommandName Send-BridgePushoverRequest -MockWith {
            return @{ status = 'ok' }
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
        }
        Send-BridgePushover @sendPushoverSplat
        Assert-MockCalled Get-BridgePushoverPayload -Times 1 -Exactly
        Assert-MockCalled Send-BridgePushoverRequest -Times 1 -Exactly
    }

    It 'Γράφει error log και ρίχνει terminating error όταν αποτυγχάνει η αποστολή' {
        Mock -CommandName Get-BridgePushoverPayload -MockWith { @{ token = 'T'; user = 'U'; message = 'hello' } }
        Mock -CommandName Send-BridgePushoverRequest -MockWith { throw 'API Error' }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
        }

        { Send-BridgePushover @sendPushoverSplat } | Should -Throw '*Αποτυχία αποστολής Pushover*'

        # Επιβεβαίωση ότι καλέστηκε το error logging
        Assert-MockCalled -CommandName Write-BridgeLog -ParameterFilter {
            $Stage -eq 'Σφάλμα' -and $Message -like '*Αποτυχία αποστολής Pushover*'
        } -Exactly 1 -Scope It
    }

    It 'Αποδέχεται έγκυρο URL με https' {
        $mockPayload = @{ token = 'T'; user = 'U'; message = 'hello' }
        Mock -CommandName Get-BridgePushoverPayload -MockWith { return $mockPayload }
        Mock -CommandName Send-BridgePushoverRequest -MockWith { return @{ status = 'ok' } }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
            Url       = 'https://example.com'
        }

        { Send-BridgePushover @sendPushoverSplat } | Should -Not -Throw
    }

    It 'Αποδέχεται έγκυρο URL με http' {
        $mockPayload = @{ token = 'T'; user = 'U'; message = 'hello' }
        Mock -CommandName Get-BridgePushoverPayload -MockWith { return $mockPayload }
        Mock -CommandName Send-BridgePushoverRequest -MockWith { return @{ status = 'ok' } }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
            Url       = 'http://example.com'
        }

        { Send-BridgePushover @sendPushoverSplat } | Should -Not -Throw
    }

    It 'Απορρίπτει άκυρο URL' {
        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
            Url       = 'invalid-url'
        }

        { Send-BridgePushover @sendPushoverSplat } | Should -Throw
    }
}


