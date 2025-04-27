function Get-BridgeStatusAdvice {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Παρέχει σύσταση κατάστασης γέφυρας βάσει κειμένου.

    .DESCRIPTION
    Η Get-BridgeStatusAdvice αναλύει ένα κείμενο και επιστρέφει
    προτεινόμενο status γέφυρας ('Ανοιχτή', 'Κλειστή', 'Άγνωστη').

    .PARAMETER Text
    Το κείμενο που θα αναλυθεί.

    .OUTPUTS
    [string] - String με προτεινόμενο status και μήνυμα.

    .EXAMPLE
    Get-BridgeStatusAdvice -Text 'Η γέφυρα είναι ανοιχτή.'

    .NOTES
    Ανιχνεύει status με βάση προκαθορισμένα patterns.
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