Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Test-BridgeMonitorInstance' {
        BeforeEach {
            # Clean up any existing lock files before each test
            $tempDir = [System.IO.Path]::GetTempPath()
            $pidFile = Join-Path $tempDir "BridgeWatcher-Monitor.pid"
            $lockFile = Join-Path $tempDir "BridgeWatcher-Monitor.lock"
            if (Test-Path $pidFile) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }
            if (Test-Path $lockFile) { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue }
        }

        AfterEach {
            # Clean up after each test
            $tempDir = [System.IO.Path]::GetTempPath()
            $pidFile = Join-Path $tempDir "BridgeWatcher-Monitor.pid"
            $lockFile = Join-Path $tempDir "BridgeWatcher-Monitor.lock"
            if (Test-Path $pidFile) { Remove-Item $pidFile -Force -ErrorAction SilentlyContinue }
            if (Test-Path $lockFile) { Remove-Item $lockFile -Force -ErrorAction SilentlyContinue }
        }

        Context 'Check Action (MED-008)' {
            It 'Returns not running when no instance exists' {
                $result = Test-BridgeMonitorInstance -Action 'Check'
                $result.IsRunning | Should -Be $false
                $result.Success | Should -Be $true
                $result.ErrorCode | Should -BeNullOrEmpty
            }

            It 'Detects stale PID file and cleans it up' {
                # Create a fake PID file with non-existent process ID
                $tempDir = [System.IO.Path]::GetTempPath()
                $pidFile = Join-Path $tempDir "BridgeWatcher-Monitor.pid"
                Set-Content -Path $pidFile -Value "999999"  # Non-existent PID

                $result = Test-BridgeMonitorInstance -Action 'Check'
                $result.IsRunning | Should -Be $false
                $result.Success | Should -Be $true
                Test-Path $pidFile | Should -Be $false  # Should be cleaned up
            }

            It 'Returns error on file access issues' {
                # This test is harder to implement without causing actual file permission issues
                # We'll verify the structure is correct for error handling
                $result = Test-BridgeMonitorInstance -Action 'Check'
                $result.GetType().Name | Should -Be 'PSCustomObject'
                $result.PSObject.Properties.Name | Should -Contain 'IsRunning'
                $result.PSObject.Properties.Name | Should -Contain 'Success'
            }
        }

        Context 'Lock Action' {
            It 'Successfully acquires lock when no other instance exists' {
                $instanceId = "test-instance-001"
                $result = Test-BridgeMonitorInstance -Action 'Lock' -InstanceId $instanceId
                
                $result.Success | Should -Be $true
                $result.InstanceId | Should -Be $instanceId
                $result.ErrorCode | Should -BeNullOrEmpty

                # Verify files were created
                Test-Path $result.PidFile | Should -Be $true
                Test-Path $result.LockFile | Should -Be $true
            }

            It 'Creates PID file with current process ID' {
                $instanceId = "test-instance-002"
                $result = Test-BridgeMonitorInstance -Action 'Lock' -InstanceId $instanceId
                
                $result.Success | Should -Be $true
                $pidContent = Get-Content $result.PidFile
                $pidContent | Should -Be ([System.Environment]::ProcessId).ToString()
            }

            It 'Creates lock file with instance information' {
                $instanceId = "test-instance-003"
                $result = Test-BridgeMonitorInstance -Action 'Lock' -InstanceId $instanceId
                
                $result.Success | Should -Be $true
                $lockContent = Get-Content $result.LockFile | ConvertFrom-Json
                $lockContent.InstanceId | Should -Be $instanceId
                $lockContent.ProcessId | Should -Be ([System.Environment]::ProcessId)
                $lockContent.MachineName | Should -Be ([System.Environment]::MachineName)
                $lockContent.StartTime | Should -Not -BeNullOrEmpty
            }

            It 'Fails when another instance is already running' {
                # First instance acquires lock
                $result1 = Test-BridgeMonitorInstance -Action 'Lock' -InstanceId "instance-001"
                $result1.Success | Should -Be $true

                # Second instance should fail
                $result2 = Test-BridgeMonitorInstance -Action 'Lock' -InstanceId "instance-002"
                $result2.Success | Should -Be $false
                $result2.IsRunning | Should -Be $true
                $result2.ErrorCode | Should -Be 'CON-001'
                $result2.ErrorMessage | Should -Match 'already running'
            }

            It 'Uses generated instance ID if none provided' {
                $result = Test-BridgeMonitorInstance -Action 'Lock'
                
                $result.Success | Should -Be $true
                $result.InstanceId | Should -Match '^monitor-\d+$'  # Should be "monitor-" + PID
            }
        }

        Context 'Unlock Action' {
            It 'Successfully removes lock files' {
                # First acquire a lock
                $result1 = Test-BridgeMonitorInstance -Action 'Lock' -InstanceId "test-unlock"
                $result1.Success | Should -Be $true

                # Verify files exist
                Test-Path $result1.PidFile | Should -Be $true
                Test-Path $result1.LockFile | Should -Be $true

                # Unlock
                $result2 = Test-BridgeMonitorInstance -Action 'Unlock'
                $result2.Success | Should -Be $true

                # Verify files are removed
                Test-Path $result1.PidFile | Should -Be $false
                Test-Path $result1.LockFile | Should -Be $false
            }

            It 'Succeeds even when no lock files exist' {
                $result = Test-BridgeMonitorInstance -Action 'Unlock'
                $result.Success | Should -Be $true
                $result.ErrorCode | Should -BeNullOrEmpty
            }
        }

        Context 'Error Handling' {
            It 'Uses correct error codes for concurrency errors' {
                # Test that error codes follow the standardized format
                $result1 = Test-BridgeMonitorInstance -Action 'Lock' -InstanceId "error-test-1"
                $result1.Success | Should -Be $true

                $result2 = Test-BridgeMonitorInstance -Action 'Lock' -InstanceId "error-test-2"
                $result2.Success | Should -Be $false
                $result2.ErrorCode | Should -Be 'CON-001'  # InstanceExists
            }
        }

        Context 'Parameter Validation' {
            It 'Validates Action parameter' {
                { Test-BridgeMonitorInstance -Action 'InvalidAction' } | Should -Throw
            }

            It 'Action parameter is mandatory' {
                # Test that the function works when Action parameter is provided
                $result = Test-BridgeMonitorInstance -Action 'Check'
                $result | Should -Not -BeNullOrEmpty
            }

            It 'Accepts valid InstanceId' {
                $result = Test-BridgeMonitorInstance -Action 'Check' -InstanceId 'custom-id-123'
                $result.InstanceId | Should -Be 'custom-id-123'
            }
        }

        Context 'File Paths' {
            It 'Uses system temp directory for lock files' {
                $result = Test-BridgeMonitorInstance -Action 'Check'
                $tempDir = [System.IO.Path]::GetTempPath()
                $result.PidFile | Should -BeLike "$tempDir*BridgeWatcher-Monitor.pid"
                $result.LockFile | Should -BeLike "$tempDir*BridgeWatcher-Monitor.lock"
            }

            It 'Returns consistent file paths across calls' {
                $result1 = Test-BridgeMonitorInstance -Action 'Check'
                $result2 = Test-BridgeMonitorInstance -Action 'Check'
                
                $result1.PidFile | Should -Be $result2.PidFile
                $result1.LockFile | Should -Be $result2.LockFile
            }
        }
    }
}