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
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [ValidateNotNullOrEmpty()][string]$Device,
        [ValidateNotNullOrEmpty()][string]$Title,
        [ValidateScript({$_ -match '^https?://'})]
        [string]$Url,
        [ValidateNotNullOrEmpty()][string]$UrlTitle,
        [ValidateRange(0, 2)][int]$Priority,
        [ValidateSet('pushover', 'bike', 'bugle', 'cashregister', 'classical', 'cosmic', 'falling', 'gamelan', 'incoming', 'intermission', 'magic', 'mechanical', 'pianobar', 'siren', 'spacealarm', 'tugboat', 'alien', 'climb', 'persistent', 'echo', 'updown', 'none')]
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
    try {
        $payload = Get-BridgePushoverPayload @newPushoverPayloadSplat
        $sendPushoverRequestSplat = @{
            Payload    = $payload
            ErrorAction = 'Stop'
        }
        Send-BridgePushoverRequest @sendPushoverRequestSplat | Out-Null
        $writeBridgeLogSplat = @{
            Stage   = 'Ειδοποίηση'
            Message = 'Pushover ✅ Sent successfully'
            Level   = 'Verbose'
        }
        Write-BridgeLog @writeBridgeLogSplat
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Αποτυχία αποστολής Pushover: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat

        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                ([System.Exception]::new("Αποτυχία αποστολής Pushover: $($_.Exception.Message)")),
                'PushoverSendError',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $Message
            )
        )
    }
}