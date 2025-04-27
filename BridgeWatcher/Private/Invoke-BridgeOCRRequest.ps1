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
        [Parameter(Mandatory)][string]$RequestBody
    )
    $url = "https://vision.googleapis.com/v1/images:annotate?key=$ApiKey"
    try {
        $invokeRestMethodSplat = @{
            Uri         = $url
            Method      = 'Post'
            Body        = $RequestBody
            ContentType = 'application/json'
            ErrorAction = 'Stop'
        }
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = '➜ Calling Google Vision API...'
        }
        Write-BridgeLog @writeBridgeLogSplat
        return Invoke-RestMethod @invokeRestMethodSplat
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Request failed: $($_.Exception.Message)"
            Level   = 'Warning'
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