<#
    .SYNOPSIS
    Επιλύει τις ενεργές επιλογές εκτέλεσης του βρόχου παρακολούθησης.

    .DESCRIPTION
    Συνδυάζει τις παραμέτρους κλήσης με τις προεπιλεγμένες τιμές του Configuration.

    .PARAMETER BoundParameters
    Το λεξικό PSBoundParameters της κλήσης Get-BridgeStatusMonitor.

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης.
    #>
function Resolve-BridgeMonitorOption {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][System.Collections.IDictionary]$BoundParameters,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    $maxIter = if ($BoundParameters.ContainsKey('MaxIterations')) {
        [int]$BoundParameters['MaxIterations']
    } else {
        [int]$Configuration.Defaults.MaxIterations
    }
    $interval = if ($BoundParameters.ContainsKey('IntervalSeconds')) {
        [int]$BoundParameters['IntervalSeconds']
    } else {
        [int]$Configuration.Defaults.IntervalSeconds
    }
    $actionBlock = if ($BoundParameters.ContainsKey('Action')) {
        [scriptblock]$BoundParameters['Action']
    } else {
        {
            param($splat)
            Update-BridgeStatus @splat
        }
    }
    return @{
        MaxIterations   = $maxIter
        IntervalSeconds = $interval
        Action          = $actionBlock
    }
}

<#
    .SYNOPSIS
    Συνθέτει το hashtable παραμέτρων που μεταβιβάζεται στην ενέργεια παρακολούθησης.

    .DESCRIPTION
    Δημιουργεί τον πίνακα παραμέτρων με OutputFile και Configuration και προσθέτει
    τα κλειδιά API μόνο όταν έχουν παρασχεθεί στην κλήση.

    .PARAMETER OutputFile
    Η διαδρομή αποθήκευσης των τρεχουσών καταστάσεων.

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης.

    .PARAMETER BoundParameters
    Το λεξικό PSBoundParameters της κλήσης Get-BridgeStatusMonitor.
    #>
function Get-BridgeMonitorActionSplat {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputFile,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter(Mandatory)][ValidateNotNull()][System.Collections.IDictionary]$BoundParameters
    )
    $splat = @{
        OutputFile    = $OutputFile
        Configuration = $Configuration
    }
    foreach ($keyName in @('ApiKey', 'PoUserKey', 'PoApiKey')) {
        if ($BoundParameters.ContainsKey($keyName)) {
            $splat[$keyName] = $BoundParameters[$keyName]
        }
    }
    return $splat
}

<#
    .SYNOPSIS
    Ελέγχει αν απομένουν επαναλήψεις στον βρόχο παρακολούθησης.

    .DESCRIPTION
    Επιστρέφει $true όταν ο βρόχος είναι ατέρμονος ή όταν ο μετρητής υπολείπεται του ορίου.

    .PARAMETER InfiniteLoop
    Υποδεικνύει αν η παρακολούθηση εκτελείται επ' αόριστον.

    .PARAMETER Iteration
    Ο τρέχων αριθμός ολοκληρωμένων επαναλήψεων.

    .PARAMETER MaxIterations
    Ο μέγιστος αριθμός επαναλήψεων.
    #>
function Test-BridgeMonitorIterationPending {
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)][bool]$InfiniteLoop,
        [Parameter(Mandatory)][int]$Iteration,
        [Parameter(Mandatory)][int]$MaxIterations
    )
    return ($InfiniteLoop -or $Iteration -lt $MaxIterations)
}

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
    Αντικείμενο διαμόρφωσης από τη New-BridgeConfiguration.

    .PARAMETER Action
    (Προαιρετικό) Scriptblock που εκτελείται κατά τη διάρκεια του monitoring αντί για την προεπιλεγμένη Update-BridgeStatus.

    .OUTPUTS
    None.

    .EXAMPLE
    $config = New-BridgeConfiguration
    $monitorParams = @{
        Configuration   = $config
        MaxIterations   = 100
        IntervalSeconds = 60
        OutputFile      = 'C:\Logs\bridge.json'
        ApiKey          = 'api123'
        PoUserKey       = 'user123'
        PoApiKey        = 'token123'
    }
    Get-BridgeStatusMonitor @monitorParams

    .EXAMPLE
    $config = New-BridgeConfiguration
    Get-BridgeStatusMonitor -Configuration $config -OutputFile 'C:\Logs\bridge.json' -Action {
        param($splat)
        Write-Verbose "Custom monitoring action running for $($splat.OutputFile)"
    }

    .NOTES
    Το monitoring συνεχίζει μέχρι να ολοκληρωθούν οι επαναλήψεις ή να τερματιστεί χειροκίνητα.
    #>
function Get-BridgeStatusMonitor {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ApiKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey',
        Justification = 'Το κλειδί API διαβάζεται από τα Docker secrets κατά το runtime, όχι από είσοδο χρήστη. Η μετατροπή σε SecureString δεν προσφέρει κανένα όφελος σε αυτό το μη διαδραστικό pipeline.')]
    [CmdletBinding(DefaultParameterSetName = 'DefaultAction')]
    [OutputType([object[]])]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter()][ValidateRange(0, [int]::MaxValue)][int]$MaxIterations,
        [Parameter()][ValidateRange(1, 3600)][int]$IntervalSeconds,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$OutputFile,
        [Parameter(Mandatory, ParameterSetName = 'DefaultAction')][Parameter(ParameterSetName = 'CustomAction')][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory, ParameterSetName = 'DefaultAction')][Parameter(ParameterSetName = 'CustomAction')][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory, ParameterSetName = 'DefaultAction')][Parameter(ParameterSetName = 'CustomAction')][ValidateNotNullOrEmpty()][string]$PoApiKey,
        [Parameter(Mandatory, ParameterSetName = 'CustomAction')][ValidateNotNull()][scriptblock]$Action
    )

    begin {
        $resolvedOptions = Resolve-BridgeMonitorOption -BoundParameters $PSBoundParameters -Configuration $Configuration
        $MaxIterations = $resolvedOptions.MaxIterations
        $IntervalSeconds = $resolvedOptions.IntervalSeconds
        $Action = $resolvedOptions.Action

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

        while (Test-BridgeMonitorIterationPending -InfiniteLoop $infiniteLoop -Iteration $iteration -MaxIterations $MaxIterations) {
            try {
                $iteration++
                $updateBridgeStatusSplat = Get-BridgeMonitorActionSplat -OutputFile $OutputFile -Configuration $Configuration -BoundParameters $PSBoundParameters

                & $Action $updateBridgeStatusSplat
                $consecutiveFailures = 0
            } catch {
                if ($_.Exception -is [System.Management.Automation.ParameterBindingException]) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
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
            }

            if (Test-BridgeMonitorIterationPending -InfiniteLoop $infiniteLoop -Iteration $iteration -MaxIterations $MaxIterations) {
                $startSleepSplat = @{
                    Seconds = $IntervalSeconds
                }
                Start-Sleep @startSleepSplat
            }
        }

        if ($iteration -gt 0 -and $consecutiveFailures -eq $iteration) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("All monitoring iterations failed ($consecutiveFailures failed of $iteration ran)."),
                'MONITOR_LOOP_ALL_FAILED',
                [System.Management.Automation.ErrorCategory]::OperationStopped,
                $null
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }

        $writeBridgeLogSplat = @{
            Stage   = $Configuration.LoggingConfig.InfoStage
            Message = "$($Configuration.StatusMessages.MonitoringComplete) μετά από $iteration επανάληψη(εις)."
            Level   = $Configuration.LoggingConfig.VerboseLevel
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
    }
}
