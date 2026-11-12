function Get-BridgeOptionalProperty {
    <#
    .SYNOPSIS
    Ανακτά με ασφάλεια προαιρετική ιδιότητα από hashtable ή PSCustomObject.

    .DESCRIPTION
    Επιστρέφει την τιμή μιας προαιρετικής ιδιότητας χωρίς σφάλμα σε strict mode.

    .PARAMETER InputObject
    Το αντικείμενο ή hashtable εισόδου.

    .PARAMETER PropertyName
    Το όνομα της ιδιότητας προς ανάγνωση.

    .OUTPUTS
    [object]
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [object]$InputObject,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PropertyName
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject[$PropertyName]
    }

    $prop = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -ne $prop) {
        return $prop.Value
    }

    return $null
}
