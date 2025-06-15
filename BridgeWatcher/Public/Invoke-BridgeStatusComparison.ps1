function Invoke-BridgeStatusComparison {
    <#
    .SYNOPSIS
    Συγκρίνει δύο λίστες καταστάσεων γεφυρών και ενεργοποιεί ειδοποιήσεις.

    .DESCRIPTION
    Η Invoke-BridgeStatusComparison συγκρίνει την προηγούμενη και την τρέχουσα
    κατάσταση γεφυρών και καλεί ειδικούς handlers για αλλαγές (άνοιγμα/κλείσιμο).

    .PARAMETER PreviousState
    Η προηγούμενη λίστα καταστάσεων.

    .PARAMETER CurrentState
    Η τρέχουσα λίστα καταστάσεων.

    .PARAMETER ApiKey
    Το API Key για OCR αν απαιτηθεί.

    .PARAMETER PoUserKey
    Το User Key για Pushover ειδοποίηση.

    .PARAMETER PoApiKey
    Το API Token για Pushover ειδοποίηση.

    .OUTPUTS
    None.

    .EXAMPLE
    Invoke-BridgeStatusComparison -PreviousState $prev -CurrentState $curr -ApiKey 'abc' -PoUserKey 'user' -PoApiKey 'token'

    .NOTES
    Καταγράφει αλλαγές και ενεργοποιεί κατάλληλες ειδοποιήσεις.
    #>    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object[]]$PreviousState,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object[]]$CurrentState,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PoUserKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PoApiKey
    )
    Set-StrictMode -Version Latest

    # Helper function για επίλυση της κατάστασης γέφυρας βάσει SideIndicator
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
        }        return $foundState
    }

    try {
        $compareSplat = @{
            ReferenceObject  = $PreviousState
            DifferenceObject = $CurrentState
            Property         = 'gefyraName', 'gefyraStatus'
            IncludeEqual     = $true
        }
        $diff = Compare-Object @compareSplat
        if (-not $diff) {
            $writeBridgeStageSplat = @{
                Level   = 'Verbose'
                Stage   = 'Ανάλυση'
                Message = '✅ Καμία αλλαγή στις γέφυρες.'
            }
            Write-BridgeStage @writeBridgeStageSplat
            return $false
        }

        $handlerMap = @{
            'Κλειστή για συντήρηση|=>' = 'Closed'
            'Κλειστή για συντήρηση|<=' = 'Closed'
            'Κλειστή με πρόγραμμα|=>'  = 'Closed'
            'Κλειστή με πρόγραμμα|<='  = 'Closed'
            'Μόνιμα κλειστή|=>'        = 'Closed'
            'Μόνιμα κλειστή|<='        = 'Closed'
            'Ανοιχτή|=>'               = 'Opened'
            'Ανοιχτή|<='               = 'Opened'
        }

        foreach ($change in $diff) {
            $writeBridgeStageSplat = @{
                Level   = 'Verbose'
                Stage   = 'Ανάλυση'
                Message = "🌉 $($change.gefyraName) ➜ $($change.gefyraStatus) ($($change.SideIndicator))"
            }
            Write-BridgeStage @writeBridgeStageSplat
            if ($change.SideIndicator -eq '==') {
                $writeBridgeStageSplat = @{
                    Level   = 'Verbose'
                    Stage   = 'Ανάλυση'
                    Message = "Καμία ουσιαστική αλλαγή στην $($change.gefyraName)."
                }
                Write-BridgeStage @writeBridgeStageSplat
                continue
            }
            $key = "$($change.gefyraStatus)|$($change.SideIndicator)"
            if ($handlerMap.ContainsKey($key)) {
                $type = $handlerMap[$key]
                # Χρήση helper function για επίλυση bridge state
                $changedBridgeState = Resolve-BridgeStateForChange -Change $change -PreviousState $PreviousState -CurrentState $CurrentState

                if ($changedBridgeState.Count -gt 0) {
                    $sendBridgeNotificationSplat = @{
                        Type      = $type
                        State     = $changedBridgeState
                        ApiKey    = $ApiKey
                        PoUserKey = $PoUserKey
                        PoApiKey  = $PoApiKey
                    }
                    Send-BridgeNotification @sendBridgeNotificationSplat
                }
                continue
            } else {
                $writeBridgeStageSplat = @{
                    Stage   = 'Σφάλμα'
                    Message = "❓ Άγνωστο combo: $key"
                    Level   = 'Warning'
                }
                Write-BridgeStage @writeBridgeStageSplat
            }
        }
        return $true
    } catch {
        $writeBridgeStageSplat = @{
            Level   = 'Warning'
            Stage   = 'Σφάλμα'
            Message = "❌ $($_.Exception.Message)"
        }
        Write-BridgeStage @writeBridgeStageSplat
        throw
    }
}