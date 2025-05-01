Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Invoke-BridgeOCRGoogleCloud' {
        It 'Επιστρέφει object από API με orchestrated call' {
            $validUri = 'https://example.com/image-bridge-open-with-schedule-isthmia.php'
            Mock New-BridgeOCRRequestBody { return '{}' }
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
            $out = Invoke-BridgeOCRGoogleCloud -ApiKey 'abc' -ImageUri $validUri
            $out.mock | Should -Be 'result'
            Assert-MockCalled New-BridgeOCRRequestBody -Times 1
            Assert-MockCalled Invoke-BridgeOCRRequest -Times 1
            Assert-MockCalled ConvertFrom-BridgeOCRResult -Times 1
        }
        It 'Ρίχνει σφάλμα αν το URI είναι άκυρο' {
            { Invoke-BridgeOCRGoogleCloud -ApiKey 'abc' -ImageUri 'notaurl' } | Should -Throw
        }
        It 'Γράφει Error όταν αποτυγχάνει η κλήση' {
            Mock Invoke-BridgeOCRRequest { 'Simulated OCR failure' }
            $invokeOCRGoogleCloudSplat = @{
                ApiKey        = 'dummy'
                ImageUri      = 'https://image.jpg'
                Verbose       = $true
                ErrorAction   = 'SilentlyContinue'
                ErrorVariable = 'myErr'
            }
            { Invoke-BridgeOCRGoogleCloud @invokeOCRGoogleCloudSplat } 2>&1 | Out-Null
        }
        It 'Γράφει Write-Error όταν αποτυγχάνει η κλήση' {
            Mock Invoke-BridgeOCRRequest { throw 'Simulated OCR failure' }
            { Invoke-BridgeOCRGoogleCloud -ApiKey 'dummy' -ImageUri 'https://image.jpg' -Verbose -ErrorAction SilentlyContinue } | Should -Throw 'Simulated OCR failure'
        }
    }
}