function Get-BridgeStatusMonitor {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ApiKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey',
        Justification = 'API key is read from Docker secrets at runtime, not user input. SecureString conversion offers no benefit in this non-interactive pipeline.')]
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
        [Parameter()][SecureString]$ApiKey,
        [Parameter()][SecureString]$PoUserKey,
        [Parameter()][SecureString]$PoApiKey,

        [Parameter()]
        [PSCustomObject]$Configuration,

        [Parameter()]
        [System.Threading.CancellationToken]$CancellationToken = [System.Threading.CancellationToken]::None
    )

    begin {
        # Ensure configuration is available
        $Configuration = Get-SafeBridgeConfiguration -Configuration $Configuration -Quiet

        # Set defaults from configuration if parameters not provided
        if (-not $PSBoundParameters.ContainsKey('MaxIterations')) {
            $MaxIterations = if ($Configuration -and $Configuration.DefaultMaxIterations) {
                $Configuration.DefaultMaxIterations
            } else {
                100
            }
        }

        if (-not $PSBoundParameters.ContainsKey('IntervalSeconds')) {
            $IntervalSeconds = if ($Configuration -and $Configuration.DefaultIntervalSeconds) {
                $Configuration.DefaultIntervalSeconds
            } else {
                300
            }
        }

        $iteration = 0
        $infiniteLoop = $MaxIterations -eq 0

        $monitoringStartMessage = if ($Configuration -and $Configuration.StatusMessages) {
            $Configuration.StatusMessages.MonitoringStart
        } else {
            "Ξεκίνησε ο κύκλος παρακολούθησης"
        }

        $writeBridgeLogSplat = @{
            Stage   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.InfoStage) {
                $Configuration.LoggingConfig.InfoStage
            } else {
                'Ανάλυση'
            }
            Message = "$monitoringStartMessage`: Διάστημα = $IntervalSeconds δευτ., Μέγιστες επαναλήψεις = $MaxIterations"
            Level   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.VerboseLevel) {
                $Configuration.LoggingConfig.VerboseLevel
            } else {
                'Verbose'
            }
        }
        Write-BridgeLog @writeBridgeLogSplat
    }
    process {
        $consecutiveFailures = 0
        while ((-not $CancellationToken.IsCancellationRequested) -and ($infiniteLoop -or $iteration -lt $MaxIterations)) {
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
                $consecutiveFailures = 0 # reset on success
                if (-not $infiniteLoop -and $iteration -ge $MaxIterations) { break }
                if ($CancellationToken.CanBeCanceled) {
                    if ($CancellationToken.WaitHandle.WaitOne([timespan]::FromSeconds($IntervalSeconds))) {
                        break
                    }
                } else {
                    Start-Sleep -Seconds $IntervalSeconds
                }
            } catch {
                $errorMessage = if ($Configuration -and $Configuration.ErrorMessages) {
                    $Configuration.ErrorMessages.MonitoringError
                } else {
                    "❌ Σφάλμα κατά την ανάκτηση της κατάστασης της γέφυρας"
                }

                $writeBridgeLogSplat = @{
                    Stage   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.ErrorStage) {
                        $Configuration.LoggingConfig.ErrorStage
                    } else {
                        'Σφάλμα'
                    }
                    Message = "$errorMessage`: $($_) $iteration"
                    Level   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.DebugLevel) {
                        $Configuration.LoggingConfig.DebugLevel
                    } else {
                        'Debug'
                    }
                }
                Write-BridgeLog @writeBridgeLogSplat
                $consecutiveFailures++
                if ($consecutiveFailures -ge 5) {
                    Write-BridgeLog -Stage 'Σφάλμα' -Message "Circuit breaker triggered. Sleeping for 15 minutes." -Level 'Warning'
                    if ($CancellationToken.CanBeCanceled) {
                        if ($CancellationToken.WaitHandle.WaitOne([timespan]::FromSeconds(900))) {
                            break
                        }
                    } else {
                        Start-Sleep -Seconds 900
                    }
                    $consecutiveFailures = 0
                } else {
                    if ($CancellationToken.CanBeCanceled) {
                        if ($CancellationToken.WaitHandle.WaitOne([timespan]::FromSeconds($IntervalSeconds))) {
                            break
                        }
                    } else {
                        Start-Sleep -Seconds $IntervalSeconds
                    }
                }
            } 
            [System.GC]::Collect()
        }

        $monitoringCompleteMessage = if ($Configuration -and $Configuration.StatusMessages) {
            $Configuration.StatusMessages.MonitoringComplete
        } else {
            "✅ Ο κύκλος παρακολούθησης ολοκληρώθηκε"
        }

        $writeBridgeLogSplat = @{
            Stage   = if ($Configuration -and $Configuration.LoggingConfig) {
                $Configuration.LoggingConfig.InfoStage
            } else {
                'Ανάλυση'
            }
            Message = "$monitoringCompleteMessage μετά από $iteration επανάληψη(εις)."
            Level   = if ($Configuration -and $Configuration.LoggingConfig) {
                $Configuration.LoggingConfig.VerboseLevel
            } else {
                'Verbose'
            }
        }
        Write-BridgeLog @writeBridgeLogSplat
    }
}
