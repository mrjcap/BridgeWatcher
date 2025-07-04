Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeHtml Retry and Timeout Tests' {
        BeforeEach {
            Mock Write-BridgeLog {}
            Mock Start-Sleep {}
        }

        Context 'HIGH-002: Retry Logic with Exponential Backoff' {
            It 'Succeeds on first attempt when Invoke-WebRequest works' {
                Mock Invoke-WebRequest {
                    return @{ Content = '<html>Success</html>' }
                }

                $result = Get-BridgeHtml

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Data | Should -Be '<html>Success</html>'
                
                Assert-MockCalled Invoke-WebRequest -Exactly 1
                Assert-MockCalled Start-Sleep -Exactly 0
            }

            It 'Retries with exponential backoff when Invoke-WebRequest fails' {
                $script:attemptCount = 0
                Mock Invoke-WebRequest {
                    $script:attemptCount++
                    if ($script:attemptCount -lt 3) {
                        throw "Network error attempt $script:attemptCount"
                    }
                    return @{ Content = '<html>Success on retry</html>' }
                }

                $result = Get-BridgeHtml

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Data | Should -Be '<html>Success on retry</html>'
                
                Assert-MockCalled Invoke-WebRequest -Exactly 3
                Assert-MockCalled Start-Sleep -Exactly 2
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Message -like '*Προσπάθεια 1/3 απέτυχε*'
                } -Exactly 1
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Message -like '*Προσπάθεια 2/3 απέτυχε*'
                } -Exactly 1
            }

            It 'Returns error after maximum retries are exhausted' {
                Mock Invoke-WebRequest {
                    throw "Persistent network error"
                }

                $result = Get-BridgeHtml

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Persistent network error'
                $result.ErrorCode | Should -Be 'HTTP_ERROR'
                
                Assert-MockCalled Invoke-WebRequest -Exactly 3
                Assert-MockCalled Start-Sleep -Exactly 2
            }

            It 'Uses correct exponential backoff delays' {
                Mock Invoke-WebRequest {
                    throw "Network error"
                }

                $result = Get-BridgeHtml

                # Verify exponential backoff: 1 second, then 2 seconds
                Assert-MockCalled Start-Sleep -ParameterFilter { $Seconds -eq 1 } -Exactly 1
                Assert-MockCalled Start-Sleep -ParameterFilter { $Seconds -eq 2 } -Exactly 1
            }

        }

        Context 'Configuration and URI Handling' {
            It 'Uses configuration SourceUrl when provided' {
                $config = [PSCustomObject]@{
                    SourceUrl = 'https://test.example.com/api'
                }
                Mock Invoke-WebRequest {
                    param($Uri)
                    $Uri | Should -Be 'https://test.example.com/api'
                    return @{ Content = '<html>Config URL</html>' }
                }

                $result = Get-BridgeHtml -Configuration $config

                $result.Success | Should -Be $true
            }

            It 'Uses fallback URL when no configuration provided' {
                Mock Invoke-WebRequest {
                    param($Uri)
                    $Uri | Should -Be 'https://www.topvision.gr/dioriga/'
                    return @{ Content = '<html>Fallback URL</html>' }
                }

                $result = Get-BridgeHtml

                $result.Success | Should -Be $true
            }

            It 'Uses explicit Uri parameter when provided' {
                Mock Invoke-WebRequest {
                    param($Uri)
                    $Uri | Should -Be 'https://explicit.example.com/test'
                    return @{ Content = '<html>Explicit URI</html>' }
                }

                $result = Get-BridgeHtml -Uri 'https://explicit.example.com/test'

                $result.Success | Should -Be $true
            }
        }
    }
}