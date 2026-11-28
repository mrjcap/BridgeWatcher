<#
.SYNOPSIS
Copies schedule fields from the OCR result into the bridge state.
.DESCRIPTION
Updates either a dictionary or a status object in memory.
.PARAMETER Entry
The bridge state to update.
.PARAMETER OcrResult
The parsed OCR schedule.
#>
function Set-BridgeEntryOcrMetadata {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Ενημερώνει μόνο αντικείμενο στη μνήμη χωρίς εξωτερικές αλλαγές συστήματος.')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Το Metadata αποτελεί καθιερωμένο συλλογικό όρο.')]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][ValidateNotNull()][object]$Entry,
        [Parameter(Mandatory)][ValidateNotNull()][object]$OcrResult
    )
    $ocrProperties = @('ScheduleState', 'From', 'To', 'ClosedFor', 'OpensIn', 'Note1', 'Note2')
    foreach ($prop in $ocrProperties) {
        $val = Get-BridgeOptionalProperty -InputObject $OcrResult -PropertyName $prop
        if ($Entry -is [System.Collections.IDictionary]) {
            $Entry[$prop] = $val
        } else {
            $Entry | Add-Member -MemberType NoteProperty -Name $prop -Value $val -Force
        }
    }
}

<#
.SYNOPSIS
Builds a scheduled closure notification.
.DESCRIPTION
Formats the title and message for a future, active, or expired schedule.
.PARAMETER Entry
The bridge whose schedule is being reported.
.PARAMETER OcrResult
The parsed schedule.
#>
function Get-BridgeScheduledNotificationContent {
    param(
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Entry,
        [Parameter(Mandatory)][ValidateNotNull()][object]$OcrResult
    )

    $fromVal = Get-BridgeOptionalProperty -InputObject $OcrResult -PropertyName 'From'
    $toVal = Get-BridgeOptionalProperty -InputObject $OcrResult -PropertyName 'To'
    $closedForVal = Get-BridgeOptionalProperty -InputObject $OcrResult -PropertyName 'ClosedFor'
    $opensInVal = Get-BridgeOptionalProperty -InputObject $OcrResult -PropertyName 'OpensIn'
    $note1Val = Get-BridgeOptionalProperty -InputObject $OcrResult -PropertyName 'Note1'
    $note2Val = Get-BridgeOptionalProperty -InputObject $OcrResult -PropertyName 'Note2'
    $scheduleState = Get-BridgeOptionalProperty -InputObject $OcrResult -PropertyName 'ScheduleState'

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

<#
.SYNOPSIS
Reads a closure schedule and delivers its notification.
.DESCRIPTION
Retries failed OCR on the next poll. Records a fallback only after successful delivery.
.PARAMETER Entry
The bridge state to update with OCR metadata or fallback delivery status.
.PARAMETER EntryImageUrl
The schedule image to read.
.PARAMETER ApiKey
The credential for the OCR request.
.PARAMETER Notification
Delivery parameters shared by scheduled and fallback notifications.
.PARAMETER OcrFailed
Batch failure flag used to warn once after processing all entries.
#>
function Invoke-BridgeScheduledClosureNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$Entry,
        [AllowNull()][string]$EntryImageUrl,
        [Parameter(Mandatory)][string]$ApiKey,
        [Parameter(Mandatory)][hashtable]$Notification,
        [Parameter(Mandatory)][ref]$OcrFailed
    )

    $ocrSplat = @{
        ApiKey        = $ApiKey
        ImageUri      = $entryImageUrl
        ErrorAction   = 'Stop'
        Configuration = $Notification.Configuration
    }
    $notifiedHash = Get-BridgeOptionalProperty -InputObject $entry -PropertyName 'FallbackNotifiedImageHash'
    try {
        $ocrResult = Invoke-BridgeOCRGoogleCloud @ocrSplat
        if ($null -eq $ocrResult) {
            throw 'OCR returned no usable closure schedule.'
        }
    } catch {
        $OcrFailed.Value = $true
        $failedHash = Get-BridgeOptionalProperty -InputObject $entry -PropertyName 'ImageHash'
        if ($failedHash) {
            $entry.ImageHash = $null
        }
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Απέτυχε η OCR για $($entryImageUrl): $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Notification.Configuration
        Write-Warning -Message "OCR failed for $($entryImageUrl): $($_.Exception.Message)"
        if ($failedHash -and $failedHash -eq $notifiedHash) { return }
        $fallback = @{
            Title   = "🚧 Η γέφυρα $($entry.GefyraName) έκλεισε με πρόγραμμα"
            Message = "Δεν κατέστη δυνατή η αυτόματη ανάγνωση του προγράμματος κλεισίματος. Δείτε την εικόνα εδώ: $entryImageUrl"
        }
        Send-BridgeNotification @Notification @fallback
        if ($failedHash) {
            if ($entry -is [System.Collections.IDictionary]) {
                $entry['FallbackNotifiedImageHash'] = $failedHash
            } else {
                $entry | Add-Member -NotePropertyName FallbackNotifiedImageHash -NotePropertyValue $failedHash -Force
            }
        }
        return
    }
    Set-BridgeEntryOcrMetadata -Entry $entry -OcrResult $ocrResult
    $content = Get-BridgeScheduledNotificationContent -Entry $entry -OcrResult $ocrResult
    Send-BridgeNotification @Notification @content
    if ($notifiedHash) { $entry.FallbackNotifiedImageHash = $null }
}

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
function Invoke-BridgeClosedNotification {
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

        $notification = @{
            Type = 'Closed'; Configuration = $Configuration; Provider = $NotificationProvider
            PoUser = $PoUserKey; PoApi = $PoApiKey
        }
    }

    process {
        foreach ($entry in $CurrentState) {
            if ($null -eq $entry) { continue }

            $entryTimestamp = Get-BridgeOptionalProperty -InputObject $entry -PropertyName 'Timestamp'
            $entryImageUrl = Get-BridgeOptionalProperty -InputObject $entry -PropertyName 'ImageUrl'

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
                    Send-BridgeNotification @notification -Title $title -Message $message
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
                    Invoke-BridgeScheduledClosureNotification -Entry $entry -EntryImageUrl $entryImageUrl -ApiKey $ApiKey -Notification $notification -OcrFailed ([ref]$ocrFailed)
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
            Write-Warning -Message 'One or more bridge notifications failed during OCR.'
        }
    }
}
