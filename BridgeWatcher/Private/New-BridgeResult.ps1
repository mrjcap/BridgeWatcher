function New-BridgeResult {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSUseShouldProcessForStateChangingFunctions",
        "",
        Justification = "Creates in-memory object only."
    )]
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
    [PSCustomObject] - Αντικείμενο αποτελέσματος με Success, Data, ErrorMessage, ErrorCode και Timestamp.

    .EXAMPLE
    New-BridgeResult -Success $true -Data $bridgeStatus
    Δημιουργεί επιτυχές αποτέλεσμα με δεδομένα.

    .EXAMPLE
    New-BridgeResult -Success $false -ErrorMessage "HTTP failed" -ErrorCode "HTTP_ERROR"
    Δημιουργεί αποτέλεσμα σφάλματος με μήνυμα και κωδικό.

    .NOTES
    Χρησιμοποιείται για τυποποίηση των αποτελεσμάτων λειτουργιών στο BridgeWatcher.
    #>

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
        Timestamp    = Get-BridgeTimestamp
    }
}
