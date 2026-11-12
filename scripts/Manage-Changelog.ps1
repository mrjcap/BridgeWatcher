<#
.SYNOPSIS
Updates CHANGELOG.md with categorized commit sections for a target release version.

.DESCRIPTION
Initializes CHANGELOG.md when missing or shorter than 100 characters, skips duplicate
version headers, collects commits via Get-GitCommitsSinceLastRelease.ps1 when explicit
section arrays are not supplied, categorizes commits via
Convert-GreekChangelogCommitsToSections.ps1, wraps lines to 120 characters, and writes
CHANGELOG.md encoded as UTF-8 with BOM.

.PARAMETER Version
The semantic version string to add to CHANGELOG.md (for example, 1.0.20).

.PARAMETER Action
The changelog operation to execute. Only 'Update' is supported.

.PARAMETER ChangelogPath
Path to CHANGELOG.md (default: ./CHANGELOG.md).

.PARAMETER From
Optional starting git ref (tag or commit) forwarded to Get-GitCommitsSinceLastRelease.ps1.

.PARAMETER IncludeMergeCommits
Includes merge commits when collecting git history.

.PARAMETER UpdatedFlagPath
Optional path to a flag file where 'true' or 'false' is written to indicate whether
CHANGELOG.md was modified.

.PARAMETER Feat
Feature entries for the release.

.PARAMETER Fix
Bug fix entries for the release.

.PARAMETER Refactor
Refactoring entries for the release.

.PARAMETER Docs
Documentation entries for the release.

.PARAMETER Ci
Continuous integration entries for the release.

.PARAMETER Build
Build system entries for the release.

.PARAMETER Test
Test suite entries for the release.

.PARAMETER Chore
Maintenance entries for the release.

.PARAMETER Style
Style and formatting entries for the release.

.PARAMETER Perf
Performance entries for the release.

.PARAMETER Revert
Reverted change entries for the release.

.PARAMETER Other
Uncategorized entries for the release.

.EXAMPLE
.\Manage-Changelog.ps1 -Version '1.0.20' -Action Update

.EXAMPLE
.\Manage-Changelog.ps1 -Version '1.0.21' -Action Update -From 'v1.0.20' -IncludeMergeCommits
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [Parameter()]
    [ValidateSet('Update')]
    [string]$Action = 'Update',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ChangelogPath = './CHANGELOG.md',

    [Parameter()]
    [string]$From,

    [Parameter()]
    [switch]$IncludeMergeCommits,

    [Parameter()]
    [string]$UpdatedFlagPath,

    [Parameter()]
    [string[]]$Feat,

    [Parameter()]
    [string[]]$Fix,

    [Parameter()]
    [string[]]$Refactor,

    [Parameter()]
    [string[]]$Docs,

    [Parameter()]
    [string[]]$Ci,

    [Parameter()]
    [string[]]$Build,

    [Parameter()]
    [string[]]$Test,

    [Parameter()]
    [string[]]$Chore,

    [Parameter()]
    [string[]]$Style,

    [Parameter()]
    [string[]]$Perf,

    [Parameter()]
    [string[]]$Revert,

    [Parameter()]
    [string[]]$Other
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Write-ChangelogUpdatedFlag {
    <#
    .SYNOPSIS
    Writes the boolean update status to the optional flag file.
    #>
    param(
        [string]$Path,
        [bool]$Updated
    )

    if (-not [string]::IsNullOrWhiteSpace($Path)) {
        $flagValue = if ($Updated) { 'true' } else { 'false' }
        Set-Content -Path $Path -Value $flagValue -Encoding utf8
    }
}

