Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe -Name 'ConvertTo-BridgeTimeRange' -Fixture {

    BeforeAll -Scriptblock {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1"
        $script:Config = New-BridgeConfiguration

    }

    Context -Name 'Όταν το OCR κείμενο δεν περιέχει έγκυρες ημερομηνίες' -Fixture {

        It -Name 'Πρέπει να επιστρέφει $null "Δεν βρέθηκαν επαρκείς ημερομηνίες"' -Test {
            $fakeLines = @('άκυρο κείμενο χωρίς ημερομηνίες')
            $res = ConvertTo-BridgeTimeRange -Lines $fakeLines
            $res | Should -BeNullOrEmpty
        }

        It -Name 'Επιστρέφει $null όταν δίνονται μη αναγνωρίσιμες ημερομηνίες' -Test {
            $res = ConvertTo-BridgeTimeRange -Lines @('ΗμερομηνίεςΠουΔενΥπάρχουνΣανFormat')
            $res | Should -BeNullOrEmpty
        }

    }

    Context -Name 'Όταν οι ημερομηνίες είναι εκτός χρονολογικής σειράς στο OCR' -Fixture {

        It -Name 'Πρέπει να ταξινομεί τις ημερομηνίες χρονολογικά και να επιστρέφει θετικό ClosedFor' -Test {

            $lines = @(

                'Έως 25/04/2025 14:30',

                'Από 25/04/2025 14:00'

            )

            $result = ConvertTo-BridgeTimeRange -Lines $lines

            $result.From | Should -Be -ExpectedValue ([datetime]::ParseExact('25/04/2025 14:00', 'dd/MM/yyyy HH:mm', $null))

            $result.To | Should -Be -ExpectedValue ([datetime]::ParseExact('25/04/2025 14:30', 'dd/MM/yyyy HH:mm', $null))

            $result.ClosedFor | Should -Be -ExpectedValue ([timespan]'00:30:00')

        }

    }

    Context -Name 'Έλεγχος ανεπαρκών matches και εξαιρέσεων' -Fixture {

        It -Name 'Επιστρέφει $null όταν υπάρχει μόνο 1 ημερομηνία' -Test {
            $res = ConvertTo-BridgeTimeRange -Lines @('Μόνο μία: 25/04/2025 14:00')
            $res | Should -BeNullOrEmpty
        }

        It -Name 'Επιστρέφει $null όταν αποτυγχάνει το parse' -Test {
            $res = ConvertTo-BridgeTimeRange -Lines @('99/99/2025 14:00', '25/04/2025 14:00')
            $res | Should -BeNullOrEmpty
        }

    }

    Context -Name 'Όταν η πρώτη ημερομηνία είναι μεγαλύτερη της δεύτερης' -Fixture {

        It -Name 'Πρέπει να αντιστρέφει from και to' -Test {

            $lines = @(

                'Πρώτη: 25/04/2025 14:30',

                'Δεύτερη: 25/04/2025 14:00'

            )

            $result = ConvertTo-BridgeTimeRange -Lines $lines

            $result.From | Should -Be -ExpectedValue ([datetime]::ParseExact('25/04/2025 14:00', 'dd/MM/yyyy HH:mm', $null))

            $result.To | Should -Be -ExpectedValue ([datetime]::ParseExact('25/04/2025 14:30', 'dd/MM/yyyy HH:mm', $null))

        }

    }

}

