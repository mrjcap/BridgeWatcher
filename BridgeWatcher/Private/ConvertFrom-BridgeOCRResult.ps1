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

    $textAnnotations = $null
    if ($null -ne $ApiResponse -and $null -ne $ApiResponse.responses -and $ApiResponse.responses.Count -gt 0) {
        $firstResponse = $ApiResponse.responses[0]
        if ($firstResponse -is [System.Collections.IDictionary]) {
            $textAnnotations = $firstResponse['textAnnotations']
        } elseif ($null -ne $firstResponse -and $firstResponse.PSObject.Properties['textAnnotations']) {
            $textAnnotations = $firstResponse.textAnnotations
        }
    }

    if ($null -eq $textAnnotations -or $textAnnotations.Count -eq 0) {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = 'Δεν βρέθηκαν αποτελέσματα (textAnnotations) στην απόκριση OCR.'
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        return $null
    }

    $ocrText = $textAnnotations[0].description

    $writeBridgeLogSplat = @{
        Stage   = 'Ανάλυση'
        Message = "Απόκριση OCR API: $ocrText"
    }
    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

    if ([string]::IsNullOrWhiteSpace($ocrText)) {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = 'Δεν κατέστη δυνατή η ανάλυση του κειμένου.'
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        return $null
    }

    $rawText = $ocrText
    $Lines = $rawText

    $convertToBridgeTimeRangeSplat = @{
        Lines = $Lines
    }
    $timeRange = ConvertTo-BridgeTimeRange @convertToBridgeTimeRangeSplat
    if (-not $timeRange) {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = 'Δεν κατέστη δυνατή η ανάλυση χρονικού διαστήματος.'
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        return
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

    $minutesLeft = [int]($to - $athensNow).TotalMinutes

    if ($minutesLeft -le 0) {
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

