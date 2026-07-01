function Get-BridgeHtml {
    <#
    .SYNOPSIS
    Ανακτά HTML περιεχόμενο από την σελίδα της γέφυρας.

    .DESCRIPTION
    Η Get-BridgeHtml πραγματοποιεί HTTP αίτηση και επιστρέφει το HTML
    περιεχόμενο της σελίδας. Τώρα επιστρέφει BridgeResult object για
    καλύτερο error handling.

    .PARAMETER Uri
    Το URI από όπου θα ανακτηθεί το HTML. Αν δεν παρέχεται, χρησιμοποιείται το Configuration.

    .PARAMETER Configuration
    Αντικείμενο διαμόρφωσης που περιέχει το SourceUrl και άλλες ρυθμίσεις.

    .OUTPUTS
    [PSCustomObject] - BridgeResult object με Success, Data (HTML content), ErrorMessage, ErrorCode, Timestamp.

    .EXAMPLE
    $htmlResult = Get-BridgeHtml -Configuration $config
    if (Test-BridgeResult $htmlResult) {
        $html = $htmlResult.Data
    }

    .NOTES
    Χρησιμοποιεί New-BridgeResult για τυποποιημένη επιστροφή αποτελεσμάτων.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param (
        [Parameter()]
        [ValidateScript({ [Uri]::IsWellFormedUriString($_, [UriKind]::Absolute) })]
        [string]$Uri,

        [Parameter()]
        [PSCustomObject]$Configuration
    )

    if (-not $Configuration) {
        $Configuration = New-BridgeConfiguration
    }

    # Use configuration for URI
    if (-not $Uri) {
        $Uri = $Configuration.SourceUrl
    }

    try {
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = "🌐 Λήψη περιεχομένου από: $Uri"
        }
        Write-BridgeLog @writeBridgeLogSplat

        $invokeWebRequestSplat = @{
            Uri             = $Uri
            UseBasicParsing = $true
            ErrorAction     = 'Stop'
        }

        $maxRetries = 3
        $response = $null
        for ($i = 1; $i -le $maxRetries; $i++) {
            try {
                $response = Invoke-WebRequest @invokeWebRequestSplat
                break
            } catch {
                if ($i -eq $maxRetries) { throw }
                Start-Sleep -Seconds ([Math]::Pow(2, $i))
            }
        }

        return New-BridgeResult -Success $true -Data $response.Content
    }    catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Σφάλμα κατά την ανάκτηση: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat

        return New-BridgeResult -Success $false -ErrorMessage $_.Exception.Message -ErrorCode 'HTTP_ERROR'
    }
}
