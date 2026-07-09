function ConvertFrom-BridgeOCRResult {
    <#
    .SYNOPSIS
    Μετατρέπει το αποτέλεσμα OCR ανάλυσης σε αντικείμενα γέφυρας.

    .DESCRIPTION
    Η ConvertFrom-BridgeOCRResult λαμβάνει τα αποτελέσματα OCR και επιστρέφει αντικείμενα
    που περιγράφουν αν η γέφυρα είναι κλειστή, ανοιχτή ή άγνωστη.

    .PARAMETER ApiResponse
    Το αντικείμενο απόκρισης από το Google Vision API.

    .PARAMETER ImageUri
    Το URI της εικόνας που αναλύθηκε με OCR.

    .OUTPUTS
    [pscustomobject[]] - Αντικείμενα κατάστασης γέφυρας.

    .EXAMPLE
    ConvertFrom-BridgeOCRResult -ApiResponse $response -ImageUri 'https://example.com/bridge.jpg'

    .NOTES
    Χρησιμοποιείται για την ανάλυση των αποκρίσεων OCR και την εξαγωγή της κατάστασης της γέφυρας.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter(Mandatory)]
        [ValidateScript({
                $null -ne $_ -and
                $null -ne $_.responses -and
                $_.responses.Count -gt 0 -and
                $null -ne $_.responses[0] -and
                $null -ne $_.responses[0].textAnnotations
            })]
        [PSCustomObject]$ApiResponse,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ImageUri
    )

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
        throw [System.Management.Automation.ErrorRecord]::new(([System.Exception]::new('Δεν βρέθηκε κείμενο OCR στην απόκριση.')), 'OCRTextNotFound', [System.Management.Automation.ErrorCategory]::InvalidData, $ApiResponse)
    }

    # Χρήση του ήδη εξαχθέντος ασφαλούς κειμένου
    $rawText = $ocrText
    $Lines = $rawText

    $getBridgeNameFromUriSplat = @{
        ImageUri = $ImageUri
    }
    $bridgeName = Get-BridgeNameFromUri @getBridgeNameFromUriSplat -Configuration $Configuration

    $convertToBridgeTimeRangeSplat = @{
        Lines = $Lines
    }
    $timeRange = ConvertTo-BridgeTimeRange @convertToBridgeTimeRangeSplat
    $writeBridgeLogSplat = @{
        Stage   = 'Ανάλυση'
        Message = "OCR ➤ Επιτυχής ανάλυση χρονικού εύρους: Από = $($timeRange.From), Έως = $($timeRange.To), ΚλειστήΓια = $($timeRange.ClosedFor)"
    }
    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
    if (-not $timeRange) {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = 'Δεν κατέστη δυνατή η ανάλυση χρονικού διαστήματος.'
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        return
    }

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
    $formatBridgeClosedDurationSplat = @{
        Duration = $duration
    }
    $getBridgeStatusAdviceSplat = @{
        MinutesUntilOpen = $minutesLeft
    }
    $closedForText = ConvertTo-BridgeClosedDuration @formatBridgeClosedDurationSplat
    $advice = Get-BridgeStatusAdvice @getBridgeStatusAdviceSplat -Configuration $Configuration
    $advice2 = if ($from -gt $athensNow) {
        "Η γέφυρα θα κλείσει στις $($from.ToString('HH:mm')) για $closedForText."
    } else {
        "Η γέφυρα είναι ήδη κλειστή από τις $($from.ToString('HH:mm'))."
    }
    return [PSCustomObject]@{
        'Bridge'      = $bridgeName
        'From'        = $from.ToString('dd/MM/yyyy HH:mm')
        'To'          = $to.ToString('dd/MM/yyyy HH:mm')
        'ClosedFor'   = $closedForText
        'OpensIn'     = "$minutesLeft λεπτά"
        'Note1'       = $advice
        'Note2'       = $advice2
    }
}

