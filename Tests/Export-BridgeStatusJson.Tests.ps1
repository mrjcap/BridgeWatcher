Import-Module "$PSScriptRoot/../BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Export-BridgeStatusJson Tests' {
        Context 'Όταν συμβαίνει σφάλμα κατά την αποθήκευση JSON' {
            It 'Πετάει σφάλμα και γράφει το κατάλληλο μήνυμα' {
                # Mock το Test-Path να επιστρέφει true για να μην αποτύχει πρόωρα
                Mock Test-Path { $true }
                # Mock Set-Content για να προκαλέσουμε σφάλμα
                Mock Set-Content { throw 'Fake error during file write' }
                # Mock Write-BridgeLog
                Mock Write-BridgeLog {}

                { Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'C:\valid\path\file.json' } |
                    Should -Throw 'Σφάλμα αποθήκευσης JSON: Fake error during file write'

                # Επιβεβαιώνουμε ότι κάλεσε το Write-BridgeLog με σφάλμα
                Assert-MockCalled Write-BridgeLog -Exactly 1 -Scope It
            }
        }
        Context 'Όταν η αποθήκευση JSON είναι επιτυχής' {
            It 'Δεν πρέπει να γράψει Warning' {
                Mock Test-Path { $true }
                Mock Set-Content {}
                Mock Write-BridgeLog {}
                Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'C:\valid\path\file.json'
                # Επιβεβαιώνουμε ότι δεν έγραψε Warning (μόνο Info)
                Assert-MockCalled Write-BridgeLog -Exactly 1 -Scope It
            }
            It 'Πρέπει να καταγράψει επιτυχές μήνυμα (Write-BridgeLog)' {
                Mock Test-Path { $true }
                Mock Set-Content {}
                Mock Write-BridgeLog {}
                Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'C:\valid\path\file.json'
                # Επιβεβαιώνουμε ότι κάλεσε το Write-BridgeLog μία φορά
                Assert-MockCalled Write-BridgeLog -Exactly 1 -Scope It
            }
        }
        Context 'Έλεγχος Validation παραμέτρων' {
            It 'Πετάει validation σφάλμα όταν το Data είναι κενό' {
                { Export-BridgeStatusJson -Data @() -Path 'out.json' } | Should -Throw
            }
            It 'Πετάει validation σφάλμα όταν το Path είναι κενό' {
                { Export-BridgeStatusJson -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path '' } | Should -Throw
            }
        }
        It 'Πετάει validation error όταν το Data είναι κενό' {
            { Export-BridgeStatusJson -Data @() -Path 'out.json' } | Should -Throw
        }
        It 'Πετάει validation error όταν το Path είναι κενό' {
            { Export-BridgeStatusJson -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path '' } | Should -Throw
        }
        It 'Γράφει exception όταν αποτυγχάνει η εγγραφή JSON' {
            Mock Set-Content { throw 'Fake write failure' }
            { Export-BridgeStatusJson -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path 'fake.json' -Verbose } |
                Should -Throw 'Σφάλμα αποθήκευσης JSON: Ο φάκελος προορισμού δεν υπάρχει: '
        }
    }
}