function Get-BridgeOCRRequestBody {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Δημιουργεί σώμα JSON αιτήματος OCR.

    .DESCRIPTION
    Η Get-BridgeOCRRequestBody δημιουργεί ένα JSON αίτημα για ανάλυση εικόνας
    μέσω OCR, βασισμένο σε URI εικόνας.

    .PARAMETER ImageUri
    Το URI της εικόνας που θα αναλυθεί.    .PARAMETER MaxResults
    Ο μέγιστος αριθμός αποτελεσμάτων OCR (προεπιλογή: 50).

    .PARAMETER JsonDepth
    Το βάθος serialization του JSON (προεπιλογή: 5).

    .OUTPUTS
    [string] - Το JSON αίτημα σε μορφή string.

    .EXAMPLE
    Get-BridgeOCRRequestBody -ImageUri 'https://example.com/image.jpg'

    .EXAMPLE
    Get-BridgeOCRRequestBody -ImageUri 'https://example.com/image.jpg' -MaxResults 25

    .NOTES
    Το JSON περιλαμβάνει fields όπως imageUri και features.
    #>

    [OutputType([string])]    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ImageUri,
        [Parameter()][ValidateRange(1, 100)][int]$MaxResults = 50,
        [Parameter()][ValidateRange(1, 10)][int]$JsonDepth = 5
    )
    $requestObject = @{
        requests = @(
            @{
                image    = @{ source = @{ imageUri = $ImageUri } }
                features = @(
                    @{
                        type       = 'DOCUMENT_TEXT_DETECTION'
                        model      = 'builtin/latest'
                        maxResults = $MaxResults
                    }
                )
            }
        )
    }
    return $requestObject | ConvertTo-Json -Depth $JsonDepth
}