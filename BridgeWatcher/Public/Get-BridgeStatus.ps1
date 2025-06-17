function Get-BridgeStatus {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Α                Stage   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.ErrorStage) {
                    $Configuration.LoggingConfig.ErrorStage
                } else {
                    'Σφάλμα'
                }             Level   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.WarningLevel) {
                    $Configuration.LoggingConfig.WarningLevel
                } else {
                    'Warning'
                }ην τρέχουσα κατάσταση γεφυρών από διαδικτυακή σελίδα.

    .DESCRIPTION
    Η Get-BridgeStatus ανακτά HTML, αναλύει την κατάσταση
    και επιστρέφει λίστα καταστάσεων γεφυρών.

    .PARAMETER OutputFile
    (Προαιρετικό) Το αρχείο όπου θα αποθηκευτεί η τρέχουσα κατάσταση.

    .OUTPUTS
    [PSCustomObject] - Λίστα καταστάσεων γεφυρών.

    .EXAMPLE
    Get-BridgeStatus -OutputFile 'C:\Logs\current-status.json'

    .NOTES
    Αν αποτύχει η ανάκτηση HTML, επιστρέφεται κενό array.
    #>    [OutputType([pscustomobject[]])]    param (
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFile,
        [Parameter()]
        [PSCustomObject]$Configuration
    )

    begin {
        # Ensure configuration is available
        if (-not $Configuration) {
            try {
                $Configuration = New-BridgeConfiguration
            } catch {
                # Fallback to null configuration - functions will handle this
                $Configuration = $null
            }
        }

        $timestamp = Get-Date -Format o
        $noStatusMessage = if ($Configuration -and $Configuration.ErrorMessages) {
            $Configuration.ErrorMessages.NoStatus
        } else {
            '⛔ Δεν υπάρχει διαθέσιμο status για αποθήκευση.'
        }
        $htmlRetrievalError = if ($Configuration -and $Configuration.ErrorMessages) {
            $Configuration.ErrorMessages.HtmlRetrievalFailure
        } else {
            'Αποτυχία λήψης HTML'
        }
        $result = @()
        $html = Get-BridgeHtml -Configuration $Configuration
    }
    process {
        if (-not $html) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new($htmlRetrievalError),
                'BridgeHtmlRetrievalFailure',
                [System.Management.Automation.ErrorCategory]::ConnectionError,
                $null
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }        $getBridgeStatusFromHtmlSplat = @{
            Html      = $html
            Timestamp = $timestamp
        }

        # Add configuration only if it's available and not null
        if ($Configuration) {
            $getBridgeStatusFromHtmlSplat.Configuration = $Configuration
        }
        $result = Get-BridgeStatusFromHtml @getBridgeStatusFromHtmlSplat
    }    end {
        if ($result.Count -eq 0) {
            $writeBridgeLogSplat = @{
                Stage   = if ($Configuration -and $Configuration.LoggingConfig) {
                    $Configuration.LoggingConfig.ErrorStage
                } else {
                    'Σφάλμα'
                }
                Message = $noStatusMessage
                Level   = if ($Configuration -and $Configuration.LoggingConfig) {
                    $Configuration.LoggingConfig.WarningLevel
                } else {
                    'Warning'
                }
            }
            Write-BridgeLog @writeBridgeLogSplat
        }
        if ($PSBoundParameters.ContainsKey('OutputFile')) {
            if ($result -and $result.Count -gt 0) {
                $splat = @{
                    Data = $result
                    Path = $OutputFile
                }
                Export-BridgeStatusJson @splat } else {
                $writeBridgeLogSplat = @{
                    Stage   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.ErrorStage) {
                        $Configuration.LoggingConfig.ErrorStage
                    } else {
                        'Σφάλμα'
                    }
                    Message = $noStatusMessage
                    Level   = if ($Configuration -and $Configuration.LoggingConfig -and $Configuration.LoggingConfig.WarningLevel) {
                        $Configuration.LoggingConfig.WarningLevel
                    } else {
                        'Warning'
                    }
                }
                Write-BridgeLog @writeBridgeLogSplat
            }
        }
        return $result
    }
}