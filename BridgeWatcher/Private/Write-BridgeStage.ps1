function Write-BridgeStage {
    <#
    .SYNOPSIS
    Εμφανίζει μήνυμα στα logs με καθορισμένο επίπεδο και στάδιο.

    .DESCRIPTION
    Η Write-BridgeStage χρησιμοποιείται για να καταγράφει μηνύματα στα logs της εφαρμογής BridgeWatcher,
    βοηθώντας στον διαχωρισμό των σταδίων (π.χ. 'Ανάλυση', 'Σφάλμα') και των επιπέδων logging ('Verbose', 'Warning', 'Error').
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
    Write-BridgeStage -Stage 'Σφάλμα' -Message 'Η σύνδεση απέτυχε.' -Level 'Error'

    Καταγράφει σφάλμα με επίπεδο Error.

    .NOTES
    Βασική helper function για logging στα modules του BridgeWatcher.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateSet('Ανάλυση','Σφάλμα')][string]$Stage,
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('Verbose','Warning','Error')][string]$Level = 'Verbose'
    )
    $writeBridgeLogSplat = @{
        Stage   = $Stage
        Message = $Message
        Level   = $Level
    }
    Write-BridgeLog @writeBridgeLogSplat
}