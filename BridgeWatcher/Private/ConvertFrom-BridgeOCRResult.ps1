function ConvertFrom-BridgeOCRResult {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Μετατρέπει το αποτέλεσμα OCR ανάλυσης σε αντικείμενα γέφυρας.

    .DESCRIPTION
    Η ConvertFrom-BridgeOCRResult λαμβάνει τα αποτελέσματα OCR και επιστρέφει αντικείμενα
    που περιγράφουν αν η γέφυρα είναι κλειστή, ανοιχτή ή άγνωστη.

    .PARAMETER OcrResult
    Το αντικείμενο αποτελεσμάτων από το OCR API.

    .OUTPUTS
    [pscustomobject[]] - Αντικείμενα κατάστασης γέφυρας.

    .EXAMPLE
    ConvertFrom-BridgeOCRResult -OcrResult $result

    .NOTES
    Χρησιμοποιείται για να αναλυθούν OCR responses και να εξαχθούν status.
    #>

    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)][object]$ApiResponse,
        [Parameter(Mandatory)][string]$ImageUri
    )
    $writeBridgeLogSplat = @{
        Stage   = 'Ανάλυση'
        Message = "OCR ApiResponse: $($ApiResponse.responses[0].textAnnotations[0].description)"
    }
    Write-BridgeLog @writeBridgeLogSplat
    # Έλεγχος για κενό κείμενο OCR
    if (-not $ApiResponse.responses[0].textAnnotations[0].description) {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = 'Δεν κατέστη δυνατή η ανάλυση του κειμένου.'
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        throw [System.Management.Automation.ErrorRecord]::new(([System.Exception]::new('Δεν βρέθηκε κείμενο OCR στην απόκριση.')),'OCRTextNotFound',[System.Management.Automation.ErrorCategory]::InvalidData,$ApiResponse)
    }
    $rawText = $ApiResponse.responses[0].textAnnotations[0].description
    $Lines = $rawText
    $getBridgeNameFromUriSplat = @{
        ImageUri = $ImageUri
    }
    $bridgeName = Get-BridgeNameFromUri @getBridgeNameFromUriSplat
    $convertToBridgeTimeRangeSplat = @{
        Lines = $Lines
    }
    $timeRange = ConvertTo-BridgeTimeRange @convertToBridgeTimeRangeSplat
    $writeBridgeLogSplat = @{
        Stage   = 'Ανάλυση'
        Message = "OCR ➤ No text annotations found in response. $($timeRange)"
    }
    Write-BridgeLog @writeBridgeLogSplat
    if (-not $timeRange) {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = 'Δεν κατέστη δυνατή η ανάλυση χρονικού διαστήματος.'
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        return @()
    }

    $from = $timeRange.From
    $to = $timeRange.To
    $duration = $timeRange.ClosedFor
    $minutesLeft = [int]($to - (Get-Date)).TotalMinutes
    $formatBridgeClosedDurationSplat = @{
        Duration = $duration
    }
    $getBridgeStatusAdviceSplat = @{
        MinutesUntilOpen = $minutesLeft
    }
    $closedForText = ConvertTo-BridgeClosedDuration @formatBridgeClosedDurationSplat
    $advice = Get-BridgeStatusAdvice @getBridgeStatusAdviceSplat
    $advice2 = if ($from -gt (Get-Date)) {
        "Η γέφυρα θα κλείσει στις $($from.ToString('HH:mm')) για $closedForText."
    } else {
        "Η γέφυρα είναι ήδη κλειστή από τις $($from.ToString('HH:mm'))."
    }
    return [PSCustomObject]@{
        'Γέφυρα'      = $bridgeName
        'Από'         = $from.ToString('dd/MM/yyyy HH:mm')
        'Έως'         = $to.ToString('dd/MM/yyyy HH:mm')
        'Κλειστή για' = $closedForText
        'Ανοίγει σε'  = "$minutesLeft λεπτά"
        'Σημείωση 1'  = $advice
        'Σημείωση 2'  = $advice2
    }
}