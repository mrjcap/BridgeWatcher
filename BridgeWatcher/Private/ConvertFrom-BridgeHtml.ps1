function ConvertFrom-BridgeHtml {
    <#
    .SYNOPSIS
    Αναλύει HTML περιεχόμενο και επιστρέφει καταστάσεις γέφυρας.

    .DESCRIPTION
    Η ConvertFrom-BridgeHtml εξάγει τη λογική ανάλυσης HTML από το
    Get-BridgeStatusFromHtml και επιστρέφει BridgeResult object
    για καλύτερο error handling και DRY compliance.

    .PARAMETER Html
    Το HTML περιεχόμενο σε μορφή string.

    .PARAMETER Configuration
    Αντικείμενο διαμόρφωσης που περιέχει bridge mappings και URLs.

    .OUTPUTS
    [PSCustomObject] - BridgeResult object με Success, Data (array of bridge statuses), ErrorMessage, ErrorCode, Timestamp.

    .EXAMPLE
    $statusResult = ConvertFrom-BridgeHtml -Html $html -Configuration $config
    if (Test-BridgeResult $statusResult) {
        $bridges = $statusResult.Data
    }

    .NOTES
    Χρησιμοποιεί New-BridgeResult για τυποποιημένη επιστροφή αποτελεσμάτων.
    Εξάγει τη λειτουργικότητα από Get-BridgeStatusFromHtml για καλύτερη δομή.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Html,

        [Parameter()]
        [PSCustomObject]$Configuration
    )

    try {
        # Use configuration or fallback
        try {
            $Configuration = Get-SafeBridgeConfiguration -Configuration $Configuration
        } catch {
            return New-BridgeResult -Success $false -ErrorMessage "Configuration initialization failed: $($_.Exception.Message)" -ErrorCode 'CONFIG_ERROR'
        }        $timestamp = Get-Date -Format o

        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = '🔍 Ανάλυση HTML για εύρεση καταστάσεων γέφυρας'
        }
        Write-BridgeLog @writeBridgeLogSplat

        # Use the existing Get-BridgeStatusFromHtml logic with BridgeResult wrapping
        $getBridgeStatusFromHtmlSplat = @{
            Html          = $Html
            Timestamp     = $timestamp
            Configuration = $Configuration
        }

        $bridgeStatuses = Get-BridgeStatusFromHtml @getBridgeStatusFromHtmlSplat

        if (-not $bridgeStatuses -or $bridgeStatuses.Count -eq 0) {
            $writeBridgeLogSplat = @{
                Stage   = 'Σφάλμα'
                Message = '⛔ Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο'
                Level   = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat

            return New-BridgeResult -Success $false -ErrorMessage 'Δεν βρέθηκαν γέφυρες στο HTML περιεχόμενο' -ErrorCode 'NO_BRIDGES_FOUND'
        }

        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = "✅ Βρέθηκαν $($bridgeStatuses.Count) γέφυρες"
        }
        Write-BridgeLog @writeBridgeLogSplat

        return New-BridgeResult -Success $true -Data $bridgeStatuses
    }
    catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Σφάλμα κατά την ανάλυση HTML: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat

        return New-BridgeResult -Success $false -ErrorMessage $_.Exception.Message -ErrorCode 'PARSING_ERROR'
    }
}

