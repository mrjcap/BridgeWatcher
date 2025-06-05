function Invoke-BridgeOpenedNotification {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Στέλνει ειδοποίηση ότι η γέφυρα άνοιξε.

    .DESCRIPTION
    Η Invoke-BridgeOpenedNotification αποστέλλει ειδοποίηση όταν ανιχνευτεί
    ότι η γέφυρα έχει ανοίξει.

    .PARAMETER CurrentState
    Η λίστα καταστάσεων των γεφυρών.

    .PARAMETER PoUserKey
    Το Pushover User Key του παραλήπτη.

    .PARAMETER PoApiKey
    Το Pushover API Token της εφαρμογής.

    .OUTPUTS
    None.

    .EXAMPLE
    Invoke-BridgeOpenedNotification -CurrentState $state -PoUserKey 'user123' -PoApiKey 'token123'

    .NOTES
    Στέλνει μόνο για γεφυρες με κατάσταση 'Ανοιχτή'.
    #>

    [OutputType([void])]
    param (
        [Parameter(Mandatory)][object[]]$CurrentState,
        [Parameter(Mandatory)][string]$PoUserKey,
        [Parameter(Mandatory)][string]$PoApiKey
    )
    foreach ($entry in $CurrentState) {
        if ($entry.gefyraStatus -eq 'Ανοιχτή') {
            $writeBridgeLogSplat = @{
                Stage   = 'Ανάλυση'
                Message = "Γέφυρα        : $($entry.GefyraName)"
            }
            Write-BridgeLog @writeBridgeLogSplat
            $writeBridgeLogSplat = @{
                Stage   = 'Ανάλυση'
                Message = "Κατάσταση     : $($entry.GefyraStatus)"
            }
            Write-BridgeLog @writeBridgeLogSplat
            $writeBridgeLogSplat = @{
                Stage = 'Ανάλυση'
                Message   = "Χρονική στιγμή: $($entry.Timestamp)"
            }
            Write-BridgeLog @writeBridgeLogSplat
            $writeBridgeLogSplat = @{
                Stage   = 'Ανάλυση'
                Message = "Εικόνα        : $($entry.ImageUrl)"
            }
            Write-BridgeLog @writeBridgeLogSplat
            $sendPushoverSplat = @{
                PoUserKey = $PoUserKey
                PoApiKey  = $PoApiKey
                Title     = 'Γέφυρα Ανοιχτή!'
                Message   = "Η γέφυρα της $($entry.gefyraName)ς άνοιξε"
            }
            Send-BridgePushover @sendPushoverSplat
        }
    }
}