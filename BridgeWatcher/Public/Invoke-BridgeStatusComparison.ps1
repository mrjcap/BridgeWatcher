function Invoke-BridgeStatusComparison {
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

    .PARAMETER Configuration
    (Προαιρετικό) Αντικείμενο διαμόρφωσης. Αν δεν παρέχεται, δημιουργείται αυτόματα.

    .OUTPUTS
    [System.Boolean]

    .EXAMPLE
    Invoke-BridgeStatusComparison -PreviousState $prev -CurrentState $curr -ApiKey 'abc' -PoUserKey 'user' -PoApiKey 'token'

    .NOTES
    Καταγράφει αλλαγές και ενεργοποιεί κατάλληλες ειδοποιήσεις.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ApiKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [CmdletBinding()]
    [OutputType([System.Boolean])]
    param (
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object[]]$PreviousState = @(),

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
        [string]$PoApiKey,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$Configuration
    )
    try {
        if (-not $PreviousState -or $PreviousState.Count -eq 0) {
            # Πρώτη εκτέλεση: όλες οι γέφυρες είναι νέες (=>)
            $diff = $CurrentState | ForEach-Object {
                [PSCustomObject]@{
                    gefyraName    = $_.gefyraName
                    gefyraStatus  = $_.gefyraStatus
                    ImageUrl      = $_.ImageUrl
                    ImageHash     = $_.ImageHash
                    SideIndicator = '=>'
                }
            }
        } else {
            # Use ImageHash if it is present on any ClosedWithSchedule states, otherwise fall back to ImageUrl
            $hasPreviousHash = $PreviousState | Where-Object { $_.gefyraStatus -eq $Configuration.Statuses.ClosedWithSchedule -and $null -ne $_.ImageHash }
            $hasCurrentHash = $CurrentState | Where-Object { $_.gefyraStatus -eq $Configuration.Statuses.ClosedWithSchedule -and $null -ne $_.ImageHash }

            $compareProperty = @('gefyraName', 'gefyraStatus')
            if ($hasPreviousHash -and $hasCurrentHash) {
                $compareProperty += 'ImageHash'
            } else {
                $compareProperty += 'ImageUrl'
            }

            $compareSplat = @{
                ReferenceObject  = $PreviousState
                DifferenceObject = $CurrentState
                Property         = $compareProperty
                IncludeEqual     = $true
            }
            $diff = Compare-Object @compareSplat
        }
        if (-not $diff) {
            $writeBridgeLogSplat = @{
                Level   = 'Verbose'
                Stage   = 'Ανάλυση'
                Message = '✅ Καμία αλλαγή στις γέφυρες.'
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            return $false
        }

        $changesTriggered = $false

        $closedStatuses = @(
            $Configuration.Statuses.ClosedForMaintenance,
            $Configuration.Statuses.ClosedWithSchedule,
            $Configuration.Statuses.PermanentlyClosed
        )

        $handlerMap = @{}
        foreach ($status in $closedStatuses) {
            $handlerMap["$status|=>"] = 'Closed'
        }
        $handlerMap["$($Configuration.Statuses.Open)|=>"] = 'Opened'

        foreach ($change in $diff) {
            $writeBridgeLogSplat = @{
                Level   = 'Verbose'
                Stage   = 'Ανάλυση'
                Message = "🌉 $($change.gefyraName) ➜ $($change.gefyraStatus) ($($change.SideIndicator))"
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            if ($change.SideIndicator -eq '==') {
                $writeBridgeLogSplat = @{
                    Level   = 'Verbose'
                    Stage   = 'Ανάλυση'
                    Message = "Καμία ουσιαστική αλλαγή στην $($change.gefyraName)."
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                continue
            }
            if ($change.SideIndicator -ne '=>') {
                # Skip any '<=' side indicators to prevent double notifications
                continue
            }
            $prevBridge = @($PreviousState) | Where-Object { $_.gefyraName -eq $change.gefyraName } | Select-Object -First 1
            if ($prevBridge -and $prevBridge.gefyraStatus -eq $change.gefyraStatus) {
                # The status did not change. If it is NOT ClosedWithSchedule, skip it!
                if ($change.gefyraStatus -ne $Configuration.Statuses.ClosedWithSchedule) {
                    $writeBridgeLogSplat = @{
                        Level   = 'Verbose'
                        Stage   = 'Ανάλυση'
                        Message = "Καμία ουσιαστική αλλαγή στην $($change.gefyraName)."
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                    continue
                } else {
                    $currentBridge = @($CurrentState) | Where-Object { $_.gefyraName -eq $change.gefyraName } | Select-Object -First 1
                    if ($currentBridge -and [string]::IsNullOrEmpty($currentBridge.ImageHash) -and -not [string]::IsNullOrEmpty($prevBridge.ImageHash)) {
                        $currentBridge.ImageHash = $prevBridge.ImageHash
                        $writeBridgeLogSplat = @{
                            Level   = 'Verbose'
                            Stage   = 'Ανάλυση'
                            Message = "Αποτυχία λήψης νέου hash. Επαναχρησιμοποίηση προηγούμενου hash για την $($change.gefyraName)."
                        }
                        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                        continue
                    }

                    $writeBridgeLogSplat = @{
                        Level   = 'Verbose'
                        Stage   = 'Ανάλυση'
                        Message = "Εντοπίστηκε ενημέρωση του προγράμματος κλεισίματος για την $($change.gefyraName)."
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                }
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
                    $changesTriggered = $true
                    $notificationSplat = @{
                        CurrentState  = $changedBridgeState
                        PoUserKey     = $PoUserKey
                        PoApiKey      = $PoApiKey
                        Configuration = $Configuration
                    }
                    if ($type -eq 'Closed') {
                        $notificationSplat.ApiKey = $ApiKey
                        Invoke-BridgeClosedNotification @notificationSplat
                    } else {
                        Invoke-BridgeOpenedNotification @notificationSplat
                    }
                }
                continue
            } else {
                $writeBridgeLogSplat = @{
                    Stage   = 'Σφάλμα'
                    Message = "❓ Άγνωστο combo: $key"
                    Level   = 'Warning'
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            }
        }
        return $changesTriggered
    } catch {
        $writeBridgeLogSplat = @{
            Level   = 'Warning'
            Stage   = 'Σφάλμα'
            Message = "❌ $($_.Exception.Message)"
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        throw
    }
}
