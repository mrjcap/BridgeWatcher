Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Write-BridgeLog Mutex and Retry Tests' {
        BeforeEach {
            # Clean up any log files created during tests
            $testLogDir = Join-Path $TestDrive 'logs'
            if (Test-Path $testLogDir) {
                Remove-Item $testLogDir -Recurse -Force
            }
        }

        Context 'HIGH-005: Mutex Locking and Retry Logic' {
            It 'Handles file access conflicts gracefully with retry logic' {
                $script:attemptCount = 0
                Mock Add-Content { 
                    $script:attemptCount++
                    if ($script:attemptCount -le 2) {
                        throw [System.IO.IOException]::new("The process cannot access the file because it is being used by another process.")
                    }
                    # Success on third attempt
                }
                Mock Write-Warning {}

                Write-BridgeLog -Stage 'Σφάλμα' -Message 'Test retry behavior'

                # Should have tried 3 times and succeeded
                $script:attemptCount | Should -Be 3
                Assert-MockCalled Write-Warning -Exactly 0
            }

            It 'Falls back to warning after maximum retries' {
                Mock Add-Content { 
                    throw [System.IO.IOException]::new("Persistent file access error")
                }
                Mock Write-Warning {}

                Write-BridgeLog -Stage 'Σφάλμα' -Message 'Test fallback behavior'

                Assert-MockCalled Write-Warning -ParameterFilter {
                    $Message -like "*Failed to write to log file*after*attempts*"
                } -Exactly 1
            }

            It 'Uses mutex for file access protection' {
                # This test verifies that mutex operations don't throw errors
                Mock New-Object { 
                    $mockMutex = New-Object PSObject
                    $mockMutex | Add-Member -MemberType ScriptMethod -Name 'WaitOne' -Value { $true }
                    $mockMutex | Add-Member -MemberType ScriptMethod -Name 'ReleaseMutex' -Value { }
                    $mockMutex | Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value { }
                    return $mockMutex
                } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }
                Mock Add-Content {}

                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'Mutex test' } | Should -Not -Throw
            }

            It 'Writes to console outputs correctly' {
                Mock Write-Verbose {} -Verifiable
                Mock Write-Debug {} -Verifiable  
                Mock Write-Warning {} -Verifiable

                Write-BridgeLog -Stage 'Ανάλυση' -Message 'Verbose test' -Level 'Verbose'
                Write-BridgeLog -Stage 'Απόφαση' -Message 'Debug test' -Level 'Debug'
                Write-BridgeLog -Stage 'Σφάλμα' -Message 'Warning test' -Level 'Warning'

                Assert-MockCalled Write-Verbose -Exactly 1
                Assert-MockCalled Write-Debug -Exactly 1
                Assert-MockCalled Write-Warning -Exactly 1
            }

            It 'Handles mutex timeout gracefully' {
                Mock New-Object {
                    $mockMutex = New-Object PSObject
                    $mockMutex | Add-Member -MemberType ScriptMethod -Name 'WaitOne' -Value { $false } # Timeout
                    $mockMutex | Add-Member -MemberType ScriptMethod -Name 'Dispose' -Value { }
                    return $mockMutex
                } -ParameterFilter { $TypeName -eq 'System.Threading.Mutex' }
                Mock Write-Warning {}

                Write-BridgeLog -Stage 'Σφάλμα' -Message 'Timeout test'

                Assert-MockCalled Write-Warning -ParameterFilter {
                    $Message -like "*Failed to write to log file*"
                } -Exactly 1
            }
        }

        Context 'Parameter Validation and Error Handling' {
            It 'Validates Stage parameter correctly' {
                { Write-BridgeLog -Stage 'InvalidStage' -Message 'test' } | Should -Throw
            }

            It 'Validates Level parameter correctly' {
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'test' -Level 'InvalidLevel' } | Should -Throw
            }

            It 'Validates Message parameter is not empty' {
                { Write-BridgeLog -Stage 'Ανάλυση' -Message '' } | Should -Throw
            }

            It 'Uses default Level when not specified' {
                Mock Write-Verbose {} -Verifiable

                Write-BridgeLog -Stage 'Ανάλυση' -Message 'Default level test'

                Assert-MockCalled Write-Verbose -Exactly 1
            }
        }
    }
}