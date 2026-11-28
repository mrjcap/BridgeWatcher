

Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope -ModuleName BridgeWatcher -ScriptBlock {
Describe -Name 'Δοκιμές ConvertFrom-BridgeOCRResult' -Fixture {

    BeforeAll -Scriptblock {
        $script:Config = New-BridgeConfiguration
    }

    Mock -CommandName Write-BridgeLog -MockWith {}

    Context -Name 'Όταν η ανάλυση OCR κειμένου αποτυγχάνει' -Fixture {

        It -Name 'Πρέπει να επιστρέφει $null όταν δεν βρίσκονται textAnnotations' -Test {
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





        It -Name 'Warns and returns no result when <Shape> omits textAnnotations' -ForEach @(
            @{ Shape = 'JSON'; Response = ('{"responses":[{}]}' | ConvertFrom-Json) }
            @{ Shape = 'a hashtable'; Response = @{ responses = @(@{}) } }
        ) -Test {
            Mock -CommandName Write-BridgeLog -MockWith {}

            $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $Response -ErrorAction Stop

            $result | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -Scope It -ParameterFilter {
                $Level -eq 'Warning' -and $Message -like '*textAnnotations*'
            }
        }

        It -Name 'Retains a usable schedule when an image also reports an error' -Test {
            Mock -CommandName Write-BridgeLog -MockWith {}
            $response = ConvertFrom-Json -InputObject '{"responses":[{"error":{"code":14},"textAnnotations":[{"description":"15/01/2030 11:30 to 15/01/2030 12:00"}]}]}'
            $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $response
            $result.To | Should -BeExactly -ExpectedValue '15/01/2030 12:00'
        }

        It -Name 'Πρέπει να επιστρέφει $null για κενό κείμενο OCR' -Test {
            $mockApiResponse = @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{ description = '' }
                        )
                    }
                )
            }
            Mock -CommandName Write-Verbose -MockWith {}
            Mock -CommandName Write-Warning -MockWith {}
            $res = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse
            $res | Should -BeNullOrEmpty
        }

    }

    It -Name 'πρέπει να καλεί το Write-BridgeLog όταν δεν βρίσκεται το εύρος χρόνου' -Test {
        $mockApiResponse = @{
            responses = @(
                @{
                    textAnnotations = @(
                        @{ description = 'Από 01/01/2025 10:00 Έως 01/01/2025 10:30' }
                    )
                }
            )
        }
        Mock -CommandName ConvertTo-BridgeTimeRange -MockWith { return $null }
        Mock -CommandName Write-BridgeLog -MockWith {}

        ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse

        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Message -like '*Δεν κατέστη δυνατή η ανάλυση χρονικού διαστήματος*' } -Times 1 -Exactly -Scope It
    }

    It -Name 'πρέπει να επιστρέφει κενό πίνακα όταν δεν βρίσκεται το εύρος χρόνου' -Test {


        $mockApiResponse = @{

            responses = @(

                @{

                    textAnnotations = @(

                        @{ description = 'Από 01/01/2025 10:00 Έως 01/01/2025 10:30' }

                    )

                }

            )

        }


        Mock -CommandName ConvertTo-BridgeTimeRange -MockWith { return $null }


        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockApiResponse


        $result | Should -Be -ExpectedValue @()

    }

    It -Name 'Keeps a closure active with twenty seconds left' -Test {
        $config = New-BridgeConfiguration
        $config.Defaults.TimezoneIds = @('UTC')
        Mock -CommandName Get-Date -MockWith { [datetime]::new(2030, 1, 15, 11, 59, 40, [DateTimeKind]::Utc) }
        Mock -CommandName Write-BridgeLog -MockWith {}
        $response = @{ responses = @(@{ textAnnotations = @(@{ description = '15/01/2030 11:30 to 15/01/2030 12:00' }) }) }

        $result = ConvertFrom-BridgeOCRResult -Configuration $config -ApiResponse $response

        $result.ScheduleState | Should -BeExactly -ExpectedValue 'Active'
        $result.Note1 | Should -BeExactly -ExpectedValue $config.AdviceMessages.Wait
    }

    It -Name 'Returns Expired exactly at the scheduled reopening time' -Test {
        $config = New-BridgeConfiguration
        $config.Defaults.TimezoneIds = @('UTC')
        Mock -CommandName Get-Date -MockWith { [datetime]::new(2030, 1, 15, 12, 0, 0, [DateTimeKind]::Utc) }
        Mock -CommandName Write-BridgeLog -MockWith {}
        $response = @{ responses = @(@{ textAnnotations = @(@{ description = '15/01/2030 11:30 έως 15/01/2030 12:00' }) }) }

        $result = ConvertFrom-BridgeOCRResult -Configuration $config -ApiResponse $response

        $result.ScheduleState | Should -BeExactly -ExpectedValue 'Expired'
        $result.OpensIn | Should -BeExactly -ExpectedValue 'Τώρα'
    }

    It -Name 'επιστρέφει προειδοποίηση με ώρα κλεισίματος' -Test {

        $mockResponse = @{

            responses = @(

                @{ textAnnotations = @(@{ description = '25/04/2025 23:00 έως 26/04/2025 00:00' }) }

            )

        }



        Mock -CommandName ConvertTo-BridgeTimeRange -MockWith {
            $tz = try { [System.TimeZoneInfo]::FindSystemTimeZoneById('Europe/Athens') } catch { [System.TimeZoneInfo]::FindSystemTimeZoneById('GTB Standard Time') }
            $athensNow = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $tz)
            [pscustomobject]@{
                From      = $athensNow.AddMinutes(60)
                To        = $athensNow.AddMinutes(90)
                ClosedFor = [timespan]::FromMinutes(30)
            }
        }



        Mock -CommandName ConvertTo-BridgeClosedDuration -MockWith { '30 λεπτά' }

        Mock -CommandName Get-BridgeStatusAdvice -MockWith { 'Επέστρεψε μετά τις 00:00' }

        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse

        $result.Note2 | Should -Match -RegularExpression 'θα κλείσει στις'
        $result.ScheduleState | Should -Be -ExpectedValue 'Future'
        $result.OpensIn | Should -BeNullOrEmpty

    }

    It -Name 'επιστρέφει μήνυμα ότι η γέφυρα είναι ήδη κλειστή' -Test {

        $mockResponse = @{

            responses = @(

                @{ textAnnotations = @(@{ description = '25/04/2025 14:00 έως 25/04/2025 14:30' }) }

            )

        }



        Mock -CommandName ConvertTo-BridgeTimeRange -MockWith {
            $tz = try { [System.TimeZoneInfo]::FindSystemTimeZoneById('Europe/Athens') } catch { [System.TimeZoneInfo]::FindSystemTimeZoneById('GTB Standard Time') }
            $athensNow = [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $tz)
            [pscustomobject]@{
                From      = $athensNow.AddMinutes(-20)
                To        = $athensNow.AddMinutes(10)
                ClosedFor = [timespan]::FromMinutes(30)
            }
        }



        Mock -CommandName ConvertTo-BridgeClosedDuration -MockWith { '30 λεπτά' }

        Mock -CommandName Get-BridgeStatusAdvice -MockWith { 'Κατέβα για καφέ' }

        $result = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse

        $result.Note2 | Should -Match -RegularExpression 'ήδη κλειστή από τις'
        $result.ScheduleState | Should -Be -ExpectedValue 'Active'
        $result.OpensIn | Should -Match -RegularExpression 'λεπτά'

    }

    It -Name 'Καταγράφει επιτυχές μήνυμα κατά την επιτυχή OCR ανάλυση' -Test {

        $calledMessage = $null

        Mock -CommandName Write-BridgeLog -MockWith {

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

        Mock -CommandName ConvertTo-BridgeTimeRange -MockWith { [pscustomobject]@{

                From      = [datetime]::ParseExact('25/04/2025 14:00', 'dd/MM/yyyy HH:mm', $null)

                To        = [datetime]::ParseExact('25/04/2025 14:30', 'dd/MM/yyyy HH:mm', $null)

                ClosedFor = [timespan]::FromMinutes(30)

            } }

        Mock -CommandName ConvertTo-BridgeClosedDuration -MockWith { '30 λεπτά' }

        Mock -CommandName Get-BridgeStatusAdvice -MockWith { 'Επέστρεψε μετά τις 00:00' }



        $null = ConvertFrom-BridgeOCRResult -Configuration $script:Config -ApiResponse $mockResponse



        $script:calledMessage | Should -Not -Match -RegularExpression 'No text annotations'

        $script:calledMessage | Should -Match -RegularExpression 'Επιτυχής ανάλυση'

    }

}

Describe -Name 'ConvertFrom-BridgeOCRResult - Καταγραφή σφάλματος ανάλυσης κειμένου' -Fixture {

    BeforeAll -Scriptblock {
        $script:Config = New-BridgeConfiguration
    }

    It -Name 'Πρέπει να καλει το Write-BridgeLog και να επιστρέφει $null όταν αποτυγχάνει η ανάλυση OCR' -Test {
        Mock -CommandName Write-BridgeLog -MockWith {}
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

