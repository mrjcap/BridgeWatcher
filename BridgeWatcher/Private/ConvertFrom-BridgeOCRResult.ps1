function ConvertFrom-BridgeOCRResult {
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
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter(Mandatory)]
        [PSCustomObject]$ApiResponse
    )

    if ($null -eq $ApiResponse -or $null -eq $ApiResponse.responses -or $ApiResponse.responses.Count -eq 0 -or $null -eq $ApiResponse.responses[0].textAnnotations -or $ApiResponse.responses[0].textAnnotations.Count -eq 0) {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = 'Δεν βρέθηκαν αποτελέσματα (textAnnotations) στην απόκριση OCR.'
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        return $null
    }

    $textAnnotations = $ApiResponse.responses[0].textAnnotations
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

    # Χρήση του ήδη εξαχθέντος ασφαλούς κειμένου
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

    $athensZone = $null
    $timezoneIds = $Configuration.Defaults.TimezoneIds
    if ($null -eq $timezoneIds -or $timezoneIds.Count -eq 0) {
        $timezoneIds = @('GTB Standard Time', 'Europe/Athens')
    }
    $failedTimezoneCount = 0
    foreach ($tzId in $timezoneIds) {
        try {
            $athensZone = [System.TimeZoneInfo]::FindSystemTimeZoneById($tzId)
            break
        } catch {
            $failedTimezoneCount += 1
            Write-Verbose "Timezone ID $tzId not supported on this platform: $($_.Exception.Message)"
        }
    }
    if ($null -eq $athensZone) {
        Write-Warning "All $failedTimezoneCount timezone IDs failed ($($timezoneIds -join ', ')). Falling back to local time."
    }
    $athensNow = if ($null -ne $athensZone) {
        [System.TimeZoneInfo]::ConvertTimeFromUtc((Get-Date).ToUniversalTime(), $athensZone)
    } else {
        Get-Date
    }

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

