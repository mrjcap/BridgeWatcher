function Send-BridgePushover {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Αποστέλλει ειδοποίηση μέσω Pushover για κατάσταση γέφυρας.

    .DESCRIPTION
    Η Send-BridgePushover δημιουργεί payload και αποστέλλει ειδοποίηση
    στο σύστημα Pushover, χρησιμοποιώντας παρεχόμενα διαπιστευτήρια.

    .PARAMETER PoUserKey
    Το User Key του παραλήπτη στο Pushover.

    .PARAMETER PoApiKey
    Το API Token της εφαρμογής.

    .PARAMETER Message
    Το μήνυμα της ειδοποίησης.

    .PARAMETER Device
    Η συσκευή στόχος (προαιρετικό).

    .PARAMETER Title
    Ο τίτλος της ειδοποίησης (προαιρετικό).

    .PARAMETER Url
    URL που θα επισυνάπτεται στην ειδοποίηση (προαιρετικό).

    .PARAMETER UrlTitle
    Ο τίτλος για το επισυναπτόμενο URL (προαιρετικό).

    .PARAMETER Priority
    Η προτεραιότητα ειδοποίησης (προαιρετικό).

    .PARAMETER Sound
    Ο ήχος ειδοποίησης (προαιρετικό).

    .OUTPUTS
    None.

    .EXAMPLE
    Send-BridgePushover -PoUserKey 'user123' -PoApiKey 'token123' -Message 'Η γέφυρα είναι ανοιχτή.'

    .NOTES
    Χρησιμοποιεί εσωτερικές helper συναρτήσεις για payload και αποστολή.
    #>

    [OutputType([void])]
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
    $writeBridgeLogSplat = @{
        Stage   = 'Ειδοποίηση'
        Message = "Pushover ➤ Sending: '$Message'"
        Level   = 'Verbose'
    }
    Write-BridgeLog @writeBridgeLogSplat
    $newPushoverPayloadSplat = @{
        PoUserKey = $PoUserKey
        PoApiKey  = $PoApiKey
        Message   = $Message
        Device    = $Device
        Title     = $Title
        Url       = $Url
        UrlTitle  = $UrlTitle
        Priority  = $Priority
        Sound     = $Sound
    }
    $payload = Get-BridgePushoverPayload @newPushoverPayloadSplat
    $sendPushoverRequestSplat = @{
        Payload    = $payload
    }
    Send-BridgePushoverRequest @sendPushoverRequestSplat | Out-Null
    $writeBridgeLogSplat = @{
        Stage   = 'Ειδοποίηση'
        Message = 'Pushover ✅ Sent successfully'
        Level   = 'Verbose'
    }
    Write-BridgeLog @writeBridgeLogSplat
}