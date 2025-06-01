[CmdletBinding()]
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

.EXAMPLE
./Update-ReleaseChangeLog.ps1 -Version 1.0.21 -IncludeMergeCommits

.NOTES
Δημιουργεί το αρχείο changelog_updated.flag με 'true' ή 'false'.
#>
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [switch]$IncludeMergeCommits
)

$ErrorActionPreference = 'Stop'

# Helper function για αρχικοποίηση CHANGELOG
function Initialize-ChangelogIfNeeded {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ChangelogPath
    )

    $initialized = $false

    # Check if file exists
    if (-not (Test-Path $ChangelogPath)) {
        Write-Verbose "📝 Creating new CHANGELOG.md file"
        $initialized = $true
    }
    else {
        # Check if file is essentially empty
        $content = Get-Content $ChangelogPath -Raw
        if ([string]::IsNullOrWhiteSpace($content) -or $content.Length -lt 100) {
            Write-Verbose "⚠️ CHANGELOG.md is empty, initializing with header"
            $initialized = $true
        }
    }

    if ($initialized) {
        $header = @'
# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

'@

        $setContentSplat = @{
            Path     = $ChangelogPath
            Value    = $header
            Encoding = 'UTF8'
            Force    = $true
        }
        Set-Content @setContentSplat
        Write-Verbose "✅ CHANGELOG.md initialized with header"
    }

    return $initialized
}

# Main script logic
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$changelogPath = Join-Path -Path $scriptRoot -ChildPath ".." -AdditionalChildPath "CHANGELOG.md" | Resolve-Path -ErrorAction SilentlyContinue

# If path doesn't resolve, create it
if (-not $changelogPath) {
    $changelogPath = Join-Path -Path $scriptRoot -ChildPath '..' -AdditionalChildPath 'CHANGELOG.md'
}

Write-Verbose "📂 Script root: $scriptRoot"
Write-Verbose "📄 Changelog path: $changelogPath"

# Βήμα 1: Αρχικοποίηση changelog αν χρειάζεται
$wasInitialized = Initialize-ChangelogIfNeeded -ChangelogPath $changelogPath -Verbose

# Βήμα 2: Έλεγχος για existing version
if (-not $wasInitialized) {
    $changelogContent = Get-Content $changelogPath -Raw -ErrorAction SilentlyContinue
    if ($changelogContent -match "## \[$Version\]") {
        Write-Warning "Η έκδοση [$Version] υπάρχει ήδη στο CHANGELOG.md. Δε θα προστεθεί ξανά."
        'false' | Set-Content './changelog_updated.flag'
        exit 0
    }
}

# Βήμα 3: Έλεγχος ύπαρξης απαιτούμενων scripts
$requiredScripts = @(
    'Get-GitCommitsSinceLastRelease.ps1',
    'Convert-GreekChangelogCommitsToSections.ps1',
    'Update-Changelog.ps1'
)

foreach ($script in $requiredScripts) {
    $scriptPath = Join-Path $scriptRoot $script
    if (-not (Test-Path $scriptPath)) {
        Write-Error "Required script not found: $scriptPath"
        'false' | Set-Content './changelog_updated.flag'
        exit 1
    }
}

# Βήμα 4: Λήψη commits
Write-Verbose "🔍 Getting commits since last release..."

$commitArgs = @{
    To                  = 'HEAD'
    ExcludeHousekeeping = $true
}

if ($IncludeMergeCommits) {
    $commitArgs.IncludeMergeCommits = $true
}

try {
    $commits = & "$scriptRoot\Get-GitCommitsSinceLastRelease.ps1" @commitArgs

    # Έλεγχος για νέα commits
    if (-not $commits -or $commits.Count -eq 0) {
        Write-Verbose "📭 No new commits since last release."
        'false' | Set-Content './changelog_updated.flag'
        exit 0
    }

    Write-Verbose "✅ Found $($commits.Count) new commits"

} catch {
    Write-Error "Failed to get commits: $_"
    'false' | Set-Content './changelog_updated.flag'
    exit 1
}

# Βήμα 5: Επεξεργασία commits σε sections
Write-Verbose "📊 Converting commits to changelog sections..."

try {
    $sections = & "$scriptRoot\Convert-GreekChangelogCommitsToSections.ps1" -Commits $commits
} catch {
    Write-Error "Failed to convert commits to sections: $_"
    'false' | Set-Content './changelog_updated.flag'
    exit 1
}

# Βήμα 6: Ενημέρωση CHANGELOG
Write-Verbose "📝 Updating CHANGELOG.md..."

try {
    $updateArgs = @{
        ChangelogPath = $changelogPath
        Version       = $Version
    }

    # Προσθήκη sections αν υπάρχουν
    if ($sections.'Προστέθηκαν' -and $sections.'Προστέθηκαν'.Count -gt 0) {
        $updateArgs.Added = $sections.'Προστέθηκαν'
    }
    if ($sections.'Αλλαγές' -and $sections.'Αλλαγές'.Count -gt 0) {
        $updateArgs.Changed = $sections.'Αλλαγές'
    }
    if ($sections.'Υποψήφια προς απόσυρση' -and $sections.'Υποψήφια προς απόσυρση'.Count -gt 0) {
        $updateArgs.Deprecated = $sections.'Υποψήφια προς απόσυρση'
    }
    if ($sections.'Αφαιρέθηκαν' -and $sections.'Αφαιρέθηκαν'.Count -gt 0) {
        $updateArgs.Removed = $sections.'Αφαιρέθηκαν'
    }
    if ($sections.'Διορθώθηκαν' -and $sections.'Διορθώθηκαν'.Count -gt 0) {
        $updateArgs.Fixed = $sections.'Διορθώθηκαν'
    }
    if ($sections.'Ασφάλεια' -and $sections.'Ασφάλεια'.Count -gt 0) {
        $updateArgs.Security = $sections.'Ασφάλεια'
    }
    if ($sections.'Τεκμηρίωση' -and $sections.'Τεκμηρίωση'.Count -gt 0) {
        $updateArgs.Documentation = $sections.'Τεκμηρίωση'
    }

    & "$scriptRoot\Update-Changelog.ps1" @updateArgs

} catch {
    Write-Error "Failed to update changelog: $_"
    'false' | Set-Content './changelog_updated.flag'
    exit 1
}

# Βήμα 7: Set success flag
'true' | Set-Content './changelog_updated.flag'
Write-Verbose "✅ CHANGELOG.md updated for version $Version."

# Display summary
if ($VerbosePreference -eq 'Continue') {
    Write-Verbose "`n📊 Summary:"
    Write-Verbose "  - Version: $Version"
    Write-Verbose "  - Commits processed: $($commits.Count)"
    Write-Verbose "  - Changelog updated: true"
}