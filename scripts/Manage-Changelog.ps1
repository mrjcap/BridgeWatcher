[CmdletBinding()]
<#
.SYNOPSIS
Simplified changelog management - combines update, format, and commit functionality.

.DESCRIPTION
This script consolidates changelog operations:
- Update changelog with commits since last release
- Format changelog sections with emojis
- Create pull request for changelog updates

Replaces Update-Changelog.ps1, Update-ChangelogFormat.ps1, and Update-ChangelogAndCreatePR.ps1

.PARAMETER Version
The version for changelog update.

.PARAMETER Action
What to do: Update, Format, or CreatePR.

.PARAMETER ChangelogPath
Path to CHANGELOG.md (default: ./CHANGELOG.md).

.PARAMETER Added
Array of added features.

.PARAMETER Changed
Array of changed features.

.PARAMETER Fixed
Array of fixed issues.

.PARAMETER Removed
Array of removed features.

.PARAMETER Security
Array of security changes.

.PARAMETER Deprecated
Array of deprecated features.

.PARAMETER Documentation
Array of documentation changes.

.EXAMPLE
.\Manage-Changelog.ps1 -Version "1.0.5" -Action Update

.EXAMPLE
.\Manage-Changelog.ps1 -Action Format

.EXAMPLE
.\Manage-Changelog.ps1 -Version "1.0.5" -Action CreatePR
#>
param(
    [Parameter()]
    [string]$Version,

    [Parameter(Mandatory)]
    [ValidateSet('Update', 'Format', 'CreatePR')]
    [string]$Action,

    [Parameter()]
    [string]$ChangelogPath = './CHANGELOG.md',

    [Parameter()]
    [string[]]$Added,

    [Parameter()]
    [string[]]$Changed,

    [Parameter()]
    [string[]]$Fixed,

    [Parameter()]
    [string[]]$Removed,

    [Parameter()]
    [string[]]$Security,

    [Parameter()]
    [string[]]$Deprecated,

    [Parameter()]
    [string[]]$Documentation
)

