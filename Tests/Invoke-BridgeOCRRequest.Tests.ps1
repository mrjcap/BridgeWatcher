Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Invoke-BridgeOCRRequest' {
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
            {
                Invoke-BridgeOCRRequest -ApiKey 'abc' -RequestBody '{}'
            } | Should -Throw "Google Vision API call failed: Simulated API failure"
        }
    }
}