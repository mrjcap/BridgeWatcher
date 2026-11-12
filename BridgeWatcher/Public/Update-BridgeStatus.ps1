<#
    .SYNOPSIS
    Ελέγχει το αποτέλεσμα εξαγωγής JSON και εγείρει τερματικό σφάλμα σε αποτυχία.

    .PARAMETER ExportResult
    Το αποτέλεσμα της Export-BridgeStatusJson.

    .PARAMETER OutputFile
    Η διαδρομή του αρχείου εξόδου.

    .PARAMETER Cmdlet
    Το αντικείμενο PSCmdlet του καλούντος.
    #>
function Assert-BridgeSnapshotExport {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$ExportResult,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputFile,
        [Parameter(Mandatory)][ValidateNotNull()][System.Management.Automation.PSCmdlet]$Cmdlet
    )
    if (-not $ExportResult.Success) {
        $Cmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new($ExportResult.ErrorMessage),
            $ExportResult.ErrorCode,
            [System.Management.Automation.ErrorCategory]::WriteError,
            $OutputFile
        ))
    }
}

<#
    .SYNOPSIS
    Αποστέλλει την κατάλληλη ειδοποίηση για ένα συμβάν αλλαγής γέφυρας.

    .PARAMETER DiffEvent
    Το συμβάν διαφοράς κατάστασης γέφυρας.

    .PARAMETER ApiKey
    Το API Key για OCR ανάλυση.

    .PARAMETER PoUserKey
    Το User Key του παραλήπτη Pushover.

    .PARAMETER PoApiKey
    Το API Token της εφαρμογής Pushover.

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης.
    #>
function Invoke-BridgeDiffEventDelivery {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$DiffEvent,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoApiKey,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    $notificationSplat = @{
        CurrentState  = $DiffEvent.StateInfo
        PoUserKey     = $PoUserKey
        PoApiKey      = $PoApiKey
        Configuration = $Configuration
    }
    if ($DiffEvent.Type -eq 'Closed') {
        $notificationSplat.ApiKey = $ApiKey
        Invoke-BridgeClosedNotification @notificationSplat
    } else {
        Invoke-BridgeOpenedNotification @notificationSplat
    }
}

<#
    .SYNOPSIS
    Συνθέτει το snapshot καταστάσεων προς αποθήκευση μετά από μερική επιτυχία ειδοποιήσεων.

    .DESCRIPTION
    Ξεκινά από την προηγούμενη κατάσταση ανά γέφυρα και ενημερώνει τις αμετάβλητες
    καθώς και όσες γέφυρες ειδοποιήθηκαν επιτυχώς με την τρέχουσα εγγραφή τους.

    .PARAMETER PreviousState
    Η προηγούμενη λίστα καταστάσεων γεφυρών.

    .PARAMETER CurrentState
    Η τρέχουσα λίστα καταστάσεων γεφυρών.

    .PARAMETER DiffEvents
    Τα γεγονότα αλλαγών κατάστασης που προέκυψαν από τη σύγκριση.

    .PARAMETER NotifiedBridgeNames
    Τα ονόματα των γεφυρών των οποίων η ειδοποίηση ολοκληρώθηκε επιτυχώς.
    #>
function Resolve-BridgeAlertSnapshot {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter()][AllowNull()][AllowEmptyCollection()][object[]]$PreviousState = @(),
        [Parameter()][AllowNull()][AllowEmptyCollection()][object[]]$CurrentState = @(),
        [Parameter()][AllowNull()][AllowEmptyCollection()][object[]]$DiffEvents = @(),
        [Parameter()][AllowNull()][AllowEmptyCollection()][string[]]$NotifiedBridgeNames = @()
    )
    $persistedByBridge = [ordered]@{}
    foreach ($entry in $PreviousState) {
        $persistedByBridge[$entry.GefyraName] = $entry
    }
    $pendingBridgeNames = @(
        $DiffEvents |
            ForEach-Object { @($_.StateInfo) } |
            ForEach-Object { $_.GefyraName } |
            Where-Object { $_ -notin $NotifiedBridgeNames }
    )
    foreach ($entry in $CurrentState) {
        if ($entry.GefyraName -notin $pendingBridgeNames) {
            $persistedByBridge[$entry.GefyraName] = $entry
        }
    }
    return @($persistedByBridge.Values)
}

