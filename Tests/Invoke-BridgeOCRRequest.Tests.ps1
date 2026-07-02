Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Invoke-BridgeOCRRequest' {

    BeforeAll {

        Mock -CommandName Start-Sleep -MockWith { }

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRRequest.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeNameFromUri.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeClosedDuration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusAdvice.ps1"

    }



    It 'Στέλνει POST και επιστρέφει αποτέλεσμα' {



        Mock -CommandName Invoke-RestMethod -MockWith {

            return @{ responses = @(@{ textAnnotations = @(@{ description = 'fake text' }) }) }

        }

        $response = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}'

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

        { Invoke-BridgeOCRRequest -ApiKey 'abc' -RequestBody '{}' } | Should -Throw 'Η κλήση του Google Vision API απέτυχε: Simulated API failure'

    }



    It 'Σταματάει χωρίς retries όταν η API επιστρέφει 401 Unauthorized' {

        Mock Invoke-RestMethod {

            $response = [PSCustomObject]@{ StatusCode = 401 }

            $ex = New-Object System.Net.WebException("Unauthorized")

            $ex | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $ex

        }

        { Invoke-BridgeOCRRequest -ApiKey 'abc' -RequestBody '{}' } | Should -Throw "Η κλήση του Google Vision API απέτυχε: Unauthorized"

        Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly

    }



    It 'Κάνει retries και πετάει το σφάλμα αν εξαντληθούν (π.χ. 500 Internal Server Error)' {

        Mock Invoke-RestMethod {

            $response = [PSCustomObject]@{ StatusCode = 500 }

            $ex = New-Object System.Net.WebException("Internal Error")

            $ex | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force

            throw $ex

        }

        Mock Start-Sleep {}

        { Invoke-BridgeOCRRequest -ApiKey 'abc' -RequestBody '{}' } | Should -Throw "Η κλήση του Google Vision API απέτυχε: Internal Error"

        Assert-MockCalled Invoke-RestMethod -Times 3 -Exactly

        Assert-MockCalled Start-Sleep -Times 2 -Exactly

    }



    It 'Καλύπτει Configuration.OCRApiUrl path' {



        Mock Invoke-RestMethod {

            return @{ responses = @(@{ textAnnotations = @(@{ description = 'test' }) }) }

        }

        Mock Write-BridgeLog {}



        $config = New-BridgeConfiguration

        $config = [PSCustomObject]@{

            Urls             = [PSCustomObject]@{

                OCRApi      = 'https://custom-ocr-api.com/annotate'

                PushoverApi = $config.Urls.PushoverApi

            }

            OCRMessages      = $config.OCRMessages

            LoggingConfig    = $config.LoggingConfig

            PushoverMessages = $config.PushoverMessages

        }



        $result = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{"test": "data"}' -Configuration $config



        $result | Should -Not -BeNullOrEmpty

        $result.responses[0].textAnnotations[0].description | Should -Be 'test'

        Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly

    }



    It 'Καλύπτει Configuration.OCRMessages.StartOCR path' {



        Mock Invoke-RestMethod {

            return @{ responses = @(@{ textAnnotations = @(@{ description = 'test' }) }) }

        }

        Mock Write-BridgeLog {}



        $baseConfig = New-BridgeConfiguration

        $config = [PSCustomObject]@{

            Urls          = [PSCustomObject]@{

                OCRApi = $baseConfig.Urls.OCRApi

            }

            OCRMessages   = @{

                StartOCR  = 'Custom start OCR message'

                OCRFailed = $baseConfig.OCRMessages.OCRFailed

            }

            LoggingConfig = $baseConfig.LoggingConfig

        }



        Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' -Configuration $config



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



        { Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' -Configuration $config } | Should -Throw

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



        $baseConfig = New-BridgeConfiguration

        $config = [PSCustomObject]@{

            Urls          = [PSCustomObject]@{

                OCRApi = $baseConfig.Urls.OCRApi

            }

            OCRMessages   = $baseConfig.OCRMessages

            LoggingConfig = @{

                InfoStage    = 'Ανάλυση'

                ErrorStage   = $baseConfig.LoggingConfig.ErrorStage

                WarningLevel = $baseConfig.LoggingConfig.WarningLevel

            }

        }



        Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' -Configuration $config



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

            Urls          = [PSCustomObject]@{

                OCRApi = 'https://custom-api.com/test'

            }

            OCRMessages   = @{

                StartOCR = 'Custom start message'

            }

            LoggingConfig = @{

                InfoStage = 'Ανάλυση'

            }

        }



        $result = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{"test": "data"}' -Configuration $config



        $result | Should -Not -BeNullOrEmpty

        $result.responses[0].textAnnotations[0].description | Should -Be 'success'

        Assert-MockCalled Invoke-RestMethod -Times 1 -Exactly

        Assert-MockCalled Write-BridgeLog -ParameterFilter {

            $Message -eq 'Custom start message' -and $Stage -eq 'Ανάλυση'

        } -Times 1

    }

}

