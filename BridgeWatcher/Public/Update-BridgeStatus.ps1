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
            # Το αρχείο δεν υπάρχει – πρώτη εκτέλεση
            # Χρήση κενού array ώστε η πρώτη κατάσταση να ενεργοποιεί ειδοποιήσεις
            $getDiorigaStatusSplat = @{
                OutputFile    = $OutputFile
                Configuration = $Configuration
            }
            $currentState = Get-BridgeStatus @getDiorigaStatusSplat -Configuration $Configuration
            $previousState = @()
        } else {
            # Το αρχείο υπάρχει, μπορείς να το διαβάσεις με ασφάλεια
            $getDiorigaPreviousStatusSplat = @{
                InputFile     = $OutputFile
                Configuration = $Configuration
            }
            $previousState = Get-BridgePreviousStatus @getDiorigaPreviousStatusSplat -Configuration $Configuration
            $currentState = Get-BridgeStatus -Configuration $Configuration
        }
        if ($PSCmdlet.ShouldProcess("BridgeWatcher", "Update status and send notifications")) {
            $invokeSplat = @{
                PreviousState = $previousState
                CurrentState  = $currentState
                ApiKey        = $ApiKey
                PoUserKey     = $PoUserKey
                PoApiKey      = $PoApiKey
                Configuration = $Configuration
            }
            $null = Invoke-BridgeStatusComparison @invokeSplat -Configuration $Configuration
            $exportBridgeStatusJsonSplat = @{
                Data          = $currentState
                Path          = $OutputFile
                Configuration = $Configuration
            }
            $null = Export-BridgeStatusJson @exportBridgeStatusJsonSplat
            return $currentState
        }
        $writeBridgeLogSplat = @{
            Stage   = $Configuration.LoggingConfig.InfoStage
            Message = 'Finished comparison and saved snapshot.'
            Level   = $Configuration.LoggingConfig.VerboseLevel
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
    }
}


