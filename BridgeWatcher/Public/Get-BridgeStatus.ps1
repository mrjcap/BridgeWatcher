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
    [PSCustomObject] - BridgeResult object με Success, Data, ErrorMessage, ErrorCode και Timestamp.

    .EXAMPLE
    $result = Get-BridgeStatus -OutputFile 'C:\Logs\current-status.json'
    if (Test-BridgeResult $result) {
        Write-Host "Success: $($result.Data.Count) bridges found"
    }

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
                # CRIT-001: Use fallback configuration instead of returning error
                $Configuration = [PSCustomObject]@{
                    SourceUrl = 'https://www.topvision.gr/dioriga/'
                    BaseImageUrl = 'https://www.topvision.gr/dioriga'
                }
            }
        }
    }    process { 
        # Stage 1: Data Acquisition - Get HTML content
        $htmlResult = Get-BridgeHtml -Configuration $Configuration
        if (-not $htmlResult) {
            # CRIT-002: Return BridgeResult instead of ThrowTerminatingError
            return New-BridgeResult -Success $false -ErrorMessage 'HTML retrieval returned null' -ErrorCode 'HTML_NULL'
        }
        if (-not (Test-BridgeResult $htmlResult)) {
            # CRIT-002: Return BridgeResult instead of ThrowTerminatingError
            return New-BridgeResult -Success $false -ErrorMessage $htmlResult.ErrorMessage -ErrorCode $htmlResult.ErrorCode
        }

        # Stage 2: Data Processing - Convert HTML to bridge status
        $statusResult = ConvertFrom-BridgeHtml -Html $htmlResult.Data -Configuration $Configuration
        if (-not (Test-BridgeResult $statusResult)) {
            # CRIT-002: Return BridgeResult instead of ThrowTerminatingError
            return New-BridgeResult -Success $false -ErrorMessage $statusResult.ErrorMessage -ErrorCode $statusResult.ErrorCode
        }

        # Stage 3: Data Persistence (optional)
        if ($OutputFile) {
            $exportResult = Export-BridgeStatusJson -Data $statusResult.Data -Path $OutputFile
            if (-not (Test-BridgeResult $exportResult)) {
                # CRIT-002: Return BridgeResult instead of ThrowTerminatingError
                return New-BridgeResult -Success $false -ErrorMessage $exportResult.ErrorMessage -ErrorCode $exportResult.ErrorCode
            }
        }

        # CRIT-003: Return BridgeResult instead of raw data
        return $statusResult
    }
}