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
function Invoke-BridgeStatusComparison {
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
        [object]$PreviousState = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object]$CurrentState,

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
        $previousStateArray = @($PreviousState | Where-Object { $null -ne $_ })
        $currentStateArray = @($CurrentState | Where-Object { $null -ne $_ })

        if (-not $previousStateArray -or $previousStateArray.Count -eq 0) {
            # Πρώτη εκτέλεση: όλες οι γέφυρες είναι νέες (=>)
            $diff = $currentStateArray | ForEach-Object {
                [PSCustomObject]@{
                    GefyraName    = $_.GefyraName
                    GefyraStatus  = $_.GefyraStatus
                    ImageUrl      = $_.ImageUrl
                    ImageHash     = $_.ImageHash
                    SideIndicator = '=>'
                }
            }
        } else {
            # Use ImageHash if it is present on any ClosedWithSchedule states, otherwise fall back to ImageUrl
            $hasPreviousHash = $previousStateArray | Where-Object { $_.GefyraStatus -eq $Configuration.Statuses.ClosedWithSchedule -and $null -ne $_.ImageHash }
            $hasCurrentHash = $currentStateArray | Where-Object { $_.GefyraStatus -eq $Configuration.Statuses.ClosedWithSchedule -and $null -ne $_.ImageHash }

            $compareProperty = @('GefyraName', 'GefyraStatus')
            if ($hasPreviousHash -and $hasCurrentHash) {
                $compareProperty += 'ImageHash'
            } else {
                $compareProperty += 'ImageUrl'
            }

            $compareSplat = @{
                ReferenceObject  = $previousStateArray
                DifferenceObject = $currentStateArray
                Property         = $compareProperty
                IncludeEqual     = $true
            }
            $diff = Compare-Object @compareSplat
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
                Message = "🌉 $($change.GefyraName) ➜ $($change.GefyraStatus) ($($change.SideIndicator))"
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            if ($change.SideIndicator -eq '==') {
                $currBridge = $currentStateArray | Where-Object { $_.GefyraName -eq $change.GefyraName } | Select-Object -First 1
                $prevBridge = $previousStateArray | Where-Object { $_.GefyraName -eq $change.GefyraName } | Select-Object -First 1
                if ($prevBridge) {
                    $ocrProps = @('From', 'To', 'ClosedFor', 'OpensIn', 'Note1', 'Note2')
                    foreach ($prop in $ocrProps) {
                        if ($prevBridge.psobject.Properties.Match($prop).Count -gt 0 -and $null -ne $prevBridge.$prop) {
                            $currBridge | Add-Member -MemberType NoteProperty -Name $prop -Value $prevBridge.$prop -Force
                        }
                    }
                }
                $writeBridgeLogSplat = @{
                    Level   = 'Verbose'
                    Stage   = 'Ανάλυση'
                    Message = "Καμία ουσιαστική αλλαγή στην $($change.GefyraName)."
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                continue
            }
            if ($change.SideIndicator -ne '=>') {
                # Skip any '<=' side indicators to prevent double notifications
                continue
            }
            $prevBridge = $previousStateArray | Where-Object { $_.GefyraName -eq $change.GefyraName } | Select-Object -First 1
            if ($prevBridge -and $prevBridge.GefyraStatus -eq $change.GefyraStatus) {
                # The status did not change. If it is NOT ClosedWithSchedule, skip it!
                if ($change.GefyraStatus -ne $Configuration.Statuses.ClosedWithSchedule) {
                    $writeBridgeLogSplat = @{
                        Level   = 'Verbose'
                        Stage   = 'Ανάλυση'
                        Message = "Καμία ουσιαστική αλλαγή στην $($change.GefyraName)."
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                    continue
                } else {
                    $currentBridge = $currentStateArray | Where-Object { $_.GefyraName -eq $change.GefyraName } | Select-Object -First 1

                    # Backfill OCR fields when no changes occurred to prevent data loss
                    $ocrProps = @('From', 'To', 'ClosedFor', 'OpensIn', 'Note1', 'Note2')
                    foreach ($prop in $ocrProps) {
                        if ($prevBridge.psobject.Properties.Match($prop).Count -gt 0 -and $null -ne $prevBridge.$prop) {
                            $currentBridge | Add-Member -MemberType NoteProperty -Name $prop -Value $prevBridge.$prop -Force
                        }
                    }
                    if ($currentBridge -and [string]::IsNullOrEmpty($currentBridge.ImageHash) -and -not [string]::IsNullOrEmpty($prevBridge.ImageHash)) {
                        $currentBridge.ImageHash = $prevBridge.ImageHash
                        $writeBridgeLogSplat = @{
                            Level   = 'Verbose'
                            Stage   = 'Ανάλυση'
                            Message = "Αποτυχία λήψης νέου hash. Επαναχρησιμοποίηση προηγούμενου hash για την $($change.GefyraName)."
                        }
                        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                        continue
                    }

                    $writeBridgeLogSplat = @{
                        Level   = 'Verbose'
                        Stage   = 'Ανάλυση'
                        Message = "Εντοπίστηκε ενημέρωση του προγράμματος κλεισίματος για την $($change.GefyraName)."
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                }
            }
            $key = "$($change.GefyraStatus)|$($change.SideIndicator)"
            if ($handlerMap.ContainsKey($key)) {
                $type = $handlerMap[$key]
                # Χρήση helper function για επίλυση bridge state
                $resolveBridgeStateForChangeSplat = @{
                    Change        = $change
                    PreviousState = $previousStateArray
                    CurrentState  = $currentStateArray
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
