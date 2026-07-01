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

.PARAMETER Configuration
Το configuration object που περιέχει τις ρυθμίσεις.

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
        [string]$Level = 'Verbose',
        [Parameter()][PSCustomObject]$Configuration
    )
    if (-not $Configuration) {
        $Configuration = New-BridgeConfiguration
    }
    $prefix = "[Bridge:$Stage]"
    $output = "$prefix $Message"
    # Console logging
    switch ($Level) {
        'Verbose' { Write-Verbose $output }
        'Debug' { Write-Debug $output }
        'Warning' { Write-Warning $output }
    }
    # File logging — uses configured log directory
    $logDir = $Configuration.LogDirectory
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

    $isPester = [bool](Get-PSCallStack | Where-Object { $_.ScriptName -like '*Tests.ps1' -or $_.ScriptName -like '*Pester*' })

    if ($isPester -or $logDir -like 'TestDrive:\*') {
        try {
            $addContentSplat = @{
                Path        = $logPath
                Value       = $logLine
                Encoding    = 'utf8BOM'
                ErrorAction = 'Stop'
            }
            Add-Content @addContentSplat
        }
        catch {
            Write-Warning "Failed to write to log file '$logPath': $($_.Exception.Message)"
        }
    } else {
        try {
            if ($script:LogStream -and $script:LogStreamPath -eq $logPath) {
                $script:LogStream.WriteLine($logLine)
                $script:LogStream.Flush()
            } else {
                if ($script:LogStream) {
                    try { $script:LogStream.Close() } catch { Write-Verbose $_.Exception.Message }
                    $script:LogStream = $null
                }
                $utf8WithBOM = New-Object System.Text.UTF8Encoding $true
                $script:LogStream = New-Object System.IO.StreamWriter($logPath, $true, $utf8WithBOM)
                $script:LogStream.AutoFlush = $true
                $script:LogStreamPath = $logPath
                
                $script:LogStream.WriteLine($logLine)
            }
        }
        catch {
            Write-Warning "Failed to write to log file '$logPath': $($_.Exception.Message)"
        }
    }
}

