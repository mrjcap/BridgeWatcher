function Export-BridgeStatusJson {
    <#
    .SYNOPSIS
    Εξάγει την κατάσταση γέφυρας σε αρχείο JSON.

    .DESCRIPTION
    Η Export-BridgeStatusJson αποθηκεύει δεδομένα κατάστασης γέφυρας σε μορφή JSON
    σε καθορισμένη διαδρομή. Τώρα επιστρέφει BridgeResult object για καλύτερο
    error handling και pipeline integration.

    .PARAMETER Data
    Το αντικείμενο ή η λίστα αντικειμένων που θα εξαχθεί.

    .PARAMETER Path
    Η πλήρης διαδρομή του αρχείου εξόδου.

    .PARAMETER JsonDepth
    Το βάθος serialization του JSON (προεπιλογή: 10).

    .PARAMETER Configuration
    Το configuration object που περιέχει τις ρυθμίσεις.

    .OUTPUTS
    [PSCustomObject] - BridgeResult object με Success, Data, ErrorMessage, ErrorCode, Timestamp.

    .EXAMPLE
    $exportResult = Export-BridgeStatusJson -Data $bridgeStatus -Path 'C:\Logs\status.json'
    if (Test-BridgeResult $exportResult) {
        Write-Host "Export successful"
    }

    .NOTES
    Χρησιμοποιεί New-BridgeResult για τυποποιημένη επιστροφή αποτελεσμάτων.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [object[]]$Data,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter()]
        [ValidateRange(1, 20)]
        [int]$JsonDepth,

        [Parameter()]
        [PSCustomObject]$Configuration
    )

    if (-not $Configuration) {
        $Configuration = New-BridgeConfiguration
    }

    # Get JSON depth from configuration or parameter or use fallback
    if (-not $JsonDepth) {
        $JsonDepth = $Configuration.DefaultJsonDepth
    }

    # Get messages from configuration or use fallback
    $successMessage = $Configuration.ExportMessages.Success

    $failedMessage = $Configuration.ExportMessages.Failed

    $directoryNotExistsMessage = $Configuration.ExportMessages.DirectoryNotExists

    # Get logging stage from configuration or use fallback
    $analysisStage = $Configuration.LoggingConfig.InfoStage

    $errorStage = $Configuration.LoggingConfig.ErrorStage

    $warningLevel = $Configuration.LoggingConfig.WarningLevel

    try {
        $convertToJsonSplat = @{
            Depth    = $JsonDepth
            Compress = $true
        }

        if (-not (Test-Path -Path (Split-Path -Parent $Path))) {
            $errorMessage = "$directoryNotExistsMessage`: $(Split-Path -Parent $Path)"
            $writeBridgeLogSplat = @{
                Stage   = $errorStage
                Message = $errorMessage
                Level   = $warningLevel
            }
            Write-BridgeLog @writeBridgeLogSplat

            return New-BridgeResult -Success $false -ErrorMessage $errorMessage -ErrorCode 'DIRECTORY_NOT_EXISTS'
        }

        $json = $Data | ConvertTo-Json @convertToJsonSplat
        $tmpPath = "$Path.tmp"
        $setContentSplat = @{
            Path  = $tmpPath
            Value = $json
        }
        Set-Content @setContentSplat
        Move-Item -Path $tmpPath -Destination $Path -Force

        $writeBridgeLogSplat = @{
            Stage   = $analysisStage
            Message = "$successMessage`: $Path"
        }
        Write-BridgeLog @writeBridgeLogSplat

        return New-BridgeResult -Success $true -Data @{ ExportedPath = $Path; RecordCount = $Data.Count }
    }
    catch {
        $errorMessage = "$failedMessage`: $($_.Exception.Message)"
        $writeBridgeLogSplat = @{
            Stage   = $errorStage
            Message = $errorMessage
            Level   = $warningLevel
        }
        Write-BridgeLog @writeBridgeLogSplat

        return New-BridgeResult -Success $false -ErrorMessage $errorMessage -ErrorCode 'JSON_EXPORT_FAILURE'
    }
}

