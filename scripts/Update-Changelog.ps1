<#
.SYNOPSIS
    Ενημερώνει το CHANGELOG.md με νέα έκδοση και αλλαγές, ακολουθώντας το πρότυπο "Keep a Changelog".

.DESCRIPTION
    Το script προσθέτει μια νέα καταχώρηση έκδοσης στο CHANGELOG.md, διατηρώντας το αρχικό header.
    Υποστηρίζει όλα τα βασικά sections (Προστέθηκαν, Αλλαγές, Υποψήφια προς απόσυρση, Αφαιρέθηκαν, Διορθώθηκαν, Ασφάλεια, Τεκμηρίωση).
    Δεν προσθέτει άδεια sections και τοποθετεί κάθε λίστα κάτω από το αντίστοιχο header με σωστό newline.

.PARAMETER ChangelogPath
    Η διαδρομή προς το CHANGELOG.md.

.PARAMETER Version
    Η έκδοση (π.χ. "1.0.2").

.PARAMETER Added
    Νέες λειτουργίες (array).

.PARAMETER Changed
    Τροποποιήσεις υπαρχουσών λειτουργιών (array).

.PARAMETER Deprecated
    Υποψήφιες προς απόσυρση λειτουργίες (array).

.PARAMETER Removed
    Αφαιρεθείσες λειτουργίες (array).

.PARAMETER Fixed
    Διορθώσεις σφαλμάτων (array).

.PARAMETER Security
    Αλλαγές ασφαλείας (array).

.PARAMETER Documentation
    Αλλαγές τεκμηρίωσης (array).

.PARAMETER Date
    Ημερομηνία έκδοσης (προεπιλογή: σήμερα).

.EXAMPLE
    .\Update-Changelog.ps1 `
        -ChangelogPath './CHANGELOG.md' `
        -Version '1.0.2' `
        -Added @('Νέο cmdlet για ειδοποίηση μέσω email') `
        -Fixed @('Διορθώθηκε bug με το push notification')
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]$ChangelogPath,

    [Parameter(Mandatory)]
    [string]$Version,

    [Parameter()]
    [string[]]$Added,

    [Parameter()]
    [string[]]$Changed,

    [Parameter()]
    [string[]]$Deprecated,

    [Parameter()]
    [string[]]$Removed,

    [Parameter()]
    [string[]]$Fixed,

    [Parameter()]
    [string[]]$Security,

    [Parameter()]
    [string[]]$Documentation,

    [Parameter()]
    [datetime]$Date = (Get-Date)
)

# Αντιστοίχιση section key -> ελληνικός τίτλος με emojis, σειρά εμφάνισης
$sectionTitles = @{
    Added         = '✨ Προστέθηκαν'
    Changed       = '🔄 Αλλαγές'
    Deprecated    = '⚠️ Υποψήφια προς απόσυρση'
    Removed       = '❌ Αφαιρέθηκαν'
    Fixed         = '🐛 Διορθώθηκαν'
    Security      = '🔒 Ασφάλεια'
    Documentation = '📝 Τεκμηρίωση'
}

$sections = @(
    @{ Key = 'Added'; Items = $Added },
    @{ Key = 'Changed'; Items = $Changed },
    @{ Key = 'Deprecated'; Items = $Deprecated },
    @{ Key = 'Removed'; Items = $Removed },
    @{ Key = 'Fixed'; Items = $Fixed },
    @{ Key = 'Security'; Items = $Security },
    @{ Key = 'Documentation'; Items = $Documentation }
)

# Διαβάζουμε το changelog ως raw string
if (-not (Test-Path $ChangelogPath)) {
    throw "Το αρχείο '$ChangelogPath' δεν βρέθηκε."
}
$changelog = Get-Content $ChangelogPath -Raw

# Εντοπισμός header (μέχρι και το Semantic Versioning)
$headerRegex = '# Αρχείο Αλλαγών.*?Semantic Versioning.*?(\r?\n){2,}'
$headerMatch = [regex]::Match($changelog, $headerRegex, 'Singleline')
if (-not $headerMatch.Success) {
    throw "Δεν βρέθηκε το header στο changelog. Βεβαιώσου ότι ξεκινά με '# Αρχείο Αλλαγών' και αναφέρεται το Semantic Versioning."
}
$header = $headerMatch.Value
$body = $changelog.Substring($header.Length)

# Δημιουργία νέου entry
$newEntry = "## [$Version] - $($Date.ToString('yyyy-MM-dd'))`r`n"
foreach ($section in $sections) {
    $items = $section.Items | Where-Object { $_ -and $_.Trim() -ne '' }
    if ($items.Count -gt 0) {
        $title = $sectionTitles[$section.Key]
        $newEntry += "`r`n### $title`r`n`r`n"
        foreach ($item in $items) {
            $newEntry += "- $item`r`n"
        }
    }
}
$newEntry += "`r`n"

# Συνένωση τελικού changelog
$finalChangelog = "$header$newEntry$body"

# Εγγραφή στο αρχείο
Set-Content -Path $ChangelogPath -Value $finalChangelog -Encoding UTF8

Write-Verbose "Το CHANGELOG.md ενημερώθηκε με επιτυχία για την έκδοση $Version."