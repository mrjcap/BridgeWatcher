function Invoke-BridgeOCRGoogleCloud {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Αναλύει εικόνα με OCR μέσω Google Cloud.

    .DESCRIPTION
    Η Invoke-BridgeOCRGoogleCloud στέλνει Base64 εικόνα σε Google Vision OCR
    και επιστρέφει τα αναγνωρισμένα αποτελέσματα.

    .PARAMETER ApiKey
    Το API Key της υπηρεσίας Google Cloud.

    .PARAMETER ImageUri
    Το URI της εικόνας που θα αναλυθεί.

    .OUTPUTS
    [pscustomobject[]] - Αποτελέσματα OCR σε μορφή αντικειμένων.

    .EXAMPLE
    Invoke-BridgeOCRGoogleCloud -ApiKey 'your-api-key' -ImageUri 'https://example.com/image.jpg'

    .NOTES
    Απαιτεί έγκυρο API Key και δημόσια προσβάσιμες εικόνες.
    #>

    [OutputType([pscustomobject[]])]
    param (
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$ImageUri
    )
    $writeBridgeLogSplat = @{
        Stage      = 'Ανάλυση'
        Message    = "📥 [BEGIN] OCR for: $ImageUri"
    }
    Write-BridgeLog @writeBridgeLogSplat
    if (-not [Uri]::IsWellFormedUriString($ImageUri, [UriKind]::Absolute)) {
        throw "The provided ImageUri is not a valid absolute URI: '$ImageUri'"
    }
    try {
        $newOCRRequestBodySplat = @{
            ImageUri    = $ImageUri
        }
        $requestBody    = New-BridgeOCRRequestBody @newOCRRequestBodySplat
        $invokeOCRRequestSplat = @{
            ApiKey         = $ApiKey
            RequestBody    = $requestBody
        }
        $apiResponse    = Invoke-BridgeOCRRequest @invokeOCRRequestSplat
        $convertFromOCRResultSplat = @{
            ApiResponse    = $apiResponse
            ImageUri       = $ImageUri
        }
        $result         = ConvertFrom-BridgeOCRResult @convertFromOCRResultSplat
        return $result
    } catch {
        $writeBridgeLogSplat = @{
            Stage      = 'Σφάλμα'
            Message    = "❌ OCR Request failed: $_"
            Level      = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        throw
    } finally {
        $writeBridgeLogSplat = @{
            Stage      = 'Ανάλυση'
            Message    = "📤 [END] OCR process completed"
        }
        Write-BridgeLog @writeBridgeLogSplat
    }
}