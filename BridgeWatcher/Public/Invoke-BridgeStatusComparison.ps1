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
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][object[]]$PreviousState,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][object[]]$CurrentState,
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$PoUserKey,
        [Parameter(Mandatory)][string]$PoApiKey
    )
    Set-StrictMode -Version Latest
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
            'Κλειστή για συντήρηση|=>' = { Send-BridgeNotification 'Closed' $CurrentState }
            'Κλειστή για συντήρηση|<=' = { Send-BridgeNotification 'Closed' $CurrentState }
            'Κλειστή με πρόγραμμα|=>'  = { Send-BridgeNotification 'Closed' $CurrentState }
            'Κλειστή με πρόγραμμα|<='  = { Send-BridgeNotification 'Closed' $CurrentState }
            'Μόνιμα κλειστή|=>'        = { Send-BridgeNotification 'Closed' $CurrentState }
            'Μόνιμα κλειστή|<='        = { Send-BridgeNotification 'Closed' $CurrentState }
            'Ανοιχτή|=>'               = { Send-BridgeNotification 'Opened' $CurrentState }
            'Ανοιχτή|<='               = { Send-BridgeNotification 'Opened' $CurrentState }
        }
        foreach ($change in $diff) {
            $writeBridgeStageSplat = @{
                Level   = 'Verbose'
                Stage   = 'Ανάλυση'
                Message = "🌉 $($change.gefyraName) ➜ $($change.gefyraStatus) ($($change.SideIndicator))"
            }
            Write-BridgeStage @writeBridgeStageSplat
            $key = "$($change.gefyraStatus)|$($change.SideIndicator)"
            $handler = $handlerMap[$key]
            switch ($true) {
                { $handler } { & $handler;           continue }
                { $change.SideIndicator -eq '==' } {
                    $writeBridgeStageSplat = @{
                        Level   = 'Verbose'
                        Stage   = 'Ανάλυση'
                        Message = "Καμία ουσιαστική αλλαγή στην $($change.gefyraName)."
                    }
                    Write-BridgeStage @writeBridgeStageSplat
                    continue
                }
                default { $writeBridgeStageSplat = @{
                    Stage      = 'Σφάλμα'
                    Message    = "❓ Άγνωστο combo: $key"
                    Level      = 'Warning'
                }
                Write-BridgeStage @writeBridgeStageSplat }
            }
        }
        return $true
    } catch {
        $writeBridgeStageSplat = @{
            Level      = 'Warning'
            Stage      = 'Σφάλμα'
            Message    = "❌ $($_.Exception.Message)"
        }
        Write-BridgeStage @writeBridgeStageSplat
        throw
    }
}
function Write-BridgeStage {
    param(
        [ValidateSet('Ανάλυση','Σφάλμα')][string]$Stage,
        [string]$Message,
        [ValidateSet('Verbose','Warning','Error')][string]$Level = 'Verbose'
    )
    $writeBridgeLogSplat = @{
        Stage      = $Stage
        Message    = $Message
        Level      = $Level
    }
    Write-BridgeLog @writeBridgeLogSplat
}
function Send-BridgeNotification {
    param(
        [ValidateSet('Closed','Opened')]$Type,
        [object[]]$State
    )
    $splat = @{
        CurrentState = $State
        PoUserKey    = $PoUserKey
        PoApiKey     = $PoApiKey
    }
    if ($Type -eq 'Closed') { $splat.ApiKey = $ApiKey;  Invoke-BridgeClosedNotification @splat }
    else { Invoke-BridgeOpenedNotification @splat }
}