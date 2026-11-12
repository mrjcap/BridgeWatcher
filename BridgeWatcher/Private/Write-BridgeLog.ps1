function Remove-BridgeExpiredLogFile {
    <#
    .SYNOPSIS
    Διαγράφει ημερήσια αρχεία καταγραφής BridgeWatcher παλαιότερα από το όριο διατήρησης.

    .DESCRIPTION
    Αναζητά αρχεία με πρότυπο BridgeWatcher-*.log στον φάκελο καταγραφής και διαγράφει
    όσα έχουν LastWriteTime παλαιότερο από τον καθορισμένο αριθμό ημερών διατήρησης.

    .PARAMETER LogDirectory
    Ο φάκελος αποθήκευσης των αρχείων καταγραφής.

    .PARAMETER RetentionDays
    Ο αριθμός ημερών διατήρησης των αρχείων καταγραφής (προεπιλογή: 7).

    .OUTPUTS
    None.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '',
        Justification = 'Εσωτερική βοηθητική συνάρτηση αυτόματου καθαρισμού ληγμένων αρχείων καταγραφής.')]
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$LogDirectory,
        [Parameter()][ValidateRange(1, 3650)][int]$RetentionDays = 7
    )

    $cutoff = (Get-Date).AddDays(-$RetentionDays)
    Get-ChildItem -Path $LogDirectory -Filter 'BridgeWatcher-*.log' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.LastWriteTime -lt $cutoff } |
        Remove-Item -Force -ErrorAction SilentlyContinue
}

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
    $isNewDailyLog = -not (Test-Path -Path $logPath)
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

    if ($isNewDailyLog) {
        Remove-BridgeExpiredLogFile -LogDirectory $logDir
    }
}



