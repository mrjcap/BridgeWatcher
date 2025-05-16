function Get-BridgeStatusFromHtml {
    [CmdletBinding()]
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

    [OutputType([pscustomobject[]])]
    param (
        [Parameter(Mandatory)][string]$Html,
        [Parameter(Mandatory)][string]$Timestamp
    )
    $baseUrl = 'https://www.topvision.gr/dioriga/'
    $patterns = @{
        'poseidonia' = @{
            'Κλειστή για συντήρηση'  = 'image-bridge-close-for-maintenance\.php(\?\d+)?'
            'Κλειστή με πρόγραμμα'   = 'image-bridge-open-with-schedule-posidonia\.php(\?\d+)?'
            'Μόνιμα κλειστή'         = 'image-bridge-always-close\.php(\?\d+)?'
            'Ανοιχτή'                = 'image-bridge-open-no-schedule\.php\?\d+'
        }
        'isthmia'    = @{
            'Κλειστή για συντήρηση' = 'image-bridge-close-for-maintenance\.php(\?\d+)?'
            'Κλειστή με πρόγραμμα'  = 'image-bridge-open-with-schedule-isthmia\.php(\?\d+)?'
            'Μόνιμα κλειστή'        = 'image-bridge-always-close\.php(\?\d+)?'
            'Ανοιχτή'               = 'image-bridge-open-no-schedule\.php\?\d+'
        }
    }
    $result = @()
    foreach ($location in $patterns.Keys) {
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = "➤ Επεξεργασία: $location"
            Level   = 'Debug'
        }
        Write-BridgeLog @writeBridgeLogSplat
        $getBridgeImagesSplat = @{
            HtmlContent = $Html
            Location    = $location
        }
        $bridgeImages = Get-BridgeImage @getBridgeImagesSplat
        if (-not $bridgeImages -or $bridgeImages.Count -eq 0) {
            $writeBridgeLogSplat = @{
                Stage   = 'Σφάλμα'
                Message = "❌ Δεν εντοπίστηκαν εικόνες για $location"
                Level   = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                ([System.Exception]::new("Δεν βρέθηκαν εικόνες για το $location.")),
                'BridgeImagesNotFound',
                [System.Management.Automation.ErrorCategory]::ObjectNotFound,
                $location
            )
            $PSCmdlet.ThrowTerminatingError($errorRecord)
            continue
        }
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = '✔ Εικόνες:'
            Level   = 'Debug'
        }
        Write-BridgeLog @writeBridgeLogSplat
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = "  • $($_.src)"
            Level   = 'Debug'
        }
        $bridgeImages | ForEach-Object { Write-BridgeLog @writeBridgeLogSplat }
        foreach ($statusEntry in $patterns[$location].GetEnumerator()) {
            $status = $statusEntry.Key
            $pattern = $statusEntry.Value
            $resolveBridgeStatusSplat = @{
                Location         = $location
                Status           = $status
                Pattern          = $pattern
                BridgeImages     = $bridgeImages
                RequireInfoImage = ($status -eq 'Ανοιχτή')
            }
            $image = Resolve-BridgeStatus @resolveBridgeStatusSplat
            if ($image) {
                $writeBridgeLogSplat = @{
                    Stage   = 'Ανάλυση'
                    Message = "✅ Εντοπίστηκε: Γέφυρα: $location Κατάσταση: $status"
                    Level   = 'Debug'
                }
                Write-BridgeLog @writeBridgeLogSplat
                $newBridgeStatusObjectSplat = @{
                    Location  = $location
                    Status    = $status
                    Timestamp = $Timestamp
                    ImageSrc  = $image.src
                    BaseUrl   = $baseUrl
                }
                $object = New-BridgeStatusObject @newBridgeStatusObjectSplat
                $result += $object
                break
            } else {
                $writeBridgeLogSplat = @{
                    Stage   = 'Ανάλυση'
                    Message = "⏭ Δεν ταιριάζει: $status"
                    Level   = 'Debug'
                }
                Write-BridgeLog @writeBridgeLogSplat
            }
        }
    }
    return $result
}