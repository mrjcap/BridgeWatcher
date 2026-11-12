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
            $checkpointState = @($previousState)
            $notificationFailures = @()
            foreach ($diffEvent in $diffEvents) {
                $notificationSplat = @{
                    CurrentState  = $diffEvent.StateInfo
                    PoUserKey     = $PoUserKey
                    PoApiKey      = $PoApiKey
                    Configuration = $Configuration
                }
                try {
                    if ($diffEvent.Type -eq 'Closed') {
                        $notificationSplat.ApiKey = $ApiKey
                        Invoke-BridgeClosedNotification @notificationSplat
                    } else {
                        Invoke-BridgeOpenedNotification @notificationSplat
                    }
                } catch {
                    $notificationFailures += $_
                    continue
                }

                $notifiedBridgeNames = @($diffEvent.StateInfo.GefyraName)
                $checkpointState = @($checkpointState | Where-Object {
                    $_.GefyraName -notin $notifiedBridgeNames
                }) + @($diffEvent.StateInfo)
                $checkpointResult = Export-BridgeStatusJson -Data $checkpointState -Path $OutputFile -Configuration $Configuration
                if (-not $checkpointResult.Success) {
                    # Do not send more notifications if their progress cannot be saved.
                    $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new($checkpointResult.ErrorMessage),
                        $checkpointResult.ErrorCode,
                        [System.Management.Automation.ErrorCategory]::WriteError,
                        $OutputFile
                    ))
                }
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
            if (-not $exportResult.Success) {
                $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new($exportResult.ErrorMessage),
                    $exportResult.ErrorCode,
                    [System.Management.Automation.ErrorCategory]::WriteError,
                    $OutputFile
                ))
            }
        }
        $writeBridgeLogSplat.Message = 'Finished comparison and saved snapshot.'
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        return $currentState
    }
}
