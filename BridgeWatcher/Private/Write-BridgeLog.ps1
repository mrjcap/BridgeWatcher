function Write-BridgeLog {
    <#
    .SYNOPSIS
    Καταγράφει μηνύματα λειτουργίας του συστήματος.

    .DESCRIPTION
    Η Write-BridgeLog γράφει μηνύματα με κατάλληλη κατηγοριοποίηση
    (Verbose, Debug, Warning) και αποθηκεύει σε ημερήσια αρχεία καταγραφής.

    .PARAMETER Stage
    The operation stage (Ανάλυση, Απόφαση, Ειδοποίηση, Σφάλμα).

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
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][ValidateSet('Ανάλυση', 'Απόφαση', 'Ειδοποίηση', 'Σφάλμα')]
        [string]$Stage,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [Parameter()][ValidateSet('Verbose', 'Debug', 'Warning')]
        [string]$Level = 'Verbose',
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )

    $Message = $Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
    $prefix = "[Bridge:$Stage]"
    $output = "$prefix $Message"
    # Console logging
    switch ($Level) {
        'Verbose' { Write-Verbose $output }
        'Debug' { Write-Debug $output }
        'Warning' { Write-Warning $output }
    }
    # File logging using configured log directory
    $logDir = $Configuration.Defaults.LogDirectory
    if (-not (Test-Path $logDir)) {
        $newItemSplat = @{
            Path     = $logDir
            ItemType = 'Directory'
            Force    = $true
        }
        [void](New-Item @newItemSplat)
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
        $isLegacy = $null -ne $env:IsLegacyPowerShell
        $isLegacyPowerShell = if ($isLegacy) { $env:IsLegacyPowerShell -eq 'true' } else { $PSVersionTable.PSVersion.Major -lt 6 }
        $encodingVal = if ($isLegacyPowerShell) { 'utf8' } else { 'utf8BOM' }
        $addContentSplat = @{
            Path        = $logPath
            Value       = $logLine
            Encoding    = $encodingVal
            ErrorAction = 'Stop'
        }
        Add-Content @addContentSplat
    }
    catch {
        Write-Warning "Failed to write to log file '$logPath': $($_.Exception.Message)"
        $PSCmdlet.ThrowTerminatingError($_)
    }
}



