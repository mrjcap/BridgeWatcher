<#
.SYNOPSIS
    Ενημερώνει το CHANGELOG.md, κάνει commit σε νέο branch και ανοίγει αυτόματο Pull Request μέσω GitHub Actions.

.DESCRIPTION
    - Εντοπίζει το version δυναμικά από το CHANGELOG.md.
    - Δημιουργεί νέο branch με βάση το version και το timestamp.
    - Κάνει commit/προσθήκη αλλαγών και τα σπρώχνει στο remote branch.
    - Ανοίγει αυτόματο PR προς main μέσω gh cli.
    - Υποστηρίζει τρεξίματα μόνο αν υπάρχουν αλλαγές στο CHANGELOG.

.PARAMETER ChangelogPath
    Το path του CHANGELOG.md (default: ./CHANGELOG.md).

.EXAMPLE
    .\Update-ChangelogAndCreatePR.ps1
#>

[CmdletBinding()]
param(
    [string]$ChangelogPath = ".\CHANGELOG.md"
)

function Get-VersionFromChangelog {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)]
        [string]$Path
    )
    process {
        if (-not (Test-Path $Path)) {
            throw "File not found: $Path"
        }
        $line = Get-Content -Path $Path | Select-String -Pattern '^##\s*\[\s*v?([0-9]+\.[0-9]+\.[0-9]+)\s*\]' | Select-Object -First 1
        if ($line -and $line.Matches.Count -gt 0) {
            return $line.Matches[0].Groups[1].Value
        } else {
            throw "Δεν βρέθηκε έκδοση στην αρχή του $Path"
        }
    }
}

try {
    $Version = Get-VersionFromChangelog -Path $ChangelogPath
} catch {
    Write-Error $_.Exception.Message
    exit 1
}

if (-not $Version) { throw "Δεν βρέθηκε έκδοση στο $ChangelogPath" }

$Branch = "changelog/update-v$Version-$(Get-Date -UFormat %s)"

# Config git user για CI
git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

# Ελέγχει αν έχει αλλαγές
if (git status --porcelain $ChangelogPath) {
    git checkout -b $Branch
    git add $ChangelogPath
    git commit -m "docs: auto-update CHANGELOG.md για έκδοση v$Version"
    git push origin $Branch

    # Δημιουργία PR με το GitHub CLI
    gh pr create --title "docs: auto-update CHANGELOG.md για v$Version" `
        --body "Αυτόματο update από CI" --base main --head $Branch --label auto-changelog

    "changelog_updated=true" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
    Write-Verbose "✅ Δημιουργήθηκε Pull Request για το v$Version."
} else {
    Write-Verbose "Δεν υπάρχουν αλλαγές στο CHANGELOG.md"
    "changelog_updated=false" | Out-File -FilePath $env:GITHUB_OUTPUT -Append
}