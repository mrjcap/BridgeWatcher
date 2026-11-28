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
function Invoke-BridgeOCRRequest {
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

    $timeout = @($Configuration.Defaults.HttpRequestTimeout, 60) | Where-Object -FilterScript { $_ -gt 0 } | Select-Object -First 1

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
                break
            } catch {
                $errInfo = Get-BridgeHttpExceptionInfo -Exception $_.Exception -FatalStatusCodes @(400, 401, 413, 422)
                $response = $errInfo.Response
                try {
                    if ($errInfo.IsFatal -or $i -eq $maxRetries) { throw }
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

    $appendFailure = $null
    try {
        Write-BridgeLog -Stage $analysisStage -Message "$successMessage (Αίτημα OCR)" -Configuration $Configuration -ErrorAction Stop
    } catch {
        $appendFailure = $_
    }
    if ($null -ne $appendFailure) {
        Write-Warning -Message "OCR request succeeded, but writing its success log failed: $($appendFailure.Exception.Message)" -WarningAction Continue
    }
    return $result
}
