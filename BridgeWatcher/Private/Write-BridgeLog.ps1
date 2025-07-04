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

.PARAMETER SuppressConsoleOutput
Καταστέλλει την έξοδο στην κονσόλα (για internal χρήση).

.PARAMETER Configuration
Το configuration object που περιέχει ρυθμίσεις logging.

.OUTPUTS
None.

.EXAMPLE
Write-BridgeLog -Stage 'Ανάλυση' -Message 'Έλεγχος OCR...' -Level 'Verbose'

Καταγράφει ένα verbose μήνυμα ανάλυσης.

.EXAMPLE
Write-BridgeLog -Stage 'Σφάλμα' -Message 'API κλήση απέτυχε' -Level 'Warning' -Configuration $config

Καταγράφει ένα warning με χρήση configuration settings.

.EXAMPLE
Write-BridgeLog -Stage 'Ανάλυση' -Message 'Debug info' -Level 'Debug' -SuppressConsoleOutput

Καταγράφει debug μήνυμα μόνο σε αρχείο, όχι στην κονσόλα.

.NOTES
Δημιουργεί log directory αν δεν υπάρχει και καταγράφει ημερήσια αρχεία.
Υποστηρίζει configurable console output και file logging μέσω Configuration object.
#>    param (
        [Parameter(Mandatory)][ValidateSet('Ανάλυση', 'Απόφαση', 'Ειδοποίηση', 'Σφάλμα')]
        [string]$Stage,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [Parameter()][ValidateSet('Verbose', 'Debug', 'Warning')]
        [string]$Level = 'Verbose',
        [Parameter()][switch]$SuppressConsoleOutput,
        [Parameter()][PSCustomObject]$Configuration
    )
    $prefix = "[Bridge:$Stage]"
    $output = "$prefix $Message"
    
    # Check if console output should be suppressed based on configuration
    $enableConsoleOutput = if ($Configuration) {
        Get-ConfigurationValue -Configuration $Configuration -PropertyPath 'LoggingConfig.EnableConsoleOutput' -FallbackValue $true
    } else {
        $true
    }
    
    # Console logging (only if not suppressed)
    if (-not $SuppressConsoleOutput -and $enableConsoleOutput) {
        switch ($Level) {
            'Verbose' { Write-Verbose $output }
            'Debug' { Write-Debug $output }
            'Warning' { Write-Warning $output }
        }
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

    try {
        $addContentSplat = @{
            Path        = $logPath
            Value       = $logLine
            Encoding    = 'utf8'
            ErrorAction = 'Stop'
        }
        Add-Content @addContentSplat
    }
    catch {
        # Fallback: write only to console if file logging fails
        Write-Warning "Failed to write to log file '$logPath': $($_.Exception.Message)"
    }
}