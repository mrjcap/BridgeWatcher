function Invoke-BridgeOpenedNotification {
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
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)][object[]]$CurrentState,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoApiKey,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter()][scriptblock]$NotificationProvider
    )
    $null = $PoUserKey; $null = $PoApiKey; $null = $NotificationProvider

    $SendNotification = {
        param(
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
            [string]$Title,
            [string]$Message,
            [string]$Type
        )
        if ($NotificationProvider) {
            & $NotificationProvider -Title $Title -Message $Message -Type $Type
        } else {
            $pushoverSplat = @{
                PoUserKey     = $PoUserKey
                PoApiKey      = $PoApiKey
                Title         = $Title
                Message       = $Message
                ErrorAction   = 'Stop'
                Configuration = $Configuration
            }
            Send-BridgePushover @pushoverSplat
        }
    }

    foreach ($entry in $CurrentState) {
        if ($entry.gefyraStatus -eq $Configuration.Statuses.Open) {
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
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                & $SendNotification -Title 'Γέφυρα Ανοιχτή!' -Message "Η γέφυρα της $($entry.gefyraName)ς άνοιξε" -Type 'Opened' -Configuration $Configuration
            } catch {
                $err = $_
                $writeBridgeLogSplat = @{
                    Stage   = 'Σφάλμα'
                    Message = "❌ Αποτυχία αποστολής ειδοποίησης ανοίγματος για $($entry.gefyraName): $($err.Exception.Message)"
                    Level   = 'Warning'
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Αποτυχία αποστολής ειδοποίησης ανοίγματος για $($entry.gefyraName)", $err.Exception),
                    'NotificationFailed',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $entry
                ))
            }
        }
    }
}
