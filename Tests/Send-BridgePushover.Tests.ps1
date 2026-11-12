Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Send-Pushover' {
    BeforeAll {
        $script:Config = New-BridgeConfiguration
    }

    It 'Καλεί helper functions και στέλνει μήνυμα' {
        Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -MockWith {
            return @{ status = 'ok' }
        }
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith { }
        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
        }
        Send-BridgePushover @sendPushoverSplat -Configuration $script:Config
        Should -Invoke -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -Times 1 -Exactly -ParameterFilter {
            $Payload.token -eq 'T' -and $Payload.user -eq 'U' -and $Payload.message -eq 'hello'
        }
    }

    It 'Γράφει error log και ρίχνει terminating error όταν αποτυγχάνει η αποστολή' {
        Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -MockWith { throw 'API Error' }
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
        }

        { Send-BridgePushover @sendPushoverSplat -Configuration $script:Config } | Should -Throw '*Αποτυχία αποστολής Pushover*'

        # Επιβεβαίωση ότι καλέστηκε το error logging
        Should -Invoke -ModuleName BridgeWatcher -CommandName Write-BridgeLog -ParameterFilter {
            $Stage -eq 'Σφάλμα' -and $Message -like '*Αποτυχία αποστολής Pushover*'
        } -Times 1 -Exactly -Scope It
    }

    It 'Αποδέχεται έγκυρο URL με https' {
        Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -MockWith { return @{ status = 'ok' } }
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey = 'U'
            PoApiKey  = 'T'
            Message   = 'hello'
            Url       = 'https://example.com'
        }

        { Send-BridgePushover @sendPushoverSplat -Configuration $script:Config } | Should -Not -Throw
    }

    It 'Αποδέχεται έγκυρο URL με http' {
        Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -MockWith { return @{ status = 'ok' } }
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith { }

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
        Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -MockWith {
            return @{ status = 'ok' }
        }
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith { }

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

        Should -Invoke -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -Times 1 -Exactly -ParameterFilter {
            $Payload.device -eq 'myphone' -and
            $Payload.title -eq 'Test Title' -and
            $Payload.url -eq 'https://example.com' -and
            $Payload.url_title -eq 'Click Here' -and
            $Payload.priority -eq 1 -and
            $Payload.sound -eq 'siren'
        }
    }

    It 'Απορρίπτει Priority 2 (Emergency) όταν λείπουν τα Retry και Expire' {
        Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -MockWith { return @{ status = 'ok' } }
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith { }

        { Send-BridgePushover -PoUserKey 'U' -PoApiKey 'T' -Message 'emergency' -Priority 2 -Configuration $script:Config } | Should -Throw '*Retry*Expire*'
        { Send-BridgePushover -PoUserKey 'U' -PoApiKey 'T' -Message 'emergency' -Priority 2 -Retry 60 -Configuration $script:Config } | Should -Throw '*Retry*Expire*'
        { Send-BridgePushover -PoUserKey 'U' -PoApiKey 'T' -Message 'emergency' -Priority 2 -Expire 3600 -Configuration $script:Config } | Should -Throw '*Retry*Expire*'
        Should -Not -Invoke -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -Scope It
    }

    It 'Περνάει τα retry και expire στο payload όταν Priority είναι 2' {
        Mock -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -MockWith {
            return @{ status = 'ok' }
        }
        Mock -ModuleName BridgeWatcher -CommandName Write-BridgeLog -MockWith { }

        $sendPushoverSplat = @{
            PoUserKey     = 'U'
            PoApiKey      = 'T'
            Message       = 'emergency bridge alert'
            Priority      = 2
            Retry         = 60
            Expire        = 3600
            Configuration = $script:Config
        }

        Send-BridgePushover @sendPushoverSplat

        Should -Invoke -ModuleName BridgeWatcher -CommandName Send-BridgePushoverRequest -Times 1 -Exactly -ParameterFilter {
            $Payload.priority -eq 2 -and
            $Payload.retry -eq 60 -and
            $Payload.expire -eq 3600
        }
    }
}
