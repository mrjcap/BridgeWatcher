function Get-BridgeStatus {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Ανακτά την τρέχουσα κατάσταση γεφυρών από διαδικτυακή σελίδα.

    .DESCRIPTION
    Η Get-BridgeStatus ανακτά HTML, αναλύει την κατάσταση
    και επιστρέφει λίστα καταστάσεων γεφυρών.

    .PARAMETER OutputFile
    (Προαιρετικό) Το αρχείο όπου θα αποθηκευτεί η τρέχουσα κατάσταση.

    .OUTPUTS
    [object[]] - Λίστα καταστάσεων γεφυρών.

    .EXAMPLE
    Get-BridgeStatus -OutputFile 'C:\Logs\current-status.json'

    .NOTES
    Αν αποτύχει η ανάκτηση HTML, επιστρέφεται κενό array.
    #>

    [OutputType([object[]])]
    param (
        [Parameter()][string]$OutputFile
    )
    begin {
        $timestamp = Get-Date -Format o
        $result    = @()
        $html      = Get-BridgeHtml
    }
    process {
        if (-not $html) {
            $writeBridgeLogSplat = @{
                Stage      = 'Σφάλμα'
                Message    = '❌ Αποτυχία ανάκτησης HTML.'
                Level      = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat
            return @()
        }
        $getBridgeStatusFromHtmlSplat = @{
            Html         = $html
            Timestamp    = $timestamp
        }
        $result    = Get-BridgeStatusFromHtml @getBridgeStatusFromHtmlSplat
    }
    end {
        if ($result.Count -eq 0) {
            $writeBridgeLogSplat = @{
                Stage      = 'Σφάλμα'
                Message    = '⛔ Δεν υπάρχει διαθέσιμο status για αποθήκευση.'
                Level      = 'Warning'
            }
            Write-BridgeLog @writeBridgeLogSplat
        }
        if ($PSBoundParameters.ContainsKey('OutputFile')) {
            if ($result -and $result.Count -gt 0) {
                $splat = @{
                    Data                 = $result
                    Path                 = $OutputFile
                }
                Export-BridgeStatusJson @splat
            } else {
                $writeBridgeLogSplat = @{
                    Stage      = 'Σφάλμα'
                    Message    = '⛔ Δεν υπάρχει διαθέσιμο status για αποθήκευση.'
                    Level      = 'Warning'
                }
                Write-BridgeLog @writeBridgeLogSplat
            }
        }
        return $result
    }
}