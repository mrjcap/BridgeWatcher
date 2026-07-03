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
    [PSCustomObject] - Αντικείμενο με ιδιότητες From, To και ClosedFor.

    .EXAMPLE
    ConvertTo-BridgeTimeRange -Lines @('Από 25/04/2025 14:00', 'Έως 25/04/2025 14:30')
    # Επιστρέφει: @{From=[datetime]; To=[datetime]; ClosedFor=[timespan]}

    .NOTES
    Χρησιμοποιεί regex pattern matching για εξαγωγή ημερομηνιών
    με μορφή dd/MM/yyyy HH:mm από το κείμενο.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [string[]]$Lines
    )
    try {
        # Συνενώνουμε όλες τις γραμμές σε ένα ενιαίο string
        $text = $Lines -join ' '
        # Ορίζουμε regex pattern για ημερομηνία και ώρα
        $pattern = '(?<Date>\d{2}/\d{2}/\d{4})\s+(?<Time>\d{2}:\d{2})'
        # Εκτελούμε regex match
        $bmatches = [regex]::Matches($text, $pattern)
        # Βεβαιωνόμαστε ότι υπάρχουν τουλάχιστον δύο matches
        if ($bmatches.Count -lt 2) {
            throw [System.Management.Automation.ErrorRecord]::new(
                ([System.Exception]::new('Αποτυχία ανάλυσης ημερομηνιών: Δεν βρέθηκαν επαρκείς ημερομηνίες και ώρες για ανάλυση.')),
                'NotEnoughDateTimes',
                [System.Management.Automation.ErrorCategory]::InvalidData,
                $Lines
            )
        }
        # Παίρνουμε τα 2 πρώτα matches
        $date1 = [datetime]::ParseExact($bmatches[0].Value, 'dd/MM/yyyy HH:mm', $null)
        $date2 = [datetime]::ParseExact($bmatches[1].Value, 'dd/MM/yyyy HH:mm', $null)

        # Ταξινομούμε χρονολογικά
        if ($date1 -gt $date2) {
            $from = $date2
            $to = $date1
        } else {
            $from = $date1
            $to = $date2
        }

        # Επιστρέφουμε structured αντικείμενο
        return [PSCustomObject]@{
            From      = $from
            To        = $to
            ClosedFor = $to - $from
        }
    }
    catch {
        if ($_.FullyQualifiedErrorId -eq 'NotEnoughDateTimes' -or ($_.Exception -and $_.Exception.Message -like '*Δεν βρέθηκαν επαρκείς ημερομηνίες*')) {
            throw $_
        }
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Αποτυχία ανάλυσης ημερομηνιών: $($_.Exception.Message)", $_.Exception)),
            'BridgeTimeParseError',
            [System.Management.Automation.ErrorCategory]::InvalidData,
            $Lines
        )
        throw $errorRecord
    }
}

