function Get-BridgeStatusComparison {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ApiKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
    [CmdletBinding()]
    [OutputType([void])]
    <#
    .SYNOPSIS
    Συγκρίνει προηγούμενη και τρέχουσα κατάσταση γεφυρών.

    .DESCRIPTION
    Η Get-BridgeStatusComparison συγκρίνει δύο snapshots γεφυρών
    και ανιχνεύει αλλαγές κατάστασης.

    .PARAMETER OutputFile
    Το path του αρχείου JSON για αποθήκευση νέου snapshot.

    .PARAMETER ApiKey
    Το API Key για OCR ανάλυση αν απαιτηθεί.

    .PARAMETER PoUserKey
    Το User Key του παραλήπτη για ειδοποίηση.

    .PARAMETER PoApiKey
    Το API Token της εφαρμογής Pushover.

    .OUTPUTS
    None.

    .EXAMPLE
    Get-BridgeStatusComparison -OutputFile 'C:\Logs\bridge-status.json' -ApiKey 'abc123' -PoUserKey 'user123' -PoApiKey 'token123'

    .NOTES
    Χρησιμοποιεί OCR αν χρειάζεται, συγκρίνει states και αποστέλλει ειδοποιήσεις.
    #>

    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputFile,
        [Parameter(Mandatory)][SecureString]$ApiKey,
        [Parameter(Mandatory)][SecureString]$PoUserKey,
        [Parameter(Mandatory)][SecureString]$PoApiKey
    )
    $writeBridgeLogSplat = @{
        Stage   = 'Ανάλυση'
        Message = 'Starting comparison...'
        Level   = "Verbose"
    }
    Write-BridgeLog @writeBridgeLogSplat
    if (-not (Test-Path $OutputFile)) {
        # Το αρχείο δεν υπάρχει – πρώτη εκτέλεση
        $getDiorigaStatusSplat = @{
            OutputFile = $OutputFile
        }
        $currentState = Get-BridgeStatus @getDiorigaStatusSplat
        $previousState = $currentState
    } else {
        # Το αρχείο υπάρχει, μπορείς να το διαβάσεις με ασφάλεια
        $getDiorigaPreviousStatusSplat = @{
            InputFile = $OutputFile
        }
        $previousState = Get-BridgePreviousStatus @getDiorigaPreviousStatusSplat
        $currentState = Get-BridgeStatus
    }
    $invokeSplat = @{
        PreviousState = $previousState
        CurrentState  = $currentState
        ApiKey        = $ApiKey
        PoUserKey     = $PoUserKey
        PoApiKey      = $PoApiKey
    }
    Invoke-BridgeStatusComparison @invokeSplat
    $exportBridgeStatusJsonSplat = @{
        Data = $currentState
        Path = $OutputFile
    }
    Export-BridgeStatusJson @exportBridgeStatusJsonSplat
    $writeBridgeLogSplat = @{
        Stage   = 'Ανάλυση'
        Message = 'Finished comparison and saved snapshot.'
        Level   = "Verbose"
    }
    Write-BridgeLog @writeBridgeLogSplat
}
