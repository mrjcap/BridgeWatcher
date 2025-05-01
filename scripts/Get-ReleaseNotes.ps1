<#
.SYNOPSIS
  Εξάγει το changelog section για συγκεκριμένη έκδοση από το CHANGELOG.md.

.DESCRIPTION
  Διαβάζει το CHANGELOG.md και επιστρέφει το section για το δοσμένο version tag (π.χ. v1.0.22).
  Επιστρέφει κενό ή μήνυμα αν δεν βρεθεί section.

.PARAMETER Version
  Το version tag (π.χ. v1.0.22) που θέλεις να εξάγεις.

.PARAMETER Path
  Προαιρετικά, το path προς το CHANGELOG.md (default: ./CHANGELOG.md)

.EXAMPLE
  .\scripts\Get-ReleaseNotes.ps1 -Version v1.0.22
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,
    [string]$Path = './CHANGELOG.md'
)

if (!(Test-Path $Path)) {
    throw "Το αρχείο $Path δεν βρέθηκε."
}

$changelog = Get-Content $Path -Raw
$regex = "(## $Version[^\r\n]*\r?\n(?:.*?\r?\n)*?)(?=\r?\n## |\Z)"
if ($changelog -match $regex) {
    $matches[1].Trim()
} else {
    Write-Warning "Δεν βρέθηκε changelog entry για $Version."
    ''
}