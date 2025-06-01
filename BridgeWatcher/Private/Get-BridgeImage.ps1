function Get-BridgeImage {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Εξάγει όλα τα links εικόνων από HTML περιεχόμενο.

    .DESCRIPTION
    Η Get-BridgeImage αναλύει HTML δεδομένα και επιστρέφει αντικείμενα
    με τα links εικόνων που σχετίζονται με την κατάσταση γέφυρας.

    .PARAMETER Html
    Το HTML περιεχόμενο της σελίδας.

    .OUTPUTS
    [pscustomobject[]] - Λίστα από αντικείμενα εικόνων.

    .EXAMPLE
    Get-BridgeImage -Html $htmlContent

    .NOTES
    Η ανάλυση βασίζεται σε regex για ανεύρεση εικόνων.
    #>

    [OutputType([System.Collections.ArrayList])]
    param (
        [Parameter(Mandatory)][string]$HtmlContent,
        [Parameter(Mandatory)][ValidateSet('poseidonia','isthmia')] [string]$Location
    )
    $bridgeLabel = switch ($Location) {
        'poseidonia' { 'ΠΟΣΕΙΔΩΝΙΑ' }
        'isthmia' { 'ΙΣΘΜΙΑ' }
    }
    $blocks = $HtmlContent -split '<div class="panel panel-primary">'
    $block = $blocks | Where-Object { $_ -match "<b>$bridgeLabel</b>" }
    if (-not $block) {
        $writeBridgeLogSplat = @{
            Stage   = 'Ανάλυση'
            Message = "❌ Δεν βρέθηκε block για $Location"
        }
        Write-BridgeLog @writeBridgeLogSplat
        $errorRecord = [System.Management.Automation.ErrorRecord]::new(
            ([System.Exception]::new("Δεν βρέθηκε block για τη θέση $Location.")),
            'BridgeImageBlockNotFound',
            [System.Management.Automation.ErrorCategory]::ObjectNotFound,
            $Location
        )
        $PSCmdlet.ThrowTerminatingError($errorRecord)
    }
    $bmatches = [regex]::Matches($block, '<img[^>]+src="([^"]+)"')
    $imageList = [System.Collections.ArrayList]::new()
    foreach ($m in $bmatches) {
        $src = $m.Groups[1].Value
        if ($src -notmatch '\.png$' -and $src -match 'image-bridge') {
            $null = $imageList.Add([pscustomobject]@{ src = $src })
        }
    }
    return $imageList
}