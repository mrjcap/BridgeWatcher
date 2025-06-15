function Invoke-BridgeClosedNotification {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Στέλνει ειδοποίηση ότι η γέφυρα έκλεισε.

    .DESCRIPTION
    Η Invoke-BridgeClosedNotification δημιουργεί και αποστέλλει ειδοποίηση
    όταν εντοπιστεί κλείσιμο της γέφυρας.

    .PARAMETER CurrentState
    Η λίστα καταστάσεων των γεφυρών.

    .PARAMETER PoUserKey
    Το Pushover User Key του παραλήπτη.

    .PARAMETER PoApiKey
    Το Pushover API Token της εφαρμογής.

    .OUTPUTS
    None.

    .EXAMPLE
    Invoke-BridgeClosedNotification -CurrentState $state -PoUserKey 'user123' -PoApiKey 'token123'

    .NOTES
    Στέλνει μόνο για γεφυρες με κατάσταση 'Κλειστή'.
    #>

    [OutputType([void])]
    param (
        [Parameter(Mandatory)][object[]]$CurrentState,
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][string]$PoUserKey,
        [Parameter(Mandatory)][string]$PoApiKey
    )
    foreach ($entry in $CurrentState) {
        switch ($entry.gefyraStatus) {
            'Κλειστή για συντήρηση' {

                $logDetails = @(
                    "🛑 Κλειστή για συντήρηση: $($entry.gefyraName)",
                    "Χρονική στιγμή: $($entry.timestamp)",
                    "Εικόνα: $($entry.imageUrl)",
                    "Μέθοδος: Άμεση ειδοποίηση (χωρίς OCR)"
                ) -join "`n"
                $writeBridgeLogSplat = @{
                    Stage   = 'Ειδοποίηση'
                    Message = $logDetails
                    Level   = 'Debug'
                }
                Write-BridgeLog @writeBridgeLogSplat
                $pushoverSplat = @{
                    PoUserKey = $PoUserKey
                    PoApiKey  = $PoApiKey
                    Title     = "🚧 Η γέφυρα της $($entry.gefyraName)ς είναι κλειστή για συντήρηση"
                    Message   = "Η γέφυρα $($entry.gefyraName)ς είναι κλειστή για συντήρηση. Επιλέξτε άλλη διαδρομή."
                }
                Send-BridgePushover @pushoverSplat
            }
            'Μόνιμα κλειστή' {

                $logDetails = @(
                    "🛑 Μόνιμα κλειστή: $($entry.gefyraName)",
                    "Χρονική στιγμή: $($entry.timestamp)",
                    "Εικόνα: $($entry.imageUrl)",
                    "Μέθοδος: Άμεση ειδοποίηση (χωρίς OCR)"
                ) -join "`n"
                $writeBridgeLogSplat = @{
                    Stage   = 'Ειδοποίηση'
                    Message = $logDetails
                    Level   = 'Debug'
                }
                Write-BridgeLog @writeBridgeLogSplat
                $pushoverSplat = @{
                    PoUserKey = $PoUserKey
                    PoApiKey  = $PoApiKey
                    Title     = "🚧 Η γέφυρα της $($entry.gefyraName)ς είναι μόνιμα κλειστή"
                    Message   = "Η γέφυρα $($entry.gefyraName)ς είναι μόνιμα κλειστή. Επιλέξτε άλλη διαδρομή."
                }
                Send-BridgePushover @pushoverSplat
            }
            'Κλειστή με πρόγραμμα' {

                $logDetails = @(
                    "📸 Κλειστή με πρόγραμμα: $($entry.gefyraName)",
                    "Χρονική στιγμή: $($entry.timestamp)",
                    "📷 Εικόνα προς OCR: $($entry.imageUrl)",
                    "Μέθοδος: OCR + Ειδοποίηση"
                ) -join "`n"
                $writeBridgeLogSplat = @{
                    Stage   = 'Ειδοποίηση'
                    Message = $logDetails
                    Level   = 'Debug'
                }
                Write-BridgeLog @writeBridgeLogSplat
                $ocrSplat = @{
                    ApiKey      = $ApiKey
                    ImageUri    = $entry.imageUrl
                    Verbose     = $true
                    ErrorAction = 'Stop'
                }
                try {
                    $ocrResult = Invoke-BridgeOCRGoogleCloud @ocrSplat
                    if ($ocrResult) {
                        $pushoverSplat = @{
                            PoUserKey = $PoUserKey
                            PoApiKey  = $PoApiKey
                            Title     = "🚧 Η γέφυρα της $($entry.gefyraName)ς έκλεισε"
                            Message   = ($ocrResult | Out-String)
                        }
                        Send-BridgePushover @pushoverSplat
                    }
                } catch {
                    $writeBridgeLogSplat = @{
                        Stage   = 'Σφάλμα'
                        Message = "❌ Απέτυχε η OCR για $($entry.imageUrl): $($_.Exception.Message)"
                        Level   = 'Warning'
                    }
                    Write-BridgeLog @writeBridgeLogSplat
                }
            }
            default {
                $writeBridgeLogSplat = @{
                    Stage   = 'Ειδοποίηση'
                    Message = "ℹ️ Αγνοείται ειδοποίηση για $($entry.gefyraName)ς με κατάσταση: $($entry.gefyraStatus)"
                    Level   = 'Debug'
                }
                Write-BridgeLog @writeBridgeLogSplat
            }
        }
    }
}
