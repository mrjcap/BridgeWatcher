Import-Module "$PSScriptRoot\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'ConvertFrom-BridgeOCRResult Tests' {
        Context 'Όταν η ανάλυση OCR κειμένου αποτυγχάνει' {
            It 'Πρέπει να ρίχνει σφάλμα "Δεν κατέστη δυνατή η ανάλυση του κειμένου."' {
                $mockApiResponse = @{
                    responses = @(
                        @{
                            textAnnotations = @(
                                @{ description = $null }
                            )
                        }
                    )
                }
                { ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'mock_image.jpg' } |
                    Should -Throw 'Δεν βρέθηκε κείμενο OCR στην απόκριση.'
            }
        }
        It 'Πρέπει να ρίχνει σφάλμα "Δεν βρέθηκε κείμενο OCR στην απόκριση."' {
            # Δημιουργία mock δεδομένων για την περίπτωση όπου δεν υπάρχουν annotations
            $mockApiResponse = @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{ description = $null }
                        )
                    }
                )
            }
            # Mock για το Write-Verbose και Write-Warning
            Mock Write-Verbose {}
            Mock Write-Warning {}
            # Εκτέλεση της συνάρτησης
            { ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'mock_image.jpg' } | Should -Throw 'Δεν βρέθηκε κείμενο OCR στην απόκριση.'
        }
        It 'should call Write-Verbose and Write-Warning when time range is not found' {
            # Δημιουργία mock δεδομένων όπου το ConvertTo-BridgeTimeRange επιστρέφει $null
            $mockApiResponse = @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{ description = 'Από 01/01/2025 10:00 Έως 01/01/2025 10:30' }
                        )
                    }
                )
            }
            # Mock για το ConvertTo-BridgeTimeRange που επιστρέφει $null
            Mock ConvertTo-BridgeTimeRange { return $null }
            # Mock για το Write-Verbose και Write-Warning
            Mock Write-Verbose {}
            Mock Write-Warning {}
            # Εκτέλεση της συνάρτησης
            ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'mock_image.jpg'
            # Ελέγχουμε αν τα μηνύματα Write-Verbose και Write-Warning καλούνται
            Assert-MockCalled Write-Verbose -Exactly 3 -Scope It
            Assert-MockCalled Write-Warning -Exactly 1 -Scope It
        }
        It 'should return an empty array when time range is not found' {
            # Δημιουργία mock δεδομένων όπου το ConvertTo-BridgeTimeRange επιστρέφει $null
            $mockApiResponse = @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{ description = 'Από 01/01/2025 10:00 Έως 01/01/2025 10:30' }
                        )
                    }
                )
            }
            # Mock για το ConvertTo-BridgeTimeRange που επιστρέφει $null
            Mock ConvertTo-BridgeTimeRange { return $null }
            # Εκτέλεση της συνάρτησης
            $result = ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'mock_image.jpg'
            # Ελέγχουμε αν επιστρέφει το αναμενόμενο κενό array
            $result | Should -Be @()
        }
        It 'επιστρέφει προειδοποίηση με ώρα κλεισίματος' {
            $mockResponse = @{
                responses = @(
                    @{ textAnnotations = @(@{ description = '25/04/2025 23:00 έως 26/04/2025 00:00' }) }
                )
            }
            Mock Get-BridgeNameFromUri { 'Ισθμία' }
            Mock ConvertTo-BridgeTimeRange { [pscustomobject]@{
                    From      = (Get-Date).AddMinutes(60)
                    To        = (Get-Date).AddMinutes(90)
                    ClosedFor = [timespan]::FromMinutes(30)
                } }
            Mock ConvertTo-BridgeClosedDuration { '30 λεπτά' }
            Mock Get-BridgeStatusAdvice { 'Επέστρεψε μετά τις 00:00' }
            $result = ConvertFrom-BridgeOCRResult -ApiResponse $mockResponse -ImageUri 'bridge.jpg'
            $result.'Σημείωση 2' | Should -Match 'θα κλείσει στις'
        }
        It 'επιστρέφει μήνυμα ότι η γέφυρα είναι ήδη κλειστή' {
            $mockResponse = @{
                responses = @(
                    @{ textAnnotations = @(@{ description = '25/04/2025 14:00 έως 25/04/2025 14:30' }) }
                )
            }
            Mock Get-BridgeNameFromUri { 'Ποσειδωνία' }
            Mock ConvertTo-BridgeTimeRange { [pscustomobject]@{
                    From      = (Get-Date).AddMinutes(-20)
                    To        = (Get-Date).AddMinutes(10)
                    ClosedFor = [timespan]::FromMinutes(30)
                } }
            Mock ConvertTo-BridgeClosedDuration { '30 λεπτά' }
            Mock Get-BridgeStatusAdvice { 'Κατέβα για καφέ' }
            $result = ConvertFrom-BridgeOCRResult -ApiResponse $mockResponse -ImageUri 'bridge.jpg'
            $result.'Σημείωση 2' | Should -Match 'ήδη κλειστή από τις'
        }
    }
    Describe 'ConvertFrom-BridgeOCRResult - Καταγραφή σφάλματος ανάλυσης κειμένου' {
        It 'Πρέπει να καλει το Write-BridgeLog όταν αποτυγχάνει η ανάλυση OCR' {
            Mock Write-BridgeLog {}
            $mockApiResponse = @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{ description = $null }
                        )
                    }
                )
            }
            {ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'mock_image.jpg'} | Should -Throw
            Assert-MockCalled Write-BridgeLog -Exactly 2 -Scope It
        }
    }
}