function ConvertTo-BridgeClosedDuration {
    <#
    .SYNOPSIS
    Μετατρέπει TimeSpan σε ελληνική περιγραφή διάρκειας.

    .DESCRIPTION
    Η ConvertTo-BridgeClosedDuration μετατρέπει ένα αντικείμενο TimeSpan
    σε φιλική ελληνική περιγραφή (π.χ. "2 ώρες, 30 λεπτά").

    .PARAMETER Duration
    Η διάρκεια ως αντικείμενο TimeSpan προς μετατροπή σε ελληνική περιγραφή.

    .OUTPUTS
    [string] - Η διάρκεια σε ελληνική περιγραφή.

    .EXAMPLE
    # Επιστρέφει: "2 ώρες, 30 λεπτά"

    .EXAMPLE
    # Επιστρέφει: "1 ημέρα, 3 ώρες"

    .NOTES
    Χειρίζεται ημέρες, ώρες και λεπτά με σωστή πληθυντική μορφή στα ελληνικά.
    Δεν εμφανίζει μηδενικές τιμές (π.χ. αν είναι 0 ώρες, παραλείπεται).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][timespan]$Duration
    )
    $components = @()
    if ($Duration -lt [timespan]::Zero) {
        $exception = [System.Exception]::new('Η διάρκεια δεν μπορεί να είναι αρνητική.')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            $exception,
            'NegativeDurationNotAllowed',
            [System.Management.Automation.ErrorCategory]::InvalidArgument,
            $Duration
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    # Αν η διάρκεια περιλαμβάνει ημέρες
    if ($Duration.Days -gt 0) {
        $components += "$($Duration.Days) $(if ($Duration.Days -eq 1) { 'ημέρα' } else { 'ημέρες' })"
    }
    # Αν η διάρκεια περιλαμβάνει ώρες
    if ($Duration.Hours -gt 0) {
        $components += "$($Duration.Hours) $(if ($Duration.Hours -eq 1) { 'ώρα' } else { 'ώρες' })"
    }
    # Αν η διάρκεια περιλαμβάνει λεπτά
    if ($Duration.Minutes -gt 0) {
        $components += "$($Duration.Minutes) $(if ($Duration.Minutes -eq 1) { 'λεπτό' } else { 'λεπτά' })"
    }
    # Επιστρέφουμε την ένωση των συνιστωσών
    return ($components -join ', ')
}

