<#
    .SYNOPSIS
    Συγκρίνει τις λίστες καταστάσεων γεφυρών και επιστρέφει γεγονότα διαφορών.

    .DESCRIPTION
    Η Invoke-BridgeStatusComparison συγκρίνει την προηγούμενη και την τρέχουσα
    κατάσταση γεφυρών, εμπλουτίζει τα δεδομένα με πληροφορίες από το προηγούμενο
    ιστορικό και παράγει αντικείμενα diff events για τις αλλαγές κατάστασης.

    .PARAMETER PreviousState
    Η προηγούμενη λίστα καταστάσεων.

    .PARAMETER CurrentState
    Η τρέχουσα λίστα καταστάσεων.

    .PARAMETER Configuration
    Αντικείμενο διαμόρφωσης με ρυθμίσεις, statuses και URLs.

    .OUTPUTS
    [PSCustomObject[]]

    .EXAMPLE
    Invoke-BridgeStatusComparison -PreviousState $prev -CurrentState $curr -Configuration $config

    .NOTES
    Λειτουργεί ως pure transformation pipeline χωρίς εξωτερικές παρενέργειες.
    #>
function Invoke-BridgeStatusComparison {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param (
        [Parameter()]
        [AllowNull()]
        [AllowEmptyCollection()]
        [object]$PreviousState = @(),

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [object]$CurrentState,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$Configuration
    )
    try {
        $previousStateArray = @($PreviousState | Where-Object { $null -ne $_ })
        $currentStateArray = @($CurrentState | Where-Object { $null -ne $_ })

        $diffEvents = @()

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
                $writeBridgeLogSplat.Message = "Καμία ουσιαστική αλλαγή στην $($change.GefyraName)."
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                # Backfill OCR properties for persistence
                $prevBridge = $previousStateArray | Where-Object { $_.GefyraName -eq $change.GefyraName } | Select-Object -First 1
                $currentBridge = $currentStateArray | Where-Object { $_.GefyraName -eq $change.GefyraName } | Select-Object -First 1
                if ($prevBridge -and $currentBridge) {
                    foreach ($prop in @('From', 'To', 'ClosedFor', 'OpensIn', 'Note1', 'Note2', 'ImageHash')) {
                        if ($null -ne $prevBridge.$prop -and [string]::IsNullOrEmpty($currentBridge.$prop)) {
                            $currentBridge | Add-Member -MemberType NoteProperty -Name $prop -Value $prevBridge.$prop -Force
                        }
                    }
                }
                continue
            }
            if ($change.SideIndicator -ne '=>') {
                continue
            }

            $prevBridge = $previousStateArray | Where-Object { $_.GefyraName -eq $change.GefyraName } | Select-Object -First 1
            if ($prevBridge -and $prevBridge.GefyraStatus -eq $change.GefyraStatus) {
                if ($change.GefyraStatus -ne $Configuration.Statuses.ClosedWithSchedule) {
                    $writeBridgeLogSplat.Message = "Καμία ουσιαστική αλλαγή στην $($change.GefyraName)."
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                    continue
                } else {
                    $currentBridge = $currentStateArray | Where-Object { $_.GefyraName -eq $change.GefyraName } | Select-Object -First 1
                    if ($currentBridge -and [string]::IsNullOrEmpty($currentBridge.ImageHash) -and -not [string]::IsNullOrEmpty($prevBridge.ImageHash)) {
                        $writeBridgeLogSplat.Message = "Αποτυχία λήψης νέου hash. Επαναχρησιμοποίηση προηγούμενου hash για την $($change.GefyraName)."
                        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                        $currentBridge.ImageHash = $prevBridge.ImageHash
                        # Also backfill OCR properties since hash is same
                        foreach ($prop in @('From', 'To', 'ClosedFor', 'OpensIn', 'Note1', 'Note2')) {
                            if ($null -ne $prevBridge.$prop -and [string]::IsNullOrEmpty($currentBridge.$prop)) {
                                $currentBridge | Add-Member -MemberType NoteProperty -Name $prop -Value $prevBridge.$prop -Force
                            }
                        }
                        continue
                    }
                    $writeBridgeLogSplat.Message = "Εντοπίστηκε ενημέρωση του προγράμματος κλεισίματος για την $($change.GefyraName)."
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                }
            }

            $key = "$($change.GefyraStatus)|$($change.SideIndicator)"
            if ($handlerMap.ContainsKey($key)) {
                $type = $handlerMap[$key]
                $resolveBridgeStateForChangeSplat = @{
                    Change        = $change
                    PreviousState = $previousStateArray
                    CurrentState  = $currentStateArray
                }
                $changedBridgeState = Resolve-BridgeStateForChange @resolveBridgeStateForChangeSplat
                if ($changedBridgeState.Count -gt 0) {
                    $diffEvents += [PSCustomObject]@{
                        BridgeName = $change.GefyraName
                        Status     = $change.GefyraStatus
                        Type       = $type
                        StateInfo  = $changedBridgeState
                    }
                }
            } else {
                $writeBridgeLogSplat = @{
                    Stage   = 'Σφάλμα'
                    Message = "❓ Άγνωστο combo: $key"
                    Level   = 'Warning'
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            }
        }
        return $diffEvents
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
