function Invoke-BridgeOCRRequest {
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
    Το αντικείμενο διαμόρφωσης που περιέχει τις ρυθμίσεις.
    .OUTPUTS
    [object] - Το αποτέλεσμα του OCR API.
    .EXAMPLE
    Invoke-BridgeOCRRequest -ApiKey 'your-api-key' -RequestBody $jsonBody
    .NOTES
    Χρησιμοποιεί την Invoke-RestMethod με ασφαλή διαχείριση σφαλμάτων.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RequestBody,
        [Parameter()][PSCustomObject]$Configuration
    )
    if (-not $Configuration) {
        $Configuration = New-BridgeConfiguration
    }
    # Λήψη διεύθυνσης URL για το OCR API από τη διαμόρφωση
    $url = "$($Configuration.Urls.OCRApi)?key=$ApiKey"
    # Λήψη μηνυμάτων από τη διαμόρφωση ή χρήση εναλλακτικής λύσης
    $startMessage = $Configuration.OCRMessages.StartOCR
    $failedMessagePrefix = $Configuration.OCRMessages.OCRFailed
    # Λήψη σταδίου καταγραφής (logging stage) από τη διαμόρφωση ή χρήση εναλλακτικής λύσης
    $analysisStage = $Configuration.LoggingConfig.InfoStage
    $errorStage = $Configuration.LoggingConfig.ErrorStage
    try {
        $invokeRestMethodSplat = @{
            Uri         = $url
            Method      = 'Post'
            Body        = $RequestBody
            ContentType = 'application/json'
            Headers     = @{ 'X-Goog-Api-Key' = $ApiKey }
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
            Level   = $Configuration.LoggingConfig.WarningLevel
        }
        Write-BridgeLog @writeBridgeLogSplat
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Η κλήση του Google Vision API απέτυχε: $($_.Exception.Message)", $_.Exception)),
            'GoogleVisionRequestFailure',
            [System.Management.Automation.ErrorCategory]::ConnectionError,
            $url
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}