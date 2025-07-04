Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Boundary & Load Tests - Edge Cases and Large Data Volumes' {
        
        Context 'Export-BridgeStatusJson Boundary Tests' {
            BeforeEach {
                Mock Write-BridgeLog {}
                Mock Test-Path { $true }
                Mock Set-Content {}
            }

            It 'Handles empty data array (boundary case)' {
                $result = Export-BridgeStatusJson -Data @() -Path 'test.json'
                $result.Success | Should -Be $true
                $result.Data.RecordCount | Should -Be 0
            }

            It 'Handles single item (minimum boundary)' {
                $data = @([PSCustomObject]@{ Name = 'Test'; Status = 'Open' })
                $result = Export-BridgeStatusJson -Data $data -Path 'test.json'
                $result.Success | Should -Be $true
                $result.Data.RecordCount | Should -Be 1
            }

            It 'Handles large volume of data (1000 bridge records)' {
                $largeData = @()
                1..1000 | ForEach-Object {
                    $largeData += [PSCustomObject]@{
                        Bridge = "Γέφυρα$_"
                        Status = if ($_ % 2) { 'Ανοιχτή' } else { 'Κλειστή' }
                        Timestamp = (Get-Date).AddMinutes(-$_)
                        OpenTime = "$(Get-Random -Minimum 10 -Maximum 23):$(Get-Random -Minimum 0 -Maximum 59)"
                        CloseTime = "$(Get-Random -Minimum 10 -Maximum 23):$(Get-Random -Minimum 0 -Maximum 59)"
                        Duration = "$(Get-Random -Minimum 1 -Maximum 120) λεπτά"
                        ImagePath = "https://example.com/image$_.jpg"
                    }
                }
                
                $result = Export-BridgeStatusJson -Data $largeData -Path 'large_test.json'
                $result.Success | Should -Be $true
                $result.Data.RecordCount | Should -Be 1000
            }

            It 'Handles very deep nested objects (depth boundary test)' {
                $deepObject = @{
                    Level1 = @{
                        Level2 = @{
                            Level3 = @{
                                Level4 = @{
                                    Level5 = @{
                                        Level6 = @{
                                            Level7 = @{
                                                Level8 = @{
                                                    Level9 = @{
                                                        Level10 = 'Deep nested value'
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                $result = Export-BridgeStatusJson -Data @($deepObject) -Path 'deep_test.json' -JsonDepth 15
                $result.Success | Should -Be $true
                $result.Data.RecordCount | Should -Be 1
            }

            It 'Handles extremely long file paths (boundary test)' {
                $longPath = 'C:\' + ('a' * 200) + '\' + ('b' * 200) + '\test.json'
                Mock Test-Path { $false } -ParameterFilter { $Path -like "*$('a' * 200)*" }
                
                $result = Export-BridgeStatusJson -Data @([PSCustomObject]@{ Test = 'Value' }) -Path $longPath
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'DIRECTORY_NOT_EXISTS'
            }
        }

        Context 'ConvertFrom-BridgeOCRResult Boundary Tests' {
            It 'Handles empty OCR response (boundary case)' {
                Mock Write-BridgeLog {}
                $emptyResponse = @{ responses = @() }
                { ConvertFrom-BridgeOCRResult -ApiResponse $emptyResponse -ImageUri 'https://test.com/image.jpg' } | Should -Throw
            }

            It 'Handles response with no text annotations' {
                Mock Write-BridgeLog {}
                $responseWithoutText = @{ responses = @(@{ }) }
                { ConvertFrom-BridgeOCRResult -ApiResponse $responseWithoutText -ImageUri 'https://test.com/image.jpg' } | Should -Throw
            }

            It 'Handles malformed OCR response structure' {
                Mock Write-BridgeLog {}
                $malformedResponse = @{ invalid = 'structure' }
                { ConvertFrom-BridgeOCRResult -ApiResponse $malformedResponse -ImageUri 'https://test.com/image.jpg' } | Should -Throw
            }

            It 'Handles very long URI paths (boundary test)' {
                # This test verifies the function can handle long URIs without crashing
                # We'll expect an exception since the OCR text doesn't contain valid bridge info
                Mock Write-BridgeLog {}
                $longUri = 'https://example.com/' + ('a' * 1000) + '/image.jpg'
                $validResponse = @{ responses = @(@{ textAnnotations = @(@{ description = 'No bridge information here' }) }) }
                
                # Should handle the long URI but fail due to no valid bridge data
                { ConvertFrom-BridgeOCRResult -ApiResponse $validResponse -ImageUri $longUri } | Should -Throw
            }
        }

        Context 'Get-BridgeHtml Load Tests' {
            It 'Handles multiple rapid sequential calls (stress test)' {
                Mock Invoke-WebRequest { 
                    @{ Content = '<html><body>Test content</body></html>' }
                }
                
                $results = @()
                1..10 | ForEach-Object {
                    $results += Get-BridgeHtml
                }
                
                $results.Count | Should -Be 10
                $results | ForEach-Object { $_.Success | Should -Be $true }
                Assert-MockCalled Invoke-WebRequest -Times 10
            }

            It 'Handles very large HTML response (boundary test)' {
                $largeHtml = '<html><body>' + ('Large content ' * 10000) + '</body></html>'
                Mock Invoke-WebRequest { 
                    @{ Content = $largeHtml }
                }
                
                $result = Get-BridgeHtml
                $result.Success | Should -Be $true
                $result.Data.Length | Should -BeGreaterThan 100000
            }
        }

        Context 'Memory and Performance Boundary Tests' {
            It 'ConvertTo-BridgeClosedDuration handles maximum TimeSpan values' {
                $maxTimeSpan = [TimeSpan]::new(365, 23, 59, 59, 999)  # Max practical timespan
                
                $result = ConvertTo-BridgeClosedDuration -Duration $maxTimeSpan
                $result | Should -Match 'ημέρες'
                $result | Should -Not -BeNullOrEmpty
            }

            It 'ConvertTo-BridgeClosedDuration handles minimum positive TimeSpan' {
                $minTimeSpan = [TimeSpan]::new(0, 1, 0)  # 1 minute  
                
                $result = ConvertTo-BridgeClosedDuration -Duration $minTimeSpan
                $result | Should -Not -BeNullOrEmpty
                $result | Should -Match 'λεπτό'
            }

            It 'Write-BridgeLog handles very long messages (boundary test)' {
                Mock Add-Content {}
                Mock New-Item {}
                Mock Test-Path { $false }
                
                $longMessage = 'Test message ' * 1000  # Very long message
                
                { Write-BridgeLog -Stage 'Ανάλυση' -Message $longMessage -Level 'Verbose' } | Should -Not -Throw
                Assert-MockCalled Add-Content -Times 1
            }
        }

        Context 'Configuration Boundary Tests' {
            It 'Handles null configuration gracefully in all functions' {
                Mock Invoke-WebRequest { @{ Content = '<html>test</html>' } }
                Mock Write-BridgeLog {}
                Mock Test-Path { $true }
                Mock Set-Content {}
                
                # Test multiple functions with null configuration
                $htmlResult = Get-BridgeHtml -Configuration $null
                $htmlResult.Success | Should -Be $true
                
                $exportResult = Export-BridgeStatusJson -Data @() -Path 'test.json' -Configuration $null
                $exportResult.Success | Should -Be $true
            }

            It 'Handles configuration with missing required properties' {
                $incompleteConfig = [PSCustomObject]@{
                    # Missing most properties
                    SomeRandomProperty = 'value'
                }
                
                Mock Invoke-WebRequest { @{ Content = '<html>test</html>' } }
                Mock Write-BridgeLog {}
                
                { Get-BridgeHtml -Configuration $incompleteConfig } | Should -Not -Throw
            }
        }
    }
}