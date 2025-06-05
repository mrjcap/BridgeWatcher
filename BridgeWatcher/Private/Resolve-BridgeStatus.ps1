function Resolve-BridgeStatus {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Προσδιορίζει την τελική κατάσταση γέφυρας.

    .DESCRIPTION
    Η Resolve-BridgeStatus αναλύει εικόνες και status, και αποφασίζει
    αν μία γέφυρα πρέπει να θεωρηθεί ανοιχτή ή κλειστή.

    .PARAMETER Location
    Το αναγνωριστικό γέφυρας.

    .PARAMETER Status
    Η προτεινόμενη κατάσταση βάσει OCR/HTML.

    .PARAMETER Pattern
    Το pattern εικόνας που πρέπει να ταιριάξει.

    .PARAMETER BridgeImages
    Η λίστα εικόνων προς έλεγχο.

    .PARAMETER RequireInfoImage
    Αν απαιτείται ύπαρξη ειδικής info εικόνας.

    .OUTPUTS
    [pscustomobject] - Αντικείμενο εικόνας ή $null.

    .EXAMPLE
    Resolve-BridgeStatus -Location 'poseidonia' -Status 'Ανοιχτή' -Pattern 'open' -BridgeImages $images -RequireInfoImage $true

    .NOTES
    Ελέγχει και για special πληροφοριακές εικόνες αν χρειάζεται.
    #>

    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$Pattern,
        [Parameter(Mandatory)][AllowEmptyCollection()][pscustomobject[]]$BridgeImages,
        [Parameter(Mandatory)][bool]$RequireInfoImage
    )
    $BridgeImages = @($BridgeImages)  # Ensure it's always an array
    $matchedImage = $BridgeImages | Where-Object { $_.src -match $Pattern } | Select-Object -First 1
    if ($Status -eq 'Ανοιχτή' -and $RequireInfoImage) {
        $hasInfoImage = $BridgeImages | Where-Object { $_.src -match 'info\.php\?\d+' }
        if (-not $hasInfoImage -or $hasInfoImage.Count -eq 0) {
            $writeBridgeLogSplat = @{
                Stage   = 'Ανάλυση'
                Message = "Παραλείπεται $Location ($Status): Δεν βρέθηκε info εικόνα"
            }
            Write-BridgeLog @writeBridgeLogSplat
            return $null
        }
    }
    return $matchedImage
}