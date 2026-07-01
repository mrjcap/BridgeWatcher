Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Export-BridgeStatusJson Tests' {
        Context 'Όταν συμβαίνει σφάλμα κατά την αποθήκευση JSON' {
            It 'Επιστρέφει BridgeResult με σφάλμα και γράφει το κατάλληλο μήνυμα' {
                # Mock ConvertTo-Json για να προκαλέσουμε σφάλμα
                Mock ConvertTo-Json { throw 'Fake error during file write' }
                # Mock Write-BridgeLog
                Mock Write-BridgeLog {}

                $testPath = Join-Path $TestDrive 'file.json'
                $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path $testPath
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
                Mock Write-BridgeLog {}
                $testPath = Join-Path $TestDrive 'file.json'

                $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path $testPath

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Data.ExportedPath | Should -Be $testPath
                $result.Data.RecordCount | Should -Be 1

                # Επιβεβαιώνουμε ότι δεν έγραψε Warning (μόνο Info)
                Assert-MockCalled Write-BridgeLog -Exactly 1 -Scope It
            }
            It 'Πρέπει να καταγράψει επιτυχές μήνυμα (Write-BridgeLog)' {
                Mock Write-BridgeLog {}
                $testPath = Join-Path $TestDrive 'file.json'
                Export-BridgeStatusJson -Data @([pscustomobject]@{Bridge = 'Test' }) -Path $testPath
                # Επιβεβαιώνουμε ότι κάλεσε το Write-BridgeLog μία φορά
                Assert-MockCalled Write-BridgeLog -Exactly 1 -Scope It
            }
        }
        Context 'Έλεγχος Validation παραμέτρων' { It 'Δέχεται κενό array όταν το Data είναι κενό' {
                Mock ConvertTo-Json { '[]' }
                Mock Write-BridgeLog { }
                $testPath = Join-Path $TestDrive 'out.json'

                $result = Export-BridgeStatusJson -Data @() -Path $testPath
                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Data.RecordCount | Should -Be 0
            }

            It 'Πετάει validation σφάλμα όταν το Path είναι κενό' {
                { Export-BridgeStatusJson -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path '' } | Should -Throw
            }

            It 'Επιστρέφει BridgeResult με σφάλμα όταν αποτυγχάνει η εγγραφή JSON' {
                Mock Write-BridgeLog
                Mock New-Item { throw 'Mock Directory Error' }

                $result = Export-BridgeStatusJson -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path 'Z:\fake\dir\fake.json' -Verbose

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Match 'Ο φάκελος προορισμού δεν υπάρχει'
                $result.ErrorCode | Should -Be 'DIRECTORY_NOT_EXISTS'
            }
        }
        Context 'Configuration Coverage Tests' {
            It 'Καλύπτει Configuration.DefaultJsonDepth path' {
                Mock ConvertTo-Json { '{"test": "data"}' }
                # Note: FileStream will actually write to test.json unless we intercept it, but for coverage it's fine since we delete it or it's a test dir.
                $testPath = Join-Path $TestDrive 'test.json'

                $config = [PSCustomObject]@{
                    DefaultJsonDepth    = 8
                }

                Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path $testPath -Configuration $config

                Assert-MockCalled ConvertTo-Json -ParameterFilter { $Depth -eq 8 } -Times 1
            }
            It 'Καλύπτει Configuration.ExportMessages.Success path' {
                Mock Write-BridgeLog {}
                $testPath = Join-Path $TestDrive 'test.json'

                $config = [PSCustomObject]@{
                    ExportMessages = @{
                        Success    = 'Custom success message'
                    }
                    LoggingConfig  = @{
                        InfoStage    = 'Ανάλυση'
                    }
                }

                Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path $testPath -Configuration $config

                Assert-MockCalled Write-BridgeLog -ParameterFilter { $Message -like 'Custom success message*' } -Times 1
            }
            It 'Καλύπτει Configuration.ExportMessages.Failed σε σφάλμα' {
                Mock ConvertTo-Json { throw 'Test error' }
                Mock Write-BridgeLog {}

                $config = [PSCustomObject]@{
                    ExportMessages = @{
                        Failed    = 'Custom failed message'
                    }
                    LoggingConfig  = @{
                        ErrorStage   = 'Σφάλμα'
                        WarningLevel = 'Warning'
                    } }

                $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config

                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Match 'Custom failed message'

                Assert-MockCalled Write-BridgeLog -ParameterFilter { $Message -like 'Custom failed message*' } -Times 1
            }
            It 'Καλύπτει Configuration.ExportMessages.DirectoryNotExists' {
                Mock New-Item { throw 'Mock directory error' }
                Mock Write-BridgeLog {}

                $config = [PSCustomObject]@{
                    ExportMessages = @{
                        DirectoryNotExists = 'Custom directory not exists'
                        Failed             = 'Custom failed message'
                    }
                    LoggingConfig  = @{
                        ErrorStage   = 'Σφάλμα'
                        WarningLevel = 'Warning'
                    } }

                $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'invalid/path/test.json' -Configuration $config

                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Match 'Custom directory not exists'

                Assert-MockCalled Write-BridgeLog -ParameterFilter { $Message -like 'Custom directory not exists*' } -Times 1
            }
            It 'Καλύπτει Configuration.LoggingConfig paths' {
                Mock Test-Path { $true }
                Mock Set-Content {}
                Mock Move-Item {}
                Mock Write-BridgeLog {}

                $config = [PSCustomObject]@{
                    ExportMessages = @{
                        Success    = 'Success'
                    }
                    LoggingConfig  = @{
                        InfoStage    = 'Ανάλυση'
                        ErrorStage   = 'Σφάλμα'
                        WarningLevel = 'Warning'
                    }
                }

                Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config

                Assert-MockCalled Write-BridgeLog -ParameterFilter { $Stage -eq 'Ανάλυση' } -Times 1
            }
        }
    }
}

