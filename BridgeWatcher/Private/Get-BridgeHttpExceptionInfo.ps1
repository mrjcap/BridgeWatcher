function Get-BridgeHttpExceptionInfo {
    <#
    .SYNOPSIS
    Εξάγει την απόκριση HTTP και αν το σφάλμα είναι μη ανακτήσιμο.

    .DESCRIPTION
    Ανακτά με ασφάλεια την ιδιότητα Response μιας εξαίρεσης υπό strict mode
    και ελέγχει αν ο κωδικός κατάστασης HTTP ανήκει στους μη ανακτήσιμους κωδικούς.

    .PARAMETER Exception
    Το αντικείμενο εξαίρεσης προς εξέταση.

    .PARAMETER FatalStatusCodes
    Οι κωδικοί κατάστασης HTTP στους οποίους δεν γίνεται επανάληψη.

    .OUTPUTS
    [PSCustomObject]
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [System.Exception]$Exception,

        [Parameter(Mandatory)]
        [int[]]$FatalStatusCodes
    )

    $responseProp = $Exception.PSObject.Properties['Response']
    $response = if ($null -ne $responseProp) { $responseProp.Value } else { $null }
    $isFatal = ($null -ne $response) -and (([int]$response.StatusCode) -in $FatalStatusCodes)

    return [PSCustomObject]@{
        Response = $response
        IsFatal  = $isFatal
    }
}
