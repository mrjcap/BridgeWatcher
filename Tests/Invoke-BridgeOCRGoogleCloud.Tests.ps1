Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Invoke-BridgeOCRGoogleCloud' {
    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRGoogleCloud.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It 'Επιστρέφει object από API με orchestrated call' {
        $validUri = 'https://example.com/image-bridge-open-with-schedule-isthmia.php'
        Mock Invoke-BridgeOCRRequest {
            return @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{ description = @(
                                    'Από', '01/01/2025', '10:00', 'Έως', '01/01/2025', '10:30'
                                )
                            }
                        )
                    }
                )
            }
        }
        Mock ConvertFrom-BridgeOCRResult {
            return @{ mock = 'result' }
        }
        $out = Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'abc' -ImageUri $validUri
        $out.mock | Should -Be 'result'
        Should -Invoke -CommandName Invoke-BridgeOCRRequest -Times 1
        Should -Invoke -CommandName ConvertFrom-BridgeOCRResult -Times 1
    }
    It 'Ρίχνει σφάλμα αν το URI είναι άκυρο' {
        { Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'abc' -ImageUri 'notaurl' } | Should -Throw
    }
    It 'Γράφει Error όταν αποτυγχάνει η κλήση' {
        Mock Invoke-BridgeOCRRequest { 'Simulated OCR failure' }
        $invokeOCRGoogleCloudSplat = @{
            ApiKey = 'dummy'; Configuration = $script:Config
            ImageUri      = 'https://image.jpg'
            Verbose       = $true
            ErrorAction   = 'SilentlyContinue'
            ErrorVariable = 'myErr'
        }
        { Invoke-BridgeOCRGoogleCloud @invokeOCRGoogleCloudSplat } 2>&1 | Out-Null
    }
    It 'Γράφει Write-Error όταν αποτυγχάνει η κλήση' {
        Mock Invoke-BridgeOCRRequest { throw 'Simulated OCR failure' }
        { Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'dummy' -ImageUri 'https://image.jpg' -Verbose -ErrorAction SilentlyContinue } | Should -Throw 'Simulated OCR failure'
    }
}
