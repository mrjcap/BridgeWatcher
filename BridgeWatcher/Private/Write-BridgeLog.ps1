function Write-BridgeLog {
    [CmdletBinding()]
    [OutputType([void])]
    <#
.SYNOPSIS
Καταγράφει μηνύματα λειτουργίας του συστήματος.

.DESCRIPTION
Η Write-BridgeLog γράφει μηνύματα με κατάλληλη κατηγοριοποίηση
(Verbose, Debug, Warning) και αποθηκεύει σε ημερήσια αρχεία καταγραφής.

.PARAMETER Stage
Το στάδιο λειτουργίας (Ανάλυση, Απόφαση, Ειδοποίηση, Σφάλμα).

.PARAMETER Message
Το μήνυμα που θα καταγραφεί.

.PARAMETER Level
Το επίπεδο λογιστικού μηνύματος (Verbose, Debug, Warning).

.OUTPUTS
None.

.EXAMPLE
Write-BridgeLog -Stage 'Ανάλυση' -Message 'Έλεγχος OCR...' -Level 'Verbose'

.NOTES
Δημιουργεί log directory αν δεν υπάρχει και καταγράφει ημερήσια αρχεία.
#>    param (
        [Parameter(Mandatory)][ValidateSet('Ανάλυση', 'Απόφαση', 'Ειδοποίηση', 'Σφάλμα')]
        [string]$Stage,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [Parameter()][ValidateSet('Verbose', 'Debug', 'Warning')]
        [string]$Level = 'Verbose'
    )
    $prefix = "[Bridge:$Stage]"
    $output = "$prefix $Message"
    # Console logging
    switch ($Level) {
        'Verbose' { Write-Verbose $output }
        'Debug' { Write-Debug $output }
        'Warning' { Write-Warning $output }
    }
    # File logging - two levels up
    $splitPathSplat = @{
        Path   = (Split-Path -Path $PSScriptRoot -Parent)
        Parent = $true
    }
    $basePath = Split-Path @splitPathSplat
    $joinPathSplat = @{
        Path      = $basePath
        ChildPath = 'logs'
    }
    $logDir = Join-Path @joinPathSplat
    if (-not (Test-Path $logDir)) {
        $newItemSplat = @{
            Path     = $logDir
            ItemType = 'Directory'
            Force    = $true
        }
        New-Item @newItemSplat | Out-Null
    }
    $dateStr = (Get-Date).ToString('yyyy-MM-dd')
    $timeStr = (Get-Date).ToString('HH:mm:ss')

    $joinPathSplat = @{
        Path      = $logDir
        ChildPath = "BridgeWatcher-$dateStr.log"
    }
    $logPath = Join-Path @joinPathSplat
    $logLine = "[$timeStr] [$Stage] $Message"

    # HIGH-005: Add mutex locking and retry logic for file operations
    $mutexName = "BridgeWatcher_Log_$($logPath -replace '[\\/:*?"<>|]', '_')"
    $mutex = $null
    $maxRetries = 3
    $baseDelayMs = 50
    
    try {
        # Create or open named mutex
        $mutex = New-Object System.Threading.Mutex($false, $mutexName)
        
        for ($attempt = 1; $attempt -le $maxRetries; $attempt++) {
            try {
                # Try to acquire mutex with timeout
                if ($mutex.WaitOne(5000)) { # 5 second timeout
                    try {
                        $addContentSplat = @{
                            Path        = $logPath
                            Value       = $logLine
                            Encoding    = 'utf8BOM'
                            ErrorAction = 'Stop'
                        }
                        Add-Content @addContentSplat
                        return # Success - exit function
                    }
                    finally {
                        $mutex.ReleaseMutex()
                    }
                } else {
                    throw (New-Object System.TimeoutException("Timeout acquiring file lock"))
                }
            }
            catch {
                if ($attempt -lt $maxRetries) {
                    $delayMs = $baseDelayMs * [Math]::Pow(2, $attempt - 1)
                    Start-Sleep -Milliseconds $delayMs
                } else {
                    # Final attempt failed - use fallback
                    Write-Warning "Failed to write to log file '$logPath' after $maxRetries attempts: $($_.Exception.Message)"
                }
            }
        }
    }
    catch {
        # Fallback: write only to console if mutex creation or file logging fails
        Write-Warning "Failed to write to log file '$logPath': $($_.Exception.Message)"
    }
    finally {
        if ($mutex) {
            $mutex.Dispose()
        }
    }
}