Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {

    Describe 'Invoke-BridgeOCRRequest' {

        It 'Στέλνει POST και επιστρέφει αποτέλεσμα' {

            Mock -CommandName Invoke-RestMethod -MockWith {
                return @{ responses = @(@{ textAnnotations = @(@{ description = 'fake text' }) }) }
            }
            $response = Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'test-key').SecurePassword) -RequestBody '{}'
            $response.responses[0].textAnnotations[0].description | Should -Be 'fake text'
            Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly
        }

        It 'Ανιχνεύει Ποσειδωνία ως τοποθεσία από το imageUri' {

            $resp = @{
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
            $res = ConvertFrom-BridgeOCRResult -ApiResponse $resp -ImageUri 'https://example.com/image-bridge-open-with-schedule-posidonia.php'
            $res.'Γέφυρα' | Should -Be 'Ποσειδωνία'
        }

        It 'Υπολογίζει διάρκεια με ημέρες, ώρες και λεπτά' {
            $resp = @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{ description = @(
                                    'Από', '01/01/2025', '10:00', 'Έως', '03/01/2025', '12:30'
                                )
                            }
                        )
                    }
                )
            }
            $res = ConvertFrom-BridgeOCRResult -ApiResponse $resp -ImageUri 'https://example.com/image-bridge-open-with-schedule-isthmia.php'
            $res.'Κλειστή για' | Should -Match 'ημέρες'
            $res.'Κλειστή για' | Should -Match 'ώρες'
            $res.'Κλειστή για' | Should -Match 'λεπτά'
        }

        It 'Επιστρέφει exception όταν αποτυγχάνει η κλήση στο API' {
            Mock Invoke-RestMethod { throw 'Simulated API failure' }
            Mock Start-Sleep {}
            { Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'abc').SecurePassword) -RequestBody '{}' } | Should -Throw 'Google Vision API call failed: Simulated API failure'
        }

        It 'Καλύπτει Configuration.OCRApiUrl path' {

            Mock Invoke-RestMethod {
                return @{ responses = @(@{ textAnnotations = @(@{ description = 'test' }) }) }
            }
            Mock Write-BridgeLog {}

            $config = [PSCustomObject]@{
                OCRApiUrl = 'https://custom-ocr-api.com/annotate'
            }

            $result = Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'test-key').SecurePassword) -RequestBody '{"test": "data"}' -Configuration $config

            $result | Should -Not -BeNullOrEmpty
            $result.responses[0].textAnnotations[0].description | Should -Be 'test'
            Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly
        }

        It 'Καλύπτει Configuration.OCRMessages.StartOCR path' {

            Mock Invoke-RestMethod {
                return @{ responses = @(@{ textAnnotations = @(@{ description = 'test' }) }) }
            }
            Mock Write-BridgeLog {}

            $config = [PSCustomObject]@{
                OCRMessages = @{
                    StartOCR = 'Custom start OCR message'
                }
            }

            Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'test-key').SecurePassword) -RequestBody '{}' -Configuration $config

            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Message -eq 'Custom start OCR message'
            } -Times 1
        }

        It 'Καλύπτει Configuration.OCRMessages.OCRFailed και error logging paths' {

            Mock Invoke-RestMethod { throw 'Test API failure' }
            Mock Write-BridgeLog {}
            $config = [PSCustomObject]@{
                OCRMessages   = @{
                    OCRFailed = 'Custom OCR failed message'
                }
                LoggingConfig = @{
                    ErrorStage   = 'Σφάλμα'
                    WarningLevel = 'Warning'
                }
            }

            { Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'test-key').SecurePassword) -RequestBody '{}' -Configuration $config } | Should -Throw
            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Message -like 'Custom OCR failed message*' -and
                $Stage -eq 'Σφάλμα' -and
                $Level -eq 'Warning'
            } -Times 1
        }

        It 'Καλύπτει Configuration.LoggingConfig.InfoStage path για επιτυχή κλήση' {

            Mock Invoke-RestMethod {
                return @{ responses = @(@{ textAnnotations = @(@{ description = 'test' }) }) }
            }
            Mock Write-BridgeLog {}

            $config = [PSCustomObject]@{
                LoggingConfig = @{
                    InfoStage = 'Ανάλυση'
                }
            }

            Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'test-key').SecurePassword) -RequestBody '{}' -Configuration $config

            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Stage -eq 'Ανάλυση'
            } -Times 1
        }

        It 'Καλύπτει όλες τις configuration paths μαζί σε επιτυχή σενάριο' {

            Mock Invoke-RestMethod {
                return @{ responses = @(@{ textAnnotations = @(@{ description = 'success' }) }) }
            }
            Mock Write-BridgeLog {}

            $config = [PSCustomObject]@{
                OCRApiUrl     = 'https://custom-api.com/test'
                OCRMessages   = @{
                    StartOCR = 'Custom start message'
                }
                LoggingConfig = @{
                    InfoStage = 'Ανάλυση'
                }
            }

            $result = Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'test-key').SecurePassword) -RequestBody '{"test": "data"}' -Configuration $config

            $result | Should -Not -BeNullOrEmpty
            $result.responses[0].textAnnotations[0].description | Should -Be 'success'
            Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly
            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Message -eq 'Custom start message' -and $Stage -eq 'Ανάλυση'
            } -Times 1
        }

        It 'Κάνει retry και throw όταν WebException δεν έχει 400, 401, 403 status code' {
            Mock Invoke-RestMethod { throw [System.Net.WebException]::new("Timeout") }
            Mock Start-Sleep {}
            { Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'abc').SecurePassword) -RequestBody '{}' } | Should -Throw
            Assert-MockCalled Start-Sleep -Times 2
            Assert-MockCalled Invoke-RestMethod -Times 3
        }

        It 'Κάνει throw αμέσως όταν WebException έχει 401 status code' {
            if (-not ("MockWebResponse" -as [type])) {
                Add-Type -TypeDefinition '
                using System;
                using System.Net;
                public class MockWebResponse : WebResponse {
                    public HttpStatusCode StatusCode { get; set; } = HttpStatusCode.Unauthorized;
                }
                '
            }
            $response = [MockWebResponse]::new()
            $ex = [System.Net.WebException]::new("Unauthorized", $null, [System.Net.WebExceptionStatus]::ProtocolError, $response)
            Mock Invoke-RestMethod { throw $ex }
            Mock Start-Sleep {}
            { Invoke-BridgeOCRRequest -ApiKey ([System.Net.NetworkCredential]::new('', 'abc').SecurePassword) -RequestBody '{}' } | Should -Throw
            Assert-MockCalled Start-Sleep -Times 0
            Assert-MockCalled Invoke-RestMethod -Times 1
        }
    }
}

