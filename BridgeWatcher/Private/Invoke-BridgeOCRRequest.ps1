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
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$RequestBody,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )

    try {
        $null = ConvertFrom-Json -InputObject $RequestBody -ErrorAction Stop
    } catch {
        throw [System.ArgumentException]::new("Το RequestBody δεν είναι έγκυρο JSON.", "RequestBody")
    }

    $url = $Configuration.Urls.OCRApi
    $startMessage = $Configuration.OCRMessages.StartOCR
    $failedMessagePrefix = $Configuration.OCRMessages.OCRFailed
    $successMessage = $Configuration.ExportMessages.Success
    $analysisStage = $Configuration.LoggingConfig.InfoStage
    $errorStage = $Configuration.LoggingConfig.ErrorStage

    $timeout = @($Configuration.Defaults.HttpRequestTimeout, 60) | Where-Object { $_ -gt 0 } | Select-Object -First 1

    try {
        $invokeRestMethodSplat = @{
            Uri         = $url
            Method      = 'Post'
            Body        = $RequestBody
            ContentType = 'application/json'
            Headers     = @{ 'X-Goog-Api-Key' = $ApiKey }
            TimeoutSec  = $timeout
            ErrorAction = 'Stop'
        }

        $writeBridgeLogSplat = @{
            Stage   = $analysisStage
            Message = $startMessage
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

        $maxRetries = 3
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                $result = Invoke-RestMethod @invokeRestMethodSplat
                $writeBridgeLogSplat = @{
                    Stage   = $analysisStage
                    Message = "$successMessage (Αίτημα OCR)"
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                return $result
            } catch {
                $responseProp = $_.Exception.PSObject.Properties['Response']
                $response = if ($null -ne $responseProp) { $responseProp.Value } else { $null }
                try {
                    # Do not abort on 403 (Quota) or 429 (Rate Limit). Abort on 400, 401, 413, 422.
                    $isFatalStatus = ($null -ne $response) -and (([int]$response.StatusCode) -in @(400, 401, 413, 422))
                    if ($isFatalStatus -or $i -eq $maxRetries) { throw }
                    $baseSleep = [Math]::Pow(2, $i)
                    $jitter = Get-Random -Minimum 0 -Maximum 4
                    Start-Sleep -Seconds ($baseSleep + $jitter)
                } finally {
                    if ($response -is [System.IDisposable]) { $response.Dispose() }
                }
            }
        }
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = $errorStage
            Message = "$failedMessagePrefix`: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("$failedMessagePrefix`: $($_.Exception.Message)", $_.Exception)),
            'GoogleVisionRequestFailure',
            [System.Management.Automation.ErrorCategory]::ConnectionError,
            $Configuration.Urls.OCRApi
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}
