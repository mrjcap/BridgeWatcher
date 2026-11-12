<#
    .SYNOPSIS
    Αντιγράφει ιδιότητες OCR από την προηγούμενη στην τρέχουσα εγγραφή γέφυρας.

    .DESCRIPTION
    Συμπληρώνει κενές ιδιότητες OCR στην τρέχουσα εγγραφή γέφυρας από την προηγούμενη.

    .PARAMETER PreviousBridge
    Η προηγούμενη εγγραφή γέφυρας.

    .PARAMETER CurrentBridge
    Η τρέχουσα εγγραφή γέφυρας.

    .PARAMETER PropertyNames
    Τα ονόματα των ιδιοτήτων προς αντιγραφή.
    #>
function Copy-BridgePreviousOcrProperty {
    [CmdletBinding()]
    param (
        [Parameter()][AllowNull()][object]$PreviousBridge,
        [Parameter()][AllowNull()][object]$CurrentBridge,
        [Parameter(Mandatory)][string[]]$PropertyNames
    )
    if (-not $PreviousBridge -or -not $CurrentBridge) {
        return
    }
    foreach ($prop in $PropertyNames) {
        $prevVal = Get-BridgeOptionalProperty -InputObject $PreviousBridge -PropertyName $prop
        $currVal = Get-BridgeOptionalProperty -InputObject $CurrentBridge -PropertyName $prop
        if ($null -ne $prevVal -and [string]::IsNullOrEmpty([string]$currVal)) {
            if ($CurrentBridge -is [System.Collections.IDictionary]) {
                $CurrentBridge[$prop] = $prevVal
            } else {
                $CurrentBridge | Add-Member -MemberType NoteProperty -Name $prop -Value $prevVal -Force
            }
        }
    }
}

<#
    .SYNOPSIS
    Υπολογίζει τις ακατέργαστες διαφορές μεταξύ προηγούμενης και τρέχουσας κατάστασης.

    .DESCRIPTION
    Επιστρέφει τα αποτελέσματα σύγκρισης για την πρώτη εκτέλεση ή μέσω Compare-Object.

    .PARAMETER PreviousStateArray
    Ο πίνακας προηγούμενων καταστάσεων.

    .PARAMETER CurrentStateArray
    Ο πίνακας τρεχουσών καταστάσεων.

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης.
    #>
