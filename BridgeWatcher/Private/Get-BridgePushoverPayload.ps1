function Get-BridgePushoverPayload {
    <#
    .SYNOPSIS
    Δημιουργεί σώμα αιτήματος για αποστολή μέσω Pushover.

    .DESCRIPTION
    Η Get-BridgePushoverPayload κατασκευάζει hashtable με όλα τα απαραίτητα
    πεδία για αποστολή ειδοποίησης στο Pushover.

    .PARAMETER PoUserKey
    Το User Key του παραλήπτη στο Pushover.

    .PARAMETER PoApiKey
    Το API Token της εφαρμογής.

    .PARAMETER Message
    Το μήνυμα ειδοποίησης.

    .OUTPUTS
    [hashtable] - Το payload σε μορφή hashtable.

    .EXAMPLE
    Get-BridgePushoverPayload -PoUserKey 'user123' -PoApiKey 'token123' -Message 'Η γέφυρα έκλεισε!'

    .NOTES
    Υποστηρίζει επίσης προαιρετικά πεδία όπως Device, Title, Url, Priority, Sound.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)][string]$PoUserKey,
        [Parameter(Mandatory)][string]$PoApiKey,
        [Parameter(Mandatory)][string]$Message,
        [string]$Device,
        [string]$Title,
        [string]$Url,
        [string]$UrlTitle,
        [int]$Priority,
        [string]$Sound
    )

    $data = @{
        token   = $PoApiKey
        user    = $PoUserKey
        message = $Message
    }
    if ($PSBoundParameters.ContainsKey('Device') -and $Device) { $data.device = $Device }
    if ($PSBoundParameters.ContainsKey('Title') -and $Title) { $data.title = $Title }
    if ($PSBoundParameters.ContainsKey('Url') -and $Url) { $data.url = $Url }
    if ($PSBoundParameters.ContainsKey('UrlTitle') -and $UrlTitle) { $data.url_title = $UrlTitle }
    if ($PSBoundParameters.ContainsKey('Priority') -and $Priority) { $data.priority = $Priority }
    if ($PSBoundParameters.ContainsKey('Sound') -and $Sound) { $data.sound = $Sound }
    return $data
}

