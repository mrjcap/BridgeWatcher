Import-Module "$PSScriptRoot/../BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'ConvertTo-BridgeTimeRange' {
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
    }
}