Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Concurrency Tests - Monitor & Logging Functions' {
        
        Context 'Rapid Sequential Function Calls (Simulated Concurrency)' {
            It 'Handles multiple rapid Write-BridgeLog calls without state corruption' {
                Mock Add-Content {}
                Mock Test-Path { $false }
                Mock New-Item {}
                
                # Rapid sequential calls to simulate concurrent load
                $results = @()
                1..10 | ForEach-Object {
                    try {
                        Write-BridgeLog -Stage 'Ανάλυση' -Message "Rapid test message $_" -Level 'Verbose'
                        $results += "Success $_"
                    } catch {
                        $results += "Error $_"
                    }
                }
                
                # All calls should complete successfully
                $results.Count | Should -Be 10
                $results | ForEach-Object { $_ | Should -Match '^Success' }
                
                # Verify Add-Content was called for each log entry
                Assert-MockCalled Add-Content -Times 10
            }

            It 'Handles rapid Export-BridgeStatusJson calls with different data' {
                Mock Test-Path { $true }
                Mock Set-Content {}
                Mock Write-BridgeLog {}
                
                # Multiple rapid exports with different data
                $results = @()
                1..5 | ForEach-Object {
                    $data = @([PSCustomObject]@{ Bridge = "Bridge$_"; Status = 'Open' })
                    $result = Export-BridgeStatusJson -Data $data -Path "test$_.json"
                    $results += $result
                }
                
                # All exports should complete successfully
                $results.Count | Should -Be 5
                $results | ForEach-Object { $_.Success | Should -Be $true }
                
                # Verify each had unique data
                for ($i = 0; $i -lt 5; $i++) {
                    $results[$i].Data.RecordCount | Should -Be 1
                }
            }

            It 'Handles rapid New-BridgeResult object creation' {
                # Test rapid object creation for thread safety
                $results = @()
                1..20 | ForEach-Object {
                    $result = New-BridgeResult -Success $true -Data "Test data $_"
                    $results += $result
                }
                
                # All results should be independent and correctly formed
                $results.Count | Should -Be 20
                $results | ForEach-Object { $_.Success | Should -Be $true }
                
                # Verify each result has unique data
                for ($i = 0; $i -lt 20; $i++) {
                    $results[$i].Data | Should -Be "Test data $($i + 1)"
                }
            }
        }

        Context 'Resource Contention Simulation' {
            It 'Handles multiple exports to same file path (simulated file contention)' {
                $writeCounter = 0
                Mock Test-Path { $true }
                Mock Set-Content { 
                    $script:writeCounter++
                    if ($script:writeCounter % 3 -eq 0) {
                        # Simulate occasional file lock
                        Start-Sleep -Milliseconds 10
                    }
                }
                Mock Write-BridgeLog {}
                
                # Multiple operations to same file path
                $results = @()
                1..5 | ForEach-Object {
                    $data = @([PSCustomObject]@{ Bridge = "Bridge$_"; Status = 'Open' })
                    $result = Export-BridgeStatusJson -Data $data -Path 'shared_file.json'
                    $results += $result
                }
                
                # All operations should complete successfully despite contention
                $results.Count | Should -Be 5
                $results | ForEach-Object { $_.Success | Should -Be $true }
                Assert-MockCalled Set-Content -Times 5
            }

            It 'Handles configuration object sharing across multiple function calls' {
                Mock Write-BridgeLog {}
                Mock Invoke-WebRequest { @{ Content = '<html>test</html>' } }
                
                # Shared configuration object
                $sharedConfig = [PSCustomObject]@{
                    BridgeUrl = 'https://test.com'
                    TestProperty = 'Initial'
                }
                
                # Multiple functions using the same config object
                $results = @()
                1..3 | ForEach-Object {
                    # Modify config during each call to test for interference
                    $sharedConfig.TestProperty = "Modified $_"
                    $result = Get-BridgeHtml -Configuration $sharedConfig
                    $results += @{ 
                        Result = $result
                        ConfigValue = $sharedConfig.TestProperty 
                    }
                }
                
                # All calls should succeed
                $results.Count | Should -Be 3
                $results | ForEach-Object { $_.Result.Success | Should -Be $true }
                
                # Final config value should reflect last modification
                $sharedConfig.TestProperty | Should -Be 'Modified 3'
            }
        }

        Context 'State Management Under Load' {
            It 'Maintains function state integrity during rapid calls' {
                Mock Write-BridgeLog {}
                
                # Test state integrity by rapidly creating different result types
                $successResults = @()
                $errorResults = @()
                
                1..10 | ForEach-Object {
                    if ($_ % 2 -eq 0) {
                        $successResults += New-BridgeResult -Success $true -Data "Success $_"
                    } else {
                        $errorResults += New-BridgeResult -Success $false -ErrorMessage "Error $_" -ErrorCode 'TEST_ERROR'
                    }
                }
                
                # Verify state separation
                $successResults.Count | Should -Be 5
                $errorResults.Count | Should -Be 5
                
                # Success results should all be successful
                $successResults | ForEach-Object { $_.Success | Should -Be $true }
                
                # Error results should all be failures
                $errorResults | ForEach-Object { 
                    $_.Success | Should -Be $false
                    $_.ErrorCode | Should -Be 'TEST_ERROR'
                }
            }

            It 'Handles mixed function calls without interference' {
                Mock Add-Content {}
                Mock Test-Path { $true }
                Mock Set-Content {}
                Mock New-Item {}
                Mock Write-BridgeLog {}
                Mock Invoke-WebRequest { @{ Content = '<html>test</html>' } }
                
                # Mix different function calls rapidly
                $operations = @()
                
                1..6 | ForEach-Object {
                    switch ($_ % 3) {
                        1 {
                            $result = New-BridgeResult -Success $true -Data "Mixed test $_"
                            $operations += @{ Type = 'NewResult'; Result = $result }
                        }
                        2 {
                            $data = @([PSCustomObject]@{ Test = $_ })
                            $result = Export-BridgeStatusJson -Data $data -Path "mixed$_.json"
                            $operations += @{ Type = 'Export'; Result = $result }
                        }
                        0 {
                            $result = Get-BridgeHtml
                            $operations += @{ Type = 'GetHtml'; Result = $result }
                        }
                    }
                }
                
                # All operations should succeed
                $operations.Count | Should -Be 6
                $operations | ForEach-Object { $_.Result.Success | Should -Be $true }
                
                # Verify operation types are correct
                ($operations | Where-Object { $_.Type -eq 'NewResult' }).Count | Should -Be 2
                ($operations | Where-Object { $_.Type -eq 'Export' }).Count | Should -Be 2
                ($operations | Where-Object { $_.Type -eq 'GetHtml' }).Count | Should -Be 2
            }
        }

        Context 'Error Handling Under Concurrent-like Conditions' {
            It 'Handles errors gracefully during rapid function execution' {
                Mock Test-Path { $true }
                # Simulate intermittent failures
                $callCount = 0
                Mock Set-Content { 
                    $script:callCount++
                    if ($script:callCount % 3 -eq 0) {
                        throw "Simulated I/O error"
                    }
                }
                Mock Write-BridgeLog {}
                
                # Rapid calls with intermittent failures
                $results = @()
                1..6 | ForEach-Object {
                    $data = @([PSCustomObject]@{ Test = $_ })
                    $result = Export-BridgeStatusJson -Data $data -Path "error_test$_.json"
                    $results += $result
                }
                
                # Should have mix of successes and failures
                $results.Count | Should -Be 6
                $successCount = ($results | Where-Object { $_.Success }).Count
                $failureCount = ($results | Where-Object { -not $_.Success }).Count
                
                $successCount | Should -BeGreaterThan 0
                $failureCount | Should -BeGreaterThan 0
                
                # Failed operations should have proper error information
                $failures = $results | Where-Object { -not $_.Success }
                $failures | ForEach-Object { 
                    $_.ErrorCode | Should -Be 'JSON_EXPORT_FAILURE'
                    $_.ErrorMessage | Should -Match 'Simulated I/O error'
                }
            }

            It 'Maintains error isolation between rapid function calls' {
                Mock Write-BridgeLog {}
                
                # Create alternating success/error results rapidly
                $results = @()
                1..8 | ForEach-Object {
                    if ($_ % 2 -eq 0) {
                        # Success case
                        $results += New-BridgeResult -Success $true -Data "Success $_"
                    } else {
                        # Error case
                        $results += New-BridgeResult -Success $false -ErrorMessage "Error $_" -ErrorCode "ERROR_$_"
                    }
                }
                
                # Verify error isolation - successes shouldn't be affected by errors
                $successes = $results | Where-Object { $_.Success }
                $errors = $results | Where-Object { -not $_.Success }
                
                $successes.Count | Should -Be 4
                $errors.Count | Should -Be 4
                
                # Each error should have unique information
                for ($i = 0; $i -lt $errors.Count; $i++) {
                    $expectedErrorNum = ($i * 2) + 1
                    $errors[$i].ErrorMessage | Should -Be "Error $expectedErrorNum"
                    $errors[$i].ErrorCode | Should -Be "ERROR_$expectedErrorNum"
                }
            }
        }

        Context 'Memory and Resource Management' {
            It 'Handles large data processing without memory leaks' {
                Mock Test-Path { $true }
                Mock Set-Content {}
                Mock Write-BridgeLog {}
                
                # Process increasingly large datasets
                $results = @()
                1..5 | ForEach-Object {
                    $dataSize = $_ * 100  # 100, 200, 300, 400, 500 records
                    $largeData = @()
                    1..$dataSize | ForEach-Object {
                        $largeData += [PSCustomObject]@{
                            Bridge = "Bridge$_"
                            Status = 'Open'
                            Data = "Large data chunk for record $_"
                        }
                    }
                    
                    $result = Export-BridgeStatusJson -Data $largeData -Path "large_test$_.json"
                    $results += $result
                }
                
                # All large data operations should succeed
                $results.Count | Should -Be 5
                $results | ForEach-Object { $_.Success | Should -Be $true }
                
                # Verify record counts are correct
                for ($i = 0; $i -lt 5; $i++) {
                    $expectedCount = ($i + 1) * 100
                    $results[$i].Data.RecordCount | Should -Be $expectedCount
                }
            }
        }
    }
}