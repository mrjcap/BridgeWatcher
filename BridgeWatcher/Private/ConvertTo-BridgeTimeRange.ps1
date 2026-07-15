function ConvertTo-BridgeTimeRange {
    <#
    .SYNOPSIS
    Εξάγει χρονικό εύρος από κείμενο OCR.

    .DESCRIPTION
    Η ConvertTo-BridgeTimeRange αναλύει γραμμές κειμένου από OCR
    και εξάγει ημερομηνίες/ώρες για να δημιουργήσει χρονικό εύρος
    κλεισίματος γέφυρας.

    .PARAMETER Lines
    Πίνακας με γραμμές κειμένου από OCR ανάλυση.

    .OUTPUTS
    [PSCustomObject] - Αντικείμενο με ιδιότητες From, To και ClosedFor, ή $null αν αποτύχει.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Lines
    )
    try {
        $text = $Lines -join ' '
        # Regex that uses capture groups to ignore extraneous whitespace introduced by OCR
        $pattern = '(?<Date>\d{2}/\d{2}/\d{4})\s+(?<Time>\d{2}:\d{2})'

        $bmatches = [regex]::Matches($text, $pattern)

        if ($bmatches.Count -lt 2) {
            Write-Verbose "Δεν βρέθηκαν επαρκείς ημερομηνίες και ώρες για ανάλυση στο κείμενο OCR."
            return $null
        }

        $culture = [System.Globalization.CultureInfo]::InvariantCulture

        # Extract exactly the captured groups to avoid parsing errors from OCR spacing
        $dateStr1 = "$($bmatches[0].Groups['Date'].Value) $($bmatches[0].Groups['Time'].Value)"
        $dateStr2 = "$($bmatches[1].Groups['Date'].Value) $($bmatches[1].Groups['Time'].Value)"

        $date1 = [datetime]::ParseExact($dateStr1, 'dd/MM/yyyy HH:mm', $culture)
        $date2 = [datetime]::ParseExact($dateStr2, 'dd/MM/yyyy HH:mm', $culture)

        if ($date1 -gt $date2) {
            $from = $date2
            $to = $date1
        } else {
            $from = $date1
            $to = $date2
        }

        return [PSCustomObject]@{
            From      = $from
            To        = $to
            ClosedFor = $to - $from
        }
    }
    catch {
        Write-Warning "Αποτυχία ανάλυσης ημερομηνιών OCR: $($_.Exception.Message)"
        return $null
    }
}
