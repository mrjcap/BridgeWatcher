function Get-BridgeOCRRequestBody {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Δημιουργεί σώμα JSON αιτήματος OCR.

    .DESCRIPTION
    Η Get-BridgeOCRRequestBody δημιουργεί ένα JSON αίτημα για ανάλυση εικόνας
    μέσω OCR, βασισμένο σε URI εικόνας.

    .PARAMETER ImageUri
    Το URI της εικόνας που θα αναλυθεί.

    .OUTPUTS
    [string] - Το JSON αίτημα σε μορφή string.

    .EXAMPLE
    Get-BridgeOCRRequestBody -ImageUri 'https://example.com/image.jpg'

    .NOTES
    Το JSON περιλαμβάνει fields όπως imageUri και features.
    #>

    [OutputType([string])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ImageUri
    )
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
    return $requestObject | ConvertTo-Json -Depth 5
}