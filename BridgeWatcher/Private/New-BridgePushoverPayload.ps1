function New-BridgePushoverPayload {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Δημιουργεί σώμα αιτήματος για αποστολή μέσω Pushover.

    .DESCRIPTION
    Η New-BridgePushoverPayload κατασκευάζει hashtable με όλα τα απαραίτητα
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
    New-BridgePushoverPayload -PoUserKey 'user123' -PoApiKey 'token123' -Message 'Bridge Closed!'

    .NOTES
    Υποστηρίζει επίσης optional fields όπως Device, Title, Url, Priority, Sound.
    #>

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
    if ($PSBoundParameters.ContainsKey('Device')) { $data.device = $Device }
    if ($PSBoundParameters.ContainsKey('Title')) { $data.title = $Title }
    if ($PSBoundParameters.ContainsKey('Url')) { $data.url = $Url }
    if ($PSBoundParameters.ContainsKey('UrlTitle')) { $data.url_title = $UrlTitle }
    if ($PSBoundParameters.ContainsKey('Priority')) { $data.priority = $Priority }
    if ($PSBoundParameters.ContainsKey('Sound')) { $data.sound = $Sound }
    return $data
}