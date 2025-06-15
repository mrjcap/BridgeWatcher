    function Resolve-BridgeStateForChange {
        param(
            [Parameter(Mandatory)]$Change,
            [Parameter(Mandatory)][object[]]$PreviousState,
            [Parameter(Mandatory)][object[]]$CurrentState
        )

        if ($Change.SideIndicator -eq '=>') {
            # Νέα κατάσταση - ψάχνε στο CurrentState
            $foundState = @($CurrentState | Where-Object { $_.GefyraName -eq $Change.GefyraName })
        } else {
            # Παλιά κατάσταση (<=) - ψάχνε στο CurrentState πρώτα
            $foundState = @($CurrentState | Where-Object { $_.GefyraName -eq $Change.GefyraName })
            if ($foundState.Count -eq 0) {
                # Fallback: χρήση PreviousState αν δεν υπάρχει στο Current
                $foundState = @($PreviousState | Where-Object { $_.GefyraName -eq $Change.GefyraName })
            }
        }
        return $foundState
    }