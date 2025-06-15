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
    Απαιτεί έγκυρο API Key και δημόσια προσβάσιμες εικόνες.    #>

    [OutputType([pscustomobject[]])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateScript({
                if ([Uri]::IsWellFormedUriString($_, [UriKind]::Absolute)) {
                    $true
                } else {
                    throw "The parameter '$_' is not a valid absolute URI."
                }
            })][string]$ImageUri
    )

    try {
        $newOCRRequestBodySplat = @{
            ImageUri = $ImageUri
        }
        $requestBody = Get-BridgeOCRRequestBody @newOCRRequestBodySplat
        $invokeOCRRequestSplat = @{
            ApiKey      = $ApiKey
            RequestBody = $requestBody
        }
        $apiResponse = Invoke-BridgeOCRRequest @invokeOCRRequestSplat
        $convertFromOCRResultSplat = @{
            ApiResponse = $apiResponse
            ImageUri    = $ImageUri
        }
        $result = ConvertFrom-BridgeOCRResult @convertFromOCRResultSplat
        return $result
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ OCR Request failed: $_"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        throw
    }
    # Removed verbose END log in finally block to reduce spam - completion is implied by return or exception
}