function Invoke-BridgeOCRGoogleCloud {
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
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][ValidateScript({
                if ([Uri]::IsWellFormedUriString($_, [UriKind]::Absolute)) {
                    $true
                } else {
                    throw "Η παράμετρος '$_' δεν είναι ένα έγκυρο απόλυτο URI."
                }
            })][string]$ImageUri
    )

    try {
        $requestObject = @{
            requests = @(
                @{
                    image    = @{ source = @{ imageUri = $ImageUri } }
                    features = @(
                        @{
                            type       = 'DOCUMENT_TEXT_DETECTION'
                            model      = 'builtin/latest'
                            maxResults = 50
                        }
                    )
                }
            )
        }
        $requestBody = $requestObject | ConvertTo-Json -Depth 5
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
            Message = "❌ Η αίτηση OCR απέτυχε: $_"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        throw
    }
}
