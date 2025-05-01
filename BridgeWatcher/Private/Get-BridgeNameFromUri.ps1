function Get-BridgeNameFromUri {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Αναγνωρίζει το όνομα γέφυρας από URI εικόνας.

    .DESCRIPTION
    Η Get-BridgeNameFromUri αναλύει το URI μιας εικόνας και επιστρέφει
    το αναγνωριστικό της γέφυρας (π.χ. Ποσειδωνία ή Ισθμία).

    .PARAMETER Uri
    Η διεύθυνση URI της εικόνας.

    .OUTPUTS
    [string] - Το αναγνωριστικό της γέφυρας.

    .EXAMPLE
    Get-BridgeNameFromUri -Uri 'https://example.com/poseidonia.jpg'

    .NOTES
    Χρησιμοποιεί regex patterns για αναγνώριση ονόματος.
    #>
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][string]$ImageUri
    )
    switch -Regex ($ImageUri.ToLowerInvariant()) {
        'isthmia' { return 'Ισθμία' }
        'posidonia' { return 'Ποσειδωνία' }
        default {
            $writeBridgeLogSplat = @{
                Stage      = 'Ανάλυση'
                Message    = "⚠️ Δεν αναγνωρίστηκε η γέφυρα στο URI: $ImageUri"
            }
            Write-BridgeLog @writeBridgeLogSplat
            return 'Άγνωστη'
        }
    }
}