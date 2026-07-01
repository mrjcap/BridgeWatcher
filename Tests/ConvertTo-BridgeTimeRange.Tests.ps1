Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psm1" -Force

Describe 'ConvertTo-BridgeTimeRange' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1"
    }
        Context 'Όταν το OCR κείμενο δεν περιέχει έγκυρες ημερομηνίες' {
            It 'Πρέπει να ρίχνει σφάλμα "Αποτυχία ανάλυσης ημερομηνιών: Cannot index into a null array."' {
                # Δημιουργούμε input που θα αποτύχει στο parsing
                $fakeLines = @('άκυρο κείμενο χωρίς ημερομηνίες')  # άδειο OCR αποτέλεσμα
                { ConvertTo-BridgeTimeRange -Lines $fakeLines } | Should -Throw "Αποτυχία ανάλυσης ημερομηνιών: Αποτυχία ανάλυσης ημερομηνιών: Δεν βρέθηκαν επαρκείς ημερομηνίες και ώρες για ανάλυση."
            }
            It 'Πετάει σφάλμα όταν δίνονται μη αναγνωρίσιμες ημερομηνίες' {
                {
                    ConvertTo-BridgeTimeRange -TimeRange 'ΗμερομηνίεςΠουΔενΥπάρχουνΣανFormat'
                } | Should -Throw
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
    }
