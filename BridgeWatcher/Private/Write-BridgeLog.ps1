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
    $addContentSplat = @{
        Path  = $logPath
        Value = $logLine
    }
    Add-Content @addContentSplat
}