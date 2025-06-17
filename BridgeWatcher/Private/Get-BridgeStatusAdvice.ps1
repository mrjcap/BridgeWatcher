function Get-BridgeStatusAdvice {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Προτείνει αν αξίζει να περιμένετε το άνοιγμα της γέφυρας.

    .DESCRIPTION
    Η Get-BridgeStatusAdvice λαμβάνει τον χρόνο σε λεπτά μέχρι να ανοίξει
    η γέφυρα και επιστρέφει μήνυμα για το αν πρέπει να περιμένετε.

    .PARAMETER MinutesUntilOpen
    Τα λεπτά που απομένουν μέχρι να ανοίξει η γέφυρα.

    .PARAMETER MaxWaitTimeMinutes
    Ο μέγιστος χρόνος αναμονής σε λεπτά (προεπιλογή: 12 λεπτά).

    .PARAMETER Configuration
    Το configuration object που περιέχει τις ρυθμίσεις.

    .OUTPUTS
    [string] - String με προτεινόμενο status και μήνυμα.

    .EXAMPLE
    Get-BridgeStatusAdvice -MinutesUntilOpen 15

    .EXAMPLE
    Get-BridgeStatusAdvice -MinutesUntilOpen 8 -MaxWaitTimeMinutes 10

    .NOTES
    Αν τα λεπτά είναι περισσότερα από το MaxWaitTimeMinutes επιστρέφεται σύσταση να μην περιμένετε.
    #>
    [OutputType([string])]
    param (
        [Parameter(Mandatory)][int]$MinutesUntilOpen,
        [Parameter()][ValidateRange(1, 120)][int]$MaxWaitTimeMinutes,
        [Parameter()][PSCustomObject]$Configuration
    )

    # Get max wait time from parameter, configuration, or use fallback
    if (-not $MaxWaitTimeMinutes) {
        $MaxWaitTimeMinutes = if ($Configuration -and $Configuration.DefaultMaxWaitTimeMinutes) {
            $Configuration.DefaultMaxWaitTimeMinutes
        } else {
            12
        }
    }

    # Get advice messages from configuration or use fallback
    $doNotWaitMessage = if ($Configuration -and $Configuration.AdviceMessages -and $Configuration.AdviceMessages.DoNotWait) {
        $Configuration.AdviceMessages.DoNotWait
    } else {
        'Είναι προτιμότερο να μην περιμένεις'
    }

    $waitMessage = if ($Configuration -and $Configuration.AdviceMessages -and $Configuration.AdviceMessages.Wait) {
        $Configuration.AdviceMessages.Wait
    } else {
        'Είναι προτιμότερο να περιμένεις'
    }

    if ($MinutesUntilOpen -gt $MaxWaitTimeMinutes) {
        return $doNotWaitMessage
    }
    return $waitMessage
}