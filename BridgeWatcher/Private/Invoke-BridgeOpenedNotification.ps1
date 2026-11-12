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

    .PARAMETER NotificationProvider
    Εναλλακτικός πάροχος ειδοποιήσεων.

    .OUTPUTS
    None.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey', Justification = 'Keys are provided securely from the environment, using SecureString here breaks backward compatibility.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey', Justification = 'Keys are provided securely from the environment, using SecureString here breaks backward compatibility.')]
    [CmdletBinding(DefaultParameterSetName = 'Pushover')]
    [OutputType([void])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$CurrentState,

        [Parameter(Mandatory, ParameterSetName = 'Pushover')]
        [ValidateNotNullOrEmpty()]
        [string]$PoUserKey,

        [Parameter(Mandatory, ParameterSetName = 'Pushover')]
        [ValidateNotNullOrEmpty()]
        [string]$PoApiKey,

        [Parameter(Mandatory, ParameterSetName = 'CustomProvider')]
        [ValidateNotNull()]
        [scriptblock]$NotificationProvider,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$Configuration
    )

    process {
        foreach ($entry in $CurrentState) {
            if ($null -ne $entry -and $Configuration.Statuses.Open -eq $entry.GefyraStatus) {
                try {
                    $logDetails = @"
Γέφυρα        : $($entry.GefyraName)
Κατάσταση     : $($entry.GefyraStatus)
Χρονική στιγμή: $($entry.Timestamp)
Εικόνα        : $($entry.ImageUrl)
"@
                    $writeBridgeLogSplat = @{
                        Stage   = 'Ανάλυση'
                        Message = $logDetails
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

                    Send-BridgeNotification -Configuration $Configuration -Title 'Γέφυρα Ανοιχτή!' -Message "Η γέφυρα $($entry.GefyraName) άνοιξε" -Type 'Opened' -PoUser $PoUserKey -PoApi $PoApiKey -Provider $NotificationProvider
                } catch [System.Net.WebException], [System.Management.Automation.MethodInvocationException] {
                    $err = $_
                    $writeBridgeLogSplat = @{
                        Stage   = 'Σφάλμα'
                        Message = "❌ Αποτυχία αποστολής ειδοποίησης ανοίγματος για $($entry.GefyraName): $($err.Exception.Message)"
                        Level   = 'Warning'
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                    $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Αποτυχία αποστολής ειδοποίησης ανοίγματος για $($entry.GefyraName)", $err.Exception),
                        'NotificationFailed',
                        [System.Management.Automation.ErrorCategory]::InvalidOperation,
                        $entry
                    ))
                }
            }
        }
    }
}
