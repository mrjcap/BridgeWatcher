function Get-SafeBridgeConfiguration {
    <#
    .SYNOPSIS
    Επιστρέφει ασφαλές configuration γέφυρας, δημιουργώντας νέο αν χρειάζεται.

    .DESCRIPTION
    Η Get-SafeBridgeConfiguration μειώνει τον επαναλαμβανόμενο κώδικα στις κύριες
    συναρτήσεις χειριζόμενη τη λογική εναλλακτικού configuration.

    .PARAMETER Configuration
    Το υπάρχον configuration object, αν υπάρχει.

    .PARAMETER Quiet
    Αν οριστεί, αποκρύπτει εξαιρέσεις και επιστρέφει $null σε αποτυχία.

    .OUTPUTS
    [PSCustomObject]
    #>
    [CmdletBinding()]
    param(
        [PSCustomObject]$Configuration,
        [switch]$Quiet
    )

    if ($Configuration) {
        return $Configuration
    }

    try {
        return New-BridgeConfiguration
    } catch {
        if ($Quiet) {
            return $null
        }
        throw $_
    }
}