function Get-BridgeRawComparisonDiff {
    [CmdletBinding()]
    [OutputType([object[]])]
    param (
        [Parameter()][AllowEmptyCollection()][object[]]$PreviousStateArray = @(),
        [Parameter(Mandatory)][object[]]$CurrentStateArray,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    if ($PreviousStateArray.Count -eq 0) {
        return @($CurrentStateArray | ForEach-Object {
            [PSCustomObject]@{
                GefyraName    = $_.GefyraName
                GefyraStatus  = $_.GefyraStatus
                ImageUrl      = (Get-BridgeOptionalProperty -InputObject $_ -PropertyName 'ImageUrl')
                ImageHash     = (Get-BridgeOptionalProperty -InputObject $_ -PropertyName 'ImageHash')
                SideIndicator = '=>'
            }
        })
    }

    $scheduledStatus = $Configuration.Statuses.ClosedWithSchedule
    # Compare each bridge independently. Explicitly missing hashes are unknown,
    # not image changes; records without the field retain the legacy URL fallback.
    $imageProperty = {
        $hasHashProperty = if ($_ -is [System.Collections.IDictionary]) {
            $_.Contains('ImageHash')
        } else {
            $null -ne $_.PSObject.Properties['ImageHash']
        }
        if ($_.GefyraStatus -eq $scheduledStatus -and $hasHashProperty) {
            $hash = Get-BridgeOptionalProperty -InputObject $_ -PropertyName 'ImageHash'
            if (-not [string]::IsNullOrEmpty([string]$hash)) { $hash }
        } else {
            Get-BridgeOptionalProperty -InputObject $_ -PropertyName 'ImageUrl'
        }
    }
    $compareSplat = @{
        ReferenceObject  = $PreviousStateArray
        DifferenceObject = $CurrentStateArray
        Property         = @('GefyraName', 'GefyraStatus', $imageProperty)
        IncludeEqual     = $true
    }
    return @(Compare-Object @compareSplat)
}

<#
    .SYNOPSIS
    Ελέγχει αν μια αλλαγή κατάστασης γέφυρας απαιτεί αποστολή ειδοποίησης.

    .DESCRIPTION
    Αξιολογεί το SideIndicator, συμπληρώνει ιδιότητες OCR όταν δεν υπάρχει ουσιαστική αλλαγή,
    και επιστρέφει $true μόνο όταν πρέπει να παραχθεί γεγονός αλλαγής.

    .PARAMETER Change
    Το αντικείμενο διαφοράς προς έλεγχο.

    .PARAMETER PreviousStateArray
    Ο πίνακας προηγούμενων καταστάσεων.

    .PARAMETER CurrentStateArray
    Ο πίνακας τρεχουσών καταστάσεων.

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης.
    #>
function Test-BridgeChangeIsActionable {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)][object]$Change,
        [Parameter()][AllowEmptyCollection()][object[]]$PreviousStateArray = @(),
        [Parameter(Mandatory)][object[]]$CurrentStateArray,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    $logSplat = @{
        Level = 'Verbose'
        Stage = 'Ανάλυση'
    }
    $prevBridge = $PreviousStateArray | Where-Object { $_.GefyraName -eq $Change.GefyraName } | Select-Object -First 1
    $currentBridge = $CurrentStateArray | Where-Object { $_.GefyraName -eq $Change.GefyraName } | Select-Object -First 1
    $ocrProps = @('ScheduleState', 'From', 'To', 'ClosedFor', 'OpensIn', 'Note1', 'Note2', 'ImageHash')

    if ($Change.SideIndicator -eq '==') {
        $logSplat.Message = "Καμία ουσιαστική αλλαγή στην $($Change.GefyraName)."
        Write-BridgeLog @logSplat -Configuration $Configuration
        Copy-BridgePreviousOcrProperty -PreviousBridge $prevBridge -CurrentBridge $currentBridge -PropertyNames $ocrProps
        return $false
    }

    if ($Change.SideIndicator -ne '=>') {
        return $false
    }

    if (-not $prevBridge -or $prevBridge.GefyraStatus -ne $Change.GefyraStatus) {
        return $true
    }

    if ($Change.GefyraStatus -ne $Configuration.Statuses.ClosedWithSchedule) {
        $logSplat.Message = "Καμία ουσιαστική αλλαγή στην $($Change.GefyraName)."
        Write-BridgeLog @logSplat -Configuration $Configuration
        return $false
    }

    if ($currentBridge -and [string]::IsNullOrEmpty([string](Get-BridgeOptionalProperty -InputObject $currentBridge -PropertyName 'ImageHash')) -and -not [string]::IsNullOrEmpty([string](Get-BridgeOptionalProperty -InputObject $prevBridge -PropertyName 'ImageHash'))) {
        $logSplat.Message = "Αποτυχία λήψης νέου hash. Επαναχρησιμοποίηση προηγούμενου hash για την $($Change.GefyraName)."
        Write-BridgeLog @logSplat -Configuration $Configuration
        Copy-BridgePreviousOcrProperty -PreviousBridge $prevBridge -CurrentBridge $currentBridge -PropertyNames $ocrProps
        return $false
    }

    $logSplat.Message = "Εντοπίστηκε ενημέρωση του προγράμματος κλεισίματος για την $($Change.GefyraName)."
    Write-BridgeLog @logSplat -Configuration $Configuration
    return $true
}

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
        $diff = Get-BridgeRawComparisonDiff -PreviousStateArray $previousStateArray -CurrentStateArray $currentStateArray -Configuration $Configuration

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

            $actionableSplat = @{
                Change             = $change
                PreviousStateArray = $previousStateArray
                CurrentStateArray  = $currentStateArray
                Configuration      = $Configuration
            }
            if (-not (Test-BridgeChangeIsActionable @actionableSplat)) {
                continue
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