switch ($Action) {
    'Update' {
        if (-not $Version) {
            throw "Version required for Update action"
        }

        # Check if version already exists in changelog
        $existingChangelog = Get-Content $ChangelogPath -Raw -ErrorAction SilentlyContinue
        if ($existingChangelog -and $existingChangelog -match "## \[$([regex]::Escape($Version))\]") {
            Write-Warning "Version [$Version] already exists in changelog. Skipping update."
            exit 0
        }

        # If sections are provided directly, use them; otherwise get from commits
        if ($Added -or $Changed -or $Fixed -or $Removed -or $Security -or $Deprecated -or $Documentation) {
            # Use provided sections
            Write-Verbose "Using provided changelog sections"
        } else {
            # Get commits since last release
            $commits = & "$PSScriptRoot\Get-GitCommitsSinceLastRelease.ps1" -To HEAD -ExcludeHousekeeping

            if (-not $commits -or $commits.Count -eq 0) {
                Write-Warning "No new commits found."
                exit 0
            }

            # Convert to sections
            $sections = & "$PSScriptRoot\Convert-GreekChangelogCommitsToSections.ps1" -Commits $commits

            # Map sections to parameters
            $Added = $sections.'Προστέθηκαν'
            $Changed = $sections.'Αλλαγές'
            $Fixed = $sections.'Διορθώθηκαν'
            $Removed = $sections.'Αφαιρέθηκαν'
            $Security = $sections.'Ασφάλεια'
            $Deprecated = $sections.'Υποψήφια προς απόσυρση'
            $Documentation = $sections.'Τεκμηρίωση'
        }

        # Build changelog entry
        $sectionData = @(
            @{ Title = '✨ Προστέθηκαν'; Items = $Added },
            @{ Title = '🔄 Αλλαγές'; Items = $Changed },
            @{ Title = '⚠️ Υποψήφια προς απόσυρση'; Items = $Deprecated },
            @{ Title = '❌ Αφαιρέθηκαν'; Items = $Removed },
            @{ Title = '🐛 Διορθώθηκαν'; Items = $Fixed },
            @{ Title = '🔒 Ασφάλεια'; Items = $Security },
            @{ Title = '📝 Τεκμηρίωση'; Items = $Documentation }
        )

        # Read existing changelog or create header
        if (-not (Test-Path $ChangelogPath)) {
            $header = @'
# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

'@
            $body = ""
        } else {
            $changelog = Get-Content $ChangelogPath -Raw
            # Find header end
            $headerRegex = '# Αρχείο Αλλαγών.*?Semantic Versioning.*?(\r?\n){2,}'
            $headerMatch = [regex]::Match($changelog, $headerRegex, 'Singleline')
            if ($headerMatch.Success) {
                $header = $headerMatch.Value
                $body = $changelog.Substring($header.Length)
            } else {
                $header = ""
                $body = $changelog
            }        }
        
        # Create new entry
        $Date = Get-Date
        $newEntry = "## [$Version] - $($Date.ToString('yyyy-MM-dd'))`r`n"
        
        foreach ($section in $sectionData) {
            $items = @()
            if ($section.Items) {
                $items = @($section.Items | Where-Object { $_ -and $_.Trim() -ne '' })
            }
            
            if ($items.Count -gt 0) {
                $newEntry += "`r`n### $($section.Title)`r`n`r`n"
                foreach ($item in $items) {
                    $newEntry += "- $item`r`n"
                }
            }
        }$newEntry += "`r`n"

        # Combine and save
        $finalChangelog = "$header$newEntry$body"
        Set-Content -Path $ChangelogPath -Value $finalChangelog -Encoding UTF8
        Write-Verbose "CHANGELOG.md updated for version $Version"
    }

    'Format' {
        # Basic formatting - add emojis to sections if missing
        $content = Get-Content $ChangelogPath -Raw -ErrorAction SilentlyContinue
        if (-not $content) {
            Write-Warning "Changelog not found at $ChangelogPath"
            exit 1
        }

        $emojiMap = @{
            '### Προστέθηκαν' = '### ✨ Προστέθηκαν'
            '### Αλλαγές'     = '### 🔄 Αλλαγές'
            '### Διορθώθηκαν' = '### 🐛 Διορθώθηκαν'
            '### Τεκμηρίωση'  = '### 📝 Τεκμηρίωση'
        }

        $updated = $content
        foreach ($old in $emojiMap.Keys) {
            $new = $emojiMap[$old]
            if ($updated -match [regex]::Escape($old) -and $updated -notmatch [regex]::Escape($new)) {
                $updated = $updated -replace [regex]::Escape($old), $new
                Write-Output "✅ Updated: $old -> $new"
            }
        }

        if ($updated -ne $content) {
            Set-Content -Path $ChangelogPath -Value $updated -Encoding UTF8
            Write-Output "✅ Changelog formatted successfully"
        } else {
            Write-Output "ℹ️ No formatting changes needed"
        }
    }

    'CreatePR' {
        if (-not $Version) {
            throw "Version required for CreatePR action"
        }

        $Branch = "changelog/update-v$Version-$(Get-Date -UFormat %s)"

        # Configure git for CI
        git config user.name "github-actions[bot]"
        git config user.email "41898282+github-actions[bot]@users.noreply.github.com"

        # Check if there are changes
        if (git status --porcelain $ChangelogPath) {
            git checkout -b $Branch
            git add $ChangelogPath
            git commit -m "docs: auto-update CHANGELOG.md για έκδοση v$Version"
            git push origin $Branch

            # Create PR with GitHub CLI
            gh pr create --title "docs: auto-update CHANGELOG.md για v$Version" `
                --body "Αυτόματο update από CI" --base main --head $Branch --label auto-changelog

            Write-Output "✅ Pull Request created for v$Version"
        } else {
            Write-Output "ℹ️ No changes to create PR"
        }
    }
}
