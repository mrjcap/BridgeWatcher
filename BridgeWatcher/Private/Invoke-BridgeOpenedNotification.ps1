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
            try {
                # Συνδυασμός log messages για αποφυγή spam
                $logDetails = @(
                    "Γέφυρα        : $($entry.GefyraName)",
                    "Κατάσταση     : $($entry.GefyraStatus)",
                    "Χρονική στιγμή: $($entry.Timestamp)",
                    "Εικόνα        : $($entry.ImageUrl)"
                ) -join "`n"

                $writeBridgeLogSplat = @{
                    Stage   = 'Ανάλυση'
                    Message = $logDetails
                }
                Write-BridgeLog @writeBridgeLogSplat
                $sendPushoverSplat = @{
                    PoUserKey   = $PoUserKey
                    PoApiKey    = $PoApiKey
                    Title       = 'Γέφυρα Ανοιχτή!'
                    Message     = "Η γέφυρα της $($entry.gefyraName)ς άνοιξε"
                    ErrorAction = 'Stop'
                }
                Send-BridgePushover @sendPushoverSplat
            } catch {
                $writeBridgeLogSplat = @{
                    Stage   = 'Σφάλμα'
                    Message = "❌ Αποτυχία αποστολής ειδοποίησης ανοίγματος για $($entry.gefyraName): $($_.Exception.Message)"
                    Level   = 'Warning'
                }
                Write-BridgeLog @writeBridgeLogSplat

                $PSCmdlet.ThrowTerminatingError(
                    [System.Management.Automation.ErrorRecord]::new(
                        ([System.Exception]::new("Αποτυχία αποστολής ειδοποίησης ανοίγματος: $($_.Exception.Message)")),
                        'BridgeOpenedNotificationError',
                        [System.Management.Automation.ErrorCategory]::ConnectionError,
                        $entry
                    )
                )
            }
        }
    }
}