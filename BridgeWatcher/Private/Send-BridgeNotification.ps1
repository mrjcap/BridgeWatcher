function Send-BridgeNotification {
    <#
    .SYNOPSIS
    Αποστέλλει ειδοποίηση γέφυρας μέσω Pushover ή εναλλακτικού παρόχου.

    .DESCRIPTION
    Δρομολογεί την αποστολή ειδοποίησης είτε στο προσαρμοσμένο scriptblock Provider
    είτε στην Send-BridgePushover.

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης που περιέχει τις ρυθμίσεις.

    .PARAMETER Title
    Ο τίτλος της ειδοποίησης.

    .PARAMETER Message
    Το περιεχόμενο του μηνύματος ειδοποίησης.

    .PARAMETER Type
    Ο τύπος της ειδοποίησης (Closed ή Opened).

    .PARAMETER PoUser
    Το Pushover User Key του παραλήπτη.

    .PARAMETER PoApi
    Το Pushover API Token της εφαρμογής.

    .PARAMETER Provider
    Προαιρετικό script block που λειτουργεί ως εναλλακτικός πάροχος ειδοποιήσεων.

    .OUTPUTS
    None.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$Configuration,

        [string]$Title,

        [string]$Message,

        [string]$Type,

        [string]$PoUser,

        [string]$PoApi,

        [scriptblock]$Provider
    )

    if ($null -ne $Provider) {
        & $Provider -Title $Title -Message $Message -Type $Type
    } else {
        $pushoverSplat = @{
            PoUserKey     = $PoUser
            PoApiKey      = $PoApi
            Title         = $Title
            Message       = $Message
            ErrorAction   = 'Stop'
            Configuration = $Configuration
        }
        Send-BridgePushover @pushoverSplat
    }
}