<#
    .SYNOPSIS
    Συγκρίνει προηγούμενη και τρέχουσα κατάσταση γεφυρών.

    .DESCRIPTION
    Η Update-BridgeStatus συγκρίνει δύο snapshots γεφυρών
    και ανιχνεύει αλλαγές κατάστασης.

    .PARAMETER OutputFile
    Το path του αρχείου JSON για αποθήκευση νέου snapshot.

    .PARAMETER ApiKey
    Το API Key για OCR ανάλυση αν απαιτηθεί.

    .PARAMETER PoUserKey
    Το User Key του παραλήπτη για ειδοποίηση.

    .PARAMETER PoApiKey
    Το API Token της εφαρμογής Pushover.

    .PARAMETER Configuration
    Αντικείμενο διαμόρφωσης με ρυθμίσεις, statuses και URLs.

    .OUTPUTS
    [object[]]

    .EXAMPLE
    Update-BridgeStatus -OutputFile 'C:\Logs\bridge-status.json' -ApiKey 'abc123' -PoUserKey 'user123' -PoApiKey 'token123' -Configuration $Config

    .NOTES
    Χρησιμοποιεί OCR αν χρειάζεται, συγκρίνει states και αποστέλλει ειδοποιήσεις.
    #>
function Update-BridgeStatus {
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([object[]])]

    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputFile,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoApiKey,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    begin {
        # Initialize configuration. This is safe to run during -WhatIf as it only creates a memory object
        # and does not modify any system state.
    }
    process {
        $writeBridgeLogSplat = @{
            Stage   = $Configuration.LoggingConfig.InfoStage
            Message = 'Starting comparison...'
            Level   = $Configuration.LoggingConfig.VerboseLevel
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        $previousState = @()
        if (Test-Path $OutputFile) {
            $getDiorigaPreviousStatusSplat = @{
                InputFile     = $OutputFile
                Configuration = $Configuration
            }
            $previousState = Get-BridgePreviousStatus @getDiorigaPreviousStatusSplat
        }
        $currentState = Get-BridgeStatus -Configuration $Configuration

        if ($PSCmdlet.ShouldProcess("BridgeWatcher", "Update status and send notifications")) {
            $invokeSplat = @{
                PreviousState = $previousState
                CurrentState  = $currentState
                Configuration = $Configuration
            }
            $diffEvents = Invoke-BridgeStatusComparison @invokeSplat
            # Checkpoint successful deliveries independently, keeping failed bridges pending.
            $notifiedBridgeNames = [System.Collections.Generic.List[string]]::new()
            $notificationFailures = @()
            foreach ($diffEvent in $diffEvents) {
                $deliverySplat = @{
                    DiffEvent     = $diffEvent
                    ApiKey        = $ApiKey
                    PoUserKey     = $PoUserKey
                    PoApiKey      = $PoApiKey
                    Configuration = $Configuration
                }
                try {
                    Invoke-BridgeDiffEventDelivery @deliverySplat
                } catch {
                    $notificationFailures += $_
                    continue
                }

                $eventBridgeNames = [string[]]@($diffEvent.StateInfo | ForEach-Object { [string]$_.GefyraName })
                $notifiedBridgeNames.AddRange($eventBridgeNames)
                $snapshotSplat = @{
                    PreviousState       = $previousState
                    CurrentState        = $currentState
                    DiffEvents          = @($diffEvents)
                    NotifiedBridgeNames = $notifiedBridgeNames.ToArray()
                }
                $checkpointState = @(Resolve-BridgeAlertSnapshot @snapshotSplat)
                $checkpointResult = Export-BridgeStatusJson -Data $checkpointState -Path $OutputFile -Configuration $Configuration
                Assert-BridgeSnapshotExport -ExportResult $checkpointResult -OutputFile $OutputFile -Cmdlet $PSCmdlet
            }
            if ($notificationFailures.Count -gt 0) {
                $PSCmdlet.ThrowTerminatingError($notificationFailures[0])
            }

            $exportBridgeStatusJsonSplat = @{
                Data          = $currentState
                Path          = $OutputFile
                Configuration = $Configuration
            }
            $exportResult = Export-BridgeStatusJson @exportBridgeStatusJsonSplat
            Assert-BridgeSnapshotExport -ExportResult $exportResult -OutputFile $OutputFile -Cmdlet $PSCmdlet
        }
        $writeBridgeLogSplat.Message = 'Finished comparison and saved snapshot.'
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        return $currentState
    }
}
