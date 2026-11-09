

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
        $script:Config = New-BridgeConfiguration
    }

    Mock Write-BridgeLog {}

    Context 'Όταν η ανάλυση OCR κειμένου αποτυγχάνει' {

        It 'Πρέπει να επιστρέφει $null όταν δεν βρίσκονται textAnnotations' {
            $mockApiResponse = @{
                responses = @(
                    @{
                        textAnnotations = @()
                    }
                )
            }
            $res = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg'
            $res | Should -BeNullOrEmpty
        }





        It 'Πρέπει να επιστρέφει $null για κενό κείμενο OCR' {
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
            $res = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg'
            $res | Should -BeNullOrEmpty
        }

    }

    It 'πρέπει να καλεί το Write-BridgeLog όταν δεν βρίσκεται το εύρος χρόνου' {
        $mockApiResponse = @{
            responses = @(
                @{
                    textAnnotations = @(
                        @{ description = 'Από 01/01/2025 10:00 Έως 01/01/2025 10:30' }
                    )
                }
            )
        }
        Mock ConvertTo-BridgeTimeRange { return $null }
        Mock Write-BridgeLog {}

        ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg'

        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Message -like '*Δεν κατέστη δυνατή η ανάλυση χρονικού διαστήματος*' } -Times 1 -Exactly -Scope It
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

        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg'

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



        Mock ConvertTo-BridgeTimeRange {
            $tz = try { [System.TimeZoneInfo]::FindSystemTimeZoneById('Europe/Athens') } catch { [System.TimeZoneInfo]::FindSystemTimeZoneById('GTB Standard Time') }
            $athensNow = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $tz)
            [pscustomobject]@{
                From      = $athensNow.AddMinutes(60)
                To        = $athensNow.AddMinutes(90)
                ClosedFor = [timespan]::FromMinutes(30)
            }
        }



        Mock ConvertTo-BridgeClosedDuration { '30 λεπτά' }

        Mock Get-BridgeStatusAdvice { 'Επέστρεψε μετά τις 00:00' }

        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse -ImageUri 'https://example.com/bridge.jpg'

        $result.Note2 | Should -Match 'θα κλείσει στις'

    }

    It 'επιστρέφει μήνυμα ότι η γέφυρα είναι ήδη κλειστή' {

        $mockResponse = @{

            responses = @(

                @{ textAnnotations = @(@{ description = '25/04/2025 14:00 έως 25/04/2025 14:30' }) }

            )

        }



        Mock Get-BridgeNameFromUri { 'Ποσειδωνία' }



        Mock ConvertTo-BridgeTimeRange {
            $tz = try { [System.TimeZoneInfo]::FindSystemTimeZoneById('Europe/Athens') } catch { [System.TimeZoneInfo]::FindSystemTimeZoneById('GTB Standard Time') }
            $athensNow = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $tz)
            [pscustomobject]@{
                From      = $athensNow.AddMinutes(-20)
                To        = $athensNow.AddMinutes(10)
                ClosedFor = [timespan]::FromMinutes(30)
            }
        }



        Mock ConvertTo-BridgeClosedDuration { '30 λεπτά' }

        Mock Get-BridgeStatusAdvice { 'Κατέβα για καφέ' }

        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse -ImageUri 'https://example.com/bridge.jpg'

        $result.Note2 | Should -Match 'ήδη κλειστή από τις'

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



        $null = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse -ImageUri 'https://example.com/bridge.jpg'



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

    It 'Πρέπει να καλει το Write-BridgeLog και να επιστρέφει $null όταν αποτυγχάνει η ανάλυση OCR' {
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
        $res = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse -ImageUri 'https://example.com/mock_image.jpg'
        $res | Should -BeNullOrEmpty
        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Stage -eq 'Σφάλμα' } -Times 1 -Exactly -Scope It
    }

}