function Initialize-ChangelogFile {
    <#
    .SYNOPSIS
    Ensures CHANGELOG.md exists and contains the standard Greek Keep-a-Changelog header.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Path
    )

    $needsInit = $false
    if (-not (Test-Path -Path $Path)) {
        Write-Verbose 'Creating new CHANGELOG.md file'
        $needsInit = $true
    } else {
        $raw = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($raw) -or $raw.Length -lt 100) {
            Write-Verbose 'CHANGELOG.md is empty or shorter than 100 chars; initializing header'
            $needsInit = $true
        }
    }

    if ($needsInit) {
        $header = @'
# Αρχείο Αλλαγών (Changelog)

Όλες οι σημαντικές αλλαγές σε αυτό το έργο θα καταγράφονται σε αυτό το αρχείο.

Η μορφή βασίζεται στο [Keep a Changelog](https://keepachangelog.com/el/1.1.0/),
και το έργο αυτό ακολουθεί το [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

'@
        Set-Content -Path $Path -Value $header -Encoding utf8BOM -Force
    }
}

function Format-WrapLine {
    <#
    .SYNOPSIS
    Wraps a single Markdown list line to at most MaxLen characters preserving indentation.
    #>
    param(
        [string]$Line,
        [int]$MaxLen = 120
    )

    if ($Line.Length -le $MaxLen) {
        return $Line
    }

    $prefix = ''
    if ($Line -match '^(\s*-\s+|\s+)') {
        $prefix = $Matches[1]
    }
    $indent = ' ' * $prefix.Length

    $chunks = @()
    $current = $Line

    while ($current.Length -gt $MaxLen) {
        $breakIdx = $current.LastIndexOf(' ', $MaxLen - 1)
        if ($breakIdx -lt ($indent.Length + 10)) {
            $breakIdx = $MaxLen
        }
        $chunks += $current.Substring(0, $breakIdx)
        $current = $indent + $current.Substring($breakIdx).TrimStart()
    }
    $chunks += $current
    return ($chunks -join "`n")
}

function Format-ChangelogSectionItem {
    <#
    .SYNOPSIS
    Formats a single commit item into wrapped Markdown bullet lines.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Item
    )

    $parts = $Item -split ' \- '
    if ($parts.Count -gt 1) {
        $formattedItem = "- $($parts[0])"
        for ($i = 1; $i -lt $parts.Count; $i++) {
            $formattedItem += "`n  - $($parts[$i])"
        }
    } else {
        $formattedItem = "- $Item"
    }

    $wrappedLines = foreach ($line in ($formattedItem -split "`n")) {
        Format-WrapLine -Line $line
    }
    return (($wrappedLines -join "`n") + "`n")
}

function Format-ChangelogVersionEntry {
    <#
    .SYNOPSIS
    Builds the Markdown entry block for the target release version.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TargetVersion,

        [Parameter(Mandatory)]
        [hashtable[]]$SectionData
    )

    $dateText = (Get-Date).ToString('yyyy-MM-dd')
    $entry = "## [$TargetVersion] - $dateText`n"

    foreach ($section in $SectionData) {
        $items = @()
        if ($section['Items']) {
            $items = @($section['Items'] | Where-Object { $_ -and $_.Trim() -ne '' })
        }
        if ($items.Count -eq 0) {
            continue
        }

        $entry += "`n### $($section['Title'])`n`n"
        foreach ($item in $items) {
            $entry += Format-ChangelogSectionItem -Item $item
        }
    }

    return ($entry + "`n")
}

function Get-ChangelogHeaderAndBody {
    <#
    .SYNOPSIS
    Splits existing CHANGELOG.md content into header (including Unreleased) and body.
    #>
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Content
    )

    $headerRegex = '# Αρχείο Αλλαγών.*?Semantic Versioning.*?(\r?\n){2,}'
    $headerMatch = [regex]::Match($Content, $headerRegex, 'Singleline')
    if (-not $headerMatch.Success) {
        return @{ Header = ''; Body = $Content }
    }

    $header = $headerMatch.Value
    $body = $Content.Substring($header.Length)
    $unreleasedRegex = '^## \[(?:Unreleased|Μη Κυκλοφορημένα)\][^\r\n]*\r?\n(?:(?!## \[\d).*?\r?\n)*'
    $unreleasedMatch = [regex]::Match($body, $unreleasedRegex)
    if ($unreleasedMatch.Success) {
        $header += $unreleasedMatch.Value.TrimEnd() + "`n`n"
        $body = $body.Substring($unreleasedMatch.Length).TrimStart("`r", "`n")
    }

    return @{ Header = $header; Body = $body }
}

