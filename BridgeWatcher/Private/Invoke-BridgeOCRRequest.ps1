function Invoke-BridgeOCRRequest {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Αποστέλλει OCR αίτημα σε υπηρεσία.

    .DESCRIPTION
    Η Invoke-BridgeOCRRequest στέλνει HTTP POST αίτημα με σώμα εικόνας
    για OCR ανάλυση μέσω Google Vision API.

    .PARAMETER ApiKey
    Το API Key της υπηρεσίας OCR.

    .PARAMETER RequestBody
    Το JSON σώμα του αιτήματος.

    .PARAMETER Configuration
    Το configuration object που περιέχει τις ρυθμίσεις.

    .OUTPUTS
    [object] - Το αποτέλεσμα του OCR API.

    .EXAMPLE
    Invoke-BridgeOCRRequest -ApiKey 'your-api-key' -RequestBody $jsonBody

    .NOTES
    Χρησιμοποιεί Invoke-RestMethod με ασφαλή error handling.
    #>

    [OutputType([object])]
    param (
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$RequestBody,
        [Parameter()][PSCustomObject]$Configuration
    )    # Get OCR API URL from configuration or use fallback
    $url = if ($Configuration -and $Configuration.OCRApiUrl) {
        "$($Configuration.OCRApiUrl)?key=$ApiKey"
    } else {
        "https://vision.googleapis.com/v1/images:annotate?key=$ApiKey"
    }

    # Get messages from configuration or use fallback
    $startMessage = if ($Configuration -and $Configuration.OCRMessages -and $Configuration.OCRMessages.StartOCR) {
        $Configuration.OCRMessages.StartOCR
    } else {
        '➜ Calling Google Vision API...'
    }

    $failedMessagePrefix = if ($Configuration -and $Configuration.OCRMessages -and $Configuration.OCRMessages.OCRFailed) {
        $Configuration.OCRMessages.OCRFailed
    } else {
        '❌ Request failed'
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
    }    $url = if ($Configuration -and $Configuration.OCRApiUrl) {
        "$($Configuration.OCRApiUrl)?key=$ApiKey"
    } else {
        "https://vision.googleapis.com/v1/images:annotate?key=$ApiKey"
    }
    try {
        $invokeRestMethodSplat = @{
            Uri         = $url
            Method      = 'Post'
            Body        = $RequestBody
            ContentType = 'application/json'
            ErrorAction = 'Stop'
        }
        $writeBridgeLogSplat = @{
            Stage   = $analysisStage
            Message = $startMessage
        }
        Write-BridgeLog @writeBridgeLogSplat
        return Invoke-RestMethod @invokeRestMethodSplat
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = $errorStage
            Message = "$failedMessagePrefix`: $($_.Exception.Message)"
            Level   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.WarningLevel) {
                $Configuration.LoggingConfig.WarningLevel
            } else {
                'Warning'
            }
        }
        Write-BridgeLog @writeBridgeLogSplat
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Google Vision API call failed: $($_.Exception.Message)")),
            'GoogleVisionRequestFailure',
            [System.Management.Automation.ErrorCategory]::ConnectionError,
            $url
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}