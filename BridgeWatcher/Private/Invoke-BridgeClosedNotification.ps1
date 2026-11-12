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

        function Get-BridgeEntryValue {
            <#
            .SYNOPSIS
            Ανακτά προαιρετική τιμή ιδιότητας από εγγραφή γέφυρας ή αποτέλεσμα OCR.
            #>
            param(
                [Parameter(Mandatory)][object]$InputObject,
                [Parameter(Mandatory)][string]$Name
            )
            if ($InputObject -is [System.Collections.IDictionary]) {
                return $InputObject[$Name]
            }
            $prop = $InputObject.PSObject.Properties[$Name]
            if ($null -ne $prop) {
                return $prop.Value
            }
            return $null
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

            $entryImageUrl = Get-BridgeEntryValue -InputObject $Entry -Name 'ImageUrl'
            if (-not $OcrResult) {
                return @{
                    Title   = "🚧 Η γέφυρα $($Entry.GefyraName) έκλεισε με πρόγραμμα"
                    Message = "Δεν κατέστη δυνατή η αυτόματη ανάγνωση του προγράμματος κλεισίματος. Δείτε την εικόνα εδώ: $entryImageUrl"
                }
            }

            $fromVal = Get-BridgeEntryValue -InputObject $OcrResult -Name 'From'
            $toVal = Get-BridgeEntryValue -InputObject $OcrResult -Name 'To'
            $closedForVal = Get-BridgeEntryValue -InputObject $OcrResult -Name 'ClosedFor'
            $opensInVal = Get-BridgeEntryValue -InputObject $OcrResult -Name 'OpensIn'
            $note1Val = Get-BridgeEntryValue -InputObject $OcrResult -Name 'Note1'
            $note2Val = Get-BridgeEntryValue -InputObject $OcrResult -Name 'Note2'
            $scheduleState = Get-BridgeEntryValue -InputObject $OcrResult -Name 'ScheduleState'

            $isExpired = ($scheduleState -eq 'Expired') -or ($closedForVal -eq 'Ολοκληρώθηκε')
            $isFuture = (-not $isExpired) -and (($scheduleState -eq 'Future') -or ($note2Val -match 'θα κλείσει'))

            $title = if ($isFuture) {
                "🚧 Η γέφυρα $($Entry.GefyraName) θα κλείσει με πρόγραμμα"
            } elseif ($isExpired) {
                "ℹ️ Το πρόγραμμα κλεισίματος της γέφυρας $($Entry.GefyraName) ολοκληρώθηκε"
            } else {
                "🚧 Η γέφυρα $($Entry.GefyraName) έκλεισε"
            }

            $message = "Από: $fromVal Έως: $toVal`n"
            if ($closedForVal) { $message += "Κλειστή για: $closedForVal`n" }
            if (-not $isFuture -and -not $isExpired -and $opensInVal) { $message += "Ανοίγει σε: $opensInVal`n" }
            if (-not $isFuture -and $note1Val) { $message += "Σημείωση: $note1Val`n" }
            if ($note2Val) { $message += "$note2Val`n" }

            return @{
                Title   = $title
                Message = $message
            }
        }
    }

    process {
        foreach ($entry in $CurrentState) {
            if ($null -eq $entry) { continue }

            $entryTimestamp = Get-BridgeEntryValue -InputObject $entry -Name 'Timestamp'
            $entryImageUrl = Get-BridgeEntryValue -InputObject $entry -Name 'ImageUrl'

            switch ($entry.GefyraStatus) {
                { $_ -in @($Configuration.Statuses.ClosedForMaintenance, $Configuration.Statuses.PermanentlyClosed) } {
                    $isMaintenance = $_ -eq $Configuration.Statuses.ClosedForMaintenance
                    $statusText = if ($isMaintenance) { "κλειστή για συντήρηση" } else { "μόνιμα κλειστή" }

                    $logDetails = @"
🛑 $($statusText): $($entry.GefyraName)
Χρονική στιγμή: $entryTimestamp
Εικόνα: $entryImageUrl
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
Χρονική στιγμή: $entryTimestamp
📷 Εικόνα προς OCR: $entryImageUrl
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
                        ImageUri      = $entryImageUrl
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
                            Message = "❌ Απέτυχε η OCR για $($entryImageUrl): $($_.Exception.Message)"
                            Level   = 'Warning'
                        }
                        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                        Write-Warning "OCR failed for $($entryImageUrl): $($_.Exception.Message)"
                        $title   = "🚧 Η γέφυρα $($entry.GefyraName) έκλεισε με πρόγραμμα"
                        $message = "Απέτυχε η υπηρεσία OCR. Δείτε την εικόνα εδώ: $entryImageUrl"
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
