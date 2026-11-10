function Resolve-BridgeStateForChange {
    <#
    .SYNOPSIS
    Επιλύει το αντικείμενο κατάστασης γέφυρας που αντιστοιχεί σε μια ανιχνευθείσα αλλαγή.

    .DESCRIPTION
    Η Resolve-BridgeStateForChange αναζητά την πλήρη εγγραφή κατάστασης γέφυρας
    για μια δεδομένη αλλαγή, αντιστοιχίζοντας το GefyraName στα arrays
    CurrentState ή PreviousState, ανάλογα με την κατεύθυνση του SideIndicator.

    .PARAMETER Change
    Το αντικείμενο αλλαγής που περιέχει GefyraName και SideIndicator.

    .PARAMETER PreviousState
    Η προηγούμενη συλλογή κατάστασης γεφυρών.

    .PARAMETER CurrentState
    Η τρέχουσα συλλογή κατάστασης γεφυρών.

    .OUTPUTS
    [object[]] - Array of matching bridge state objects.

    .EXAMPLE
    $state = Resolve-BridgeStateForChange -Change $change -PreviousState $prev -CurrentState $curr

    .NOTES
    Για αλλαγές '=>', αναζητά μόνο στο CurrentState. Για αλλαγές '<=', αναζητά
    πρώτα στο CurrentState και εναλλακτικά στο PreviousState.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]$Change,
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$PreviousState = @(),
        [Parameter(Mandatory)][object]$CurrentState
    )

    $currentMatches = @([array]$CurrentState | Where-Object { $null -ne $_ -and $_.GefyraName -eq $Change.GefyraName })
    if ($currentMatches.Count -gt 0 -or $Change.SideIndicator -ne '<=') {
        return , $currentMatches
    }

    $previousMatches = @([array]$PreviousState | Where-Object { $null -ne $_ -and $_.GefyraName -eq $Change.GefyraName })
    return , $previousMatches
}
