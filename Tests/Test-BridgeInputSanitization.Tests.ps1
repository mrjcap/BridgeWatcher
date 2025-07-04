Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Test-BridgeInputSanitization' {
        Context 'URL Validation (MED-007)' {
            It 'Accepts valid HTTPS URLs' {
                $result = Test-BridgeInputSanitization -InputString 'https://www.topvision.gr/dioriga/' -Type 'URL'
                $result.IsValid | Should -Be $true
                $result.SanitizedValue | Should -Be 'https://www.topvision.gr/dioriga/'
                $result.ErrorCode | Should -BeNullOrEmpty
            }

            It 'Accepts valid HTTP URLs' {
                $result = Test-BridgeInputSanitization -InputString 'http://example.com/image.jpg' -Type 'URL'
                $result.IsValid | Should -Be $true
                $result.ErrorCode | Should -BeNullOrEmpty
            }

            It 'Rejects URLs with disallowed schemes' {
                $result = Test-BridgeInputSanitization -InputString 'ftp://example.com/file.txt' -Type 'URL'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'NET-003'
                $result.ErrorMessage | Should -Match 'URL scheme.*not allowed'
            }

            It 'Rejects relative URLs' {
                $result = Test-BridgeInputSanitization -InputString '/relative/path' -Type 'URL'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'NET-003'
                $result.ErrorMessage | Should -Match 'URL must be absolute'
            }

            It 'Rejects malformed URLs' {
                $result = Test-BridgeInputSanitization -InputString 'not-a-url' -Type 'URL'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'NET-003'
                $result.ErrorMessage | Should -Match 'Invalid URL format|URL must be absolute'
            }

            It 'Rejects javascript: URLs' {
                $result = Test-BridgeInputSanitization -InputString 'javascript:alert(1)' -Type 'URL'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'SAN-001'
                $result.ErrorMessage | Should -Match 'dangerous pattern'
            }

            It 'Rejects data: URLs' {
                $result = Test-BridgeInputSanitization -InputString 'data:text/plain,Hello' -Type 'URL'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'SAN-001'
                $result.ErrorMessage | Should -Match 'dangerous pattern'
            }
        }

        Context 'FilePath Validation' {
            It 'Accepts valid Windows file paths' {
                $testPath = 'C:\temp\bridge.json'
                $result = Test-BridgeInputSanitization -InputString $testPath -Type 'FilePath'
                $result.IsValid | Should -Be $true
                $result.SanitizedValue | Should -Not -BeNullOrEmpty
                $result.ErrorCode | Should -BeNullOrEmpty
            }

            It 'Accepts valid Unix file paths' {
                $testPath = '/tmp/bridge.json'
                $result = Test-BridgeInputSanitization -InputString $testPath -Type 'FilePath'
                $result.IsValid | Should -Be $true
                $result.SanitizedValue | Should -Not -BeNullOrEmpty
                $result.ErrorCode | Should -BeNullOrEmpty
            }

            It 'Rejects paths with path traversal attempts' {
                $result = Test-BridgeInputSanitization -InputString '../../../etc/passwd' -Type 'FilePath'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'SAN-001'
                $result.ErrorMessage | Should -Match 'dangerous pattern'
            }

            It 'Rejects paths with null bytes' {
                $result = Test-BridgeInputSanitization -InputString "test`0.txt" -Type 'FilePath'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'SAN-001'
                $result.ErrorMessage | Should -Match 'dangerous pattern'
            }
        }

        Context 'Generic String Validation' {
            It 'Sanitizes generic strings by removing dangerous characters' {
                $result = Test-BridgeInputSanitization -InputString 'Hello <script>alert(1)</script> World' -Type 'Generic'
                $result.IsValid | Should -Be $true
                $result.SanitizedValue | Should -Be 'Hello alert(1)/ World'
                $result.ErrorCode | Should -BeNullOrEmpty
            }

            It 'Removes quotes and special characters' {
                $result = Test-BridgeInputSanitization -InputString 'Text with "quotes" and ''apostrophes''' -Type 'Generic'
                $result.IsValid | Should -Be $true
                $result.SanitizedValue | Should -Be 'Text with quotes and apostrophes'
            }

            It 'Trims whitespace' {
                $result = Test-BridgeInputSanitization -InputString '  Text with spaces  ' -Type 'Generic'
                $result.IsValid | Should -Be $true
                $result.SanitizedValue | Should -Be 'Text with spaces'
            }
        }

        Context 'Empty/Null Input Handling' {
            It 'Rejects empty string when not allowed' {
                $result = Test-BridgeInputSanitization -InputString '' -Type 'URL' -AllowEmpty $false
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'VAL-003'
                $result.ErrorMessage | Should -Match 'cannot be null or empty'
            }

            It 'Accepts empty string when allowed' {
                $result = Test-BridgeInputSanitization -InputString '' -Type 'URL' -AllowEmpty $true
                $result.IsValid | Should -Be $true
                $result.SanitizedValue | Should -Be ''
                $result.ErrorCode | Should -BeNullOrEmpty
            }

            It 'Rejects whitespace-only string when not allowed' {
                $result = Test-BridgeInputSanitization -InputString '   ' -Type 'URL' -AllowEmpty $false
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'VAL-003'
            }
        }

        Context 'Dangerous Pattern Detection' {
            It 'Detects PowerShell subexpressions in URLs' {
                $result = Test-BridgeInputSanitization -InputString 'http://test$(Get-Process).com' -Type 'URL'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'SAN-001'
                $result.ErrorMessage | Should -Match 'dangerous pattern'
            }

            It 'Detects command separators in file paths' {
                $result = Test-BridgeInputSanitization -InputString '/test; rm -rf /' -Type 'FilePath'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'SAN-001'
            }

            It 'Detects pipe operators in URLs' {
                $result = Test-BridgeInputSanitization -InputString 'http://test | dangerous-command.com' -Type 'URL'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'SAN-001'
            }

            It 'Detects eval patterns in file paths' {
                $result = Test-BridgeInputSanitization -InputString '/path/eval(malicious_code)' -Type 'FilePath'
                $result.IsValid | Should -Be $false
                $result.ErrorCode | Should -Be 'SAN-001'
            }
        }

        Context 'Parameter Validation' {
            It 'Validates Type parameter' {
                { Test-BridgeInputSanitization -InputString 'test' -Type 'InvalidType' } | Should -Throw
            }

            It 'Accepts InputString parameter as mandatory' {
                # The InputString parameter is mandatory, so this should work when provided
                $result = Test-BridgeInputSanitization -InputString 'test' -Type 'Generic'
                $result | Should -Not -BeNullOrEmpty
            }
        }
    }
}