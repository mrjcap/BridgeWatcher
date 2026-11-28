<#
.SYNOPSIS
Promotes entries from the Unreleased section of CHANGELOG.md into a versioned release section.

.DESCRIPTION
Reads CHANGELOG.md, extracts populated subsections under the Unreleased heading, drops empty
subsections, resets a clean Greek Unreleased template at the top, and writes the promoted
versioned section encoded as UTF-8 with BOM and LF line endings.

.PARAMETER Version
The target semantic version (for example, 1.0.103 or v1.0.103).

.PARAMETER ChangelogPath
Path to CHANGELOG.md (default: ./CHANGELOG.md).

.PARAMETER Date
Release date formatted as yyyy-MM-dd (default: current date).

.PARAMETER AllowEmpty
Allows promoting an Unreleased section even when it contains no bullet entries.

.EXAMPLE
./scripts/Promote-UnreleasedChangelog.ps1 -Version '1.0.103'

.EXAMPLE
./scripts/Promote-UnreleasedChangelog.ps1 -Version '1.1.0' -ChangelogPath './CHANGELOG.md' -Date '2026-11-28'
#>
[CmdletBinding()]
[OutputType([PSCustomObject])]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^v?\d+\.\d+\.\d+$')]
    [string]$Version,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$ChangelogPath = './CHANGELOG.md',

    [Parameter()]
    [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
    [string]$Date = (Get-Date -Format 'yyyy-MM-dd'),

    [Parameter()]
    [switch]$AllowEmpty
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Returns the empty Greek Unreleased template block for CHANGELOG.md.

.DESCRIPTION
Provides the standard Unreleased heading and four Keep-a-Changelog Greek subsection headings.
#>
function Get-UnreleasedChangelogTemplate {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    return @(
        '## [Unreleased]'
        ''
        '### ✨ Χαρακτηριστικά'
        ''
        '### 🐛 Διορθώσεις'
        ''
        '### 🔒 Ασφάλεια'
        ''
        '### 🔄 Αλλαγές'
    ) -join "`n"
}

<#
.SYNOPSIS
Extracts populated subsections and bullet counts from an Unreleased section body.

.DESCRIPTION
Splits the Unreleased section by level-3 headings, retains only blocks that contain at least
one Markdown bullet item, and returns the combined Markdown body alongside the bullet count.

.PARAMETER UnreleasedBody
The raw text inside the Unreleased section before the next version heading.
#>
function Get-PopulatedUnreleasedContent {
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter()]
        [AllowEmptyString()]
        [string]$UnreleasedBody
    )

    $blocks = [System.Collections.Generic.List[string]]::new()
    $currentLines = [System.Collections.Generic.List[string]]::new()
    $bulletCount = 0

    foreach ($line in ($UnreleasedBody -split "`n")) {
        if ($line -match '^###\s+') {
            if ($currentLines.Count -gt 0) {
                $blocks.Add(($currentLines -join "`n"))
                $currentLines.Clear()
            }
        }
        $currentLines.Add($line)
    }
    if ($currentLines.Count -gt 0) {
        $blocks.Add(($currentLines -join "`n"))
    }

    $keptBlocks = [System.Collections.Generic.List[string]]::new()
    foreach ($block in $blocks) {
        $trimmedBlock = $block.Trim("`r", "`n")
        if ([string]::IsNullOrWhiteSpace($trimmedBlock)) {
            continue
        }
        $blockBullets = @($trimmedBlock -split "`n" | Where-Object -FilterScript { $_ -match '^\s*[-*]\s+\S' })
        if ($blockBullets.Count -gt 0) {
            $bulletCount += $blockBullets.Count
            $keptBlocks.Add($trimmedBlock)
        }
    }

    return [PSCustomObject]@{
        Body        = ($keptBlocks -join "`n`n")
        BulletCount = $bulletCount
    }
}

$normalizedVersion = $Version -replace '^v', ''
if (-not (Test-Path -LiteralPath $ChangelogPath -PathType Leaf)) {
    throw [System.IO.FileNotFoundException]::new("Changelog file not found: $ChangelogPath", $ChangelogPath)
}

$resolvedPath = (Resolve-Path -LiteralPath $ChangelogPath).Path
$rawContent = ([System.IO.File]::ReadAllText($resolvedPath) -replace "`r`n", "`n")

$existingVersionPattern = "(?m)^## \[$([regex]::Escape($normalizedVersion))\](?:\s|$)"
if ([regex]::IsMatch($rawContent, $existingVersionPattern)) {
    Write-Verbose -Message "Version [$normalizedVersion] already exists in $ChangelogPath. Skipping promotion."
    return [PSCustomObject]@{
        Updated        = $false
        AlreadyPresent = $true
        Version        = $normalizedVersion
        BulletCount    = 0
    }
}

$unreleasedPattern = '(?ms)(^## \[(?:Unreleased|Μη Κυκλοφορημένα)\][^\n]*\n)(.*?)(?=^## \[|\z)'
$match = [regex]::Match($rawContent, $unreleasedPattern)
if (-not $match.Success) {
    throw "No '## [Unreleased]' section was found in $ChangelogPath."
}

$populated = Get-PopulatedUnreleasedContent -UnreleasedBody $match.Groups[2].Value
if ($populated.BulletCount -eq 0 -and -not $AllowEmpty) {
    throw "No unreleased changelog entries found under '## [Unreleased]' in $ChangelogPath. Add at least one bullet item before preparing a release."
}

$template = Get-UnreleasedChangelogTemplate
$versionBlock = if ([string]::IsNullOrWhiteSpace($populated.Body)) {
    "## [$normalizedVersion] - $Date"
} else {
    "## [$normalizedVersion] - $Date`n`n$($populated.Body)"
}

$prefix = $rawContent.Substring(0, $match.Index)
$suffix = $rawContent.Substring($match.Index + $match.Length).TrimStart("`n")
$combined = if ([string]::IsNullOrWhiteSpace($suffix)) {
    "$prefix$template`n`n$versionBlock`n"
} else {
    "$prefix$template`n`n$versionBlock`n`n$suffix"
}
$finalContent = $combined.TrimEnd("`n") + "`n"

$utf8Bom = [System.Text.UTF8Encoding]::new($true)
[System.IO.File]::WriteAllText($resolvedPath, $finalContent, $utf8Bom)

return [PSCustomObject]@{
    Updated        = $true
    AlreadyPresent = $false
    Version        = $normalizedVersion
    BulletCount    = $populated.BulletCount
}
