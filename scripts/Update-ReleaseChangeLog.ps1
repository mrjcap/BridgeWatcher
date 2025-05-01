<#
.SYNOPSIS
  Αυτόματο update CHANGELOG.md με based-on-commits sections.
.DESCRIPTION
  Παίρνει commits από το προηγούμενο release, τα ταξινομεί σε sections, ενημερώνει το CHANGELOG.md.
  Προσαρμοσμένο για workflows/GitHub Actions/CI.
.PARAMETER Version
  Η νέα έκδοση που θα περαστεί στο CHANGELOG.
.EXAMPLE
  ./Update-Release-Changelog.ps1 -Version 1.0.20
#>
param(
    [Parameter(Mandatory)]
    [string]$Version
)
$scriptRoot    = Split-Path -Parent $MyInvocation.MyCommand.Path
$commits = & "$ScriptRoot\Get-GitCommitsSinceLastRelease.ps1" -To HEAD
# Αν δεν υπάρχουν commits, τελειώνουμε εδώ.
if (-not $commits -or $commits.Count -eq 0) {
    Write-Host 'No new commits since last release.'
    exit 0
}
$sections = & "$scriptRoot\Convert-GreekChangelogCommitsToSections.ps1" -Commits $commits
& "$scriptRoot\Update-Changelog.ps1" `
    -ChangelogPath "$PSScriptRoot\..\CHANGELOG.md" `
    -Version $Version `
    -Added $sections.'Προστέθηκαν' `
    -Changed $sections.'Αλλαγές' `
    -Deprecated $sections.'Υποψήφια προς απόσυρση' `
    -Removed $sections.'Αφαιρέθηκαν' `
    -Fixed $sections.'Διορθώθηκαν' `
    -Security $sections.'Ασφάλεια' `
    -Documentation $sections.'Τεκμηρίωση'
Write-Host "CHANGELOG.md updated for version $Version."