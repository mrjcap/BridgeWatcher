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
    (Προαιρετικό) Αντικείμενο διαμόρφωσης. Αν δεν παρέχεται, δημιουργείται αυτόματα.

    .OUTPUTS
    None.

    .EXAMPLE
    Update-BridgeStatus -OutputFile 'C:\Logs\bridge-status.json' -ApiKey 'abc123' -PoUserKey 'user123' -PoApiKey 'token123'

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
        if (-not (Test-Path $OutputFile)) {
            $getDiorigaStatusSplat = @{
                OutputFile    = $OutputFile
                Configuration = $Configuration
            }
            $currentState = Get-BridgeStatus @getDiorigaStatusSplat -Configuration $Configuration
            $previousState = @()
        } else {
            $getDiorigaPreviousStatusSplat = @{
                InputFile     = $OutputFile
                Configuration = $Configuration
            }
            $previousState = Get-BridgePreviousStatus @getDiorigaPreviousStatusSplat -Configuration $Configuration
            $currentState = Get-BridgeStatus -Configuration $Configuration
        }

        # Reduce / Backfill State
        if ($previousState.Count -gt 0) {
            foreach ($curr in $currentState) {
                $prev = $previousState | Where-Object { $_.GefyraName -eq $curr.GefyraName } | Select-Object -First 1
                if ($prev) {
                    $ocrProps = @('From', 'To', 'ClosedFor', 'OpensIn', 'Note1', 'Note2')
                    foreach ($prop in $ocrProps) {
                        if ($prev.psobject.Properties.Match($prop).Count -gt 0 -and $null -ne $prev.$prop) {
                            $curr | Add-Member -MemberType NoteProperty -Name $prop -Value $prev.$prop -Force
                        }
                    }
                    if ([string]::IsNullOrEmpty($curr.ImageHash) -and -not [string]::IsNullOrEmpty($prev.ImageHash)) {
                        $curr | Add-Member -MemberType NoteProperty -Name 'ImageHash' -Value $prev.ImageHash -Force
                    }
                }
            }
        }

        if ($PSCmdlet.ShouldProcess("BridgeWatcher", "Update status and send notifications")) {
            $invokeSplat = @{
                PreviousState = $previousState
                CurrentState  = $currentState
                Configuration = $Configuration
            }
            $diffEvents = Invoke-BridgeStatusComparison @invokeSplat -Configuration $Configuration
            # Dispatch notifications based on diff events
            if ($null -ne $diffEvents -and $diffEvents.Count -gt 0) {
                foreach ($diffEvent in $diffEvents) {
                    $notificationSplat = @{
                        CurrentState  = $diffEvent.StateInfo
                        PoUserKey     = $PoUserKey
                        PoApiKey      = $PoApiKey
                        Configuration = $Configuration
                    }
                    if ($diffEvent.Type -eq 'Closed') {
                        $notificationSplat.ApiKey = $ApiKey
                        Invoke-BridgeClosedNotification @notificationSplat
                    } else {
                        Invoke-BridgeOpenedNotification @notificationSplat
                    }
                }
            }

            $exportBridgeStatusJsonSplat = @{
                Data          = $currentState
                Path          = $OutputFile
                Configuration = $Configuration
            }
            $null = Export-BridgeStatusJson @exportBridgeStatusJsonSplat
            return $currentState
        }
        $writeBridgeLogSplat.Message = 'Finished comparison and saved snapshot.'
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
    }
}


