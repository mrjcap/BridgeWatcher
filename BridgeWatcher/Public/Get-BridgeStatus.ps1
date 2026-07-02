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
                    [System.Exception]::new("Η αρχικοποίηση της διαμόρφωσης απέτυχε: $($_.Exception.Message)", $_.Exception),
                    'CONFIG_ERROR',
                    [System.Management.Automation.ErrorCategory]::InvalidOperation,
                    $null
                ))
            }
        }
    }    process { # Stage 1: Data Acquisition - Get HTML content
        $Uri = $Configuration.Urls.Source
        Write-BridgeLog -Stage 'Ανάλυση' -Message "🌐 Λήψη περιεχομένου από: $Uri"
        $maxRetries = 3
        $response = $null
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                $response = Invoke-WebRequest -Uri $Uri -UseBasicParsing -ErrorAction 'Stop'
                break
            } catch {
                if ($i -eq $maxRetries) {
                    Write-BridgeLog -Stage 'Σφάλμα' -Message "❌ Σφάλμα κατά την ανάκτηση: $($_.Exception.Message)" -Level 'Warning'
                    $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new($_.Exception.Message, $_.Exception),
                        'HTTP_ERROR',
                        [System.Management.Automation.ErrorCategory]::ConnectionError,
                        $null
                    ))
                }
                Start-Sleep -Seconds ([Math]::Pow(2, $i))
            }
        }
        $htmlData = $response.Content
        # Stage 2: Data Processing - Convert HTML to bridge status
        Write-BridgeLog -Stage 'Ανάλυση' -Message '🔍 Ανάλυση HTML για εύρεση καταστάσεων γέφυρας'
        try {
            $bridgeStatuses = Get-BridgeStatusFromHtml -Html $htmlData -Timestamp (Get-Date -Format o) -Configuration $Configuration
            if (-not $bridgeStatuses -or $bridgeStatuses.Count -eq 0) {
                Write-BridgeLog -Stage 'Σφάλμα' -Message '⛔ Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο' -Level 'Warning'
                throw [System.Exception]::new('Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο')
            }
            Write-BridgeLog -Stage 'Ανάλυση' -Message "✅ Βρέθηκαν $($bridgeStatuses.Count) γέφυρες"
        } catch {
            Write-BridgeLog -Stage 'Σφάλμα' -Message "❌ Σφάλμα κατά την ανάλυση HTML: $($_.Exception.Message)" -Level 'Warning'
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new($_.Exception.Message, $_.Exception),
                'PARSING_ERROR',
                [System.Management.Automation.ErrorCategory]::ParserError,
                $null
            ))
        }
        # Stage 3: Data Persistence (optional)
        if ($OutputFile) {
            $exportResult = Export-BridgeStatusJson -Data $bridgeStatuses -Path $OutputFile
            if (-not $exportResult.Success) {
                $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                        [System.Exception]::new($exportResult.ErrorMessage, $_.Exception),
                        $exportResult.ErrorCode,
                        [System.Management.Automation.ErrorCategory]::WriteError,
                        $OutputFile
                    ))
            }
        }
        # Return the actual data for backward compatibility
        $bridgeStatuses
    }
}