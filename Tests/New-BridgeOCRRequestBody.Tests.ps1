Import-Module "$PSScriptRoot\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'New-OCRRequestBody' {
        It 'Επιστρέφει έγκυρο JSON με το imageUri' {
            $uri = 'https://example.com/image.jpg'
            $json = New-BridgeOCRRequestBody -ImageUri $uri | ConvertFrom-Json
            $json.requests[0].image.source.imageUri | Should -Be $uri
            $json.requests[0].features[0].type | Should -Be 'DOCUMENT_TEXT_DETECTION'
        }
    }
}