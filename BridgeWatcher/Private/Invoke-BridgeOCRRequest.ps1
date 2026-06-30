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
        [Parameter(Mandatory)][SecureString]$ApiKey,
        [Parameter(Mandatory)][string]$RequestBody,
        [Parameter()][PSCustomObject]$Configuration
    )

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
    }

    # Κατασκευή URL χωρίς API key — το κλειδί πηγαίνει στο header
    $url = if ($Configuration -and $Configuration.OCRApiUrl) {
        "$($Configuration.OCRApiUrl)"
    } else {
        "https://vision.googleapis.com/v1/images:annotate"
    }
    $plainApiKey = [System.Net.NetworkCredential]::new('', $ApiKey).Password

    try {
        $invokeRestMethodSplat = @{
            Uri         = $url
            Method      = 'Post'
            Body        = $RequestBody
            ContentType = 'application/json'
            Headers     = @{ 'X-Goog-Api-Key' = $plainApiKey }
            ErrorAction = 'Stop'
        }
        $writeBridgeLogSplat = @{
            Stage   = $analysisStage
            Message = $startMessage
        }
        Write-BridgeLog @writeBridgeLogSplat

        $maxRetries = 3
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                return Invoke-RestMethod @invokeRestMethodSplat
            } catch [System.Net.WebException] {
                $response = $_.Exception.Response
                if ($response -and $response.StatusCode -in @(400, 401, 403)) {
                    throw
                }
                if ($i -eq $maxRetries) { throw }
                Start-Sleep -Seconds ([Math]::Pow(2, $i))
            } catch {
                if ($i -eq $maxRetries) { throw }
                Start-Sleep -Seconds ([Math]::Pow(2, $i))
            }
        }
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
