function Get-BridgeStatusMonitor {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Ξεκινά συνεχή παρακολούθηση της κατάστασης γεφυρών.

    .DESCRIPTION
    Η Get-BridgeStatusMonitor εκτελεί ατέρμονο monitoring της κατάστασης γεφυρών,
    κάνοντας περιοδικά λήψη και ανάλυση της κατάστασης και αποθηκεύοντας αποτελέσματα.

    .PARAMETER MaxIterations
    Ο μέγιστος αριθμός επαναλήψεων πριν τερματιστεί (0 για άπειρες).

    .PARAMETER IntervalSeconds
    Το διάστημα (σε δευτερόλεπτα) ανάμεσα σε κάθε έλεγχο.

    .PARAMETER OutputFile
    Η διαδρομή αποθήκευσης των τρεχουσών καταστάσεων.

    .PARAMETER ApiKey
    Το API Key που χρησιμοποιείται για OCR αναλύσεις.

    .PARAMETER PoUserKey
    Το User Key για αποστολή Pushover ειδοποιήσεων.

    .PARAMETER PoApiKey
    Το API Token της εφαρμογής Pushover.

    .OUTPUTS
    None.

    .EXAMPLE
    Get-BridgeStatusMonitor -MaxIterations 100 -IntervalSeconds 60 -OutputFile 'C:\Logs\bridge.json' -ApiKey 'api123' -PoUserKey 'user123' -PoApiKey 'token123'

    .NOTES
    Το monitoring συνεχίζει μέχρι να ολοκληρωθούν οι επαναλήψεις ή να τερματιστεί χειροκίνητα.
    #>

    [OutputType([void])]
    param (
        [Parameter(Mandatory)][ValidateRange(0, [int]::MaxValue)][int]$MaxIterations,
        [Parameter(Mandatory)][ValidateRange(1, 3600)][int]$IntervalSeconds,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputFile,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoApiKey
    )
    begin {
        $iteration              = 0
        $infiniteLoop           = $MaxIterations -eq 0
        $writeBridgeLogSplat    = @{
            Stage      = 'Ανάλυση'
            Message    = "Ξεκίνησε ο κύκλος παρακολούθησης: Διάστημα = $IntervalSeconds δευτ., Μέγιστες επαναλήψεις = $MaxIterations"
            Level      = 'Verbose'
        }
        Write-BridgeLog @writeBridgeLogSplat
    }
    process {
        while ($infiniteLoop -or $iteration -lt $MaxIterations) {
            try {
                $iteration++
                $getBridgeStatusComparisonSplat = @{
                    OutputFile = $OutputFile
                    ApiKey     = $ApiKey
                    PoUserKey  = $PoUserKey
                    PoApiKey   = $PoApiKey
                }
                Get-BridgeStatusComparison @getBridgeStatusComparisonSplat
                if (-not $infiniteLoop -and $iteration -ge $MaxIterations) { break }
                $startSleepSplat = @{
                    Seconds = $IntervalSeconds
                }
                Start-Sleep @startSleepSplat
            } catch {
                $writeBridgeLogSplat = @{
                Stage   = 'Σφάλμα'
                Message = "❌ Σφάλμα κατά την ανάκτηση της κατάστασης της γέφυρας: $($_) $iteration"
                Level   = 'Debug'
                }
                Write-BridgeLog @writeBridgeLogSplat
            }
        }
        $writeBridgeLogSplat = @{
            Stage      = 'Ανάλυση'
            Message    = "✅ Ο κύκλος παρακολούθησης ολοκληρώθηκε μετά από $iteration επανάληψη(εις)."
            Level      = 'Verbose'
        }
        Write-BridgeLog @writeBridgeLogSplat
    }
}