<#
.SYNOPSIS
  Extracts release notes from CHANGELOG.md for a specific version.

.DESCRIPTION
  Reads CHANGELOG.md and extracts the section for the specified version,
  formatted with emojis for GitHub releases.

.PARAMETER Version
  The version tag (e.g., v1.2.3) to extract from changelog.

.PARAMETER Path
  Path to CHANGELOG.md (default: ./CHANGELOG.md).

.EXAMPLE
  Get-ReleaseNotes -Version v1.2.3
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,

    [string]$Path = './CHANGELOG.md'
)

if (-not (Test-Path -Path $Path)) {
    Write-Warning -Message "CHANGELOG.md not found at $Path"
    return "Release $Version"
}

$normalizedVersion = $Version -replace '^v', ''

$changelog = Get-Content -Path $Path -Raw

$sectionPattern = "(## \[$normalizedVersion\][^\r\n]*\r?\n(?:.*?\r?\n)*?)(?=\r?\n## |\Z)"
if ($changelog -notmatch $sectionPattern) {
    Write-Warning -Message "No changelog entry found for '$Version'"
    return "Release $Version"
}

$section = $matches[1].Trim()

$section = $section -replace '### Προστέθηκαν\b', '### ✨ Προστέθηκαν'
$section = $section -replace '### Αλλαγές\b', '### 🔄 Αλλαγές'
$section = $section -replace '### Διορθώθηκαν\b', '### 🐛 Διορθώθηκαν'
$section = $section -replace '### Τεκμηρίωση\b', '### 📝 Τεκμηρίωση'
$section = $section -replace '### Αφαιρέθηκαν\b', '### ❌ Αφαιρέθηκαν'
$section = $section -replace '### Ασφάλεια\b', '### 🔒 Ασφάλεια'
$section = $section -replace '### Υποψήφια προς απόσυρση\b', '### ⚠️ Υποψήφια προς απόσυρση'

return $section


