Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'ConvertTo-BridgeTimeRange' {

    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1"
        $script:Config = New-BridgeConfiguration

    }

    Context 'Όταν το OCR κείμενο δεν περιέχει έγκυρες ημερομηνίες' {

        It 'Πρέπει να επιστρέφει $null "Δεν βρέθηκαν επαρκείς ημερομηνίες"' {
            $fakeLines = @('άκυρο κείμενο χωρίς ημερομηνίες')  # άδειο OCR αποτέλεσμα
            $res = ConvertTo-BridgeTimeRange -Lines $fakeLines
            $res | Should -BeNullOrEmpty
        }

        It 'Επιστρέφει $null όταν δίνονται μη αναγνωρίσιμες ημερομηνίες' {
            $res = ConvertTo-BridgeTimeRange -Lines @('ΗμερομηνίεςΠουΔενΥπάρχουνΣανFormat')
            $res | Should -BeNullOrEmpty
        }

    }

    Context 'Όταν οι ημερομηνίες είναι εκτός χρονολογικής σειράς στο OCR' {

        It 'Πρέπει να ταξινομεί τις ημερομηνίες χρονολογικά και να επιστρέφει θετικό ClosedFor' {

            $lines = @(

                'Έως 25/04/2025 14:30',

                'Από 25/04/2025 14:00'

            )

            $result = ConvertTo-BridgeTimeRange -Lines $lines

            $result.From | Should -Be ([datetime]::ParseExact('25/04/2025 14:00', 'dd/MM/yyyy HH:mm', $null))

            $result.To | Should -Be ([datetime]::ParseExact('25/04/2025 14:30', 'dd/MM/yyyy HH:mm', $null))

            $result.ClosedFor | Should -Be ([timespan]'00:30:00')

        }

    }

    Context 'Έλεγχος ανεπαρκών matches και εξαιρέσεων' {

        It 'Επιστρέφει $null όταν υπάρχει μόνο 1 ημερομηνία' {
            $res = ConvertTo-BridgeTimeRange -Lines @('Μόνο μία: 25/04/2025 14:00')
            $res | Should -BeNullOrEmpty
        }

        It 'Επιστρέφει $null όταν αποτυγχάνει το parse' {
            $res = ConvertTo-BridgeTimeRange -Lines @('99/99/2025 14:00', '25/04/2025 14:00')
            $res | Should -BeNullOrEmpty
        }

    }

    Context 'Όταν η πρώτη ημερομηνία είναι μεγαλύτερη της δεύτερης' {

        It 'Πρέπει να αντιστρέφει from και to' {

            $lines = @(

                'Πρώτη: 25/04/2025 14:30',

                'Δεύτερη: 25/04/2025 14:00'

            )

            $result = ConvertTo-BridgeTimeRange -Lines $lines

            $result.From | Should -Be ([datetime]::ParseExact('25/04/2025 14:00', 'dd/MM/yyyy HH:mm', $null))

            $result.To | Should -Be ([datetime]::ParseExact('25/04/2025 14:30', 'dd/MM/yyyy HH:mm', $null))

        }

    }

}

