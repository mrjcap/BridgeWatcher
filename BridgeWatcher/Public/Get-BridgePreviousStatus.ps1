function Get-BridgePreviousStatus {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Ανακτά προηγούμενη αποθηκευμένη κατάσταση γέφυρας από JSON.

    .DESCRIPTION
    Η Get-BridgePreviousStatus διαβάζει αρχείο JSON που περιέχει
    καταγεγραμμένη κατάσταση γεφυρών.

    .PARAMETER InputFile
    Η διαδρομή του αρχείου JSON.

    .OUTPUTS
    [object[]] - Λίστα καταστάσεων ή κενό array αν δεν υπάρχει.

    .EXAMPLE
    Get-BridgePreviousStatus -InputFile 'C:\Logs\previous-status.json'

    .NOTES
    Ασφαλής ανάγνωση με structured error handling και fallback.
    #>    [OutputType([object[]])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$InputFile
    )
    if (-not (Test-Path $InputFile)) {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "Το αρχείο $($InputFile) δεν βρέθηκε – επιστρέφεται κενό array."
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        return @()
    }
    try {
        $getContentSplat = @{
            Path     = $InputFile
            Raw      = $true
            Encoding = 'utf8BOM'
        }
        $convertFromJsonSplat = @{
            Depth = 10
        }
        return Get-Content @getContentSplat | ConvertFrom-Json @convertFromJsonSplat
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "Σφάλμα κατά την ανάλυση JSON: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        $PSCmdlet.ThrowTerminatingError(
            [System.Management.Automation.ErrorRecord]::new(
                ([System.Exception]::new("Σφάλμα κατά την ανάλυση JSON: $($_.Exception.Message)")),
                'BridgeJsonParseError',
                [System.Management.Automation.ErrorCategory]::InvalidData,
                $InputFile
            )
        )
    }
}