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
    $patterns = @{
        'poseidonia' = @{
            ($Configuration.Statuses.ClosedForMaintenance) = 'image-bridge-close-for-maintenance\.php(\?\d+)?'
            ($Configuration.Statuses.ClosedWithSchedule)   = 'image-bridge-open-with-schedule-posidonia\.php(\?\d+)?'
            ($Configuration.Statuses.PermanentlyClosed)    = 'image-bridge-always-close\.php(\?\d+)?'
            ($Configuration.Statuses.Open)                 = 'image-bridge-open-no-schedule\.php\?\d+'
        }
        'isthmia'    = @{
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
        if (-not $bridgeImages -or $bridgeImages.Count -eq 0) {
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
            $PSCmdlet.ThrowTerminatingError($errorRecord)
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
        foreach ($statusEntry in $patterns[$location].GetEnumerator()) {
            $status = $statusEntry.Key
            $pattern = $statusEntry.Value
            # Inline Resolve-BridgeStatus
            $image = $bridgeImages | Where-Object { $_.src -match $pattern } | Select-Object -First 1
            if ($status -eq $Configuration.Statuses.Open) {
                $hasInfoImage = $bridgeImages | Where-Object { $_.src -match 'info\.php\?\d+' }
                if (-not $hasInfoImage -or $hasInfoImage.Count -eq 0) {
                    $writeBridgeLogSplat = @{
                        Stage   = 'Ανάλυση'
                        Message = "Παραλείπεται $location ($status): Δεν βρέθηκε info εικόνα"
                    }
                    Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                    $image = $null
                }
            }
            if ($image) {
                $writeBridgeLogSplat = @{
                    Stage   = 'Ανάλυση'
                    Message = "✅ Εντοπίστηκε: Γέφυρα: $location Κατάσταση: $status"
                    Level   = 'Debug'
                }
                Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
                $newBridgeStatusObjectSplat = @{
                    Location  = $location
                    Status    = $status
                    Timestamp = $Timestamp
                    ImageSrc  = $image.src
                    BaseUrl   = $baseUrl
                }
                $newBridgeStatusObjectSplat.Configuration = $Configuration
                $object = Get-BridgeStatusObject @newBridgeStatusObjectSplat
                $result.Add($object)
                break
            }
        }
    }
    return $result.ToArray()
}
