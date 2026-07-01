function Get-BridgeStatusAdvice {
    <#
    .SYNOPSIS
    Προτείνει αν αξίζει να περιμένετε το άνοιγμα της γέφυρας.

    .DESCRIPTION
    Η Get-BridgeStatusAdvice λαμβάνει τον χρόνο σε λεπτά μέχρι να ανοίξει
    η γέφυρα και επιστρέφει μήνυμα για το αν πρέπει να περιμένετε.

    .PARAMETER MinutesUntilOpen
    Τα λεπτά που απομένουν μέχρι να ανοίξει η γέφυρα.

    .PARAMETER MaxWaitTimeMinutes
    Ο μέγιστος χρόνος αναμονής σε λεπτά (προεπιλογή: 12 λεπτά).

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης που περιέχει τις ρυθμίσεις.

    .OUTPUTS
    [string] - Συμβολοσειρά με την προτεινόμενη σύσταση.

    .EXAMPLE
    Get-BridgeStatusAdvice -MinutesUntilOpen 15

    .EXAMPLE
    Get-BridgeStatusAdvice -MinutesUntilOpen 8 -MaxWaitTimeMinutes 10

    .NOTES
    Αν τα λεπτά είναι περισσότερα από το MaxWaitTimeMinutes, επιστρέφεται σύσταση να μην περιμένετε.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][int]$MinutesUntilOpen,
        [Parameter()][ValidateRange(1, 120)][int]$MaxWaitTimeMinutes,
        [Parameter()][PSCustomObject]$Configuration
    )

    if (-not $Configuration) {
        $Configuration = New-BridgeConfiguration
    }

    # Λήψη μέγιστου χρόνου αναμονής από την παράμετρο, τη διαμόρφωση, ή χρήση εναλλακτικής λύσης
    if (-not $MaxWaitTimeMinutes) {
        $MaxWaitTimeMinutes = $Configuration.Defaults.MaxWaitTimeMinutes
    }

    # Λήψη μηνυμάτων συμβουλής από τη διαμόρφωση ή χρήση εναλλακτικής λύσης
    $doNotWaitMessage = $Configuration.AdviceMessages.DoNotWait

    $waitMessage = $Configuration.AdviceMessages.Wait

    if ($MinutesUntilOpen -le 0 -or $MinutesUntilOpen -gt $MaxWaitTimeMinutes) {
        return $doNotWaitMessage
    }
    return $waitMessage
}

