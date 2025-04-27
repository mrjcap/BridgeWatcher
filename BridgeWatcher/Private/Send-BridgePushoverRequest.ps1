function Send-BridgePushoverRequest {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Αποστέλλει αίτημα ειδοποίησης στο API του Pushover.

    .DESCRIPTION
    Η Send-BridgePushoverRequest στέλνει ένα formatted payload
    στο Pushover API endpoint και επιστρέφει την απόκριση.

    .PARAMETER Payload
    Το hashtable με όλα τα απαιτούμενα δεδομένα.

    .OUTPUTS
    [object] - Το αποτέλεσμα του API ή $null σε σφάλμα.

    .EXAMPLE
    Send-BridgePushoverRequest -Payload $pushoverPayload

    .NOTES
    Χρησιμοποιεί Invoke-RestMethod με ErrorAction Stop για ασφαλή αποστολή.
    #>

    [OutputType([object])]
    param (
        [Parameter(Mandatory)][hashtable]$Payload
    )
    try {
        $invokeRestMethodSplat = @{
            Method      = 'Post'
            Uri         = 'https://api.pushover.net/1/messages.json'
            Body        = $Payload
            ErrorAction = 'Stop'
        }
        $writeBridgeLogSplat = @{
            Stage      = 'Ειδοποίηση'
            Message    = "➜ Αποστολή POST στο Pushover API..."
            Level      = 'Verbose'
        }
        Write-BridgeLog @writeBridgeLogSplat
        return Invoke-RestMethod @invokeRestMethodSplat
    } catch {
        $writeBridgeLogSplat = @{
            Stage      = 'Σφάλμα'
            Message    = "❌ Αποτυχία αποστολής: $($_.Exception.Message)"
            Level      = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        return $null
    }
}