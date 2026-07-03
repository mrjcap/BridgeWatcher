function Get-BridgeImage {
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

    .EXAMPLE
    Get-BridgeImage -HtmlContent $html -Location 'isthmia'

    .NOTES
    Η ανάλυση βασίζεται σε κανονικές εκφράσεις (regex) για την εύρεση εικόνων.
    Φιλτράρει μόνο τις εικόνες που περιέχουν 'image-bridge' στο URL.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.ArrayList])]
    param (
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$HtmlContent,
        [Parameter(Mandatory)][ValidateNotNullOrEmpty()][ValidateSet('poseidonia', 'isthmia')] [string]$Location
    )
    # Αφαίρεση τόνων από το μοτίβο (pattern) για αντιστοίχιση τόσο τονισμένου όσο και ατόνιστου ελληνικού κειμένου
    $bridgePattern = if ($Location -eq 'poseidonia') { 'Ποσειδων[ιίΙΊ]α' } else { 'Ισθμ[ιίΙΊ]α' }

    # Διαχωρισμός με χρήση ανθεκτικού regex για χειρισμό μη ευαισθησίας πεζών-κεφαλαίων, μονών/διπλών εισαγωγικών και μεταβλητών κενών/κλάσεων
    $blocks = [regex]::Split($HtmlContent, '(?i)<div[^>]+class=["''][^"'']*panel\s+panel-primary[^"'']*["''][^>]*>')

    # Αντιστοίχιση μπλοκ (block) χωρίς ευαισθησία πεζών-κεφαλαίων με βάση το μοτίβο της γέφυρας
    $block = $blocks | Where-Object { $_ -match "(?i)$bridgePattern" }
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
    # Αντιστοίχιση ετικετών img χωρίς ευαισθησία πεζών-κεφαλαίων, με μονά/διπλά εισαγωγικά και αυθαίρετη σειρά του src
    $bmatches = [regex]::Matches($block, '(?i)<img[^>]+src=["'']([^"'']+)["'']')
    $imageList = [System.Collections.ArrayList]::new()
    foreach ($m in $bmatches) {
        $src = $m.Groups[1].Value
        if ($src -notmatch '\.png$' -and $src -match 'image-bridge') {
            $null = $imageList.Add([pscustomobject]@{ src = $src })
        }
    }
    return [System.Collections.ArrayList]::new([object[]]@($imageList))
}

