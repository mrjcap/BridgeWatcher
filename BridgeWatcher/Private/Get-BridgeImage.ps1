function Get-BridgeImage {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Εξάγει όλα τα links εικόνων από HTML περιεχόμενο.

    .DESCRIPTION
    Η Get-BridgeImage αναλύει HTML δεδομένα και επιστρέφει αντικείμενα
    με τα links εικόνων που σχετίζονται με την κατάσταση γέφυρας.

    .PARAMETER HtmlContent
    Το HTML περιεχόμενο της σελίδας ως string.

    .PARAMETER Location
    Η τοποθεσία της γέφυρας ('poseidonia' ή 'isthmia').

    .OUTPUTS
    [System.Collections.ArrayList] - Λίστα από αντικείμενα εικόνων με property 'src'.

    .EXAMPLE
    Get-BridgeImage -HtmlContent $html -Location 'isthmia'

    .NOTES
    Η ανάλυση βασίζεται σε regex για ανεύρεση εικόνων.
    Φιλτράρει μόνο εικόνες που περιέχουν 'image-bridge' στο URL.
    #>

    [OutputType([System.Collections.ArrayList])]
    param (        [Parameter(Mandatory)][string]$HtmlContent,
        [Parameter(Mandatory)][ValidateSet('poseidonia', 'isthmia')] [string]$Location,

        [Parameter()]
        [PSCustomObject]$Configuration = (New-BridgeConfiguration)
    )
    $bridgeLabel = if ($Configuration -and $Configuration.BridgeNames -and $Configuration.BridgeNames[$Location]) {
        $Configuration.BridgeNames[$Location].ToUpper()
    } else {
        # Fallback to hardcoded values
        switch ($Location) {
            'poseidonia' { 'ΠΟΣΕΙΔΩΝΙΑ' }
            'isthmia' { 'ΙΣΘΜΙΑ' } }
    }

    $blocks = $HtmlContent -split '(?i)<div[^>]*class="[^"]*panel panel-primary[^"]*"[^>]*>'
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
    $bmatches = [regex]::Matches($block, '(?i)<img[^>]+src\s*=\s*["'']([^"'']+)["'']')
    $imageList = $bmatches | Where-Object {
        $_.Groups[1].Value -notmatch '\.png$' -and $_.Groups[1].Value -match 'image-bridge'
    } | ForEach-Object {
        [pscustomobject]@{ src = $_.Groups[1].Value }
    }
    return [System.Collections.ArrayList]::new([object[]]@($imageList))
}
