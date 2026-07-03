function Invoke-BridgeClosedNotification {
    <#
    .SYNOPSIS
    Στέλνει ειδοποίηση ότι η γέφυρα έκλεισε.

    .DESCRIPTION
    Η Invoke-BridgeClosedNotification δημιουργεί και αποστέλλει ειδοποίηση
    όταν εντοπιστεί κλείσιμο της γέφυρας.

    .PARAMETER CurrentState
    Η λίστα καταστάσεων των γεφυρών.

    .PARAMETER ApiKey
    Το κλειδί API για την υπηρεσία Google OCR.

    .PARAMETER PoUserKey
    Το Pushover User Key του παραλήπτη.

    .PARAMETER PoApiKey
    Το Pushover API Token της εφαρμογής.

    .PARAMETER Configuration
    Το αντικείμενο διαμόρφωσης που περιέχει τις ρυθμίσεις.

    .PARAMETER NotificationProvider
    Προαιρετικό script block που λειτουργεί ως εναλλακτικός πάροχος ειδοποιήσεων.

    .OUTPUTS
    Κανένα (void).

    .EXAMPLE
    Invoke-BridgeClosedNotification -CurrentState $state -PoUserKey 'user123' -PoApiKey 'token123'

    .NOTES
    Στέλνει μόνο για γέφυρες με κατάσταση 'Κλειστή'.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param (
        [Parameter(Mandatory)][object[]]$CurrentState,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ApiKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoUserKey,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$PoApiKey,
        [Parameter()][PSCustomObject]$Configuration,
        [Parameter()][scriptblock]$NotificationProvider
    )
    if (-not $Configuration) {
        $Configuration = New-BridgeConfiguration
    }
    $null = $PoUserKey; $null = $PoApiKey; $null = $NotificationProvider

    $SendNotification = {
        param(
            [string]$Title,
            [string]$Message,
            [string]$Type
        )
        if ($NotificationProvider) {
            & $NotificationProvider -Title $Title -Message $Message -Type $Type
        } else {
            $pushoverSplat = @{
                PoUserKey = $PoUserKey
                PoApiKey  = $PoApiKey
                Title     = $Title
                Message   = $Message
            }
            Send-BridgePushover @pushoverSplat
        }
    }

    foreach ($entry in $CurrentState) {
        switch ($entry.gefyraStatus) {
            ($Configuration.Statuses.ClosedForMaintenance) {

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
                $title   = "🚧 Η γέφυρα της $($entry.gefyraName)ς είναι κλειστή για συντήρηση"
                $message = "Η γέφυρα $($entry.gefyraName)ς είναι κλειστή για συντήρηση. Επιλέξτε άλλη διαδρομή."
                & $SendNotification -Title $title -Message $message -Type 'Closed'
            }
            ($Configuration.Statuses.PermanentlyClosed) {

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
                $title   = "🚧 Η γέφυρα της $($entry.gefyraName)ς είναι μόνιμα κλειστή"
                $message = "Η γέφυρα $($entry.gefyraName)ς είναι μόνιμα κλειστή. Επιλέξτε άλλη διαδρομή."
                & $SendNotification -Title $title -Message $message -Type 'Closed'
            }
            ($Configuration.Statuses.ClosedWithSchedule) {

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
                        $title   = "🚧 Η γέφυρα της $($entry.gefyraName)ς έκλεισε"
                        $message = ($ocrResult | Out-String)
                        & $SendNotification -Title $title -Message $message -Type 'Closed'
                    } else {
                        $title   = "🚧 Η γέφυρα της $($entry.gefyraName)ς έκλεισε με πρόγραμμα"
                        $message = "Δεν κατέστη δυνατή η αυτόματη ανάγνωση του προγράμματος κλεισίματος. Δείτε την εικόνα εδώ: $($entry.imageUrl)"
                        & $SendNotification -Title $title -Message $message -Type 'Closed'
                    }
                } catch {
                    $writeBridgeLogSplat = @{
                        Stage   = 'Σφάλμα'
                        Message = "❌ Απέτυχε η OCR για $($entry.imageUrl): $($_.Exception.Message)"
                        Level   = 'Warning'
                    }
                    Write-BridgeLog @writeBridgeLogSplat
                    $title   = "🚧 Η γέφυρα της $($entry.gefyraName)ς έκλεισε με πρόγραμμα"
                    $message = "Απέτυχε η υπηρεσία OCR. Δείτε την εικόνα εδώ: $($entry.imageUrl)"
                    & $SendNotification -Title $title -Message $message -Type 'Closed'
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

