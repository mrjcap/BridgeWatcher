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

    .OUTPUTS
    [string] - String με προτεινόμενο status και μήνυμα.

    .EXAMPLE
    Get-BridgeStatusAdvice -MinutesUntilOpen 15

    .NOTES
    Αν τα λεπτά είναι περισσότερα από 12 επιστρέφεται σύσταση να μην
    περιμένετε.
    #>
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][int]$MinutesUntilOpen
    )
    if ($MinutesUntilOpen -gt 12) {
        return 'Είναι προτιμότερο να μην περιμένεις'
    }
    return 'Είναι προτιμότερο να περιμένεις'
}