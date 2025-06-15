function Get-BridgeHtml {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Ανακτά HTML περιεχόμενο από την σελίδα της γέφυρας.

    .DESCRIPTION
    Η Get-BridgeHtml πραγματοποιεί HTTP αίτηση και επιστρέφει το HTML
    περιεχόμενο της σελίδας.

    .OUTPUTS
    [string] - Το HTML περιεχόμενο της σελίδας.

    .EXAMPLE
    $html    = Get-BridgeHtml

    .NOTES
    Χρησιμοποιείται από άλλες functions για ανάλυση περιεχομένου.
    #>    [OutputType([string])]
    param (
        [ValidateScript({ [Uri]::IsWellFormedUriString($_, [UriKind]::Absolute) })]
        [string]$Uri = 'https://www.topvision.gr/dioriga/'
    )
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
        $response = Invoke-WebRequest @invokeWebRequestSplat
        return $response.Content
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Σφάλμα κατά την ανάκτηση: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Αποτυχία λήψης HTML: $($_.Exception.Message)")),
            'BridgeHtmlDownloadFailed',
            [System.Management.Automation.ErrorCategory]::ConnectionError,
            $Uri
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}