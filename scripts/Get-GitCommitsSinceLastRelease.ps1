<#
.SYNOPSIS
  Επιστρέφει τα commit messages μεταξύ των δύο πιο πρόσφατων git tags (ή από τελευταίο tag έως HEAD).

.DESCRIPTION
  Εξάγει τα commit messages που έγιναν μεταξύ των δύο τελευταίων git tags, ή μεταξύ τελευταίου tag και HEAD αν ζητηθεί.
  Χρήσιμο για changelog automation, audit, release notes, integration με άλλα helpers.

.PARAMETER From
  Αρχικό git ref (tag/commit). Προεπιλογή: αυτόματα το προ-τελευταίο tag.

.PARAMETER To
  Τελικό git ref (tag/commit). Προεπιλογή: το τελευταίο git tag. Για HEAD δώσε -To HEAD.

.EXAMPLE
  # Commits από προ-τελευταίο tag μέχρι τελευταίο tag:
  ./scripts/Get-GitCommitsSinceLastRelease.ps1

  # Commits από τελευταίο tag μέχρι HEAD:
  ./scripts/Get-GitCommitsSinceLastRelease.ps1 -To HEAD

  # Commits μεταξύ δύο συγκεκριμένων tags:
  ./scripts/Get-GitCommitsSinceLastRelease.ps1 -From v1.0.0 -To v1.0.2
#>
[CmdletBinding()]
param(
    [string]$From,
    [string]$To
)

# Πάρε όλα τα tags με σειρά δημιουργίας
$tags = git tag --sort=creatordate | Where-Object { $_ }

if (-not $tags) {
    throw 'Δεν βρέθηκαν git tags στο repository.'
}

# Ορισμός default refs αν δεν δοθούν
if (-not $From -and $tags.Count -ge 2) {
    $From = $tags[$tags.Count - 2]
} elseif (-not $From -and $tags.Count -eq 1) {
    Write-Verbose 'Μόνο ένα tag. Θα χρησιμοποιηθεί το αρχικό commit ως From.'
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

$messages = git log "$From..$To" --pretty=format:"%s" | Where-Object { $_.Trim() }
$messages