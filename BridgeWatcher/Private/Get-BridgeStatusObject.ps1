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

    $ImageHash = $null
    if ($Status -eq $Configuration.Statuses.ClosedWithSchedule) {
        $response = $null
        try {
            $response = Invoke-WebRequest -Uri $ImageUrl -UseBasicParsing -ErrorAction Stop
            if ($response -and $response.Content) {
                try {
                    $bytes = if ($response.Content -is [byte[]]) { $response.Content } else { [System.Text.Encoding]::UTF8.GetBytes($response.Content) }
                    $hashStream = [System.IO.MemoryStream]::new($bytes)
                    $md5 = [System.Security.Cryptography.MD5]::Create()
                    $hashBytes = $md5.ComputeHash($hashStream)
                    $ImageHash = [System.BitConverter]::ToString($hashBytes) -replace '-'
                } finally {
                    if ($null -ne $md5) { $md5.Dispose() }
                    if ($null -ne $hashStream) { $hashStream.Dispose() }
                }
            }
        } catch {
            $writeBridgeLogSplat = @{
                Stage   = 'Σφάλμα'
                Message = "❌ Αποτυχία λήψης/hashing εικόνας για $ImageUrl`: $($_.Exception.Message)"
                Level   = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration
            $PSCmdlet.ThrowTerminatingError([System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new("Image download/hashing failed: $($_.Exception.Message)", $_.Exception),
                'IMAGE_DOWNLOAD_FAILED',
                [System.Management.Automation.ErrorCategory]::InvalidResult,
                $ImageUrl
            ))
        } finally {
            if ($null -ne $response -and $response -is [System.IDisposable]) {
                $response.Dispose()
            }
        }
    }

    return [pscustomobject]@{
        PSTypeName   = 'Bridge.Status'
        GefyraName   = $Configuration.BridgeNames[$Location]
        GefyraStatus = $Status
        Timestamp    = $Timestamp
        ImageUrl     = $ImageUrl
        ImageHash    = $ImageHash
    }
}
