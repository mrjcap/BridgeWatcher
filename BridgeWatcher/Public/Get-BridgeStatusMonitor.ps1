function Get-BridgeStatusMonitor {
    <#
    .SYNOPSIS
    Ξεκινά συνεχή παρακολούθηση της κατάστασης γεφυρών.

    .DESCRIPTION
    Get-BridgeStatusMonitor performs continuous monitoring of bridge statuses,
    periodically fetching and analyzing the status and storing results.

    Η Get-BridgeStatusMonitor εκτελεί ατέρμονο monitoring της κατάστασης γεφυρών,
    κάνοντας περιοδικά λήψη και ανάλυση της κατάστασης και αποθηκεύοντας αποτελέσματα.

    .PARAMETER MaxIterations
    Ο μέγιστος αριθμός επαναλήψεων πριν τερματιστεί (0 για άπειρες).

    .PARAMETER IntervalSeconds
    Το διάστημα (σε δευτερόλεπτα) ανάμεσα σε κάθε έλεγχο (1-3600 δευτερόλεπτα, μέγιστο 1 ώρα).

    .PARAMETER OutputFile
    Η διαδρομή αποθήκευσης των τρεχουσών καταστάσεων.

    .PARAMETER ApiKey
    Το API Key που χρησιμοποιείται για OCR αναλύσεις.

    .PARAMETER PoUserKey
    Το User Key για αποστολή Pushover ειδοποιήσεων.

    .PARAMETER PoApiKey
    Το API Token της εφαρμογής Pushover.

    .PARAMETER Configuration
    (Προαιρετικό) Αντικείμενο διαμόρφωσης. Αν δεν παρέχεται, δημιουργείται αυτόματα.

    .PARAMETER Action
    (Προαιρετικό) Scriptblock που εκτελείται κατά τη διάρκεια του monitoring αντί για την προεπιλεγμένη Update-BridgeStatus.

    .OUTPUTS
    None.

    .EXAMPLE
    Get-BridgeStatusMonitor -MaxIterations 100 -IntervalSeconds 60 -OutputFile 'C:\Logs\bridge.json' -ApiKey 'api123' -PoUserKey 'user123' -PoApiKey 'token123'

    .EXAMPLE
    Get-BridgeStatusMonitor -OutputFile 'C:\Logs\bridge.json' -Action {
        param(
        Write-Host "Custom monitoring action running for $($splat.OutputFile)"
        Update-BridgeStatus @splat -Configuration $Configuration
    }

    .NOTES
    Το monitoring συνεχίζει μέχρι να ολοκληρωθούν οι επαναλήψεις ή να τερματιστεί χειροκίνητα.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ApiKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter()][ValidateRange(0, [int]::MaxValue)][int]$MaxIterations,
        [Parameter()][ValidateRange(1, 3600)][int]$IntervalSeconds,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputFile,
        [Parameter()][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter()][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter()][ValidateNotNullOrEmpty()][string]$PoApiKey,


        [Parameter()]
        [scriptblock]$Action
    )

    begin {

        # Set defaults from configuration if parameters not provided
        if (-not $PSBoundParameters.ContainsKey('MaxIterations')) {
            $MaxIterations = $Configuration.Defaults.MaxIterations
        }

        if (-not $PSBoundParameters.ContainsKey('IntervalSeconds')) {
            $IntervalSeconds = $Configuration.Defaults.IntervalSeconds
        }

        if (-not $PSBoundParameters.ContainsKey('Action')) {
            $Action = {
                param($splat)
                Update-BridgeStatus @splat
            }
        }

        $iteration = 0
        $infiniteLoop = $MaxIterations -eq 0

        $writeBridgeLogSplat = @{
            Stage   = $Configuration.LoggingConfig.InfoStage
            Message = "$($Configuration.StatusMessages.MonitoringStart): Διάστημα = $IntervalSeconds δευτ., Μέγιστες επαναλήψεις = $MaxIterations"
            Level   = $Configuration.LoggingConfig.VerboseLevel
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
    }
    process {
        $consecutiveFailures = 0
        $maxConsecutiveFailures = $Configuration.Defaults.MaxConsecutiveFailures

        while ($infiniteLoop -or $iteration -lt $MaxIterations) {
            try {
                $iteration++
                $updateBridgeStatusSplat = @{
                    OutputFile    = $OutputFile
                    ApiKey        = $ApiKey
                    PoUserKey     = $PoUserKey
                    PoApiKey      = $PoApiKey
                    Configuration = $Configuration
                }

                & $Action $updateBridgeStatusSplat
                $consecutiveFailures = 0
            } catch {
                $consecutiveFailures++
                $errorMessage = $Configuration.ErrorMessages.MonitoringError

                $writeBridgeLogSplat = @{
                    Stage   = $Configuration.LoggingConfig.ErrorStage
                    Message = "${errorMessage}: $($_) $iteration"
                    Level   = $Configuration.LoggingConfig.WarningLevel
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

                if ($consecutiveFailures -ge $maxConsecutiveFailures) {
                    $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new("Monitoring failed $consecutiveFailures consecutive times. Halting.", $_.Exception),
                        'MONITOR_LOOP_FAILED',
                        [System.Management.Automation.ErrorCategory]::OperationStopped,
                        $null
                    ))
                }
            } finally {
                if ($infiniteLoop -or $iteration -lt $MaxIterations) {
                    $startSleepSplat = @{
                        Seconds = $IntervalSeconds
                    }
                    Start-Sleep @startSleepSplat
                }
            }
        }

        $writeBridgeLogSplat = @{
            Stage   = $Configuration.LoggingConfig.InfoStage
            Message = "$($Configuration.StatusMessages.MonitoringComplete) μετά από $iteration επανάληψη(εις)."
            Level   = $Configuration.LoggingConfig.VerboseLevel
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
    }
}
