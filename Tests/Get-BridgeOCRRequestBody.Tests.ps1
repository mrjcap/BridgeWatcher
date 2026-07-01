Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'New-OCRRequestBody' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeOCRRequestBody.ps1"
    }

    It 'Επιστρέφει έγκυρο JSON με το imageUri' {
        $uri = 'https://example.com/image.jpg'
        $json = Get-BridgeOCRRequestBody -ImageUri $uri | ConvertFrom-Json
        $json.requests[0].image.source.imageUri | Should -Be $uri
        $json.requests[0].features[0].type | Should -Be 'DOCUMENT_TEXT_DETECTION'
    }
}

