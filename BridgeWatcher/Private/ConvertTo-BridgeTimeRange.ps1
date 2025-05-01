function ConvertTo-BridgeTimeRange {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Μετατρέπει χρονικό διάστημα σε αναγνώσιμο εύρος ώρας.

    .DESCRIPTION
    Η ConvertTo-BridgeTimeRange λαμβάνει αρχικό και τελικό timestamp και επιστρέφει
    μία φιλική αναπαράσταση εύρους ώρας.

    .PARAMETER StartTimestamp
    Η ώρα έναρξης.

    .PARAMETER EndTimestamp
    Η ώρα λήξης.

    .OUTPUTS
    [string] - Φιλικό χρονικό εύρος.

    .EXAMPLE
    ConvertTo-BridgeTimeRange -StartTimestamp (Get-Date) -EndTimestamp (Get-Date)

    .NOTES
    Το αποτέλεσμα μορφοποιείται σε τοπική ώρα (HH:mm).
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
        $to   = [datetime]::ParseExact($bmatches[1].Value, 'dd/MM/yyyy HH:mm', $null)
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
