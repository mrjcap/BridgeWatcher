<#
.SYNOPSIS
  Επιστρέφει commit messages μεταξύ δύο git refs (tags ή commits), με έμφαση σε user-facing αλλαγές (καθαρό changelog).

.DESCRIPTION
  Χρήσιμο helper για αυτοματοποιημένο changelog. Υποστηρίζει:
    Εξαίρεση housekeeping/CI/τεχνικών commits (προεπιλογή)
    Εξαίρεση merge commits (προεπιλογή)
    Καθορισμένο range μεταξύ tags ή commits
    Αναγνώριση From/To refs με έξυπνη προεπιλογή

.PARAMETER From
  Αρχικό git ref (tag/commit). Προεπιλογή: το τελευταίο tag στο current branch.

.PARAMETER To
  Τελικό git ref (tag/commit). Προεπιλογή: HEAD.

.PARAMETER ExcludeHousekeeping
  Εξαιρεί commits που ξεκινούν με housekeeping/CI prefixes (προεπιλογή: $true).

.PARAMETER IncludeMergeCommits
  Περιλαμβάνει merge commits αν ενεργοποιηθεί (προεπιλογή: $false).

.EXAMPLE
  ./Get-GitCommitsSinceLastRelease.ps1 -To HEAD -ExcludeHousekeeping

.EXAMPLE
  ./Get-GitCommitsSinceLastRelease.ps1 -From v1.0.0 -To v1.0.3 -IncludeMergeCommits

.LINK
  https://keepachangelog.com/
  https://www.conventionalcommits.org/
  https://git-scm.com/docs/git-log
#>
[CmdletBinding()]
param(
  [string]$From,
  [string]$To = 'HEAD',
  [switch]$ExcludeHousekeeping,
  [switch]$IncludeMergeCommits
)

function Get-LatestTagOnCurrentBranch {
  # Επιστρέφει το τελευταίο tag στο current branch (όχι απλά το τελευταίο tag by date)
  $tag = git describe --tags --abbrev=0 2>$null
  if (-not $tag) {
    Write-Verbose 'Δεν βρέθηκαν tags στο current branch. Επιστροφή πρώτου commit.'
    return (git rev-list --max-parents=0 HEAD).Trim()
  }
  return $tag
}

# 1. Προσδιορισμός From/To refs
if (-not $From) {
  $From = Get-LatestTagOnCurrentBranch
}
if (-not $To) {
  $To = 'HEAD'
}

if ($From -eq $To) {
  Write-Verbose "From και To refs είναι ίδια ($From). Δεν υπάρχουν νέα commits."
  return @()
}

Write-Verbose "Λαμβάνονται commits από '$From' έως '$To'..."

# 2. Σύνθεση git log arguments
$gitArgs = @("$From..$To", '--pretty=format:%s')
if (-not $IncludeMergeCommits) { $gitArgs += '--no-merges' }

if ($ExcludeHousekeeping) {
  # Εξαίρεση housekeeping/CI/τεχνικών commits με approved patterns
  $gitArgs += @(
    '--invert-grep',
    '--grep=^(chore:|chore\(|fix:|fix\(|ci:|ci\(|docs:|build:|test:|refactor:|perf:|Ενημέρωση|Προσθήκη συγχρονισμού)',
    '--extended-regexp'
  )
}

# 3. Εκτέλεση git log και καθαρισμός αποτελεσμάτων
try {
  $messages = git log @gitArgs | Where-Object { $_.Trim() }
  if ($messages) {
    $messages
  } else {
    Write-Verbose 'Δεν βρέθηκαν user-facing commits στο επιλεγμένο range.'
  }
} catch {
  Write-Error "Σφάλμα εκτέλεσης git log: $_"
  throw
}