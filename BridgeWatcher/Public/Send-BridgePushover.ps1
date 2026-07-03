function Send-BridgePushover {
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
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [ValidateNotNullOrEmpty()][string]$Device,
        [ValidateNotNullOrEmpty()][string]$Title,
        [ValidateScript({ $_ -match '^https?://' })]
        [string]$Url,
        [ValidateNotNullOrEmpty()][string]$UrlTitle,
        [ValidateRange(0, 2)][int]$Priority,
        [ValidateSet('pushover', 'bike', 'bugle', 'cashregister', 'classical', 'cosmic', 'falling', 'gamelan', 'incoming', 'intermission', 'magic', 'mechanical', 'pianobar', 'siren', 'spacealarm', 'tugboat', 'alien', 'climb', 'persistent', 'echo', 'updown', 'none')]
        [string]$Sound
    )

    try {
        $payload = @{
            token   = $PoApiKey
            user    = $PoUserKey
            message = $Message
        }
        if ($PSBoundParameters.ContainsKey('Device') -and $Device) { $payload.device = $Device }
        if ($PSBoundParameters.ContainsKey('Title') -and $Title) { $payload.title = $Title }
        if ($PSBoundParameters.ContainsKey('Url') -and $Url) { $payload.url = $Url }
        if ($PSBoundParameters.ContainsKey('UrlTitle') -and $UrlTitle) { $payload.url_title = $UrlTitle }
        if ($PSBoundParameters.ContainsKey('Priority')) { $payload.priority = $Priority }
        if ($PSBoundParameters.ContainsKey('Sound') -and $Sound) { $payload.sound = $Sound }

        $sendPushoverRequestSplat = @{
            Payload     = $payload
            ErrorAction = 'Stop'
        }
        [void](Send-BridgePushoverRequest @sendPushoverRequestSplat)
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Αποτυχία αποστολής Pushover: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat

        $PSCmdlet.ThrowTerminatingError(
             [System.Management.Automation.ErrorRecord]::new(
                 ([System.Exception]::new("Αποτυχία αποστολής Pushover: $($_.Exception.Message)", $_.Exception)),
                 'PushoverSendError',
                 [System.Management.Automation.ErrorCategory]::ConnectionError,
                 $Message
             )
         )
    }
}
