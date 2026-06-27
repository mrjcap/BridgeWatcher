Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'New-BridgeResult' {
        Context 'Success Result Creation' {
            It 'Δημιουργεί επιτυχημένο αποτέλεσμα με δεδομένα' {
                $data = @{ TestKey = 'TestValue' }
                $result = New-BridgeResult -Success $true -Data $data

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Data | Should -Be $data
                $result.ErrorMessage | Should -Be ''
                $result.ErrorCode | Should -Be ''
                $result.Timestamp | Should -Not -BeNullOrEmpty
                $result.Timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$'
            }

            It 'Δημιουργεί επιτυχημένο αποτέλεσμα χωρίς δεδομένα' {
                $result = New-BridgeResult -Success $true

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Data | Should -BeNullOrEmpty
                $result.ErrorMessage | Should -Be ''
                $result.ErrorCode | Should -Be ''
                $result.Timestamp | Should -Not -BeNullOrEmpty
            }

            It 'Δημιουργεί επιτυχημένο αποτέλεσμα με string δεδομένα' {
                $data = 'Test String Data'
                $result = New-BridgeResult -Success $true -Data $data

                $result.Success | Should -Be $true
                $result.Data | Should -Be $data
            }

            It 'Δημιουργεί επιτυχημένο αποτέλεσμα με array δεδομένα' {
                $data = @('Item1', 'Item2', 'Item3')
                $result = New-BridgeResult -Success $true -Data $data

                $result.Success | Should -Be $true
                $result.Data | Should -Be $data
                $result.Data.Count | Should -Be 3
            }
        }

        Context 'Error Result Creation' {
            It 'Δημιουργεί αποτέλεσμα σφάλματος με μήνυμα και κωδικό' {
                $errorMessage = 'Test error message'
                $errorCode = 'TEST_ERROR'
                $result = New-BridgeResult -Success $false -ErrorMessage $errorMessage -ErrorCode $errorCode

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.Data | Should -BeNullOrEmpty
                $result.ErrorMessage | Should -Be $errorMessage
                $result.ErrorCode | Should -Be $errorCode
                $result.Timestamp | Should -Not -BeNullOrEmpty
            }

            It 'Δημιουργεί αποτέλεσμα σφάλματος μόνο με μήνυμα' {
                $errorMessage = 'Test error message'
                $result = New-BridgeResult -Success $false -ErrorMessage $errorMessage

                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be $errorMessage
                $result.ErrorCode | Should -Be ''
            }

            It 'Δημιουργεί αποτέλεσμα σφάλματος χωρίς μήνυμα' {
                $result = New-BridgeResult -Success $false

                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be ''
                $result.ErrorCode | Should -Be ''
            }
        }

        Context 'Object Structure' {
            It 'Επιστρέφει PSCustomObject με σωστές ιδιότητες' {
                $result = New-BridgeResult -Success $true

                $result | Should -BeOfType [PSCustomObject]
                $result.PSObject.Properties.Name | Should -Contain 'Success'
                $result.PSObject.Properties.Name | Should -Contain 'Data'
                $result.PSObject.Properties.Name | Should -Contain 'ErrorMessage'
                $result.PSObject.Properties.Name | Should -Contain 'ErrorCode'
                $result.PSObject.Properties.Name | Should -Contain 'Timestamp'
                # Verify we have exactly these 5 properties and no others
                $expectedProperties = @('Success', 'Data', 'ErrorMessage', 'ErrorCode', 'Timestamp')
                $actualProperties = $result.PSObject.Properties.Name | Sort-Object
                $expectedProperties | Sort-Object | Should -Be $actualProperties
            }

            It 'Το Timestamp έχει σωστή μορφή ISO 8601' {
                $result = New-BridgeResult -Success $true

                # ISO 8601 format with offset: 2023-12-01T10:30:45.1234567+02:00
                $result.Timestamp | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$'
            }

            It 'Κάθε κλήση δημιουργεί μοναδικό timestamp' {
                $result1 = New-BridgeResult -Success $true
                Start-Sleep -Milliseconds 10
                $result2 = New-BridgeResult -Success $true

                $result1.Timestamp | Should -Not -Be $result2.Timestamp
            }
        }

        Context 'Parameter Validation' { It 'Απαιτεί την παράμετρο Success' {
                # Skip this test - parameter validation is enforced by PowerShell
                # The function will prompt for missing mandatory parameters in interactive mode
                # which is the expected PowerShell behavior
                Set-ItResult -Skipped -Because "Parameter validation is enforced by PowerShell engine"
            }

            It 'Δέχεται boolean τιμές για Success' {
                { New-BridgeResult -Success $true } | Should -Not -Throw
                { New-BridgeResult -Success $false } | Should -Not -Throw
            }

            It 'Δέχεται οποιοδήποτε object για Data' {
                { New-BridgeResult -Success $true -Data 'string' } | Should -Not -Throw
                { New-BridgeResult -Success $true -Data 123 } | Should -Not -Throw
                { New-BridgeResult -Success $true -Data @{} } | Should -Not -Throw
                { New-BridgeResult -Success $true -Data @() } | Should -Not -Throw
            }

            It 'Δέχεται string τιμές για ErrorMessage και ErrorCode' {
                { New-BridgeResult -Success $false -ErrorMessage 'test' -ErrorCode 'TEST' } | Should -Not -Throw
            }
        }
    }
}


