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

    .PARAMETER Retry
    Διάστημα επανάληψης σε δευτερόλεπτα (30-10800), υποχρεωτικό όταν Priority είναι 2.

    .PARAMETER Expire
    Διάρκεια λήξης σε δευτερόλεπτα (1-10800), υποχρεωτικό όταν Priority είναι 2.

    .PARAMETER Sound
    Ο ήχος ειδοποίησης (προαιρετικό).

    .PARAMETER Configuration
    Αντικείμενο ρυθμίσεων που δημιουργείται από New-BridgeConfiguration.

    .OUTPUTS
    None.

    .EXAMPLE
    Send-BridgePushover -PoUserKey 'user123' -PoApiKey 'token123' -Message 'Η γέφυρα είναι ανοιχτή.'

    .NOTES
    Χρησιμοποιεί εσωτερικές helper συναρτήσεις για payload και αποστολή.
    #>
function Send-BridgePushover {
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
        [ValidateRange(30, 10800)][int]$Retry,
        [ValidateRange(1, 10800)][int]$Expire,
        [ValidateSet('pushover', 'bike', 'bugle', 'cashregister', 'classical', 'cosmic', 'falling', 'gamelan', 'incoming', 'intermission', 'magic', 'mechanical', 'pianobar', 'siren', 'spacealarm', 'tugboat', 'alien', 'climb', 'persistent', 'echo', 'updown', 'none')]
        [string]$Sound,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    try {
        if ($PSBoundParameters.ContainsKey('Priority') -and $Priority -eq 2 -and (-not $PSBoundParameters.ContainsKey('Retry') -or -not $PSBoundParameters.ContainsKey('Expire'))) {
            throw [System.ArgumentException]::new('Οι παράμετροι Retry και Expire είναι υποχρεωτικές όταν το Priority είναι 2 (Emergency).')
        }

        $payload = @{
            token   = $PoApiKey
            user    = $PoUserKey
            message = $Message
        }
        $optionalMap = @{
            Device   = 'device'
            Title    = 'title'
            Url      = 'url'
            UrlTitle = 'url_title'
            Priority = 'priority'
            Retry    = 'retry'
            Expire   = 'expire'
            Sound    = 'sound'
        }
        foreach ($paramName in $optionalMap.Keys) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $payload[$optionalMap[$paramName]] = $PSBoundParameters[$paramName]
            }
        }

        $sendPushoverRequestSplat = @{
            Payload       = $payload
            ErrorAction   = 'Stop'
            Configuration = $Configuration
        }
        [void](Send-BridgePushoverRequest @sendPushoverRequestSplat)
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Αποτυχία αποστολής Pushover: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

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
