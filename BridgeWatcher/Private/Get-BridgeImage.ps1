<#
.SYNOPSIS
Εξάγει όλους τους συνδέσμους εικόνων από HTML περιεχόμενο.

.DESCRIPTION
Η Get-BridgeImage αναλύει HTML δεδομένα και επιστρέφει αντικείμενα
με τους συνδέσμους εικόνων που σχετίζονται με την κατάσταση της γέφυρας.

.PARAMETER HtmlContent
Το HTML περιεχόμενο της σελίδας ως συμβολοσειρά (string).

.PARAMETER Location
Η τοποθεσία της γέφυρας ('poseidonia' ή 'isthmia').

.OUTPUTS
[System.Collections.ArrayList] - Λίστα από αντικείμενα εικόνων με την ιδιότητα 'src'.

.NOTES
Η ανάλυση βασίζεται σε κανονικές εκφράσεις (regex) για την εύρεση εικόνων.

.PARAMETER Configuration
Η διαμόρφωση της BridgeWatcher που χρησιμοποιεί η συνάρτηση.
#>
function Get-BridgeImage {
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param (
        [Parameter(Mandatory)][ValidateNotNull()][PSCustomObject]$Configuration,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$HtmlContent,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][ValidateSet('poseidonia', 'isthmia')] [string]$Location
    )

    $bridgePattern = if ($Location -eq 'poseidonia') { 'Ποσειδων[ιίΙΊ]α' } else { 'Ισθμ[ιίΙΊ]α' }

    $blocks = [regex]::Split($HtmlContent, '(?i)<div[^>]+class=["''][^"'']*panel-primary[^"'']*["''][^>]*>')

    $block = $blocks | Where-Object -FilterScript { $_ -match "(?i)$bridgePattern" }
    if (-not $block) {
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = "❌ Δεν βρέθηκε block για $Location"
        }
        Write-BridgeLog @writeBridgeLogSplat -Configuration $Configuration

        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Δεν βρέθηκε block για τη θέση $Location.")),
            'BridgeImageBlockNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $Location
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }

    $bmatches = [regex]::Matches($block, '(?i)<img[^>]+src=["'']([^"'']+)["'']')
    $imageList = [System.Collections.ArrayList]::new()
    foreach ($m in $bmatches) {
        $src = $m.Groups[1].Value
        if ($src -notmatch '\.png([?#].*)?$' -and $src -match 'image-bridge|info\.php') {
            $null = $imageList.Add([pscustomobject]@{ src = $src })
        }
    }
    return [System.Collections.ArrayList]::new([object[]]@($imageList))
}
