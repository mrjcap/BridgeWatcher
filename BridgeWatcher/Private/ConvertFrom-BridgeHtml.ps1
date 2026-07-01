function ConvertFrom-BridgeHtml {
    <#
    .SYNOPSIS
    Αναλύει HTML περιεχόμενο και επιστρέφει καταστάσεις γέφυρας.

    .DESCRIPTION
    Η ConvertFrom-BridgeHtml εξάγει τη λογική ανάλυσης HTML από το
    Get-BridgeStatusFromHtml και επιστρέφει ένα αντικείμενο BridgeResult
    για καλύτερη διαχείριση σφαλμάτων και συμμόρφωση με την αρχή DRY.

    .PARAMETER Html
    Το HTML περιεχόμενο ως συμβολοσειρά (string).

    .PARAMETER Configuration
    Αντικείμενο διαμόρφωσης που περιέχει τις αντιστοιχίσεις γεφυρών και τις διευθύνσεις URL.

    .OUTPUTS
    [PSCustomObject] - Αντικείμενο BridgeResult με Success, Data (πίνακας καταστάσεων γεφυρών), ErrorMessage, ErrorCode, Timestamp.

    .EXAMPLE
    $statusResult = ConvertFrom-BridgeHtml -Html $html -Configuration $config
    if (Test-BridgeResult $statusResult) {
        $bridges = $statusResult.Data
    }

    .NOTES
    Χρησιμοποιεί την New-BridgeResult για τυποποιημένη επιστροφή αποτελεσμάτων.
    Εξάγει τη λειτουργικότητα από την Get-BridgeStatusFromHtml για καλύτερη δομή.
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
        # Χρήση διαμόρφωσης ή εναλλακτικής λύσης
        try {
            $Configuration = Get-SafeBridgeConfiguration -Configuration $Configuration
        } catch {
            return New-BridgeResult -Success $false -ErrorMessage "Η αρχικοποίηση της διαμόρφωσης απέτυχε: $($_.Exception.Message)" -ErrorCode 'CONFIG_ERROR'
        }

        $timestamp = Get-Date -Format o

        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = '🔍 Ανάλυση HTML για εύρεση καταστάσεων γέφυρας'
        }
        Write-BridgeLog @writeBridgeLogSplat

        # Χρήση της υπάρχουσας λογικής Get-BridgeStatusFromHtml με περιτύλιγμα BridgeResult
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

