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

# Check if file exists
if (-not (Test-Path $Path)) {
    Write-Warning "CHANGELOG.md not found at $Path"
    return "Release $Version"
}

# Normalize version (remove 'v' prefix)
$normalizedVersion = $Version -replace '^v', ''

# Read changelog
$changelog = Get-Content $Path -Raw

# Extract section for this version
$sectionPattern = "(## \[$normalizedVersion\][^\r\n]*\r?\n(?:.*?\r?\n)*?)(?=\r?\n## |\Z)"
if ($changelog -notmatch $sectionPattern) {
    Write-Warning "No changelog entry found for '$Version'"
    return "Release $Version"
}

$section = $matches[1].Trim()

# Simple emoji mapping for common Greek headers
$section = $section -replace '### Προστέθηκαν\b', '### ✨ Προστέθηκαν'
$section = $section -replace '### Αλλαγές\b', '### 🔄 Αλλαγές'
$section = $section -replace '### Διορθώθηκαν\b', '### 🐛 Διορθώθηκαν'
$section = $section -replace '### Τεκμηρίωση\b', '### 📝 Τεκμηρίωση'
$section = $section -replace '### Αφαιρέθηκαν\b', '### ❌ Αφαιρέθηκαν'
$section = $section -replace '### Ασφάλεια\b', '### 🔒 Ασφάλεια'
$section = $section -replace '### Υποψήφια προς απόσυρση\b', '### ⚠️ Υποψήφια προς απόσυρση'

return $section

