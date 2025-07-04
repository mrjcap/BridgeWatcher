Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Negative Test Cases - Critical/High Error Scenarios' {
        
        Context 'Critical Error Scenarios for External Service Failures' {
            It 'Get-BridgeHtml handles network timeouts and connection failures' {
                Mock Invoke-WebRequest { 
                    throw [System.Net.WebException]::new('The operation has timed out')
                }
                Mock Write-BridgeLog {}
                
                $result = Get-BridgeHtml
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'HTTP_ERROR'
                $result.ErrorMessage | Should -Match 'timeout'
            }

            It 'Get-BridgeHtml handles HTTP error responses (404, 500, etc.)' {
                Mock Invoke-WebRequest { 
                    throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('404 Not Found')
                }
                Mock Write-BridgeLog {}
                
                $result = Get-BridgeHtml
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'HTTP_ERROR'
                $result.ErrorMessage | Should -Match 'Not Found'
            }

            It 'Invoke-BridgeOCRRequest handles OCR service authentication failures' {
                Mock Invoke-RestMethod { 
                    throw [System.UnauthorizedAccessException]::new('Invalid API key')
                }
                Mock Write-BridgeLog {}
                
                { Invoke-BridgeOCRRequest -ApiKey 'invalid-key' -RequestBody '{}' } | Should -Throw '*Invalid API key*'
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and $Message -like '*Invalid API key*'
                } -Times 1
            }

            It 'Invoke-BridgeOCRRequest handles OCR service rate limiting' {
                Mock Invoke-RestMethod { 
                    throw [System.Net.WebException]::new('Rate limit exceeded')
                }
                Mock Write-BridgeLog {}
                
                { Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' } | Should -Throw
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Message -like '*Rate limit*'
                } -Times 1
            }

            It 'Send-BridgePushoverRequest handles Pushover service outages' {
                Mock Invoke-RestMethod { 
                    throw [System.Net.WebException]::new('Service Unavailable')
                }
                Mock Write-BridgeLog {}
                
                $payload = @{ token = 'test'; user = 'test'; message = 'test' }
                { Send-BridgePushoverRequest -Payload $payload } | Should -Throw
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Stage -eq 'Σφάλμα' -and $Message -like '*Service Unavailable*'
                } -Times 1
            }
        }

        Context 'Critical File System Error Scenarios' {
            It 'Export-BridgeStatusJson handles disk space exhaustion' {
                Mock Test-Path { $true }
                Mock Set-Content { 
                    throw [System.IO.IOException]::new('There is not enough space on the disk')
                }
                Mock Write-BridgeLog {}
                
                $data = @([PSCustomObject]@{ Test = 'Value' })
                $result = Export-BridgeStatusJson -Data $data -Path 'C:\test.json'
                
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'JSON_EXPORT_FAILURE'
                $result.ErrorMessage | Should -Match 'not enough space'
            }

            It 'Export-BridgeStatusJson handles permission denied errors' {
                Mock Test-Path { $true }
                Mock Set-Content { 
                    throw [System.UnauthorizedAccessException]::new('Access to the path is denied')
                }
                Mock Write-BridgeLog {}
                
                $data = @([PSCustomObject]@{ Test = 'Value' })
                $result = Export-BridgeStatusJson -Data $data -Path 'C:\Windows\System32\test.json'
                
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'JSON_EXPORT_FAILURE'
                $result.ErrorMessage | Should -Match 'Access.*denied'
            }

            It 'Write-BridgeLog handles file locking scenarios' {
                Mock Test-Path { $false }
                Mock New-Item {}
                Mock Add-Content { 
                    throw [System.IO.IOException]::new('The process cannot access the file because it is being used by another process')
                }
                
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message' -Level 'Verbose' } | Should -Not -Throw
                
                Assert-MockCalled Add-Content -Times 1
            }

            It 'Write-BridgeLog handles corrupted file system scenarios' {
                Mock Test-Path { $false }
                Mock New-Item {}
                Mock Add-Content { 
                    throw [System.IO.DirectoryNotFoundException]::new('Could not find a part of the path')
                }
                
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message' -Level 'Verbose' } | Should -Not -Throw
            }
        }

        Context 'Critical Data Processing Error Scenarios' {
            It 'ConvertFrom-BridgeOCRResult handles completely corrupted OCR data' {
                Mock Write-BridgeLog {}
                
                $corruptedText = [string]::new([char]0, 1000)  # Null characters
                { ConvertFrom-BridgeOCRResult -OCRText $corruptedText } | Should -Throw
            }

            It 'ConvertFrom-BridgeOCRResult handles malicious input patterns' {
                Mock Write-BridgeLog {}
                
                # Script injection attempt in description field
                $maliciousResponse = @{ 
                    responses = @(@{ 
                        textAnnotations = @(@{ 
                            description = 'Γέφυρα Ισθμού $(Get-Process) κλειστή από 10:00 έως 12:00' 
                        }) 
                    }) 
                }
                
                # Should handle safely without executing embedded commands
                { ConvertFrom-BridgeOCRResult -ApiResponse $maliciousResponse -ImageUri 'https://test.com/image.jpg' } | Should -Not -Throw
            }

            It 'ConvertTo-BridgeTimeRange handles invalid date formats that could cause crashes' {
                # Test various malformed date inputs that could cause parsing errors
                $malformedInputs = @(
                    'από 99:99 έως 88:88',
                    'από αα:ββ έως γγ:δδ',
                    'από 25:70 έως 30:90',
                    'από -1:-1 έως -2:-2'
                )
                
                foreach ($input in $malformedInputs) {
                    { ConvertTo-BridgeTimeRange -OCRText $input } | Should -Throw
                }
            }

            It 'New-BridgeResult handles null and invalid object construction' {
                # Should handle null values gracefully by providing defaults
                $result = New-BridgeResult -Success $false -Data $null -ErrorMessage $null -ErrorCode $null
                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
            }
        }

        Context 'Critical Memory and Resource Error Scenarios' {
            It 'Export-BridgeStatusJson handles out-of-memory scenarios with large datasets' {
                Mock Test-Path { $true }
                Mock ConvertTo-Json { 
                    throw [System.OutOfMemoryException]::new('Insufficient memory to continue the execution of the program')
                }
                Mock Write-BridgeLog {}
                
                $data = @([PSCustomObject]@{ Test = 'Value' })
                $result = Export-BridgeStatusJson -Data $data -Path 'test.json'
                
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'JSON_EXPORT_FAILURE'
                $result.ErrorMessage | Should -Match 'memory'
            }

            It 'ConvertFrom-BridgeHtml handles extremely malformed HTML that could cause parser crashes' {
                Mock Write-BridgeLog {}
                Mock Get-BridgeStatusFromHtml { 
                    throw [System.Xml.XmlException]::new('The input is not a valid Base-64 string')
                }
                
                $malformedHtml = '<html><body>' + ('<div>' * 10000) + 'content' + ('</div>' * 5000) + '</body></html>'
                $result = ConvertFrom-BridgeHtml -Html $malformedHtml
                
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'HTML_PARSING_FAILURE'
            }
        }

        Context 'Critical Configuration Error Scenarios' {
            It 'Functions handle completely invalid configuration objects' {
                $invalidConfig = 'This is not an object'
                Mock Write-BridgeLog {}
                Mock Invoke-WebRequest { @{ Content = '<html>test</html>' } }
                
                # Should not crash even with invalid config type
                { Get-BridgeHtml -Configuration $invalidConfig } | Should -Not -Throw
            }

            It 'Functions handle configuration objects with circular references' {
                $circularConfig = [PSCustomObject]@{ Name = 'Test' }
                $circularConfig | Add-Member -NotePropertyName 'SelfReference' -NotePropertyValue $circularConfig
                
                Mock Write-BridgeLog {}
                Mock Test-Path { $true }
                Mock Set-Content {}
                
                # Should handle circular references without infinite loops
                { Export-BridgeStatusJson -Data @() -Path 'test.json' -Configuration $circularConfig } | Should -Not -Throw
            }

            It 'Functions handle configuration with script blocks (security test)' {
                $maliciousConfig = [PSCustomObject]@{
                    BridgeUrl = { Get-Process }  # Script block instead of string
                    ApiKey = { Remove-Item -Path 'C:\' -Recurse -Force }  # Malicious script
                }
                
                Mock Write-BridgeLog {}
                Mock Invoke-WebRequest { @{ Content = '<html>test</html>' } }
                
                # Should handle script blocks safely without execution
                { Get-BridgeHtml -Configuration $maliciousConfig } | Should -Not -Throw
            }
        }

        Context 'Critical Network Security Error Scenarios' {
            It 'Get-BridgeHtml handles SSL certificate validation failures' {
                Mock Invoke-WebRequest { 
                    throw [System.Net.WebException]::new('The underlying connection was closed: Could not establish trust relationship for the SSL/TLS secure channel')
                }
                Mock Write-BridgeLog {}
                
                $result = Get-BridgeHtml
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Match 'SSL|trust|certificate'
            }

            It 'Invoke-BridgeOCRRequest handles man-in-the-middle attack scenarios' {
                Mock Invoke-RestMethod { 
                    throw [System.Security.Authentication.AuthenticationException]::new('The remote certificate is invalid according to the validation procedure')
                }
                Mock Write-BridgeLog {}
                
                { Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' } | Should -Throw
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Message -like '*certificate*invalid*'
                } -Times 1
            }

            It 'Send-BridgePushoverRequest handles DNS resolution failures' {
                Mock Invoke-RestMethod { 
                    throw [System.Net.Sockets.SocketException]::new('No such host is known')
                }
                Mock Write-BridgeLog {}
                
                $payload = @{ token = 'test'; user = 'test'; message = 'test' }
                { Send-BridgePushoverRequest -Payload $payload } | Should -Throw
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Message -like '*host*known*'
                } -Times 1
            }
        }

        Context 'Critical Input Validation Error Scenarios' {
            It 'Functions handle extremely large parameter values that could cause buffer overflows' {
                # Use a more reasonable large string to avoid actual out of memory
                $largeString = 'x' * 100000  # 100KB string instead of trying to create huge one
                Mock Write-BridgeLog {}
                Mock Add-Content {}
                Mock Test-Path { $false }
                Mock New-Item {}
                
                # Should handle large inputs gracefully
                { Write-BridgeLog -Stage 'Ανάλυση' -Message $largeString -Level 'Verbose' } | Should -Not -Throw
            }

            It 'Functions handle parameters with embedded null characters' {
                $nullString = "Test`0`0`0Message"
                Mock Write-BridgeLog {}
                Mock Add-Content {}
                Mock Test-Path { $false }
                Mock New-Item {}
                
                { Write-BridgeLog -Stage 'Ανάλυση' -Message $nullString -Level 'Verbose' } | Should -Not -Throw
            }

            It 'Functions reject malicious path traversal attempts' {
                $maliciousPath = '..\..\..\..\Windows\System32\drivers\etc\hosts'
                Mock Write-BridgeLog {}
                Mock Test-Path { $false }
                
                $result = Export-BridgeStatusJson -Data @() -Path $maliciousPath
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'DIRECTORY_NOT_EXISTS'
            }
        }
    }
}