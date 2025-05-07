<#
.SYNOPSIS
  Επιστρέφει commit messages μεταξύ δύο git refs (tags ή commits) με επιλογές για φιλτράρισμα.

.DESCRIPTION
  Χρήσιμο helper για αυτοματοποιημένο changelog. Υποστηρίζει:
    - Εξαίρεση bump version commits
    - Εξαίρεση merge commits (by default)
    - Καθορισμένο range μεταξύ tags ή commits

.PARAMETER From
  Αρχικό git ref (tag/commit). Default: προτελευταίο tag.

.PARAMETER To
  Τελικό git ref (tag/commit). Default: τελευταίο tag (ή HEAD αν ζητηθεί).

.PARAMETER ExcludeBumpCommits
  Αν ενεργοποιηθεί, εξαιρεί commits που ξεκινούν με "Bump version to ...".

.PARAMETER IncludeMergeCommits
  Αν **δεν** ενεργοποιηθεί, merge commits αγνοούνται (default συμπεριφορά).

.EXAMPLE
  ./Get-GitCommitsSinceLastRelease.ps1 -To HEAD -ExcludeBumpCommits

.EXAMPLE
  ./Get-GitCommitsSinceLastRelease.ps1 -From v1.0.0 -To v1.0.3 -IncludeMergeCommits
#>
[CmdletBinding()]
param(
  [string]$From,
  [string]$To,
  [switch]$ExcludeBumpCommits,
  [switch]$IncludeMergeCommits
)

# 1. Συλλογή tags
$tags    = git tag --sort    = creatordate | Where-Object { $_ }

if (-not $tags) {
  throw 'Δεν βρέθηκαν git tags στο repository.'
}

# 2. Προσδιορισμός From/To
if (-not $From -and $tags.Count -ge 2) {
  $From = $tags[$tags.Count - 2]
} elseif (-not $From -and $tags.Count -eq 1) {
  Write-Verbose 'Μόνο ένα tag. Χρησιμοποιείται το αρχικό commit ως From.'
  $From = (git rev-list --max-parents=0 HEAD).Trim()
}

if (-not $To) {
  $To = $tags[-1]
}

if ($From -eq $To) {
  Write-Host "From και To refs είναι ίδια ($From). Δεν υπάρχουν νέα commits."
  return @()
}

Write-Host "Λαμβάνονται commits από '$From' έως '$To'..." -ForegroundColor Cyan

# 3. Σύνθεση git log arguments
$gitArgs = @("$From..$To", '--pretty=format:%s')

if (-not $IncludeMergeCommits) {
  $gitArgs += '--no-merges'
}
if ($ExcludeBumpCommits) {
  $gitArgs += @('--invert-grep', '--grep=^Bump version to [0-9]\+\.[0-9]\+\.[0-9]\+')
}

# 4. Εκτέλεση και καθαρισμός
$messages = git log @gitArgs | Where-Object { $_.Trim() }
$messages
