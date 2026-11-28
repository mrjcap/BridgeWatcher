Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope -ModuleName BridgeWatcher -ScriptBlock {
Describe -Name 'Invoke-BridgeOCRRequest' -Fixture {

    BeforeAll -Scriptblock {
        $script:Config = New-BridgeConfiguration

        Mock -CommandName Start-Sleep -MockWith {
        }
    }



    It -Name 'Returns the accepted OCR response without retrying when its success log fails' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith { @{ responses = @(@{}) } }
        Mock -CommandName Write-BridgeLog -MockWith {}
        Mock -CommandName Write-BridgeLog -ParameterFilter { $Message -like '*Αίτημα OCR*' } -MockWith { throw 'Log append failed' }
        Mock -CommandName Write-Warning -MockWith {}

        $result = Invoke-BridgeOCRRequest -Configuration $script:Config -ApiKey 'test-key' -RequestBody '{}'

        $result.responses.Count | Should -Be -ExpectedValue 1
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly -Scope It
        Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -Scope It -ParameterFilter { $Message -like '*Log append failed*' }
    }

    It -Name 'Στέλνει POST και επιστρέφει αποτέλεσμα' -Test {



        Mock -CommandName Invoke-RestMethod -MockWith {

            return @{ responses = @(@{ textAnnotations = @(@{ description = 'fake text' }) }) }

        }

        $response = Invoke-BridgeOCRRequest -Configuration $script:Config -ApiKey 'test-key' -RequestBody '{}'

        $response.responses[0].textAnnotations[0].description | Should -Be -ExpectedValue 'fake text'

        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly

    }



    It -Name 'Υπολογίζει διάρκεια με ημέρες, ώρες και λεπτά' -Test {
        $resp = @{
            responses = @(
                @{
                    textAnnotations = @(
                        @{ description = @(
                                'Από', '01/01/2050', '10:00', 'Έως', '03/01/2050', '12:30'
                            )
                        }
                    )
                }
            )
        }
        $res = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $resp
        $res.ClosedFor | Should -Match -RegularExpression 'ημέρες'
        $res.ClosedFor | Should -Match -RegularExpression 'ώρες'
        $res.ClosedFor | Should -Match -RegularExpression 'λεπτά'
    }

    It -Name 'Επιστρέφει exception όταν αποτυγχάνει η κλήση στο API' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith { throw 'Simulated API failure' }
        { Invoke-BridgeOCRRequest -Configuration $script:Config -ApiKey 'abc' -RequestBody '{}' } | Should -Throw -ExpectedMessage '❌ Αποτυχία OCR: Simulated API failure'
    }

    It -Name 'Σταματάει χωρίς retries όταν η API επιστρέφει 401 Unauthorized' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            $response = [PSCustomObject]@{ StatusCode = 401 }
            $ex = New-Object -TypeName System.Net.WebException -ArgumentList ("Unauthorized")
            $ex | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force
            throw $ex
        }
        { Invoke-BridgeOCRRequest -Configuration $script:Config -ApiKey 'abc' -RequestBody '{}' } | Should -Throw -ExpectedMessage "❌ Αποτυχία OCR: Unauthorized"
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly
    }

    It -Name 'Κάνει retries και πετάει το σφάλμα αν εξαντληθούν (π.χ. 500 Internal Server Error)' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            $response = [PSCustomObject]@{ StatusCode = 500 }
            $ex = New-Object -TypeName System.Net.WebException -ArgumentList ("Internal Error")
            $ex | Add-Member -MemberType NoteProperty -Name Response -Value $response -Force
            throw $ex
        }
        Mock -CommandName Start-Sleep -MockWith {}
        { Invoke-BridgeOCRRequest -Configuration $script:Config -ApiKey 'abc' -RequestBody '{}' } | Should -Throw -ExpectedMessage "❌ Αποτυχία OCR: Internal Error"
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly
    }

    It -Name 'Πρέπει να επαναλαμβάνει (retry) το αίτημα σε περίπτωση αποτυχίας' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith { throw 'Connection Timeout' }
        Mock -CommandName Start-Sleep -MockWith {}

        { Invoke-BridgeOCRRequest -ApiKey 'test_key' -RequestBody '{"test":"json"}' -Configuration $script:Config } | Should -Throw -ExpectedMessage '*Αποτυχία OCR*'

        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly
        Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly
    }

    It -Name 'Πρέπει να ρίχνει ArgumentException όταν το RequestBody δεν είναι έγκυρο JSON' -Test {
        { Invoke-BridgeOCRRequest -ApiKey 'test_key' -RequestBody '{invalid_json}' -Configuration $script:Config } | Should -Throw -ExpectedMessage '*δεν είναι έγκυρο JSON*'
    }

    It -Name 'Disposes WebException Response if it is IDisposable' -Test {
        $resp = [System.Net.HttpWebResponse]::new()
        Mock -CommandName Invoke-RestMethod -MockWith {
            $ex = New-Object -TypeName System.Net.WebException -ArgumentList ("Mock WebException")
            $ex | Add-Member -MemberType NoteProperty -Name Response -Value $resp -Force
            throw $ex
        }
        Mock -CommandName Start-Sleep -MockWith {}
        { Invoke-BridgeOCRRequest -Configuration $script:Config -ApiKey 'abc' -RequestBody '{}' } | Should -Throw -ExpectedMessage "❌ Αποτυχία OCR: Mock WebException"
    }



    It -Name 'Καλύπτει Configuration.OCRApiUrl path' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{ responses = @(@{ textAnnotations = @(@{ description = 'test' }) }) }
        }
        Mock -CommandName Write-BridgeLog -MockWith {}

        $config = New-BridgeConfiguration
        $config.Urls.OCRApi = 'https://custom-ocr-api.com/annotate'

        $result = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{"test": "data"}' -Configuration $config

        $result | Should -Not -BeNullOrEmpty
        $result.responses[0].textAnnotations[0].description | Should -Be -ExpectedValue 'test'
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly
    }

    It -Name 'Καλύπτει Configuration.OCRMessages.StartOCR path' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{ responses = @(@{ textAnnotations = @(@{ description = 'test' }) }) }
        }
        Mock -CommandName Write-BridgeLog -MockWith {}

        $config = New-BridgeConfiguration
        $config.OCRMessages.StartOCR = 'Custom start OCR message'

        Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' -Configuration $config

        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
            $Message -eq 'Custom start OCR message'
        } -Times 1
    }

    It -Name 'Καλύπτει Configuration.OCRMessages.OCRFailed και error logging paths' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith { throw 'Test API failure' }
        Mock -CommandName Write-BridgeLog -MockWith {}

        $config = New-BridgeConfiguration
        $config.OCRMessages.OCRFailed = 'Custom OCR failed message'
        $config.LoggingConfig.ErrorStage = 'Σφάλμα'
        $config.LoggingConfig.WarningLevel = 'Warning'

        { Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' -Configuration $config } | Should -Throw
        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
            $Message -like 'Custom OCR failed message*' -and
            $Stage -eq 'Σφάλμα' -and
            $Level -eq 'Warning'
        } -Times 1
    }

    It -Name 'Καλύπτει Configuration.LoggingConfig.InfoStage path για επιτυχή κλήση' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{ responses = @(@{ textAnnotations = @(@{ description = 'test' }) }) }
        }
        Mock -CommandName Write-BridgeLog -MockWith {}

        $config = New-BridgeConfiguration
        $config.LoggingConfig.InfoStage = 'Ανάλυση'

        Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' -Configuration $config

        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
            $Stage -eq 'Ανάλυση'
        } -Times 1
    }

    It -Name 'Καλύπτει όλες τις configuration paths μαζί σε επιτυχή σενάριο' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{ responses = @(@{ textAnnotations = @(@{ description = 'success' }) }) }
        }
        Mock -CommandName Write-BridgeLog -MockWith {}

        $config = New-BridgeConfiguration
        $config.Urls.OCRApi = 'https://custom-api.com/test'
        $config.OCRMessages.StartOCR = 'Custom start message'
        $config.LoggingConfig.InfoStage = 'Ανάλυση'

        $result = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{"test": "data"}' -Configuration $config

        $result | Should -Not -BeNullOrEmpty
        $result.responses[0].textAnnotations[0].description | Should -Be -ExpectedValue 'success'
        Should -Invoke -CommandName Invoke-RestMethod -Times 1 -Exactly
        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
            $Message -eq 'Custom start message' -and $Stage -eq 'Ανάλυση'
        } -Times 1
    }

    It -Name 'Επαναλαμβάνει (retry) σε HttpRequestException χωρίς ιδιότητα Response υπό strict mode' -Test {
        Mock -CommandName Invoke-RestMethod -MockWith {
            throw [System.Net.Http.HttpRequestException]::new('Name or service not known')
        }
        Mock -CommandName Start-Sleep -MockWith {}
        Mock -CommandName Write-BridgeLog -MockWith {}

        { Invoke-BridgeOCRRequest -Configuration $script:Config -ApiKey 'abc' -RequestBody '{}' } | Should -Throw -ExpectedMessage '*Name or service not known*'
        Should -Invoke -CommandName Invoke-RestMethod -Times 3 -Exactly -Scope It
        Should -Invoke -CommandName Start-Sleep -Times 2 -Exactly -Scope It
    }

}
}


