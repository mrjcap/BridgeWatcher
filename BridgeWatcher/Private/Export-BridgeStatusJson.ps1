function Export-BridgeStatusJson {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Εξάγει την κατάσταση γέφυρας σε αρχείο JSON.

    .DESCRIPTION
    Η Export-BridgeStatusJson αποθηκεύει δεδομένα κατάστασης γέφυρας σε μορφή JSON
    σε καθορισμένη διαδρομή.

    .PARAMETER Data
    Το αντικείμενο ή η λίστα αντικειμένων που θα εξαχθεί.

    .PARAMETER Path
    Η πλήρης διαδρομή του αρχείου εξόδου.

    .PARAMETER JsonDepth
    Το βάθος serialization του JSON (προεπιλογή: 10).

    .PARAMETER Configuration
    Το configuration object που περιέχει τις ρυθμίσεις.

    .OUTPUTS
    None.

    .EXAMPLE
    Export-BridgeStatusJson -Data $bridgeStatus -Path 'C:\Logs\status.json'

    .NOTES
    Χρησιμοποιεί ConvertTo-Json και Set-Content για ασφαλή αποθήκευση.
    #>
    [OutputType([void])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][object[]]$Data,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter()][ValidateRange(1, 20)][int]$JsonDepth,
        [Parameter()][PSCustomObject]$Configuration
    )

    # Get JSON depth from configuration or parameter or use fallback
    if (-not $JsonDepth) {
        $JsonDepth = if ($Configuration -and $Configuration.DefaultJsonDepth) {
            $Configuration.DefaultJsonDepth
        } else {
            10
        }
    }

    # Get messages from configuration or use fallback
    $successMessage = if ($Configuration -and $Configuration.ExportMessages -and $Configuration.ExportMessages.Success) {
        $Configuration.ExportMessages.Success
    } else {
        '✅ JSON αποθηκεύτηκε στο'
    }

    $failedMessage = if ($Configuration -and $Configuration.ExportMessages -and $Configuration.ExportMessages.Failed) {
        $Configuration.ExportMessages.Failed
    } else {
        '❌ Σφάλμα κατά την αποθήκευση JSON'
    }

    $directoryNotExistsMessage = if ($Configuration -and $Configuration.ExportMessages -and $Configuration.ExportMessages.DirectoryNotExists) {
        $Configuration.ExportMessages.DirectoryNotExists
    } else {
        'Ο φάκελος προορισμού δεν υπάρχει'
    }

    # Get logging stage from configuration or use fallback
    $analysisStage = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.InfoStage) {
        $Configuration.LoggingConfig.InfoStage
    } else {
        'Ανάλυση'
    }

    $errorStage = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.ErrorStage) {
        $Configuration.LoggingConfig.ErrorStage
    } else {
        'Σφάλμα'
    }

    $warningLevel = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.WarningLevel) {
        $Configuration.LoggingConfig.WarningLevel
    } else {
        'Warning'
    }

    try {
        $convertToJsonSplat = @{
            Depth    = $JsonDepth
            Compress = $true
        }
        if (-not (Test-Path -Path (Split-Path -Parent $Path))) {
            throw "$directoryNotExistsMessage`: $(Split-Path -Parent $Path)"
        }
        $json = $Data | ConvertTo-Json @convertToJsonSplat
        $setContentSplat = @{
            Path     = $Path
            Value    = $json
            Encoding = 'utf8BOM'
        }
        Set-Content @setContentSplat
        $writeBridgeLogSplat = @{
            Stage   = $analysisStage
            Message = "$successMessage`: $Path"
        }
        Write-BridgeLog @writeBridgeLogSplat
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = $errorStage
            Message = "$failedMessage`: $($_.Exception.Message)"
            Level   = $warningLevel
        }
        Write-BridgeLog @writeBridgeLogSplat
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Σφάλμα αποθήκευσης JSON: $($_.Exception.Message)")),
            'JsonExportFailure',
            [System.Management.Automation.ErrorCategory]::WriteError,
            $Path
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}