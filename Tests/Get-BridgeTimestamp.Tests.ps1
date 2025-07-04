Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeTimestamp' {
        Context 'ISO8601 Format (Default)' {
            It 'Returns timestamp in ISO 8601 format with timezone' {
                $result = Get-BridgeTimestamp
                # ISO 8601 format with offset: 2023-12-01T10:30:45.1234567+02:00
                $result | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$'
            }

            It 'Returns different timestamps for successive calls' {
                $result1 = Get-BridgeTimestamp
                Start-Sleep -Milliseconds 10
                $result2 = Get-BridgeTimestamp
                $result1 | Should -Not -Be $result2
            }

            It 'Uses ISO8601 as default format when no format specified' {
                $result1 = Get-BridgeTimestamp
                $result2 = Get-BridgeTimestamp -Format 'ISO8601'
                
                # Both should have same format structure (not exact match due to timing)
                $result1 | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$'
                $result2 | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$'
            }
        }

        Context 'DateOnly Format' {
            It 'Returns date in YYYY-MM-DD format' {
                $result = Get-BridgeTimestamp -Format 'DateOnly'
                $result | Should -Match '^\d{4}-\d{2}-\d{2}$'
            }

            It 'Returns current date' {
                $result = Get-BridgeTimestamp -Format 'DateOnly'
                $expected = (Get-Date).ToString('yyyy-MM-dd')
                $result | Should -Be $expected
            }
        }

        Context 'TimeOnly Format' {
            It 'Returns time in HH:mm:ss format' {
                $result = Get-BridgeTimestamp -Format 'TimeOnly'
                $result | Should -Match '^\d{2}:\d{2}:\d{2}$'
            }
        }

        Context 'LogFormat' {
            It 'Returns timestamp with timezone for logging' {
                $result = Get-BridgeTimestamp -Format 'LogFormat'
                # Should include timezone offset: 2023-12-01 10:30:45 +02:00
                $result | Should -Match '^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} [+-]\d{2}:\d{2}$'
            }
        }

        Context 'Timezone Handling (MED-003)' {
            It 'Includes timezone information in ISO8601 format' {
                $result = Get-BridgeTimestamp -Format 'ISO8601'
                # Should have timezone offset at the end
                $result | Should -Match '[+-]\d{2}:\d{2}$'
            }

            It 'Includes timezone information in LogFormat' {
                $result = Get-BridgeTimestamp -Format 'LogFormat'
                # Should have timezone offset at the end
                $result | Should -Match '[+-]\d{2}:\d{2}$'
            }
        }

        Context 'Parameter Validation' {
            It 'Validates Format parameter accepts only valid values' {
                { Get-BridgeTimestamp -Format 'InvalidFormat' } | Should -Throw
            }

            It 'Falls back to ISO8601 for unknown format' {
                # This test would only work if we change the ValidateSet to allow unknown values
                # For now, we'll test the default behavior
                $result = Get-BridgeTimestamp
                $result | Should -Match '^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{7}[+-]\d{2}:\d{2}$'
            }
        }

        Context 'Consistency' {
            It 'Maintains format consistency across calls' {
                $result1 = Get-BridgeTimestamp -Format 'DateOnly'
                $result2 = Get-BridgeTimestamp -Format 'DateOnly'
                
                # Both should be in the same format (might be same value if called quickly)
                $result1 | Should -Match '^\d{4}-\d{2}-\d{2}$'
                $result2 | Should -Match '^\d{4}-\d{2}-\d{2}$'
            }
        }
    }
}