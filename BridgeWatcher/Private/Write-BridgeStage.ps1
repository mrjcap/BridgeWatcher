function Write-BridgeStage {
    [OutputType([void])]
    <#
    .SYNOPSIS
    Εμφανίζει μήνυμα στα logs με καθορισμένο επίπεδο και στάδιο.

    .DESCRIPTION
    Η Write-BridgeStage χρησιμοποιείται για να καταγράφει μηνύματα στα logs της εφαρμογής BridgeWatcher,
    βοηθώντας στον διαχωρισμό των σταδίων (π.χ. 'Ανάλυση', 'Σφάλμα') και των επιπέδων logging ('Verbose', 'Debug', 'Warning').
    Βασίζεται στην Write-BridgeLog για πραγματική καταγραφή, προσφέροντας πιο φιλικό interface για σταδιακή αναφορά και ανάλυση.

    .PARAMETER Stage
    Το στάδιο στο οποίο αναφέρεται το μήνυμα (π.χ. 'Ανάλυση', 'Σφάλμα').

    .PARAMETER Message
    Το μήνυμα που θα καταγραφεί στα logs.

    .PARAMETER Level
    Το επίπεδο log (π.χ. 'Verbose', 'Warning', 'Error'). Προεπιλογή: 'Verbose'.

    .EXAMPLE
    Write-BridgeStage -Stage 'Ανάλυση' -Message 'Η διαδικασία ολοκληρώθηκε επιτυχώς.'

    Καταγράφει μήνυμα ανάλυσης με προεπιλεγμένο επίπεδο Verbose.

    .EXAMPLE
    Write-BridgeStage -Stage 'Σφάλμα' -Message 'Η σύνδεση απέτυχε.' -Level 'Warning'

    Καταγράφει σφάλμα με επίπεδο Warning.

    .NOTES
    Βασική helper function για logging στα modules του BridgeWatcher.
    #>    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Ανάλυση', 'Απόφαση', 'Ειδοποίηση', 'Σφάλμα')][string]$Stage,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Message,
        [ValidateSet('Verbose', 'Debug', 'Warning')][string]$Level = 'Verbose'
    )
    $writeBridgeLogSplat = @{
        Stage   = $Stage
        Message = $Message
        Level   = $Level
    }
    Write-BridgeLog @writeBridgeLogSplat
}