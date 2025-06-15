function Get-BridgeStatusAdvice {
    [CmdletBinding()]
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

    .OUTPUTS
    [string] - String με προτεινόμενο status και μήνυμα.

    .EXAMPLE
    Get-BridgeStatusAdvice -MinutesUntilOpen 15

    .EXAMPLE
    Get-BridgeStatusAdvice -MinutesUntilOpen 8 -MaxWaitTimeMinutes 10

    .NOTES
    Αν τα λεπτά είναι περισσότερα από το MaxWaitTimeMinutes επιστρέφεται 
    σύσταση να μην περιμένετε.
    #>
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][int]$MinutesUntilOpen,
        [Parameter()][ValidateRange(1, 120)][int]$MaxWaitTimeMinutes = 12
    )
    if ($MinutesUntilOpen -gt $MaxWaitTimeMinutes) {
        return 'Είναι προτιμότερο να μην περιμένεις'
    }
    return 'Είναι προτιμότερο να περιμένεις'
}