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
    $ocrProps = @('ScheduleState', 'From', 'To', 'ClosedFor', 'OpensIn', 'Note1', 'Note2', 'ImageHash', 'FallbackNotifiedImageHash')

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

    # The delivered fallback belongs to these image bytes, not to a changing URL.
    $previousFallback = Get-BridgeOptionalProperty -InputObject $prevBridge -PropertyName 'FallbackNotifiedImageHash'
    if ($previousFallback -and $previousFallback -eq (Get-BridgeOptionalProperty -InputObject $currentBridge -PropertyName 'ImageHash')) {
        Copy-BridgePreviousOcrProperty -PreviousBridge $prevBridge -CurrentBridge $currentBridge -PropertyNames 'FallbackNotifiedImageHash'
    }

    $logSplat.Message = "Εντοπίστηκε ενημέρωση του προγράμματος κλεισίματος για την $($Change.GefyraName)."
    Write-BridgeLog @logSplat -Configuration $Configuration
    return $true
}

<#
    .SYNOPSIS
    Checks whether a scheduled bridge closure has ended.

    .DESCRIPTION
    Confirms that the schedule image was replaced by the open placeholder and
    that the saved schedule's end time has passed in the bridge's time zone.

    .PARAMETER PreviousBridge
    The saved bridge state that contains the closure schedule.

    .PARAMETER CurrentBridge
    The latest bridge state and image.

    .PARAMETER Configuration
    The configuration containing the bridge time zone IDs.
#>
function Test-BridgeScheduledOpening {
    param($PreviousBridge, $CurrentBridge, $Configuration)

    # Ignore cache-busting queries when comparing the saved and current images.
    $previousPath = (Get-BridgeOptionalProperty -InputObject $PreviousBridge -PropertyName 'ImageUrl') -replace '[?#].*$', ''
    $currentPath = (Get-BridgeOptionalProperty -InputObject $CurrentBridge -PropertyName 'ImageUrl') -replace '[?#].*$', ''
    if (-not $previousPath -or $currentPath -eq $previousPath -or
        $currentPath -notmatch '(?:^|/)image-bridge-open-no-schedule\.php$' -or
        (Get-BridgeOptionalProperty -InputObject $CurrentBridge -PropertyName 'HasScheduleImage')) {
        return $false
    }

    $savedTo = Get-BridgeOptionalProperty -InputObject $PreviousBridge -PropertyName 'To'
    $end = [datetime]::MinValue
    if ($savedTo -isnot [string] -or -not [datetime]::TryParseExact($savedTo, 'dd/MM/yyyy HH:mm',
            [cultureinfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::None, [ref]$end)) {
        return $false
    }
    $timezoneIds = $Configuration.Defaults.TimezoneIds
    if (-not $timezoneIds) { $timezoneIds = @('GTB Standard Time', 'Europe/Athens') }
    foreach ($id in $timezoneIds) {
        try {
            $zone = [TimeZoneInfo]::FindSystemTimeZoneById($id)
        } catch {
            Write-Verbose "Cannot resolve configured time zone '$id': $_"
            continue
        }
        if ($zone.IsInvalidTime($end)) {
            return $false
        }
        $endUtc = if ($zone.IsAmbiguousTime($end)) {
            # The smaller UTC offset gives the later occurrence of the wall time.
            $offset = $zone.GetAmbiguousTimeOffsets($end) | Sort-Object | Select-Object -First 1
            [datetimeoffset]::new($end, $offset).UtcDateTime
        } else {
            [TimeZoneInfo]::ConvertTimeToUtc($end, $zone)
        }
        return ($endUtc -lt (Get-Date).ToUniversalTime())
    }
    return $false
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

    .PARAMETER DeferredOpenings
    Optional table populated with previous records for deferred openings, keyed by bridge name.

    .OUTPUTS
    [PSCustomObject[]]

    .EXAMPLE
    Invoke-BridgeStatusComparison -PreviousState $prev -CurrentState $curr -Configuration $config

    .NOTES
    Reads the clock for scheduled openings and does not write a snapshot or send notifications.
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
        [PSCustomObject]$Configuration,

        [Parameter()]
        [ValidateNotNull()]
        [hashtable]$DeferredOpenings = @{}
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
            if (-not $handlerMap.ContainsKey($key)) {
                $writeBridgeLogSplat = @{
                    Stage   = 'Σφάλμα'
                    Message = "❓ Άγνωστο combo: $key"
                    Level   = 'Warning'
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                continue
            }

            $type = $handlerMap[$key]
            $changedBridgeState = Resolve-BridgeStateForChange -Change $change -PreviousState $previousStateArray -CurrentState $currentStateArray
            if ($changedBridgeState.Count -eq 0) { continue }

            if ($type -eq 'Opened') {
                $saved = $previousStateArray | Where-Object -Property GefyraName -EQ -Value $change.GefyraName | Select-Object -First 1
                if ($saved -and $saved.GefyraStatus -eq $Configuration.Statuses.ClosedWithSchedule -and
                    -not (Test-BridgeScheduledOpening -PreviousBridge $saved -CurrentBridge $changedBridgeState[0] -Configuration $Configuration)) {
                    $DeferredOpenings[$change.GefyraName] = $saved
                    continue
                }
            }
            $diffEvents += [PSCustomObject]@{
                BridgeName = $change.GefyraName
                Status     = $change.GefyraStatus
                Type       = $type
                StateInfo  = $changedBridgeState
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
