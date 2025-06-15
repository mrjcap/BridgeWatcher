function Export-BridgeStatusJson {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Εξάγει την κατάσταση γέφυρας σε αρχείο JSON.

    .DESCRIPTION
    Η Export-BridgeStatusJson αποθηκεύει δεδομένα κατάστασης γέφυρας σε μορφή JSON
    σε καθορισμένη διαδρομή.

    .PARAMETER Data
    Το αντικείμενο ή η λίστα αντικειμένων που θα εξαχθεί.    .PARAMETER Path
    Η πλήρης διαδρομή του αρχείου εξόδου.

    .PARAMETER JsonDepth
    Το βάθος serialization του JSON (προεπιλογή: 10).

    .OUTPUTS
    None.

    .EXAMPLE
    Export-BridgeStatusJson -Data $bridgeStatus -Path 'C:\Logs\status.json'

    .NOTES
    Χρησιμοποιεί ConvertTo-Json και Set-Content για ασφαλή αποθήκευση.
    #>
    [OutputType([void])]    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][object[]]$Data,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter()][ValidateRange(1, 20)][int]$JsonDepth = 10
    )
    try {
        $convertToJsonSplat = @{
            Depth    = $JsonDepth
            Compress = $true
        }
        if (-not (Test-Path -Path (Split-Path -Parent $Path))) {
            throw "Ο φάκελος προορισμού δεν υπάρχει: $(Split-Path -Parent $Path)"
        }
        $json = $Data | ConvertTo-Json @convertToJsonSplat
        $setContentSplat = @{
            Path     = $Path
            Value    = $json
            Encoding = 'utf8BOM'
        }
        Set-Content @setContentSplat
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = "✅ JSON αποθηκεύτηκε στο: $Path"
        }
        Write-BridgeLog @writeBridgeLogSplat
    } catch {
        $writeBridgeLogSplat = @{
            Stage   = 'Σφάλμα'
            Message = "❌ Σφάλμα κατά την αποθήκευση JSON: $($_.Exception.Message)"
            Level   = 'Warning'
        }
        Write-BridgeLog @writeBridgeLogSplat
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Σφάλμα αποθήκευσης JSON: $($_.Exception.Message)")),
            'JsonExportFailure',
            [System.Management.Automation.ErrorCategory]::WriteError,
            $Path
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
}