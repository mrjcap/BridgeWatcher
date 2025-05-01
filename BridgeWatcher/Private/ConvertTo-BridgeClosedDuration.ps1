function ConvertTo-BridgeClosedDuration {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Υπολογίζει τη διάρκεια κλεισίματος γέφυρας.

    .DESCRIPTION
    Η ConvertTo-BridgeClosedDuration υπολογίζει πόσο χρονικό διάστημα παραμένει κλειστή η γέφυρα
    με βάση την ώρα ανοίγματος και κλεισίματος.

    .PARAMETER CloseTimestamp
    Η χρονική στιγμή κλεισίματος της γέφυρας.

    .PARAMETER OpenTimestamp
    Η χρονική στιγμή ανοίγματος της γέφυρας.

    .OUTPUTS
    [Timespan] - Η διάρκεια κλεισίματος.

    .EXAMPLE
    ConvertTo-BridgeClosedDuration -CloseTimestamp (Get-Date) -OpenTimestamp (Get-Date)

    .NOTES
    Απαιτεί έγκυρες χρονικές σφραγίδες.
    #>

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