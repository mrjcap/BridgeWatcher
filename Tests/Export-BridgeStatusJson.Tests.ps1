Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psm1" -Force

Describe 'Export-BridgeStatusJson Tests' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
    }
    Context 'Όταν συμβαίνει σφάλμα κατά την αποθήκευση JSON' {
        It 'Επιστρέφει BridgeResult με σφάλμα και γράφει το κατάλληλο μήνυμα' {
            # Mock το Test-Path να επιστρέφει true για να μην αποτύχει πρόωρα
            Mock Test-Path { $true }
            # Mock Set-Content για να προκαλέσουμε σφάλμα
            Mock ConvertTo-Json { throw 'Fake error during file write' }
            Mock Move-Item {}
            # Mock Write-BridgeLog
            Mock Write-BridgeLog {}

            $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'C:\valid\path\file.json'

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'Fake error during file write'
            $result.ErrorCode | Should -Be 'JSON_EXPORT_FAILURE'

            # Επιβεβαιώνουμε ότι κάλεσε το Write-BridgeLog με σφάλμα
            Assert-MockCalled Write-BridgeLog -Exactly 1 -Scope It
        }
    }

    Context 'Όταν η αποθήκευση JSON είναι επιτυχής' {
        It 'Επιστρέφει BridgeResult με επιτυχία' {
            Mock Test-Path { $true }

            Mock Move-Item {}
            Mock Write-BridgeLog {}

            $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'C:\valid\path\file.json'

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.Data.ExportedPath | Should -Be 'C:\valid\path\file.json'
            $result.Data.RecordCount | Should -Be 1

            # Επιβεβαιώνουμε ότι δεν έγραψε Warning (μόνο Info)
            Assert-MockCalled Write-BridgeLog -Exactly 1 -Scope It
        }
        It 'Πρέπει να καταγράψει επιτυχές μήνυμα (Write-BridgeLog)' {
            Mock Test-Path { $true }

            Mock Move-Item {}
            Mock Write-BridgeLog {}
            Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'C:\valid\path\file.json'
            # Επιβεβαιώνουμε ότι κάλεσε το Write-BridgeLog μία φορά
            Assert-MockCalled Write-BridgeLog -Exactly 1 -Scope It
        }
    }
    Context 'Έλεγχος Validation παραμέτρων' { It 'Δέχεται κενό array όταν το Data είναι κενό' {
            Mock Test-Path { $true }
            Mock ConvertTo-Json { '[]' }

            Mock Move-Item {}
            Mock Write-BridgeLog { }

            $result = Export-BridgeStatusJson -Data @() -Path 'out.json'
            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $true
            $result.Data.RecordCount | Should -Be 0
        }

        It 'Πετάει validation σφάλμα όταν το Path είναι κενό' {
            { Export-BridgeStatusJson -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path '' } | Should -Throw
        }

        It 'Επιστρέφει BridgeResult με σφάλμα όταν αποτυγχάνει η εγγραφή JSON' {
            Mock ConvertTo-Json { throw 'Ο φάκελος προορισμού δεν υπάρχει' }
            Mock Write-BridgeLog

            $result = Export-BridgeStatusJson -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path 'fake.json' -Verbose

            $result | Should -Not -BeNullOrEmpty
            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'Ο φάκελος προορισμού δεν υπάρχει'
            $result.ErrorCode | Should -Be 'JSON_EXPORT_FAILURE'
        }
    }
    Context 'Configuration Coverage Tests' {
        It 'Καλύπτει Configuration.DefaultJsonDepth path' {
            Mock Test-Path { $true }

            Mock Move-Item {}
            Mock ConvertTo-Json { '{"test": "data"}' }

            $config = New-BridgeConfiguration
            $config.DefaultJsonDepth = 8

            Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config

            Assert-MockCalled ConvertTo-Json -ParameterFilter { $Depth -eq 8 } -Times 1
        }
        It 'Καλύπτει Configuration.ExportMessages.Success path' {
            Mock Test-Path { $true }

            Mock Move-Item {}
            Mock Write-BridgeLog {}

            $config = New-BridgeConfiguration
            $config.ExportMessages.Success = 'Custom success message'

            Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config

            Assert-MockCalled Write-BridgeLog -ParameterFilter { $Message -like 'Custom success message*' } -Times 1
        }
        It 'Καλύπτει Configuration.ExportMessages.Failed σε σφάλμα' {
            Mock Test-Path { $true }
            Mock ConvertTo-Json { throw 'Test error' }
            Mock Move-Item {}
            Mock Write-BridgeLog {}

            $config = New-BridgeConfiguration
            $config.ExportMessages.Failed = 'Custom failed message'

            $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config

            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'Custom failed message'

            Assert-MockCalled Write-BridgeLog -ParameterFilter { $Message -like 'Custom failed message*' } -Times 1
        }
        It 'Καλύπτει Configuration.ExportMessages.DirectoryNotExists' {
            Mock Test-Path { $false }
            Mock Split-Path { 'invalid/path' }
            Mock New-Item { throw 'Custom directory not exists' }
            Mock Write-BridgeLog {}

            $config = New-BridgeConfiguration
            $config.ExportMessages.DirectoryNotExists = 'Custom directory not exists'

            $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'invalid/path/test.json' -Configuration $config

            $result.Success | Should -Be $false
            $result.ErrorMessage | Should -Match 'Custom directory not exists'

            Assert-MockCalled Write-BridgeLog -ParameterFilter { $Message -like 'Custom directory not exists*' } -Times 1
        }
        It 'Καλύπτει Configuration.LoggingConfig paths' {
            Mock Test-Path { $true }

            Mock Move-Item {}
            Mock Write-BridgeLog {}

            $config = New-BridgeConfiguration
            # LoggingConfig.InfoStage already defaults to 'Ανάλυση'

            Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config

            Assert-MockCalled Write-BridgeLog -ParameterFilter { $Stage -eq 'Ανάλυση' } -Times 1
        }
    }
}
