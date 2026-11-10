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
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'ApiKey', Justification = 'Keys are provided securely from the environment')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoUserKey', Justification = 'Keys are provided securely from the environment')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', 'PoApiKey', Justification = 'Keys are provided securely from the environment')]
    [CmdletBinding(DefaultParameterSetName = 'Pushover')]
    [OutputType([void])]
    param (
        [Parameter(Mandatory, ValueFromPipeline)]
        [object]$CurrentState,

        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$ApiKey,

        [Parameter(Mandatory, ParameterSetName = 'Pushover')]
        [ValidateNotNullOrEmpty()]
        [string]$PoUserKey,

        [Parameter(Mandatory, ParameterSetName = 'Pushover')]
        [ValidateNotNullOrEmpty()]
        [string]$PoApiKey,

        [Parameter(Mandatory, ParameterSetName = 'CustomProvider')]
        [ValidateNotNull()]
        [scriptblock]$NotificationProvider,

        [Parameter(Mandatory)]
        [ValidateNotNull()]
        [PSCustomObject]$Configuration
    )

    begin {
        $ocrFailed = $false

        function Send-Notification {
            <#
            .SYNOPSIS
            Στέλνει την ειδοποίηση κλεισίματος.
            .DESCRIPTION
            Βοηθητική συνάρτηση για την αποστολή μέσω Pushover ή CustomProvider.
            #>
            param(
                [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Config,
                [string]$Title,
                [string]$Message,
                [string]$Type,
                [string]$PoUser,
                [string]$PoApi,
                [scriptblock]$Provider
            )

            if ($null -ne $Provider) {
                & $Provider -Title $Title -Message $Message -Type $Type
            } else {
                $pushoverSplat = @{
                    PoUserKey     = $PoUser
                    PoApiKey      = $PoApi
                    Title         = $Title
                    Message       = $Message
                    ErrorAction   = 'Stop'
                    Configuration = $Config
                }
                Send-BridgePushover @pushoverSplat
            }
        }

        function Get-BridgeScheduledNotificationContent {
            <#
            .SYNOPSIS
            Δημιουργεί τον τίτλο και το μήνυμα ειδοποίησης από το αποτέλεσμα OCR.
            #>
            param(
                [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Entry,
                [Parameter()][AllowNull()][object]$OcrResult
            )

            if (-not $OcrResult) {
                return @{
                    Title   = "🚧 Η γέφυρα $($Entry.GefyraName) έκλεισε με πρόγραμμα"
                    Message = "Δεν κατέστη δυνατή η αυτόματη ανάγνωση του προγράμματος κλεισίματος. Δείτε την εικόνα εδώ: $($Entry.imageUrl)"
                }
            }

            $message = "Από: $($OcrResult.From) Έως: $($OcrResult.To)`n"
            if ($OcrResult.ClosedFor) { $message += "Κλειστή για: $($OcrResult.ClosedFor)`n" }
            if ($OcrResult.OpensIn) { $message += "Ανοίγει σε: $($OcrResult.OpensIn)`n" }
            if ($OcrResult.Note1) { $message += "Σημείωση: $($OcrResult.Note1)`n" }

            return @{
                Title   = "🚧 Η γέφυρα $($Entry.GefyraName) έκλεισε"
                Message = $message
            }
        }
    }

    process {
        foreach ($entry in $CurrentState) {
            if ($null -eq $entry) { continue }

            switch ($entry.GefyraStatus) {
                { $_ -in @($Configuration.Statuses.ClosedForMaintenance, $Configuration.Statuses.PermanentlyClosed) } {
                    $isMaintenance = $_ -eq $Configuration.Statuses.ClosedForMaintenance
                    $statusText = if ($isMaintenance) { "κλειστή για συντήρηση" } else { "μόνιμα κλειστή" }

                    $logDetails = @"
🛑 $($statusText): $($entry.GefyraName)
Χρονική στιγμή: $($entry.timestamp)
Εικόνα: $($entry.imageUrl)
Μέθοδος: Άμεση ειδοποίηση (χωρίς OCR)
"@
                    $writeBridgeLogSplat = @{
                        Stage   = 'Ειδοποίηση'
                        Message = $logDetails
                        Level   = 'Debug'
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                    $title   = "🚧 Η γέφυρα $($entry.GefyraName) είναι $statusText"
                    $message = "Η γέφυρα $($entry.GefyraName) είναι $statusText. Επιλέξτε άλλη διαδρομή."
                    Send-Notification -Config $Configuration -Title $title -Message $message -Type 'Closed' -PoUser $PoUserKey -PoApi $PoApiKey -Provider $NotificationProvider
                }
                ($Configuration.Statuses.ClosedWithSchedule) {
                    $logDetails = @"
📸 Κλειστή με πρόγραμμα: $($entry.GefyraName)
Χρονική στιγμή: $($entry.timestamp)
📷 Εικόνα προς OCR: $($entry.imageUrl)
Μέθοδος: OCR + Ειδοποίηση
"@
                    $writeBridgeLogSplat = @{
                        Stage   = 'Ειδοποίηση'
                        Message = $logDetails
                        Level   = 'Debug'
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                    $ocrSplat = @{
                        ApiKey        = $ApiKey
                        ImageUri      = $entry.imageUrl
                        ErrorAction   = 'Stop'
                        Configuration = $Configuration
                    }
                    try {
                        $ocrResult = Invoke-BridgeOCRGoogleCloud @ocrSplat
                        $content = Get-BridgeScheduledNotificationContent -Entry $entry -OcrResult $ocrResult
                        Send-Notification -Config $Configuration -Title $content.Title -Message $content.Message -Type 'Closed' -PoUser $PoUserKey -PoApi $PoApiKey -Provider $NotificationProvider
                    } catch {
                        $ocrFailed = $true
                        $writeBridgeLogSplat = @{
                            Stage   = 'Σφάλμα'
                            Message = "❌ Απέτυχε η OCR για $($entry.imageUrl): $($_.Exception.Message)"
                            Level   = 'Warning'
                        }
                        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                        Write-Warning "OCR failed for $($entry.imageUrl): $($_.Exception.Message)"
                        $title   = "🚧 Η γέφυρα $($entry.GefyraName) έκλεισε με πρόγραμμα"
                        $message = "Απέτυχε η υπηρεσία OCR. Δείτε την εικόνα εδώ: $($entry.imageUrl)"
                        Send-Notification -Config $Configuration -Title $title -Message $message -Type 'Closed' -PoUser $PoUserKey -PoApi $PoApiKey -Provider $NotificationProvider
                    }
                }
                default {
                    $writeBridgeLogSplat = @{
                        Stage   = 'Ειδοποίηση'
                        Message = "ℹ️ Αγνοείται ειδοποίηση για $($entry.GefyraName) με κατάσταση: $($entry.GefyraStatus)"
                        Level   = 'Debug'
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                }
            }
        }
    }

    end {
        if ($ocrFailed) {
            Write-Warning 'One or more bridge notifications failed during OCR.'
        }
    }
}
