function ConvertTo-BridgeTimeRange {
    [CmdletBinding()]
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
    [PSCustomObject] - Αντικείμενο με From, To και ClosedFor properties.

    .EXAMPLE
    ConvertTo-BridgeTimeRange -Lines @('Από 25/04/2025 14:00', 'Έως 25/04/2025 14:30')
    # Returns:@{From=[datetime]; To=[datetime]; ClosedFor=[timespan]}

    .NOTES
    Χρησιμοποιεί regex pattern matching για εξαγωγή ημερομηνιών
    με μορφή dd/MM/yyyy HH:mm από το κείμενο.
    #>

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
        $from = [datetime]::ParseExact($bmatches[0].Value, 'dd/MM/yyyy HH:mm', $null)
        $to = [datetime]::ParseExact($bmatches[1].Value, 'dd/MM/yyyy HH:mm', $null)
        # Επιστρέφουμε structured αντικείμενο
        return [PSCustomObject]@{
            From      = $from
            To        = $to
            ClosedFor = $to - $from
        }
    }
    catch {
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Αποτυχία ανάλυσης ημερομηνιών: $($_.Exception.Message)")),
            'BridgeTimeParseError',
            [System.Management.Automation.ErrorCategory]::InvalidData,
            $Lines
        )
        throw $errorRecord
    }
}
