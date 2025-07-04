Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeErrorCode' {
        Context 'Validation Errors' {
            It 'Returns correct code for BridgeNameEmpty' {
                $result = Get-BridgeErrorCode -Category 'Validation' -Type 'BridgeNameEmpty'
                $result | Should -Be 'VAL-001'
            }

            It 'Returns correct code for ParameterNull' {
                $result = Get-BridgeErrorCode -Category 'Validation' -Type 'ParameterNull'
                $result | Should -Be 'VAL-004'
            }
        }

        Context 'Network Errors' {
            It 'Returns correct code for HttpError' {
                $result = Get-BridgeErrorCode -Category 'Network' -Type 'HttpError'
                $result | Should -Be 'NET-001'
            }

            It 'Returns correct code for InvalidUrl' {
                $result = Get-BridgeErrorCode -Category 'Network' -Type 'InvalidUrl'
                $result | Should -Be 'NET-003'
            }
        }

        Context 'Configuration Errors' {
            It 'Returns correct code for ConfigError' {
                $result = Get-BridgeErrorCode -Category 'Configuration' -Type 'ConfigError'
                $result | Should -Be 'CFG-001'
            }
        }

        Context 'Parsing Errors' {
            It 'Returns correct code for HtmlParseError' {
                $result = Get-BridgeErrorCode -Category 'Parsing' -Type 'HtmlParseError'
                $result | Should -Be 'PAR-002'
            }

            It 'Returns correct code for TimeParseError' {
                $result = Get-BridgeErrorCode -Category 'Parsing' -Type 'TimeParseError'
                $result | Should -Be 'PAR-004'
            }
        }

        Context 'Concurrency Errors' {
            It 'Returns correct code for InstanceExists' {
                $result = Get-BridgeErrorCode -Category 'Concurrency' -Type 'InstanceExists'
                $result | Should -Be 'CON-001'
            }

            It 'Returns correct code for MutexError' {
                $result = Get-BridgeErrorCode -Category 'Concurrency' -Type 'MutexError'
                $result | Should -Be 'CON-003'
            }
        }

        Context 'Sanitization Errors' {
            It 'Returns correct code for InvalidCharacters' {
                $result = Get-BridgeErrorCode -Category 'Sanitization' -Type 'InvalidCharacters'
                $result | Should -Be 'SAN-001'
            }

            It 'Returns correct code for PathTraversal' {
                $result = Get-BridgeErrorCode -Category 'Sanitization' -Type 'PathTraversal'
                $result | Should -Be 'SAN-002'
            }
        }

        Context 'Fallback Behavior' {
            It 'Returns fallback code for unknown type in Validation category' {
                $result = Get-BridgeErrorCode -Category 'Validation' -Type 'UnknownType'
                $result | Should -Be 'VAL-999'
            }

            It 'Returns fallback code for unknown type in Network category' {
                $result = Get-BridgeErrorCode -Category 'Network' -Type 'UnknownType'
                $result | Should -Be 'NET-999'
            }
        }

        Context 'Parameter Validation' {
            It 'Validates Category parameter' {
                { Get-BridgeErrorCode -Category 'InvalidCategory' -Type 'SomeType' } | Should -Throw
            }

            It 'Validates Type parameter is not null or empty' {
                { Get-BridgeErrorCode -Category 'Validation' -Type '' } | Should -Throw
            }
        }
    }
}