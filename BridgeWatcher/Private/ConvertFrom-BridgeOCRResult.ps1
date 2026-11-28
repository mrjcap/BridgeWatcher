<#
.SYNOPSIS
Returns the current time in the bridge's configured time zone.
.DESCRIPTION
Tries the configured zone IDs in order and falls back to local time with a warning.
.PARAMETER TimezoneIds
Platform-specific IDs for the bridge's time zone, in preference order.
#>
function Get-BridgeScheduleLocalTime {
    [CmdletBinding()]
    [OutputType([datetime])]
    param([string[]]$TimezoneIds)

    if ($null -eq $TimezoneIds -or $TimezoneIds.Count -eq 0) {
        $TimezoneIds = @('GTB Standard Time', 'Europe/Athens')
    }
    foreach ($tzId in $TimezoneIds) {
        try {
            $zone = [System.TimeZoneInfo]::FindSystemTimeZoneById($tzId)
        } catch {
            Write-Verbose -Message "Timezone ID $tzId not supported on this platform: $($_.Exception.Message)"
            continue
        }
        return [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $zone)
    }
    Write-Warning -Message "All $($TimezoneIds.Count) timezone IDs failed ($($TimezoneIds -join ', ')). Falling back to local time."
    return Get-Date
}

<#
.SYNOPSIS
Μετατρέπει το αποτέλεσμα OCR ανάλυσης σε αντικείμενα γέφυρας.

.DESCRIPTION
Η ConvertFrom-BridgeOCRResult λαμβάνει τα αποτελέσματα OCR και επιστρέφει αντικείμενα
που περιγράφουν αν η γέφυρα είναι κλειστή, ανοιχτή ή άγνωστη.

.PARAMETER Configuration
Το αντικείμενο διαμόρφωσης που περιέχει τις ρυθμίσεις.

.PARAMETER ApiResponse
Το αντικείμενο απόκρισης από το Google Vision API.

.OUTPUTS
[pscustomobject[]] - Αντικείμενα κατάστασης γέφυρας.

.EXAMPLE
ConvertFrom-BridgeOCRResult -Configuration $config -ApiResponse $response

.NOTES
Χρησιμοποιείται για την ανάλυση των αποκρίσεων OCR και την εξαγωγή της κατάστασης της γέφυρας.
#>
function ConvertFrom-BridgeOCRResult {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter(Mandatory)]
        [PSCustomObject]$ApiResponse
    )

    $textAnnotations = @()
    $imageError = $null
    $responses = @(Get-BridgeOptionalProperty -InputObject $ApiResponse -PropertyName 'responses')
    if ($responses.Count -gt 0 -and $null -ne $responses[0]) {
        $textAnnotations = @(Get-BridgeOptionalProperty -InputObject $responses[0] -PropertyName 'textAnnotations')
        $imageError = Get-BridgeOptionalProperty -InputObject $responses[0] -PropertyName 'error'
    }

    $timeRange = $null
    if ($textAnnotations.Count -eq 0 -or $null -eq $textAnnotations[0]) {
        $warningMessage = 'Δεν βρέθηκαν αποτελέσματα (textAnnotations) στην απόκριση OCR.'
    } else {
        $ocrText = Get-BridgeOptionalProperty -InputObject $textAnnotations[0] -PropertyName 'description'
        Write-BridgeLog -Stage 'Ανάλυση' -Message "Απόκριση OCR API: $ocrText" -Configuration $Configuration
        if ([string]::IsNullOrWhiteSpace($ocrText)) {
            $warningMessage = 'Δεν κατέστη δυνατή η ανάλυση του κειμένου.'
        } else {
            $timeRange = ConvertTo-BridgeTimeRange -Lines $ocrText
            $warningMessage = 'Δεν κατέστη δυνατή η ανάλυση χρονικού διαστήματος.'
        }
    }
    if (-not $timeRange) {
        if ($null -ne $imageError) {
            throw 'Google Vision reported an image error without a readable schedule.'
        }
        Write-BridgeLog -Stage 'Σφάλμα' -Message $warningMessage -Level 'Warning' -Configuration $Configuration
        return $null
    }

    $writeBridgeLogSplat = @{
        Stage   = 'Ανάλυση'
        Message = "OCR ➤ Επιτυχής ανάλυση χρονικού εύρους: Από = $($timeRange.From), Έως = $($timeRange.To), ΚλειστήΓια = $($timeRange.ClosedFor)"
    }
    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

    $from = $timeRange.From
    $to = $timeRange.To
    $duration = $timeRange.ClosedFor

    $athensNow = Get-BridgeScheduleLocalTime -TimezoneIds $Configuration.Defaults.TimezoneIds

    if ($to -le $athensNow) {
        return [PSCustomObject]@{
            'ScheduleState' = 'Expired'
            'From'          = $from.ToString('dd/MM/yyyy HH:mm')
            'To'            = $to.ToString('dd/MM/yyyy HH:mm')
            'ClosedFor'     = 'Ολοκληρώθηκε'
            'OpensIn'       = 'Τώρα'
            'Note1'         = 'Η γέφυρα έχει ανοίξει ή το χρονικό διάστημα έχει παρέλθει.'
            'Note2'         = 'Η γέφυρα είναι ανοιχτή.'
        }
    }

    $formatBridgeClosedDurationSplat = @{
        Duration = $duration
    }
    $closedForText = ConvertTo-BridgeClosedDuration @formatBridgeClosedDurationSplat

    if ($from -gt $athensNow) {
        return [PSCustomObject]@{
            'ScheduleState' = 'Future'
            'From'          = $from.ToString('dd/MM/yyyy HH:mm')
            'To'            = $to.ToString('dd/MM/yyyy HH:mm')
            'ClosedFor'     = $closedForText
            'OpensIn'       = ''
            'Note1'         = ''
            'Note2'         = "Η γέφυρα θα κλείσει στις $($from.ToString('HH:mm')) για $closedForText."
        }
    }

    $minutesLeft = [Math]::Max(1, [int]($to - $athensNow).TotalMinutes)
    $getBridgeStatusAdviceSplat = @{
        MinutesUntilOpen = $minutesLeft
    }
    $advice = Get-BridgeStatusAdvice @getBridgeStatusAdviceSplat -Configuration $Configuration
    return [PSCustomObject]@{
        'ScheduleState' = 'Active'
        'From'          = $from.ToString('dd/MM/yyyy HH:mm')
        'To'            = $to.ToString('dd/MM/yyyy HH:mm')
        'ClosedFor'     = $closedForText
        'OpensIn'       = "$minutesLeft λεπτά"
        'Note1'         = $advice
        'Note2'         = "Η γέφυρα είναι ήδη κλειστή από τις $($from.ToString('HH:mm'))."
    }
}

