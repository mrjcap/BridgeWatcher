$script:BridgeImageBytesByUrl = @{}

function Get-BridgeImageBuffer {
    <#
    .SYNOPSIS
    Λήψη δεδομένων εικόνας.
    .DESCRIPTION
    Κατεβάζει την εικόνα και επιστρέφει τα bytes της.
    #>
    [CmdletBinding()]
    param(
        [string]$Url,
        [int]$TimeoutSec = 60
    )
    $response = Invoke-WebRequest -Uri $Url -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop -Method Get
    try {
        if ($response.Content -is [byte[]]) {
            return $response.Content
        } else {
            return [System.Text.Encoding]::UTF8.GetBytes($response.Content)
        }
    } finally {
        if ($response -is [System.IDisposable]) {
            $response.Dispose()
        }
    }
}

function Get-BridgeCachedImageBytes {
    <#
    .SYNOPSIS
    Ανακτά τα bytes εικόνας από τη μνήμη cache ή μέσω HTTP.

    .DESCRIPTION
    Η Get-BridgeCachedImageBytes επιστρέφει τα αποθηκευμένα bytes από το
    $script:BridgeImageBytesByUrl αν υπάρχουν και δεν είναι κενά, διαφορετικά
    καλεί την Get-BridgeImageBuffer για λήψη τους.

    .PARAMETER Url
    Το πλήρες URL της εικόνας προς ανάκτηση.

    .PARAMETER TimeoutSec
    Το χρονικό όριο αναμονής HTTP σε δευτερόλεπτα.

    .OUTPUTS
    [byte[]]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Returns raw image byte array from cache or HTTP')]
    [CmdletBinding()]
    [OutputType([byte[]])]
    param(
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Url,
        [int]$TimeoutSec = 60
    )

    $cachedBytes = $script:BridgeImageBytesByUrl[$Url]
    if ($null -ne $cachedBytes -and $cachedBytes.Count -gt 0) {
        return [byte[]]$cachedBytes
    }

    return [byte[]](Get-BridgeImageBuffer -Url $Url -TimeoutSec $TimeoutSec)
}

function Get-BridgeStatusObject {
    <#
    .SYNOPSIS
    Δημιουργεί αντικείμενο κατάστασης γέφυρας.

    .DESCRIPTION
    Η Get-BridgeStatusObject δημιουργεί structured αντικείμενο που περιέχει
    όνομα γέφυρας, κατάσταση, χρονική σφραγίδα και URL εικόνας.

    .PARAMETER Location
    Το αναγνωριστικό της γέφυρας ('poseidonia' ή 'isthmia').

    .PARAMETER Status
    Η κατάσταση της γέφυρας ('Ανοιχτή', 'Κλειστή', 'Άγνωστη').

    .PARAMETER Timestamp
    Η χρονική στιγμή καταγραφής.

    .PARAMETER ImageSrc
    Το URL ή το σχετικό path της εικόνας.

    .PARAMETER BaseUrl
    Το base URL για συμπλήρωση εικόνων (προεπιλογή https://www.topvision.gr/dioriga/).

    .OUTPUTS
    Αντικείμενο κατάστασης.

    .EXAMPLE
    Get-BridgeStatusObject -Location 'poseidonia' -Status 'Closed' -Timestamp (Get-Date) -ImageSrc 'bridge1.jpg'

    .NOTES
    Επιστρέφει πάντα πλήρες αντικείμενο με σωστά πεδία.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Location,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Status,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Timestamp,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$ImageSrc, [Parameter()][ValidateScript({
                if ([string]::IsNullOrEmpty($_) -or [Uri]::IsWellFormedUriString($_, [UriKind]::Absolute)) {
                    $true
                } else {
                    throw "The parameter '$_' is not a valid absolute URI."
                }
            })][string]$BaseUrl,
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration
    )


    # Use configuration or fallback for BaseUrl
    if (-not $BaseUrl) {
        $BaseUrl = $Configuration.Urls.BaseImage
    }
    $ImageUrl = if ($ImageSrc -match '^https?://') { $ImageSrc } else { "$($BaseUrl.TrimEnd('/'))/$ImageSrc" }
    $baseHost = ([uri]$BaseUrl).Host -replace '^www\.', ''
    $imageUriObj = $null
    if (-not [uri]::TryCreate($ImageUrl, [UriKind]::Absolute, [ref]$imageUriObj) -or (($imageUriObj.Host -replace '^www\.', '') -ne $baseHost)) {
        $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new("Untrusted or invalid image URI host: $ImageUrl"),
            'INVALID_IMAGE_HOST',
            [System.Management.Automation.ErrorCategory]::SecurityError,
            $ImageUrl
        ))
    }

    $ImageHash = $null
    if ($Status -eq $Configuration.Statuses.ClosedWithSchedule) {
        try {
            $bytes = Get-BridgeImageBuffer -Url $ImageUrl -TimeoutSec $Configuration.Defaults.HttpRequestTimeout
            $md5 = [System.Security.Cryptography.MD5]::Create()
            try {
                $hashBytes = $md5.ComputeHash($bytes)
                $ImageHash = [System.BitConverter]::ToString($hashBytes) -replace '-'
            } finally {
                if ($null -ne $md5) { $md5.Dispose() }
            }
            if ($script:BridgeImageBytesByUrl.Count -ge 4) {
                $script:BridgeImageBytesByUrl.Clear()
            }
            $script:BridgeImageBytesByUrl[$ImageUrl] = [byte[]]$bytes
        } catch {
            $script:BridgeImageBytesByUrl.Remove($ImageUrl)
            $writeBridgeLogSplat = @{
                Stage   = 'Σφάλμα'
                Message = "❌ Αποτυχία λήψης/hashing εικόνας για $ImageUrl`: $($_.Exception.Message)"
                Level   = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            # A missing fingerprint must not suppress valid status changes for the other bridge.
            # Comparison retains the previous schedule/hash until the image can be downloaded.
            $ImageHash = $null
        }
    }

    return [pscustomobject]@{
        PSTypeName   = 'Bridge.Status'
        GefyraName   = $Configuration.BridgeNames.$Location
        GefyraStatus = $Status
        Timestamp    = $Timestamp
        ImageUrl     = $ImageUrl
        ImageHash    = $ImageHash
    }
}
