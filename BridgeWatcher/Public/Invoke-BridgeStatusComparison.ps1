function Invoke-BridgeStatusComparison {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ApiKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
    <#
    .SYNOPSIS
    Συγκρίνει τις λίστες καταστάσεων γεφυρών και ενεργοποιεί ειδοποιήσεις.

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
        [SecureString]$ApiKey,

        [Parameter(Mandatory)]
        [SecureString]$PoUserKey,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$PoApiKey,

        [Parameter()]
        [PSCustomObject]$Configuration
    )
    Set-StrictMode -Version Latest
    try {
        if (-not $Configuration) {
            $Configuration = New-BridgeConfiguration
        }

        $compareSplat = @{
            ReferenceObject  = $PreviousState
            DifferenceObject = $CurrentState
            Property         = 'gefyraName', 'gefyraStatus'
            IncludeEqual     = $true
        }
        $diff = Compare-Object @compareSplat
        if (-not $diff) {
            $writeBridgeLogSplat = @{
                Level   = 'Verbose'
                Stage   = 'Ανάλυση'
                Message = '✅ Καμία αλλαγή στις γέφυρες.'
            }
            Write-BridgeLog @writeBridgeLogSplat
            return $false
        }

        $handlerMap = @{
            "$($Configuration.Statuses.ClosedForMaintenance)|=>" = 'Closed'
            "$($Configuration.Statuses.ClosedForMaintenance)|<=" = 'Closed'
            "$($Configuration.Statuses.ClosedWithSchedule)|=>"   = 'Closed'
            "$($Configuration.Statuses.ClosedWithSchedule)|<="   = 'Closed'
            "$($Configuration.Statuses.PermanentlyClosed)|=>"    = 'Closed'
            "$($Configuration.Statuses.PermanentlyClosed)|<="    = 'Closed'
            "$($Configuration.Statuses.Open)|=>"                 = 'Opened'
            "$($Configuration.Statuses.Open)|<="                 = 'Opened'
        }

        foreach ($change in $diff) {
            $writeBridgeLogSplat = @{
                Level   = 'Verbose'
                Stage   = 'Ανάλυση'
                Message = "🌉 $($change.gefyraName) ➜ $($change.gefyraStatus) ($($change.SideIndicator))"
            }
            Write-BridgeLog @writeBridgeLogSplat
            if ($change.SideIndicator -eq '==') {
                $writeBridgeLogSplat = @{
                    Level   = 'Verbose'
                    Stage   = 'Ανάλυση'
                    Message = "Καμία ουσιαστική αλλαγή στην $($change.gefyraName)."
                }
                Write-BridgeLog @writeBridgeLogSplat
                continue
            }
            if ($change.SideIndicator -ne '=>') {
                # Skip any '<=' side indicators to prevent double notifications
                continue
            }
            $key = "$($change.gefyraStatus)|$($change.SideIndicator)"
            if ($handlerMap.ContainsKey($key)) {
                $type = $handlerMap[$key]
                # Χρήση helper function για επίλυση bridge state
                $resolveBridgeStateForChangeSplat = @{
                    Change        = $change
                    PreviousState = $PreviousState
                    CurrentState  = $CurrentState
                }
                $changedBridgeState = Resolve-BridgeStateForChange @resolveBridgeStateForChangeSplat
                if ($changedBridgeState.Count -gt 0) {
                    $sendBridgeNotificationSplat = @{
                        Type          = $type
                        State         = $changedBridgeState
                        ApiKey        = $ApiKey
                        PoUserKey     = $PoUserKey
                        PoApiKey      = $PoApiKey
                        Configuration = $Configuration
                    }
                    Send-BridgeNotification @sendBridgeNotificationSplat
                }
                continue
            } else {
                $writeBridgeLogSplat = @{
                    Stage   = 'Σφάλμα'
                    Message = "❓ Άγνωστο combo: $key"
                    Level   = 'Warning'
                }
                Write-BridgeLog @writeBridgeLogSplat
            }
        }
        return $true
    } catch {
        $writeBridgeLogSplat = @{
            Level   = 'Warning'
            Stage   = 'Σφάλμα'
            Message = "❌ $($_.Exception.Message)"
        }
        Write-BridgeLog @writeBridgeLogSplat
        throw
    }
}
