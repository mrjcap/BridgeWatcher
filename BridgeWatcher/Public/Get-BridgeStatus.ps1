function Get-BridgeStatus {
    <#
    .SYNOPSIS
    Ανακτά την τρέχουσα κατάσταση γεφυρών από διαδικτυακή σελίδα.

    .DESCRIPTION
    Η Get-BridgeStatus ανακτά HTML, αναλύει την κατάσταση
    και επιστρέφει λίστα καταστάσεων γεφυρών χρησιμοποιώντας
    τα utility functions New-BridgeResult και Test-BridgeResult
    για καλύτερο error handling και DRY compliance.

    .PARAMETER OutputFile
    (Προαιρετικό) Το αρχείο όπου θα αποθηκευτεί η τρέχουσα κατάσταση.

    .PARAMETER Configuration
    (Προαιρετικό) Αντικείμενο διαμόρφωσης. Αν δεν παρέχεται, δημιουργείται αυτόματα.

    .OUTPUTS
    [PSCustomObject] - Αντικείμενο αποτελέσματος με Success, Data, ErrorMessage, ErrorCode και Timestamp.

    .EXAMPLE
    Get-BridgeStatus -OutputFile 'C:\Logs\current-status.json'

    .EXAMPLE
    $result = Get-BridgeStatus
    if (Test-BridgeResult $result) {
        Write-Host "Success: $($result.Data.Count) bridges found"
    } else {
        Write-Warning "Error: $($result.ErrorMessage)"
    }

    .NOTES
    Χρησιμοποιεί pipeline approach με New-BridgeResult/Test-BridgeResult για καλύτερο error handling.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]$OutputFile,

        [Parameter()]
        [PSCustomObject]$Configuration
    )

    begin {
        # Stage 0: Configuration Setup
        if (-not $Configuration) {
            try {
                $Configuration = New-BridgeConfiguration
            } catch {
                $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new("Configuration initialization failed: $($_.Exception.Message)"),
                    'CONFIG_ERROR',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $null
                ))
            }
        }
    }    process { # Stage 1: Data Acquisition - Get HTML content
        $htmlResult = Get-BridgeHtml -Configuration $Configuration
        if (-not $htmlResult) {
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    [System.InvalidOperationException]::new('HTML retrieval returned null'),
                    'HTML_NULL',
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $null
                ))
        }
        if (-not (Test-BridgeResult $htmlResult)) {
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new($htmlResult.ErrorMessage),
                    $htmlResult.ErrorCode,
                    [System.Management.Automation.ErrorCategory]::ConnectionError,
                    $null
                ))
        }

        # Stage 2: Data Processing - Convert HTML to bridge status
        $statusResult = ConvertFrom-BridgeHtml -Html $htmlResult.Data -Configuration $Configuration
        if (-not (Test-BridgeResult $statusResult)) {
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                    [System.Exception]::new($statusResult.ErrorMessage),
                    $statusResult.ErrorCode,
                    [System.Management.Automation.ErrorCategory]::ParserError,
                    $null                ))
        }

        # Stage 3: Data Persistence (optional)
        if ($OutputFile) {
            $exportResult = Export-BridgeStatusJson -Data $statusResult.Data -Path $OutputFile
            if (-not (Test-BridgeResult $exportResult)) {
                $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new($exportResult.ErrorMessage),
                        $exportResult.ErrorCode,
                        [System.Management.Automation.ErrorCategory]::WriteError,
                        $OutputFile
                    ))
            }
        }

        # Return the actual data for backward compatibility
        return $statusResult.Data
    }
}
