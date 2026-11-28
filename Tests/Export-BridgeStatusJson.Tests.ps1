Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope -ModuleName BridgeWatcher -ScriptBlock {
Describe -Name 'Δοκιμές Export-BridgeStatusJson' -Fixture {

    BeforeAll -Scriptblock {
        $script:Config = New-BridgeConfiguration
    }

    Context -Name 'Όταν συμβαίνει σφάλμα κατά την αποθήκευση JSON' -Fixture {

        It -Name 'Επιστρέφει BridgeResult με σφάλμα και γράφει το κατάλληλο μήνυμα' -Test {


            Mock -CommandName Test-Path -MockWith { $true }

            Mock -CommandName New-Item -MockWith { }


            Mock -CommandName ConvertTo-Json -MockWith { throw 'Fake error during file write' }

            Mock -CommandName Move-Item -MockWith {}


            Mock -CommandName Write-BridgeLog -MockWith {}



            $result = Export-BridgeStatusJson -Configuration $script:Config -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'valid/path/file.json'



            $result | Should -Not -BeNullOrEmpty

            $result.Success | Should -Be -ExpectedValue $false

            $result.ErrorMessage | Should -Match -RegularExpression 'Fake error during file write'

            $result.ErrorCode | Should -Be -ExpectedValue 'JSON_EXPORT_FAILURE'




            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -Scope It

        }

        It -Name 'Διαγράφει το προσωρινό αρχείο .tmp όταν το Move-Item αποτυγχάνει' -Test {
            $targetPath = Join-Path -Path $TestDrive -ChildPath 'atomic-fail.json'
            Mock -CommandName Move-Item -MockWith { throw 'Simulated atomic move failure' }
            Mock -CommandName Write-BridgeLog -MockWith {}

            $result = Export-BridgeStatusJson -Configuration $script:Config -Data @([pscustomobject]@{ Bridge = 'Test' }) -Path $targetPath
            $result.Success | Should -Be -ExpectedValue $false
            $result.ErrorCode | Should -Be -ExpectedValue 'JSON_EXPORT_FAILURE'

            $leftoverTmp = Get-ChildItem -Path $TestDrive -Filter 'atomic-fail.json.*.tmp'
            $leftoverTmp | Should -BeNullOrEmpty
        }

        It -Name 'Δεν αντικαθιστά το υπάρχον snapshot όταν η Set-Content αποτυγχάνει με non-terminating σφάλμα' -Test {
            $targetPath = Join-Path -Path $TestDrive -ChildPath 'preserve-good-state.json'
            $originalJson = '[{"GefyraName":"Ισθμία","GefyraStatus":"Ανοιχτή"}]'
            Microsoft.PowerShell.Management\Set-Content -Path $targetPath -Value $originalJson -Encoding UTF8 -Force

            Mock -CommandName Write-BridgeLog -MockWith {}
            Mock -CommandName Set-Content -MockWith {
                [System.IO.File]::WriteAllText($Path, '{"corrupt":')
                Write-Error -Message 'Simulated non-terminating disk quota error'
            }

            $result = Export-BridgeStatusJson -Configuration $script:Config -Data @([pscustomobject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή' }) -Path $targetPath -ErrorAction Continue
            $result.Success | Should -Be -ExpectedValue $false
            $result.ErrorCode | Should -Be -ExpectedValue 'JSON_EXPORT_FAILURE'
            (Get-Content -Path $targetPath -Raw).Trim() | Should -Be -ExpectedValue $originalJson

            $leftoverTmp = Get-ChildItem -Path $TestDrive -Filter 'preserve-good-state.json.*.tmp'
            $leftoverTmp | Should -BeNullOrEmpty
        }

    }



    Context -Name 'Όταν η αποθήκευση JSON είναι επιτυχής' -Fixture {

        It -Name 'Επιστρέφει BridgeResult με επιτυχία' -Test {

            Mock -CommandName Test-Path -MockWith { $true }

            Mock -CommandName New-Item -MockWith { }

            Mock -CommandName Set-Content -MockWith {}

            Mock -CommandName Move-Item -MockWith {}

            Mock -CommandName Write-BridgeLog -MockWith {}



            $result = Export-BridgeStatusJson -Configuration $script:Config -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'valid/path/file.json'



            $result | Should -Not -BeNullOrEmpty

            $result.Success | Should -Be -ExpectedValue $true

            $result.Data.ExportedPath | Should -Be -ExpectedValue 'valid/path/file.json'

            $result.Data.RecordCount | Should -Be -ExpectedValue 1




            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -Scope It

        }

        It -Name 'Πρέπει να καταγράψει επιτυχές μήνυμα (Write-BridgeLog)' -Test {

            Mock -CommandName Test-Path -MockWith { $true }

            Mock -CommandName New-Item -MockWith { }

            Mock -CommandName Set-Content -MockWith {}

            Mock -CommandName Move-Item -MockWith {}

            Mock -CommandName Write-BridgeLog -MockWith {}

            Export-BridgeStatusJson -Configuration $script:Config -Data @([pscustomobject]@{Bridge = 'Test' }) -Path 'valid/path/file.json'


            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -Scope It

        }

    }

    Context -Name 'Έλεγχος Validation παραμέτρων' -Fixture { It -Name 'Δέχεται κενό array όταν το Data είναι κενό' -Test {

            Mock -CommandName Test-Path -MockWith { $true }

            Mock -CommandName New-Item -MockWith { }

            Mock -CommandName ConvertTo-Json -MockWith { '[]' }



            Mock -CommandName Move-Item -MockWith {}

            Mock -CommandName Write-BridgeLog -MockWith { }



            $result = Export-BridgeStatusJson -Configuration $script:Config -Data @() -Path 'out.json'

            $result | Should -Not -BeNullOrEmpty

            $result.Success | Should -Be -ExpectedValue $true

            $result.Data.RecordCount | Should -Be -ExpectedValue 0

        }



        It -Name 'Πετάει validation σφάλμα όταν το Path είναι κενό' -Test {

            { Export-BridgeStatusJson -Configuration $script:Config -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path '' } | Should -Throw

        }



        It -Name 'Επιστρέφει BridgeResult με σφάλμα όταν αποτυγχάνει η εγγραφή JSON' -Test {

            Mock -CommandName ConvertTo-Json -MockWith { throw 'Ο φάκελος προορισμού δεν υπάρχει' }

            Mock -CommandName Write-BridgeLog



            $result = Export-BridgeStatusJson -Configuration $script:Config -Data @([pscustomobject]@{ gefyra = 'Ισθμία' }) -Path 'fake.json' -Verbose



            $result | Should -Not -BeNullOrEmpty

            $result.Success | Should -Be -ExpectedValue $false

            $result.ErrorMessage | Should -Match -RegularExpression 'Ο φάκελος προορισμού δεν υπάρχει'

            $result.ErrorCode | Should -Be -ExpectedValue 'JSON_EXPORT_FAILURE'

        }

    }

    Context -Name 'Configuration Coverage Δοκιμές' -Fixture {

        It -Name 'Καλύπτει Configuration.DefaultJsonDepth path' -Test {

            Mock -CommandName Test-Path -MockWith { $true }

            Mock -CommandName New-Item -MockWith { }



            Mock -CommandName Move-Item -MockWith {}

            Mock -CommandName ConvertTo-Json -MockWith { '{"test": "data"}' }
            Mock -CommandName Write-BridgeLog -MockWith {}

            $config = New-BridgeConfiguration

            $config.Defaults.JsonDepth = 8



            Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config



            Should -Invoke -CommandName ConvertTo-Json -ParameterFilter { $Depth -eq 8 } -Times 1

        }

        It -Name 'Καλύπτει απουσία Configuration.DefaultJsonDepth (fallback σε 10)' -Test {
            Mock -CommandName Test-Path -MockWith { $true }
            Mock -CommandName New-Item -MockWith { }
            Mock -CommandName Move-Item -MockWith {}
            Mock -CommandName ConvertTo-Json -MockWith { '{"test": "data"}' }
            Mock -CommandName Write-BridgeLog -MockWith {}

            $config = New-BridgeConfiguration
            $config.Defaults = [PSCustomObject]@{ }

            Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config

            Should -Invoke -CommandName ConvertTo-Json -ParameterFilter { $Depth -eq 10 } -Times 1
        }

        It -Name 'Καλύπτει Configuration.ExportMessages.Success path' -Test {

            Mock -CommandName Test-Path -MockWith { $true }

            Mock -CommandName New-Item -MockWith { }



            Mock -CommandName Move-Item -MockWith {}

            Mock -CommandName Write-BridgeLog -MockWith {}



            $config = New-BridgeConfiguration

            $config.ExportMessages.Success = 'Custom success message'



            Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config



            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Message -like 'Custom success message*' } -Times 1

        }

        It -Name 'Καλύπτει Configuration.ExportMessages.Failed σε σφάλμα' -Test {

            Mock -CommandName Test-Path -MockWith { $true }

            Mock -CommandName New-Item -MockWith { }

            Mock -CommandName ConvertTo-Json -MockWith { throw 'Test error' }

            Mock -CommandName Move-Item -MockWith {}

            Mock -CommandName Write-BridgeLog -MockWith {}



            $config = New-BridgeConfiguration

            $config.ExportMessages.Failed = 'Custom failed message'



            $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config



            $result.Success | Should -Be -ExpectedValue $false

            $result.ErrorMessage | Should -Match -RegularExpression 'Custom failed message'



            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Message -like 'Custom failed message*' } -Times 1

        }

        It -Name 'Καλύπτει Configuration.ExportMessages.DirectoryNotExists' -Test {
            $config = New-BridgeConfiguration
            $config.ExportMessages.DirectoryNotExists = 'Custom directory not exists'

            Mock -CommandName Test-Path -MockWith { $false } -ParameterFilter { $Path -notmatch 'config.json' }
            Mock -CommandName Split-Path -MockWith { 'invalid/path' } -ParameterFilter { $Path -like '*test.json*' }
            Mock -CommandName New-Item -MockWith { throw 'Custom directory not exists' }
            Mock -CommandName Write-BridgeLog -MockWith {}



            $result = Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'invalid/path/test.json' -Configuration $config



            $result.Success | Should -Be -ExpectedValue $false

            $result.ErrorMessage | Should -Match -RegularExpression 'Custom directory not exists'



            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Message -like 'Custom directory not exists*' } -Times 1

        }

        It -Name 'Καλύπτει Configuration.LoggingConfig paths' -Test {

            Mock -CommandName Test-Path -MockWith { $true }

            Mock -CommandName New-Item -MockWith { }



            Mock -CommandName Move-Item -MockWith {}

            Mock -CommandName Write-BridgeLog -MockWith {}



            $config = New-BridgeConfiguration




            Export-BridgeStatusJson -Data @([pscustomobject]@{Test = 'Data' }) -Path 'test.json' -Configuration $config



            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Stage -eq 'Ανάλυση' } -Times 1

        }

    }

}
}

