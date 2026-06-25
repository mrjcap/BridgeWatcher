function Get-BridgeStatusMonitor {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Ξεκινά συνεχή παρακολούθηση της κατάστασης γεφυρών.

    .DESCRIPTION
    Η Get-BridgeStatusMonitor εκτελεί ατέρμονο monitoring της κατάστασης γεφυρών,
    κάνοντας περιοδικά λήψη και ανάλυση της κατάστασης και αποθηκεύοντας αποτελέσματα.

    .PARAMETER MaxIterations
    Ο μέγιστος αριθμός επαναλήψεων πριν τερματιστεί (0 για άπειρες).    .PARAMETER IntervalSeconds
    Το διάστημα (σε δευτερόλεπτα) ανάμεσα σε κάθε έλεγχο (1-3600 δευτερόλεπτα, μέγιστο 1 ώρα).

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
    #>    [OutputType([void])]
    param (
        [Parameter()][ValidateRange(0, [int]::MaxValue)][int]$MaxIterations,
        [Parameter()][ValidateRange(1, 3600)][int]$IntervalSeconds,
        [Parameter()][ValidateNotNullOrEmpty()][string]$OutputFile,
        [Parameter()][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter()][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter()][ValidateNotNullOrEmpty()][string]$PoApiKey,

        [Parameter()]
        [PSCustomObject]$Configuration
    )

    begin {
        # Ensure configuration is available
        if (-not $Configuration) {
            $Configuration = New-BridgeConfiguration
        }

        # Set defaults from configuration if parameters not provided
        if (-not $PSBoundParameters.ContainsKey('MaxIterations')) {
            $MaxIterations = $Configuration.DefaultMaxIterations
        }

        if (-not $PSBoundParameters.ContainsKey('IntervalSeconds')) {
            $IntervalSeconds = $Configuration.DefaultIntervalSeconds
        }

        $iteration = 0
        $infiniteLoop = $MaxIterations -eq 0

        $monitoringStartMessage = $Configuration.StatusMessages.MonitoringStart

        $writeBridgeLogSplat = @{
            Stage   = $Configuration.LoggingConfig.InfoStage
            Message = "$monitoringStartMessage`: Διάστημα = $IntervalSeconds δευτ., Μέγιστες επαναλήψεις = $MaxIterations"
            Level   = $Configuration.LoggingConfig.VerboseLevel
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

                # Note: Get-BridgeStatusComparison doesn't support Configuration parameter yet
                # Will be added in future refactoring iteration
                Get-BridgeStatusComparison @getBridgeStatusComparisonSplat
                if (-not $infiniteLoop -and $iteration -ge $MaxIterations) { break }
                $startSleepSplat = @{
                    Seconds = $IntervalSeconds
                }
                Start-Sleep @startSleepSplat } catch {
                $errorMessage = $Configuration.ErrorMessages.MonitoringError

                $writeBridgeLogSplat = @{
                    Stage   = $Configuration.LoggingConfig.ErrorStage
                    Message = "$errorMessage`: $($_) $iteration"
                    Level   = $Configuration.LoggingConfig.DebugLevel
                }
                Write-BridgeLog @writeBridgeLogSplat
            } }

        $monitoringCompleteMessage = $Configuration.StatusMessages.MonitoringComplete

        $writeBridgeLogSplat = @{
            Stage   = $Configuration.LoggingConfig.InfoStage
            Message = "$monitoringCompleteMessage μετά από $iteration επανάληψη(εις)."
            Level   = $Configuration.LoggingConfig.VerboseLevel
        }
        Write-BridgeLog @writeBridgeLogSplat
    }
}
