function Get-BridgeNameFromUri {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Αναγνωρίζει το όνομα γέφυρας από URI εικόνας.

    .DESCRIPTION
    Η Get-BridgeNameFromUri αναλύει το URI μιας εικόνας και επιστρέφει
    το αναγνωριστικό της γέφυρας (π.χ. Ποσειδωνία ή Ισθμία).

    .PARAMETER ImageUri
    Η διεύθυνση URI της εικόνας προς ανάλυση.

    .OUTPUTS
    [string] - Το όνομα της γέφυρας ('Ισθμία', 'Ποσειδωνία' ή 'Άγνωστη').

    .EXAMPLE
    Get-BridgeNameFromUri -ImageUri 'https://example.com/image-bridge-posidonia.jpg'
    # Returns: 'Ποσειδωνία'

    .EXAMPLE
    Get-BridgeNameFromUri -ImageUri 'https://example.com/bridge-isthmia-status.png'
    # Returns: 'Ισθμία'

    .NOTES
    Χρησιμοποιεί case-insensitive regex matching για αναγνώριση ονόματος.
    Επιστρέφει 'Άγνωστη' αν δεν αναγνωριστεί η γέφυρα.
    #>    [OutputType([string])]
    param (
        [Parameter(Mandatory)]
        [ValidateScript({ [Uri]::IsWellFormedUriString($_, [UriKind]::Absolute) })]
        [string]$ImageUri
    )
    switch -Regex ($ImageUri.ToLowerInvariant()) {
        'isthmia' { return 'Ισθμία' }
        'posidonia' { return 'Ποσειδωνία' }
        default {
            $writeBridgeLogSplat = @{
                Stage   = 'Ανάλυση'
                Message = "⚠️ Δεν αναγνωρίστηκε η γέφυρα στο URI: $ImageUri"
            }
            Write-BridgeLog @writeBridgeLogSplat
            return 'Άγνωστη'
        }
    }
}