Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Enhanced Mock External Services - Web/OCR Calls' {
        
        Context 'Advanced Web Service Mocking' {
            It 'Mocks web requests with realistic response delays' {
                Mock Invoke-WebRequest { 
                    Start-Sleep -Milliseconds (Get-Random -Minimum 100 -Maximum 500)  # Realistic network delay
                    return @{ 
                        Content = '<html><body>Bridge status data</body></html>'
                        StatusCode = 200
                        Headers = @{ 'Content-Type' = 'text/html' }
                    }
                }
                Mock Write-BridgeLog {}
                
                $result = Get-BridgeHtml
                $result.Success | Should -Be $true
                $result.Data | Should -Match 'Bridge status data'
                
                Assert-MockCalled Invoke-WebRequest -Times 1 -Exactly
            }

            It 'Mocks web requests with different HTTP status codes' {
                $statusCodes = @(200, 404, 500, 503)
                $results = @()
                
                foreach ($status in $statusCodes) {
                    Mock Invoke-WebRequest { 
                        if ($status -eq 200) {
                            return @{ Content = '<html>Success</html>'; StatusCode = $status }
                        } else {
                            throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("HTTP $status Error")
                        }
                    }
                    Mock Write-BridgeLog {}
                    
                    $result = Get-BridgeHtml
                    $results += @{ StatusCode = $status; Success = $result.Success }
                }
                
                # Only 200 should succeed
                ($results | Where-Object { $_.StatusCode -eq 200 }).Success | Should -Be $true
                ($results | Where-Object { $_.StatusCode -ne 200 }) | ForEach-Object { $_.Success | Should -Be $false }
            }

            It 'Mocks web requests with various response sizes' {
                $sizes = @(100, 1000, 10000, 100000)  # Different content sizes
                
                foreach ($size in $sizes) {
                    $content = '<html><body>' + ('x' * $size) + '</body></html>'
                    Mock Invoke-WebRequest { 
                        return @{ Content = $content }
                    }
                    Mock Write-BridgeLog {}
                    
                    $result = Get-BridgeHtml
                    $result.Success | Should -Be $true
                    $result.Data.Length | Should -BeGreaterThan $size
                }
            }

            It 'Mocks web requests with realistic headers and metadata' {
                Mock Invoke-WebRequest { 
                    return @{ 
                        Content = '<html><body>Bridge status</body></html>'
                        StatusCode = 200
                        Headers = @{
                            'Content-Type' = 'text/html; charset=utf-8'
                            'Server' = 'nginx/1.18.0'
                            'Date' = (Get-Date).ToString('r')
                            'Content-Length' = '45'
                        }
                        ResponseUri = 'https://example.com/bridge-status'
                    }
                }
                Mock Write-BridgeLog {}
                
                $result = Get-BridgeHtml
                $result.Success | Should -Be $true
                Assert-MockCalled Invoke-WebRequest -Times 1
            }
        }

        Context 'Advanced OCR Service Mocking' {
            It 'Mocks OCR requests with realistic API responses' {
                Mock Invoke-RestMethod { 
                    return @{
                        responses = @(
                            @{
                                textAnnotations = @(
                                    @{
                                        description = "Γέφυρα Ισθμού κλειστή από 10:00 έως 12:00"
                                        boundingPoly = @{
                                            vertices = @(
                                                @{ x = 100; y = 100 },
                                                @{ x = 400; y = 100 },
                                                @{ x = 400; y = 150 },
                                                @{ x = 100; y = 150 }
                                            )
                                        }
                                    }
                                )
                                fullTextAnnotation = @{
                                    pages = @(
                                        @{
                                            property = @{
                                                detectedLanguages = @(
                                                    @{ languageCode = 'el'; confidence = 0.95 }
                                                )
                                            }
                                        }
                                    )
                                }
                            }
                        )
                    }
                }
                Mock Write-BridgeLog {}
                
                $result = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}'
                $result | Should -Not -BeNullOrEmpty
                Assert-MockCalled Invoke-RestMethod -Times 1
            }

            It 'Mocks OCR requests with different confidence levels' {
                $confidenceLevels = @(0.95, 0.85, 0.75, 0.60)
                
                foreach ($confidence in $confidenceLevels) {
                    Mock Invoke-RestMethod { 
                        return @{
                            responses = @(
                                @{
                                    textAnnotations = @(
                                        @{
                                            description = "Γέφυρα Ισθμού ανοιχτή"
                                            confidence = $confidence
                                        }
                                    )
                                }
                            )
                        }
                    }
                    Mock Write-BridgeLog {}
                    
                    $result = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}'
                    $result | Should -Not -BeNullOrEmpty
                }
            }

            It 'Mocks OCR requests with multiple text regions' {
                Mock Invoke-RestMethod { 
                    return @{
                        responses = @(
                            @{
                                textAnnotations = @(
                                    @{ description = "Γέφυρα Ισθμού" },
                                    @{ description = "κλειστή" },
                                    @{ description = "από 10:00" },
                                    @{ description = "έως 12:00" },
                                    @{ description = "Λόγω εργασιών συντήρησης" }
                                )
                            }
                        )
                    }
                }
                Mock Write-BridgeLog {}
                
                $result = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}'
                $result | Should -Not -BeNullOrEmpty
                Assert-MockCalled Invoke-RestMethod -Times 1
            }

            It 'Mocks OCR requests with API rate limiting simulation' {
                $callCount = 0
                Mock Invoke-RestMethod { 
                    $script:callCount++
                    if ($script:callCount -eq 3) {
                        throw [System.Net.WebException]::new('Rate limit exceeded')
                    }
                    return @{
                        responses = @(
                            @{
                                textAnnotations = @(
                                    @{ description = "Γέφυρα Ισθμού ανοιχτή" }
                                )
                            }
                        )
                    }
                }
                Mock Write-BridgeLog {}
                
                # First two calls should succeed
                $result1 = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}'
                $result1 | Should -Not -BeNullOrEmpty
                
                $result2 = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}'
                $result2 | Should -Not -BeNullOrEmpty
                
                # Third call should fail due to rate limiting
                { Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}' } | Should -Throw '*Rate limit*'
            }
        }

        Context 'Advanced Pushover Service Mocking' {
            It 'Mocks Pushover requests with realistic API responses' {
                Mock Invoke-RestMethod { 
                    return @{
                        status = 1
                        request = [System.Guid]::NewGuid().ToString()
                        user = 'test-user-id'
                        device = 'test-device'
                        receipt = 'receipt-id-12345'
                    }
                }
                Mock Write-BridgeLog {}
                
                $payload = @{ token = 'test-token'; user = 'test-user'; message = 'Test message' }
                $result = Send-BridgePushoverRequest -Payload $payload
                
                $result.status | Should -Be 1
                $result.request | Should -Not -BeNullOrEmpty
                Assert-MockCalled Invoke-RestMethod -Times 1
            }

            It 'Mocks Pushover requests with different priority levels' {
                $priorities = @(-1, 0, 1, 2)  # Quiet, Normal, High, Emergency
                
                foreach ($priority in $priorities) {
                    Mock Invoke-RestMethod { 
                        $response = @{
                            status = 1
                            request = [System.Guid]::NewGuid().ToString()
                        }
                        
                        if ($priority -eq 2) {
                            $response.receipt = 'emergency-receipt-' + [System.Guid]::NewGuid().ToString()
                        }
                        
                        return $response
                    }
                    Mock Write-BridgeLog {}
                    
                    $payload = @{ 
                        token = 'test-token'
                        user = 'test-user'
                        message = 'Priority test message'
                        priority = $priority
                    }
                    
                    $result = Send-BridgePushoverRequest -Payload $payload
                    $result.status | Should -Be 1
                    
                    if ($priority -eq 2) {
                        $result.receipt | Should -Not -BeNullOrEmpty
                    }
                }
            }

            It 'Mocks Pushover requests with API error responses' {
                $errorScenarios = @(
                    @{ ErrorCode = 400; Message = 'Invalid token' },
                    @{ ErrorCode = 403; Message = 'User not found' },
                    @{ ErrorCode = 429; Message = 'Rate limit exceeded' },
                    @{ ErrorCode = 500; Message = 'Internal server error' }
                )
                
                foreach ($scenario in $errorScenarios) {
                    Mock Invoke-RestMethod { 
                        throw [Microsoft.PowerShell.Commands.HttpResponseException]::new("$($scenario.ErrorCode) $($scenario.Message)")
                    }
                    Mock Write-BridgeLog {}
                    
                    $payload = @{ token = 'test-token'; user = 'test-user'; message = 'Error test message' }
                    { Send-BridgePushoverRequest -Payload $payload } | Should -Throw "*$($scenario.Message)*"
                }
            }

            It 'Mocks Pushover requests with network timeout simulation' {
                Mock Invoke-RestMethod { 
                    Start-Sleep -Seconds 1  # Simulate slow response
                    throw [System.Net.WebException]::new('The operation has timed out')
                }
                Mock Write-BridgeLog {}
                
                $payload = @{ token = 'test-token'; user = 'test-user'; message = 'Timeout test message' }
                { Send-BridgePushoverRequest -Payload $payload } | Should -Throw '*timed out*'
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Message -like '*timed out*'
                } -Times 1
            }
        }

        Context 'Mock Service Integration Tests' {
            It 'Mocks complete service chain: Web -> OCR -> Pushover' {
                # Mock web request
                Mock Invoke-WebRequest { 
                    return @{ Content = '<html><body>Bridge status page</body></html>' }
                }
                
                # Mock OCR request
                Mock Invoke-RestMethod { 
                    param($Uri, $Method, $Body, $Headers)
                    
                    if ($Uri -like '*vision.googleapis.com*') {
                        # OCR API call
                        return @{
                            responses = @(
                                @{
                                    textAnnotations = @(
                                        @{ description = "Γέφυρα Ισθμού κλειστή από 14:00 έως 16:00" }
                                    )
                                }
                            )
                        }
                    } elseif ($Uri -like '*pushover.net*') {
                        # Pushover API call
                        return @{
                            status = 1
                            request = 'mock-request-id'
                        }
                    }
                }
                
                Mock Write-BridgeLog {}
                Mock Test-Path { $true }
                Mock Set-Content {}
                
                # Test the complete chain
                $htmlResult = Get-BridgeHtml
                $htmlResult.Success | Should -Be $true
                
                $ocrResult = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}'
                $ocrResult | Should -Not -BeNullOrEmpty
                
                $pushoverPayload = @{ token = 'test'; user = 'test'; message = 'Test notification' }
                $pushoverResult = Send-BridgePushoverRequest -Payload $pushoverPayload
                $pushoverResult.status | Should -Be 1
                
                # Verify all mocks were called
                Assert-MockCalled Invoke-WebRequest -Times 1
                Assert-MockCalled Invoke-RestMethod -Times 2  # OCR + Pushover
            }

            It 'Mocks service chain with realistic error propagation' {
                # Mock web request failure
                Mock Invoke-WebRequest { 
                    throw [System.Net.WebException]::new('Network unreachable')
                }
                Mock Write-BridgeLog {}
                
                # Web failure should stop the chain
                $htmlResult = Get-BridgeHtml
                $htmlResult.Success | Should -Be $false
                $htmlResult.ErrorMessage | Should -Match 'Network unreachable'
                
                # Mock OCR failure (even if web succeeds)
                Mock Invoke-WebRequest { 
                    return @{ Content = '<html>Success</html>' }
                }
                Mock Invoke-RestMethod { 
                    throw [System.UnauthorizedAccessException]::new('Invalid API key')
                }
                
                # OCR failure should be handled gracefully
                { Invoke-BridgeOCRRequest -ApiKey 'invalid-key' -RequestBody '{}' } | Should -Throw '*Invalid API key*'
                
                Assert-MockCalled Write-BridgeLog -ParameterFilter {
                    $Message -like '*Invalid API key*'
                } -AtLeast 1
            }

            It 'Mocks service responses with realistic data volumes' {
                # Mock large HTML response
                $largeHtml = '<html><body>' + ('Bridge data ' * 1000) + '</body></html>'
                Mock Invoke-WebRequest { 
                    return @{ Content = $largeHtml }
                }
                
                # Mock large OCR response
                Mock Invoke-RestMethod { 
                    $textAnnotations = @()
                    1..50 | ForEach-Object {
                        $textAnnotations += @{ description = "Text chunk $_" }
                    }
                    
                    return @{
                        responses = @(
                            @{ textAnnotations = $textAnnotations }
                        )
                    }
                }
                
                Mock Write-BridgeLog {}
                
                # Test handling of large responses
                $htmlResult = Get-BridgeHtml
                $htmlResult.Success | Should -Be $true
                $htmlResult.Data.Length | Should -BeGreaterThan 10000
                
                $ocrResult = Invoke-BridgeOCRRequest -ApiKey 'test-key' -RequestBody '{}'
                $ocrResult | Should -Not -BeNullOrEmpty
                
                Assert-MockCalled Invoke-WebRequest -Times 1
                Assert-MockCalled Invoke-RestMethod -Times 1
            }
        }
    }
}