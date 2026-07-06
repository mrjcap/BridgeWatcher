Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Send-Pushover' {
    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It 'Καλεί helper functions και στέλνει μήνυμα' {
        Mock -CommandName Send-BridgePushoverRequest -MockWith {
            return @{ status = 'ok' }
        }
        Mock -CommandName Write-BridgeLog -MockWith { }
        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
        }
        Send-BridgePushover @sendPushoverSplat -Configuration $script:Config
        Assert-MockCalled Send-BridgePushoverRequest -Times 1 -Exactly -ParameterFilter {
            $Payload.token -eq 'T' -and $Payload.user -eq 'U' -and $Payload.message -eq 'hello'
        }
    }

    It 'Γράφει error log και ρίχνει terminating error όταν αποτυγχάνει η αποστολή' {
        Mock -CommandName Send-BridgePushoverRequest -MockWith { throw 'API Error' }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
        }

        { Send-BridgePushover @sendPushoverSplat -Configuration $script:Config } | Should -Throw '*Αποτυχία αποστολής Pushover*'

        # Επιβεβαίωση ότι καλέστηκε το error logging
        Assert-MockCalled -CommandName Write-BridgeLog -ParameterFilter {
            $Stage -eq 'Σφάλμα' -and $Message -like '*Αποτυχία αποστολής Pushover*'
        } -Exactly 1 -Scope It
    }

    It 'Αποδέχεται έγκυρο URL με https' {
        Mock -CommandName Send-BridgePushoverRequest -MockWith { return @{ status = 'ok' } }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
            Url       = 'https://example.com'
        }

        { Send-BridgePushover @sendPushoverSplat -Configuration $script:Config } | Should -Not -Throw
    }

    It 'Αποδέχεται έγκυρο URL με http' {
        Mock -CommandName Send-BridgePushoverRequest -MockWith { return @{ status = 'ok' } }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
            Url       = 'http://example.com'
        }

        { Send-BridgePushover @sendPushoverSplat -Configuration $script:Config } | Should -Not -Throw
    }

    It 'Απορρίπτει άκυρο URL' {
        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
            Url       = 'invalid-url'
        }

        { Send-BridgePushover @sendPushoverSplat -Configuration $script:Config } | Should -Throw
    }

    It 'Περνάει όλες τις προαιρετικές παραμέτρους στο payload' {
        Mock -CommandName Send-BridgePushoverRequest -MockWith {
            return @{ status = 'ok' }
        }
        Mock -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
            Device    = 'myphone'
            Title     = 'Test Title'
            Url       = 'https://example.com'
            UrlTitle  = 'Click Here'
            Priority  = 1
            Sound     = 'siren'
        }

        Send-BridgePushover @sendPushoverSplat -Configuration $script:Config

        Assert-MockCalled Send-BridgePushoverRequest -Times 1 -Exactly -ParameterFilter {
            $Payload.device -eq 'myphone' -and
            $Payload.title -eq 'Test Title' -and
            $Payload.url -eq 'https://example.com' -and
            $Payload.url_title -eq 'Click Here' -and
            $Payload.priority -eq 1 -and
            $Payload.sound -eq 'siren'
        }
    }
}
