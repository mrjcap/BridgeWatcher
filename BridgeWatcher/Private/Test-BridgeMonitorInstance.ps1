function Test-BridgeMonitorInstance {
    <#
    .SYNOPSIS
    Checks for running BridgeWatcher monitor instances and provides concurrency protection.

    .DESCRIPTION
    Implements concurrency protection for the BridgeWatcher monitor to prevent
    multiple instances from running simultaneously (MED-008).

    .PARAMETER Action
    The action to perform: Check, Lock, or Unlock.

    .PARAMETER InstanceId
    Unique identifier for this monitor instance.

    .OUTPUTS
    [PSCustomObject] - Result object with IsRunning, InstanceId, and PidFile properties

    .EXAMPLE
    Test-BridgeMonitorInstance -Action 'Check'

    .EXAMPLE
    Test-BridgeMonitorInstance -Action 'Lock' -InstanceId 'monitor-001'

    .NOTES
    Addresses MED-008: Concurrency Protection σε Monitor Script.
    Uses PID files and process checking for cross-platform compatibility.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Check', 'Lock', 'Unlock')]
        [string]$Action,

        [Parameter()]
        [string]$InstanceId = "monitor-$([System.Environment]::ProcessId)"
    )

    $tempDir = [System.IO.Path]::GetTempPath()
    $pidFile = Join-Path $tempDir "BridgeWatcher-Monitor.pid"
    $lockFile = Join-Path $tempDir "BridgeWatcher-Monitor.lock"

    $result = [PSCustomObject]@{
        IsRunning = $false
        InstanceId = $InstanceId
        PidFile = $pidFile
        LockFile = $lockFile
        Success = $false
        ErrorCode = ''
        ErrorMessage = ''
    }

    switch ($Action) {
        'Check' {
            try {
                # Check if PID file exists
                if (Test-Path $pidFile) {
                    $existingPid = Get-Content $pidFile -ErrorAction Stop
                    
                    # Check if process is still running
                    $process = Get-Process -Id $existingPid -ErrorAction SilentlyContinue
                    if ($process) {
                        # Check if it's actually a BridgeWatcher process
                        if ($process.ProcessName -like "*pwsh*" -or $process.ProcessName -like "*powershell*") {
                            $result.IsRunning = $true
                            $result.Success = $true
                        } else {
                            # Stale PID file - remove it
                            Remove-Item $pidFile -ErrorAction SilentlyContinue
                            Remove-Item $lockFile -ErrorAction SilentlyContinue
                            $result.Success = $true
                        }
                    } else {
                        # Process not running - remove stale files
                        Remove-Item $pidFile -ErrorAction SilentlyContinue
                        Remove-Item $lockFile -ErrorAction SilentlyContinue
                        $result.Success = $true
                    }
                } else {
                    $result.Success = $true
                }
            }
            catch {
                $result.ErrorCode = Get-BridgeErrorCode -Category 'Concurrency' -Type 'MutexError'
                $result.ErrorMessage = "Failed to check monitor instance: $($_.Exception.Message)"
            }
        }
        'Lock' {
            try {
                # First check if another instance is running
                $checkResult = Test-BridgeMonitorInstance -Action 'Check'
                if ($checkResult.IsRunning) {
                    $result.IsRunning = $true
                    $result.ErrorCode = Get-BridgeErrorCode -Category 'Concurrency' -Type 'InstanceExists'
                    $result.ErrorMessage = 'Another BridgeWatcher monitor instance is already running'
                    return $result
                }

                # Create PID file
                $currentPid = [System.Environment]::ProcessId
                Set-Content -Path $pidFile -Value $currentPid -ErrorAction Stop

                # Create lock file with instance information
                $lockInfo = @{
                    InstanceId = $InstanceId
                    ProcessId = $currentPid
                    StartTime = Get-BridgeTimestamp
                    MachineName = [System.Environment]::MachineName
                } | ConvertTo-Json
                
                Set-Content -Path $lockFile -Value $lockInfo -ErrorAction Stop

                $result.Success = $true
            }
            catch {
                $result.ErrorCode = Get-BridgeErrorCode -Category 'Concurrency' -Type 'LockTimeout'
                $result.ErrorMessage = "Failed to acquire monitor lock: $($_.Exception.Message)"
            }
        }
        'Unlock' {
            try {
                # Remove PID and lock files
                if (Test-Path $pidFile) {
                    Remove-Item $pidFile -ErrorAction Stop
                }
                if (Test-Path $lockFile) {
                    Remove-Item $lockFile -ErrorAction Stop
                }
                $result.Success = $true
            }
            catch {
                $result.ErrorCode = Get-BridgeErrorCode -Category 'Concurrency' -Type 'MutexError'
                $result.ErrorMessage = "Failed to release monitor lock: $($_.Exception.Message)"
            }
        }
    }

    return $result
}