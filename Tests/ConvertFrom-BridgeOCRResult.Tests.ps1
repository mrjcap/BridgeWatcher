

Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope BridgeWatcher {
Describe 'Δοκιμές ConvertFrom-BridgeOCRResult' {

    BeforeAll {
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
            $res = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse
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
            $res = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse
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

        ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse

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

        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse

        # Ελέγχουμε αν επιστρέφει το αναμενόμενο κενό array

        $result | Should -Be @()

    }

    It 'επιστρέφει προειδοποίηση με ώρα κλεισίματος' {

        $mockResponse = @{

            responses = @(

                @{ textAnnotations = @(@{ description = '25/04/2025 23:00 έως 26/04/2025 00:00' }) }

            )

        }



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

        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse

        $result.Note2 | Should -Match 'θα κλείσει στις'
        $result.ScheduleState | Should -Be 'Future'
        $result.OpensIn | Should -BeNullOrEmpty

    }

    It 'επιστρέφει μήνυμα ότι η γέφυρα είναι ήδη κλειστή' {

        $mockResponse = @{

            responses = @(

                @{ textAnnotations = @(@{ description = '25/04/2025 14:00 έως 25/04/2025 14:30' }) }

            )

        }



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

        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse

        $result.Note2 | Should -Match 'ήδη κλειστή από τις'
        $result.ScheduleState | Should -Be 'Active'
        $result.OpensIn | Should -Match 'λεπτά'

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

        Mock ConvertTo-BridgeTimeRange { [pscustomobject]@{

                From      = [datetime]::ParseExact('25/04/2025 14:00', 'dd/MM/yyyy HH:mm', $null)

                To        = [datetime]::ParseExact('25/04/2025 14:30', 'dd/MM/yyyy HH:mm', $null)

                ClosedFor = [timespan]::FromMinutes(30)

            } }

        Mock ConvertTo-BridgeClosedDuration { '30 λεπτά' }

        Mock Get-BridgeStatusAdvice { 'Επέστρεψε μετά τις 00:00' }



        $null = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse



        $script:calledMessage | Should -Not -Match 'No text annotations'

        $script:calledMessage | Should -Match 'Επιτυχής ανάλυση'

    }

}

Describe 'ConvertFrom-BridgeOCRResult - Καταγραφή σφάλματος ανάλυσης κειμένου' {

    BeforeAll {
        $script:Config = New-BridgeConfiguration
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
        $res = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse
        $res | Should -BeNullOrEmpty
        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Stage -eq 'Σφάλμα' } -Times 1 -Exactly -Scope It
    }

}
}

