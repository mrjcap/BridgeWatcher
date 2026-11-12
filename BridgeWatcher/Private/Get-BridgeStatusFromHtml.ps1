function Resolve-BridgeLocationStatus {
    <#
    .SYNOPSIS
    Αντιστοιχίζει τις εικόνες μιας τοποθεσίας με την ενεργή κατάσταση γέφυρας.
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Location,
        [Parameter(Mandatory)][ValidateNotNull()][object[]]$BridgeImages,
        [Parameter(Mandatory)][ValidateNotNull()][System.Collections.IDictionary]$StatusPatterns,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Timestamp,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$BaseUrl,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    $hasInfoImage = [bool]($BridgeImages | Where-Object { $_.src -match 'info\.php\?\d+' })
    foreach ($statusEntry in $StatusPatterns.GetEnumerator()) {
        $status = $statusEntry.Key
        $pattern = $statusEntry.Value
        $image = $BridgeImages | Where-Object { $_.src -match $pattern } | Select-Object -First 1
        if ($image) {
            if ($status -eq $Configuration.Statuses.Open -and -not $hasInfoImage) {
                $writeBridgeLogSplat = @{
                    Stage   = 'Ανάλυση'
                    Message = "Λείπει η εικόνα info.php για $Location ($status). Η γέφυρα θα θεωρηθεί Ανοιχτή, αλλά ενδέχεται να υπάρχει σφάλμα."
                    Level   = 'Warning'
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            }
            $writeBridgeLogSplat = @{
                Stage   = 'Ανάλυση'
                Message = "✅ Εντοπίστηκε: Γέφυρα: $Location Κατάσταση: $status"
                Level   = 'Debug'
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            $newBridgeStatusObjectSplat = @{
                Location      = $Location
                Status        = $status
                Timestamp     = $Timestamp
                ImageSrc      = $image.src
                BaseUrl       = $BaseUrl
                Configuration = $Configuration
            }
            return (Get-BridgeStatusObject @newBridgeStatusObjectSplat)
        }
    }
    return $null
}

function Get-BridgeStatusFromHtml {
    <#
    .SYNOPSIS
    Αναλύει HTML και επιστρέφει καταστάσεις γέφυρας.
    .DESCRIPTION
    Η Get-BridgeStatusFromHtml αναλύει HTML περιεχόμενο και επιστρέφει
    την τρέχουσα κατάσταση για κάθε γέφυρα που ανιχνεύεται.
    .PARAMETER Html
    Το HTML περιεχόμενο σε μορφή string.
    .PARAMETER Timestamp
    Η χρονική στιγμή συλλογής του HTML.
    .OUTPUTS
    [pscustomobject[]] - Καταστάσεις γέφυρας με ονόματα και timestamps.
    .EXAMPLE
    Get-BridgeStatusFromHtml -Html $htmlContent -Timestamp (Get-Date)
    .NOTES
    Χρησιμοποιεί regex και structured parsing για ανάλυση.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject[]])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Html,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Timestamp,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )
    # Χρήση διαμόρφωσης ή εναλλακτικής λύσης

    $baseUrl = $Configuration.Urls.BaseImage
    $patterns = [ordered]@{
        'poseidonia' = [ordered]@{
            ($Configuration.Statuses.ClosedForMaintenance) = 'image-bridge-close-for-maintenance\.php(\?\d+)?'
            ($Configuration.Statuses.ClosedWithSchedule)   = 'image-bridge-open-with-schedule-posidonia\.php(\?\d+)?'
            ($Configuration.Statuses.PermanentlyClosed)    = 'image-bridge-always-close\.php(\?\d+)?'
            ($Configuration.Statuses.Open)                 = 'image-bridge-open-no-schedule\.php\?\d+'
        }
        'isthmia'    = [ordered]@{
            ($Configuration.Statuses.ClosedForMaintenance) = 'image-bridge-close-for-maintenance\.php(\?\d+)?'
            ($Configuration.Statuses.ClosedWithSchedule)   = 'image-bridge-open-with-schedule-isthmia\.php(\?\d+)?'
            ($Configuration.Statuses.PermanentlyClosed)    = 'image-bridge-always-close\.php(\?\d+)?'
            ($Configuration.Statuses.Open)                 = 'image-bridge-open-no-schedule\.php\?\d+'
        }
    }
    $result = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($location in $patterns.Keys) {
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = "➤ Επεξεργασία: $location"
            Level   = 'Debug'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        $getBridgeImagesSplat = @{
            HtmlContent   = $Html
            Location      = $location
            Configuration = $Configuration
        }
        $bridgeImages = Get-BridgeImage @getBridgeImagesSplat
        if (-not $bridgeImages) {
            $writeBridgeLogSplat = @{
                Stage   = 'Σφάλμα'
                Message = "❌ Δεν εντοπίστηκαν εικόνες για $location"
                Level   = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                ([System.Exception]::new("Δεν βρέθηκαν εικόνες για το $location.")),
                'BridgeImagesNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $location
            )
            $PSCmdlet.WriteError($errorRecord)
            continue
        }
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = '✔ Εικόνες:'
            Level   = 'Debug'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        $imageList = ($bridgeImages | ForEach-Object { "  • $($_.src)" }) -join "`n"
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = $imageList
            Level   = 'Debug'
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
        $resolveLocationSplat = @{
            Location       = $location
            BridgeImages   = @($bridgeImages)
            StatusPatterns = $patterns[$location]
            Timestamp      = $Timestamp
            BaseUrl        = $baseUrl
            Configuration  = $Configuration
        }
        $statusObject = Resolve-BridgeLocationStatus @resolveLocationSplat
        if ($null -ne $statusObject) {
            $result.Add($statusObject)
        } else {
            $writeBridgeLogSplat = @{
                Stage   = 'Σφάλμα'
                Message = "❌ Δεν βρέθηκε έγκυρη εικόνα κατάστασης για $location"
                Level   = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                ([System.Exception]::new("Δεν βρέθηκε έγκυρη εικόνα κατάστασης για το $location.")),
                'BridgeStatusPatternNotFound',
                [System.Management.Automation.ErrorCategory]::ParserError,
                $location
            )
            $PSCmdlet.WriteError($errorRecord)
        }
    }
    return $result.ToArray()
}
