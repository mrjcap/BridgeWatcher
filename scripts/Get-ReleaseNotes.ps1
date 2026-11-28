<#
.SYNOPSIS
  Extracts release notes from CHANGELOG.md for a specific version.

.DESCRIPTION
  Reads CHANGELOG.md and extracts the section for the specified version,
  formatted with emojis for GitHub releases and an optional Greek compare link.

.PARAMETER Version
  The version tag (e.g., v1.2.3) to extract from changelog.

.PARAMETER Path
  Path to CHANGELOG.md (default: ./CHANGELOG.md).

.PARAMETER IncludeCompareLink
  Appends a Greek GitHub compare link between the previous version and Version when available.

.PARAMETER PreviousVersion
  Optional previous version (e.g., v1.0.101) for the compare link; auto-detected from CHANGELOG.md when omitted.

.PARAMETER RepositoryUrl
  Base GitHub repository URL used when constructing the compare link.

.EXAMPLE
  ./scripts/Get-ReleaseNotes.ps1 -Version v1.2.3

.EXAMPLE
  ./scripts/Get-ReleaseNotes.ps1 -Version v1.2.3 -IncludeCompareLink
#>
[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$Path = './CHANGELOG.md',

    [Parameter()]
    [switch]$IncludeCompareLink,

    [Parameter()]
    [string]$PreviousVersion = '',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$RepositoryUrl = 'https://github.com/mrjcap/BridgeWatcher'
)

if (-not (Test-Path -LiteralPath $Path)) {
    Write-Warning -Message "CHANGELOG.md not found at $Path"
    return "Release $Version"
}

$normalizedVersion = $Version -replace '^v', ''
$changelog = Get-Content -LiteralPath $Path -Raw

$escapedVersion = [regex]::Escape($normalizedVersion)
$sectionPattern = "(## \[$escapedVersion\][^\r\n]*\r?\n(?:.*?\r?\n)*?)(?=\r?\n## |\Z)"
$sectionMatch = [regex]::Match($changelog, $sectionPattern)
if (-not $sectionMatch.Success) {
    Write-Warning -Message "No changelog entry found for '$Version'"
    return "Release $Version"
}

$section = $sectionMatch.Groups[1].Value.Trim()

$section = $section -replace '### Προστέθηκαν\b', '### ✨ Προστέθηκαν'
$section = $section -replace '### Αλλαγές\b', '### 🔄 Αλλαγές'
$section = $section -replace '### Διορθώθηκαν\b', '### 🐛 Διορθώθηκαν'
$section = $section -replace '### Τεκμηρίωση\b', '### 📝 Τεκμηρίωση'
$section = $section -replace '### Αφαιρέθηκαν\b', '### ❌ Αφαιρέθηκαν'
$section = $section -replace '### Ασφάλεια\b', '### 🔒 Ασφάλεια'
$section = $section -replace '### Υποψήφια προς απόσυρση\b', '### ⚠️ Υποψήφια προς απόσυρση'

if ($IncludeCompareLink) {
    $null, $sectionBody = $section -split '\r?\n', 2
    if (-not [string]::IsNullOrWhiteSpace($sectionBody)) {
        $resolvedPrev = $PreviousVersion -replace '^v', ''
        if ([string]::IsNullOrWhiteSpace($resolvedPrev)) {
            $tail = $changelog.Substring($sectionMatch.Index + $sectionMatch.Length)
            $prevMatch = [regex]::Match($tail, '(?m)^## \[(\d+\.\d+\.\d+)\]')
            if ($prevMatch.Success) {
                $resolvedPrev = $prevMatch.Groups[1].Value
            }
        }
        if (-not [string]::IsNullOrWhiteSpace($resolvedPrev)) {
            $baseRepo = $RepositoryUrl.TrimEnd('/')
            $section = "$section`n`n**Πλήρες Αρχείο Αλλαγών**: $baseRepo/compare/v$resolvedPrev...v$normalizedVersion"
        }
    }
}

return $section
