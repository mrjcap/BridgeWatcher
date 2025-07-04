Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-ConfigurationValue Tests' {
        Context 'Όταν δίνεται έγκυρο Configuration object' {
            BeforeEach {
                $config = New-BridgeConfiguration
            }

            It 'Επιστρέφει την τιμή για simple property' {
                $result = Get-ConfigurationValue -Configuration $config -PropertyPath 'DefaultMaxWaitTimeMinutes' -FallbackValue 99
                $result | Should -Be 12
            }

            It 'Επιστρέφει την τιμή για nested hashtable property' {
                $result = Get-ConfigurationValue -Configuration $config -PropertyPath 'ExportMessages.Success' -FallbackValue 'fallback'
                $result | Should -Be '✅ Επιτυχής εξαγωγή JSON'
            }

            It 'Επιστρέφει fallback για μη υπάρχουσα property' {
                $result = Get-ConfigurationValue -Configuration $config -PropertyPath 'NonExistent.Property' -FallbackValue 'fallback'
                $result | Should -Be 'fallback'
            }

            It 'Επιστρέφει fallback για μερικώς υπάρχουσα property path' {
                $result = Get-ConfigurationValue -Configuration $config -PropertyPath 'ExportMessages.NonExistent' -FallbackValue 'fallback'
                $result | Should -Be 'fallback'
            }
        }

        Context 'Όταν δίνεται null Configuration' {
            It 'Επιστρέφει fallback value' {
                $result = Get-ConfigurationValue -Configuration $null -PropertyPath 'SomeProperty' -FallbackValue 'fallback'
                $result | Should -Be 'fallback'
            }
        }

        Context 'Edge cases' {
            It 'Ρίχνει validation σφάλμα για κενή PropertyPath' {
                $config = New-BridgeConfiguration
                { Get-ConfigurationValue -Configuration $config -PropertyPath '' -FallbackValue 'fallback' } | Should -Throw
            }

            It 'Χειρίζεται null FallbackValue' {
                $config = New-BridgeConfiguration
                $result = Get-ConfigurationValue -Configuration $config -PropertyPath 'NonExistent' -FallbackValue $null
                $result | Should -Be $null
            }
        }
    }

    Describe 'Write-BridgeErrorLog Tests' {
        Context 'Όταν καλείται με Configuration' {
            BeforeEach {
                Mock Write-BridgeLog {}
                Mock New-BridgeResult { return [PSCustomObject]@{ Success = $false; ErrorMessage = $ErrorMessage; ErrorCode = $ErrorCode } }
                $config = New-BridgeConfiguration
            }

            It 'Καλεί Write-BridgeLog με σωστές παραμέτρους' {
                $result = Write-BridgeErrorLog -Configuration $config -ErrorMessage 'Test error' -ErrorCode 'TEST_ERROR'
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter { 
                    $Stage -eq 'Σφάλμα' -and $Message -eq 'Test error' -and $Level -eq 'Warning'
                } -Times 1
            }

            It 'Επιστρέφει BridgeResult object' {
                $result = Write-BridgeErrorLog -Configuration $config -ErrorMessage 'Test error'
                
                Assert-MockCalled New-BridgeResult -ParameterFilter {
                    $Success -eq $false -and $ErrorMessage -eq 'Test error'
                } -Times 1
            }

            It 'Συνδυάζει ErrorMessage με Exception' {
                $exception = [System.Exception]::new('Inner exception')
                $result = Write-BridgeErrorLog -Configuration $config -ErrorMessage 'Outer error' -Exception $exception
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Message -eq 'Outer error: Inner exception'
                } -Times 1
            }
        }

        Context 'Όταν καλείται χωρίς Configuration' {
            BeforeEach {
                Mock Write-BridgeLog {}
                Mock New-BridgeResult { return [PSCustomObject]@{ Success = $false; ErrorMessage = $ErrorMessage; ErrorCode = $ErrorCode } }
            }

            It 'Χρησιμοποιεί fallback values' {
                $result = Write-BridgeErrorLog -ErrorMessage 'Test error'
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and $Level -eq 'Warning'
                } -Times 1
            }
        }
    }
}