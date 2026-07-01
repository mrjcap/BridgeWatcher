function New-BridgeResult {
    <#
    .SYNOPSIS
    Δημιουργεί ένα τυποποιημένο αποτέλεσμα για λειτουργίες του BridgeWatcher.

    .DESCRIPTION
    Η New-BridgeResult δημιουργεί ένα τυποποιημένο PSCustomObject που περιέχει
    πληροφορίες επιτυχίας/αποτυχίας, δεδομένα και σφάλματα για λειτουργίες
    του BridgeWatcher module.

    .PARAMETER Success
    Υποδεικνύει αν η λειτουργία ήταν επιτυχής.

    .PARAMETER Data
    Τα δεδομένα που επιστρέφονται από την επιτυχή λειτουργία.

    .PARAMETER ErrorMessage
    Το μήνυμα σφάλματος σε περίπτωση αποτυχίας.

    .PARAMETER ErrorCode
    Ο κωδικός σφάλματος σε περίπτωση αποτυχίας.

    .OUTPUTS
    [PSCustomObject] - Result object with Success, Data, ErrorMessage, ErrorCode, and Timestamp.

    .EXAMPLE
    New-BridgeResult -Success $true -Data $bridgeStatus
    Creates a successful result with data.

    .EXAMPLE
    New-BridgeResult -Success $false -ErrorMessage "HTTP failed" -ErrorCode "HTTP_ERROR"
    Creates an error result with message and code.

    .NOTES
    Χρησιμοποιείται για τυποποίηση των αποτελεσμάτων λειτουργιών στο BridgeWatcher.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSUseShouldProcessForStateChangingFunctions",
        "",
        Justification = "Δημιουργεί αντικείμενο μόνο στη μνήμη."
    )]
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [bool]$Success,

        [Parameter()]
        [object]$Data = $null,

        [Parameter()]
        [string]$ErrorMessage = '',

        [Parameter()]
        [string]$ErrorCode = ''
    )

    return [PSCustomObject]@{
        Success      = $Success
        Data         = $Data
        ErrorMessage = $ErrorMessage
        ErrorCode    = $ErrorCode
        Timestamp    = Get-Date -Format o
    }
}

