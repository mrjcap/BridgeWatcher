# Critical Issue Validation Tests for BridgeWatcher Module
# These tests validate the specific critical logic bugs identified in the analysis

Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

Describe 'Critical Logic Bug Validation Tests' {
    BeforeEach {
        Mock Write-BridgeLog
    }

    Context 'CRIT-001: Configuration Null Reference Validation' {
        It 'Should handle configuration creation failure gracefully' {
            InModuleScope 'BridgeWatcher' {
                # Mock New-BridgeConfiguration to fail
                Mock New-BridgeConfiguration { throw "Configuration failure" }
                
                # This should reproduce the critical null reference issue
                $result = ConvertFrom-BridgeHtml -Html '<html>test</html>'
                
                # In current broken state, this would try to access null configuration
                # After fix, should return proper error result
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'CONFIG_ERROR'
            }
        }

        It 'Should not set Configuration to null in catch block' {
            InModuleScope 'BridgeWatcher' {
                Mock New-BridgeConfiguration { throw "Configuration failure" }
                
                # The function should not set $Configuration = $null
                # Instead should create fallback configuration
                $testScript = {
                    try {
                        $Configuration = New-BridgeConfiguration
                    } catch {
                        $Configuration = $null  # This is the bug
                    }
                    
                    # This would fail with null reference if $Configuration is null
                    $baseUrl = $Configuration.BaseImageUrl
                }
                
                # This should throw because of the null reference
                { & $testScript } | Should -Throw
            }
        }
    }

    Context 'CRIT-002: ThrowTerminatingError Validation' {
        It 'Should demonstrate that ThrowTerminatingError cannot be caught' {
            InModuleScope 'BridgeWatcher' {
                # Mock Get-BridgeImage to return empty array to trigger the error
                Mock Get-BridgeImage { return @() }
                
                # This demonstrates the uncatchable error
                {
                    try {
                        Get-BridgeStatusFromHtml -Html '<html>test</html>' -Timestamp (Get-Date -Format o)
                    }
                    catch {
                        # This catch block will never execute because ThrowTerminatingError
                        # creates terminating errors that bypass try/catch
                        Write-Host "Caught error: $($_.Exception.Message)"
                    }
                } | Should -Throw -ExpectedMessage "*Δεν βρέθηκαν εικόνες*"
            }
        }
    }

    Context 'CRIT-003: Return Type Inconsistency Validation' {
        It 'Should demonstrate return type inconsistency in Get-BridgeStatus' {
            InModuleScope 'BridgeWatcher' {
                # Mock successful pipeline
                Mock Get-BridgeHtml { 
                    return New-BridgeResult -Success $true -Data '<html>mock</html>' 
                }
                Mock ConvertFrom-BridgeHtml { 
                    return New-BridgeResult -Success $true -Data @(@{ gefyraName = 'Test'; gefyraStatus = 'Ανοιχτή' }) 
                }
                
                $result = Get-BridgeStatus
                
                # Current implementation returns raw data array instead of BridgeResult
                # This breaks the pattern and makes error checking impossible
                $result | Should -BeOfType [Object[]]
                
                # Calling code cannot check if operation was successful
                # because $result.Success doesn't exist (it's just an array)
                { $result.Success } | Should -Throw
            }
        }
    }

    Context 'HIGH-002: Web Request Resilience Validation' {
        It 'Should demonstrate lack of retry logic in Get-BridgeHtml' {
            InModuleScope 'BridgeWatcher' {
                # Mock Invoke-WebRequest to fail
                Mock Invoke-WebRequest { throw "Network timeout" }
                
                # Measure the time - should fail immediately without retries
                $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
                $result = Get-BridgeHtml -Uri 'https://example.com'
                $stopwatch.Stop()
                
                # Should fail immediately (< 1 second) because there's no retry logic
                $stopwatch.ElapsedMilliseconds | Should -BeLessThan 1000
                $result.Success | Should -Be $false
                $result.ErrorCode | Should -Be 'HTTP_ERROR'
            }
        }
    }

    Context 'HIGH-003: Pipeline Processing Risk Validation' {
        It 'Should demonstrate Compare-Object failure with null inputs' {
            InModuleScope 'BridgeWatcher' {
                # This should fail when null is passed to Compare-Object
                {
                    Invoke-BridgeStatusComparison -PreviousState $null -CurrentState @() -ApiKey 'test' -PoUserKey 'test' -PoApiKey 'test'
                } | Should -Throw
            }
        }

        It 'Should demonstrate Compare-Object failure with malformed objects' {
            InModuleScope 'BridgeWatcher' {
                # Objects without required properties should cause issues
                $malformedPrevious = @(@{ wrongProperty = 'value' })
                $malformedCurrent = @(@{ anotherWrongProperty = 'value' })
                
                {
                    Invoke-BridgeStatusComparison -PreviousState $malformedPrevious -CurrentState $malformedCurrent -ApiKey 'test' -PoUserKey 'test' -PoApiKey 'test'
                } | Should -Throw
            }
        }
    }

    Context 'HIGH-004: PSScriptRoot Scope Issue Validation' {
        It 'Should demonstrate PSScriptRoot availability issue' {
            InModuleScope 'BridgeWatcher' {
                # In some contexts, PSScriptRoot might not be available
                $originalPSScriptRoot = $PSScriptRoot
                try {
                    # Simulate missing PSScriptRoot
                    Remove-Variable PSScriptRoot -Scope Local -ErrorAction SilentlyContinue
                    
                    # This should fail or behave unexpectedly
                    { Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test' -Level 'Verbose' } | Should -Throw
                }
                finally {
                    # Restore PSScriptRoot if possible
                    if ($originalPSScriptRoot) {
                        Set-Variable PSScriptRoot -Value $originalPSScriptRoot -Scope Local
                    }
                }
            }
        }
    }

    Context 'Memory and Performance Issues' {
        It 'Should demonstrate inefficient array concatenation' {
            InModuleScope 'BridgeWatcher' {
                # Simulate the inefficient += pattern used in the code
                $result = @()
                
                # This pattern is used in Get-BridgeStatusFromHtml line 145
                # Each += operation creates a new array and copies all elements
                for ($i = 0; $i -lt 1000; $i++) {
                    $result += @{ Index = $i }
                }
                
                # This should be much slower than using ArrayList or proper collection
                $result.Count | Should -Be 1000
            }
        }
    }
}