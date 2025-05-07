<#
.SYNOPSIS
  Αυτόματο update CHANGELOG.md με based-on-commits sections.

.DESCRIPTION
  Παίρνει commits από το προηγούμενο release, τα ταξινομεί σε sections, ενημερώνει το CHANGELOG.md.
  Προσαρμοσμένο για workflows/GitHub Actions/CI.

.PARAMETER Version
  Η νέα έκδοση που θα περαστεί στο CHANGELOG.

.PARAMETER IncludeMergeCommits
  Αν ενεργοποιηθεί, περιλαμβάνονται και merge commits στο changelog.

.EXAMPLE
  ./Update-ReleaseChangeLog.ps1 -Version 1.0.20
  ./Update-ReleaseChangeLog.ps1 -Version 1.0.21 -IncludeMergeCommits
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory)]
  [string]$Version,

  [switch]$IncludeMergeCommits
)

$scriptRoot    = Split-Path -Parent $MyInvocation.MyCommand.Path

# 🔹 Εξαγωγή commits με optional switches
$commitArgs = @{
  To                    = 'HEAD'
  ExcludeBumpCommits    = $true
}
if ($IncludeMergeCommits) {
  $commitArgs.IncludeMergeCommits    = $true
}
$commits    = & "$scriptRoot\Get-GitCommitsSinceLastRelease.ps1" @commitArgs
# 🔹 Αν δεν υπάρχουν commits, exit
if (-not $commits -or $commits.Count -eq 0) {
  Write-Host 'No new commits since last release.'
  exit 0
}
# Έλεγχος αν η έκδοση υπάρχει ήδη στο CHANGELOG.md
$changelogPath    = "$PSScriptRoot\..\CHANGELOG.md"
if (Get-Content $changelogPath | Select-String "## \[$Version\]") {
  Write-Warning "Η έκδοση [$Version] υπάρχει ήδη στο CHANGELOG.md. Δε θα προστεθεί ξανά."
  exit 0
}
# 🔹 Μετατροπή σε sections
$sections    = & "$scriptRoot\Convert-GreekChangelogCommitsToSections.ps1" -Commits $commits

# 🔹 Ενημέρωση CHANGELOG
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

Write-Host "CHANGELOG.md updated for version $Version." -ForegroundColor Green
