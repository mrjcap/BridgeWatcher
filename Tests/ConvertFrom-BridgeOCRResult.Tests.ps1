

Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Δοκιμές ConvertFrom-BridgeOCRResult' {

    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeNameFromUri.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeClosedDuration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusAdvice.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1"

    }

    Mock Write-BridgeLog {}

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

            { ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg' } |

                Should -Throw 'Δεν βρέθηκε κείμενο OCR στην απόκριση.'

        }



        It 'Πρέπει να ρίχνει σφάλμα για κενό κείμενο OCR' {

            # Δημιουργία mock δεδομένων για την περίπτωση όπου δεν υπάρχουν annotations

            $mockApiResponse = @{

                responses = @(

                    @{

                        textAnnotations = @(

                            @{ description = '' }

                        )

                    }

                )

            }

            # Mock για το Write-Verbose και Write-Warning

            Mock Write-Verbose {}

            Mock Write-Warning {}

            # Εκτέλεση της συνάρτησης

            { ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg' } | Should -Throw 'Δεν βρέθηκε κείμενο OCR στην απόκριση.'

        }

    }

    It 'πρέπει να καλεί τα Write-Verbose και Write-Warning όταν δεν βρίσκεται το εύρος χρόνου' {

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

        ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg'

        # Ελέγχουμε αν τα μηνύματα Write-Verbose και Write-Warning καλούνται

        Assert-MockCalled Write-Verbose -Exactly 3 -Scope It

        Assert-MockCalled Write-Warning -Exactly 1 -Scope It

    }

    It 'πρέπει να επιστρέφει κενό πίνακα όταν δεν βρίσκεται το εύρος χρόνου' {

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

        $result = ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg'

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

        $result = ConvertFrom-BridgeOCRResult -ApiResponse $mockResponse -ImageUri 'https://example.com/bridge.jpg'

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

        $result = ConvertFrom-BridgeOCRResult -ApiResponse $mockResponse -ImageUri 'https://example.com/bridge.jpg'

        $result.'Σημείωση 2' | Should -Match 'ήδη κλειστή από τις'

    }

    It 'Καταγράφει επιτυχές μήνυμα κατά την επιτυχή OCR ανάλυση' {

        $calledMessage = $null

        Mock Write-BridgeLog {

            param($Stage, $Message, $Level, $Configuration)

            $null = $Stage; $null = $Level; $null = $Configuration

            if ($Message -like '*Επιτυχής ανάλυση*' -or $Message -like '*No text annotations*') {

                $script:calledMessage = $Message

            }

        }

        $mockResponse = @{

            responses = @(

                @{ textAnnotations = @(@{ description = '25/04/2025 14:00 έως 25/04/2025 14:30' }) }

            )

        }

        Mock Get-BridgeNameFromUri { 'Ισθμία' }

        Mock ConvertTo-BridgeTimeRange { [pscustomobject]@{

                From      = [datetime]::ParseExact('25/04/2025 14:00', 'dd/MM/yyyy HH:mm', $null)

                To        = [datetime]::ParseExact('25/04/2025 14:30', 'dd/MM/yyyy HH:mm', $null)

                ClosedFor = [timespan]::FromMinutes(30)

            } }

        Mock ConvertTo-BridgeClosedDuration { '30 λεπτά' }

        Mock Get-BridgeStatusAdvice { 'Επέστρεψε μετά τις 00:00' }



        $null = ConvertFrom-BridgeOCRResult -ApiResponse $mockResponse -ImageUri 'https://example.com/bridge.jpg'



        $script:calledMessage | Should -Not -Match 'No text annotations'

        $script:calledMessage | Should -Match 'Επιτυχής ανάλυση'

    }

}

Describe 'ConvertFrom-BridgeOCRResult - Καταγραφή σφάλματος ανάλυσης κειμένου' {

    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeNameFromUri.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeClosedDuration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusAdvice.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1"

    }

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

        { ConvertFrom-BridgeOCRResult -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg' } | Should -Throw

        Assert-MockCalled Write-BridgeLog -Exactly 2 -Scope It

    }

}

