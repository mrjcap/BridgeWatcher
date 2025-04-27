function New-BridgeStatusObject {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Δημιουργεί αντικείμενο κατάστασης γέφυρας.

    .DESCRIPTION
    Η New-BridgeStatusObject δημιουργεί structured αντικείμενο που περιέχει
    όνομα γέφυρας, κατάσταση, χρονική σφραγίδα και URL εικόνας.

    .PARAMETER Location
    Το αναγνωριστικό της γέφυρας ('poseidonia' ή 'isthmia').

    .PARAMETER Status
    Η κατάσταση της γέφυρας ('Ανοιχτή', 'Κλειστή', 'Άγνωστη').

    .PARAMETER Timestamp
    Η χρονική στιγμή καταγραφής.

    .PARAMETER ImageSrc
    Το URL ή το σχετικό path της εικόνας.

    .PARAMETER BaseUrl
    Το base URL για συμπλήρωση εικόνων (προεπιλογή https://www.topvision.gr/dioriga/).

    .OUTPUTS
    [pscustomobject] - Αντικείμενο κατάστασης.

    .EXAMPLE
    New-BridgeStatusObject -Location 'poseidonia' -Status 'Closed' -Timestamp (Get-Date) -ImageSrc 'bridge1.jpg'

    .NOTES
    Επιστρέφει πάντα πλήρες αντικείμενο με σωστά πεδία.
    #>

    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Location,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Status,
        [Parameter(Mandatory)][string]$Timestamp,
        [Parameter(Mandatory)][string]$ImageSrc,
        [Parameter()][string]$BaseUrl = 'https://www.topvision.gr/dioriga/'
    )
    return [pscustomobject]@{
        GefyraName   = if ($Location -eq 'poseidonia') { 'Ποσειδωνία' } else { 'Ισθμία' }
        GefyraStatus = $Status
        Timestamp    = $Timestamp
        ImageUrl     = if ($ImageSrc -match '^https?://') { $ImageSrc } else { "$BaseUrl$ImageSrc" }
    }
}