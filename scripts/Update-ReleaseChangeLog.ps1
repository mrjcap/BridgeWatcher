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
            Encoding = 'utf8BOM'
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
    'Manage-Changelog.ps1'
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

# Βρίσκουμε το προηγούμενο tag για την version που δημιουργούμε
$tagOutput = git tag --sort=version:refname 2>$null
$tags = @($tagOutput | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
$versionTag = "v$Version"
$previousTag = $null

if ($tags -and $tags.Count -gt 0) {
    # Βρίσκουμε το προηγούμενο tag από την version που δημιουργούμε
    $currentIndex = [array]::IndexOf($tags, $versionTag)
    if ($currentIndex -gt 0) {
        $previousTag = $tags[$currentIndex - 1]
    } elseif ($currentIndex -eq -1) {
        # Αν η version δεν υπάρχει ακόμα, παίρνουμε το τελευταίο tag
        $previousTag = $tags[-1]
    }
}

Write-Verbose "🏷️ Previous tag: $(if ($previousTag) { $previousTag } else { 'None' })"
Write-Verbose "🎯 Target version: $versionTag"

$commitArgs = @{
    To                  = 'HEAD'
    ExcludeHousekeeping = $true
}

# Ορίζουμε το From ref βάσει του προηγούμενου tag
if ($previousTag) {
    $commitArgs.From = $previousTag
    Write-Verbose "📍 Getting commits from $previousTag to HEAD"
} else {
    Write-Verbose "📍 Getting all commits (no previous tags found)"
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
    $sectionsObject = & "$scriptRoot\Convert-GreekChangelogCommitsToSections.ps1" -Commits $commits
    $sections = @{}
    if ($sectionsObject) {
        $sectionsObject.PSObject.Properties | ForEach-Object {
            $sections[$_.Name] = $_.Value
        }
    }

    $defaultSections = @{
        'Προστέθηκαν'            = @()
        'Αλλαγές'                = @()
        'Υποψήφια προς απόσυρση' = @()
        'Αφαιρέθηκαν'            = @()
        'Διορθώθηκαν'            = @()
        'Ασφάλεια'               = @()
        'Τεκμηρίωση'             = @()
    }

    foreach ($key in $defaultSections.Keys) {
        if (-not $sections.ContainsKey($key) -or -not $sections[$key]) {
            $sections[$key] = @()
    }

} catch {
    Write-Error "Failed to convert commits to sections: $_"
    'false' | Set-Content './changelog_updated.flag'
    exit 1
}

# Βήμα 6: Ενημέρωση CHANGELOG
Write-Verbose "📝 Updating CHANGELOG.md..."

try {
    $updateArgs = @{
        Version       = $Version
        Action        = 'Update'
        ChangelogPath = $changelogPath
        Added         = if ($sections['Προστέθηκαν']) { $sections['Προστέθηκαν'] } else { @() }
        Changed       = if ($sections['Αλλαγές']) { $sections['Αλλαγές'] } else { @() }
        Deprecated    = if ($sections['Υποψήφια προς απόσυρση']) { $sections['Υποψήφια προς απόσυρση'] } else { @() }
        Removed       = if ($sections['Αφαιρέθηκαν']) { $sections['Αφαιρέθηκαν'] } else { @() }
        Fixed         = if ($sections['Διορθώθηκαν']) { $sections['Διορθώθηκαν'] } else { @() }
        Security      = if ($sections['Ασφάλεια']) { $sections['Ασφάλεια'] } else { @() }
        Documentation = if ($sections['Τεκμηρίωση']) { $sections['Τεκμηρίωση'] } else { @() }
    }

    & "$scriptRoot\Manage-Changelog.ps1" @updateArgs

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