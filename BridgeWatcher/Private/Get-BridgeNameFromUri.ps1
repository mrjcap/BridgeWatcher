function Get-BridgeNameFromUri {
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
    # Επιστρέφει: 'Ποσειδωνία'

    .EXAMPLE
    # Επιστρέφει: 'Ισθμία'

    .NOTES
    Χρησιμοποιεί regex χωρίς διάκριση πεζών-κεφαλαίων για την αναγνώριση του ονόματος.
    Επιστρέφει 'Άγνωστη' αν η γέφυρα δεν αναγνωριστεί.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter(Mandatory)]
        [ValidateScript({ [Uri]::IsWellFormedUriString($_, [UriKind]::Absolute) })]
        [ValidateNotNullOrEmpty()]
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
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            return 'Άγνωστη'
        }
    }
}

