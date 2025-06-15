function Send-BridgeNotification {
    <#
    .SYNOPSIS
    Στέλνει ειδοποίηση ανάλογα με την κατάσταση της γέφυρας (άνοιγμα ή κλείσιμο).

    .DESCRIPTION
    Η Send-BridgeNotification καλεί το κατάλληλο notification handler (Invoke-BridgeOpenedNotification ή Invoke-BridgeClosedNotification)
    ανάλογα με το αν η γέφυρα άνοιξε ή έκλεισε. Τα credentials και τα δεδομένα κατάστασης περνάνε μέσω splatting, εξασφαλίζοντας καθαρότητα και auditability.
    Υποστηρίζει ειδοποιήσεις τύπου 'Closed' και 'Opened' και απαιτεί τις σχετικές παραμέτρους (API key, User key) να υπάρχουν στο scope.

    .PARAMETER Type
    Ο τύπος ειδοποίησης που θα σταλεί ('Closed' για κλείσιμο, 'Opened' για άνοιγμα).

    .PARAMETER State
    Η λίστα κατάστασης γεφυρών που σχετίζεται με την ειδοποίηση.

    .EXAMPLE
    Send-BridgeNotification -Type 'Closed' -State $currentState

    Στέλνει notification για κλείσιμο γέφυρας στο $currentState.

    .EXAMPLE
    Send-BridgeNotification -Type 'Opened' -State $currentState

    Στέλνει notification για άνοιγμα γέφυρας στο $currentState.

    .NOTES
    Οι μεταβλητές $PoUserKey, $PoApiKey και (για 'Closed') $ApiKey πρέπει να υπάρχουν στο scope της function.
    Η function χρησιμοποιεί splatting για καθαρότητα και ευκολία επεκτασιμότητας.
    #>    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Closed', 'Opened')]$Type,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][object[]]$State,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoApiKey
    )
    $splat = @{
        CurrentState = $State
        PoUserKey    = $PoUserKey
        PoApiKey     = $PoApiKey
    }
    if ($Type -eq 'Closed') {
        $splat.ApiKey = $ApiKey
        Invoke-BridgeClosedNotification @splat
    }
    else {
        Invoke-BridgeOpenedNotification @splat
    }
}