$null = $Action
Initialize-ChangelogFile -Path $ChangelogPath

$existingChangelog = Get-Content -Path $ChangelogPath -Raw -ErrorAction SilentlyContinue
if ($existingChangelog -and $existingChangelog -match "## \[$([regex]::Escape($Version))\]") {
    Write-Warning "Version [$Version] already exists in changelog. Skipping update."
    Write-ChangelogUpdatedFlag -Path $UpdatedFlagPath -Updated $false
    return
}

$hasProvidedSections = [bool](
    $Feat -or $Fix -or $Refactor -or $Docs -or $Ci -or $Build -or
    $Test -or $Chore -or $Style -or $Perf -or $Revert -or $Other
)

if ($hasProvidedSections) {
    Write-Verbose 'Using provided changelog sections'
} else {
    $commitArgs = @{
        To                  = 'HEAD'
        ExcludeHousekeeping = $true
    }
    if (-not [string]::IsNullOrWhiteSpace($From)) {
        $commitArgs['From'] = $From
    }
    if ($IncludeMergeCommits) {
        $commitArgs['IncludeMergeCommits'] = $true
    }

    $commits = @(& (Join-Path $PSScriptRoot 'Get-GitCommitsSinceLastRelease.ps1') @commitArgs | Where-Object { $null -ne $_ })
    if ($commits.Count -eq 0) {
        Write-Warning 'No new commits found.'
        Write-ChangelogUpdatedFlag -Path $UpdatedFlagPath -Updated $false
        return
    }

    $sections = & (Join-Path $PSScriptRoot 'Convert-GreekChangelogCommitsToSections.ps1') -Commits $commits
    $Feat = $sections.feat
    $Fix = $sections.fix
    $Refactor = $sections.refactor
    $Docs = $sections.docs
    $Ci = $sections.ci
    $Build = $sections.build
    $Test = $sections.test
    $Chore = $sections.chore
    $Style = $sections.style
    $Perf = $sections.perf
    $Revert = $sections.revert
    $Other = $sections.other
}

$sectionData = @(
    @{ Title = '✨ Χαρακτηριστικά'; Items = $Feat },
    @{ Title = '🐛 Διορθώσεις'; Items = $Fix },
    @{ Title = '♻️ Αναδιαρθρώσεις'; Items = $Refactor },
    @{ Title = '📝 Τεκμηρίωση'; Items = $Docs },
    @{ Title = '⚙️ CI/CD (Συνεχής Ενοποίηση)'; Items = $Ci },
    @{ Title = '🛠️ Κατασκευή'; Items = $Build },
    @{ Title = '🧪 Δοκιμές'; Items = $Test },
    @{ Title = '🧹 Εργασίες Συντήρησης'; Items = $Chore },
    @{ Title = '🎨 Στυλ & Μορφοποίηση'; Items = $Style },
    @{ Title = '⚡ Απόδοση'; Items = $Perf },
    @{ Title = '⏪ Επαναφορές'; Items = $Revert },
    @{ Title = '❓ Άλλες Αλλαγές'; Items = $Other }
)

$parts = Get-ChangelogHeaderAndBody -Content $existingChangelog
$newEntry = Format-ChangelogVersionEntry -TargetVersion $Version -SectionData $sectionData
$finalChangelog = ("$($parts['Header'])$newEntry$($parts['Body'])").TrimEnd("`r", "`n") + "`n"
Set-Content -Path $ChangelogPath -Value $finalChangelog -Encoding utf8BOM -NoNewline
Write-ChangelogUpdatedFlag -Path $UpdatedFlagPath -Updated $true
Write-Verbose "CHANGELOG.md updated for version $Version"
