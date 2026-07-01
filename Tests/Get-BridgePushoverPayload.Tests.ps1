Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'New-PushoverPayload' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgePushoverPayload.ps1"
    }

    It 'Δημιουργεί σωστό payload με όλα τα πεδία' {
        $newPushoverPayloadSplat = @{
            PoUserKey = 'u1'
            PoApiKey  = 'a1'
            Message   = 'msg'
            Device    = 'dev1'
            Title     = 'test'
            Url       = 'http://a.com'
            UrlTitle  = 'alink'
            Priority  = 1
            Sound     = 'bike'
        }
        $payload = Get-BridgePushoverPayload @newPushoverPayloadSplat
        $payload | Should -BeOfType 'hashtable'
        $payload.token | Should -Be 'a1'
        $payload.user | Should -Be 'u1'
        $payload.message | Should -Be 'msg'
        $payload.device | Should -Be 'dev1'
        $payload.title | Should -Be 'test'
        $payload.url | Should -Be 'http://a.com'
        $payload.url_title | Should -Be 'alink'
        $payload.priority | Should -Be 1
        $payload.sound | Should -Be 'bike'
    }
    It 'Δεν περιλαμβάνει optional πεδία όταν είναι null' {
        $newPushoverPayloadSplat = @{
            PoUserKey = 'u1'
            PoApiKey  = 'a1'
            Message   = 'msg'
        }
        $payload = Get-BridgePushoverPayload @newPushoverPayloadSplat
        $payload.Keys.Count | Should -Be 3
        $payload['device'] | Should -BeNullOrEmpty
    }
}

