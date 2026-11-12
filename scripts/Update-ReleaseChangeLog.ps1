<#
.SYNOPSIS
Αυτόματο update CHANGELOG.md με βάση τα git commits από το προηγούμενο release tag.

.DESCRIPTION
Εντοπίζει το προηγούμενο release tag μέσω git tag --sort=version:refname,
καλεί το Manage-Changelog.ps1 για την ενημέρωση του CHANGELOG.md και γράφει
'true' ή 'false' στο changelog_updated.flag για χρήση από το CI workflow.

.PARAMETER Version
Η νέα έκδοση που θα περαστεί στο CHANGELOG.

.PARAMETER ChangelogPath
Προαιρετική διαδρομή προς το CHANGELOG.md (προεπιλογή: ../CHANGELOG.md).

.PARAMETER UpdatedFlagPath
Προαιρετική διαδρομή προς το αρχείο σημαίας ενημέρωσης (προεπιλογή: ./changelog_updated.flag).

.PARAMETER IncludeMergeCommits
Αν ενεργοποιηθεί, περιλαμβάνονται και merge commits στο changelog.

.EXAMPLE
./Update-ReleaseChangeLog.ps1 -Version 1.0.20

.EXAMPLE
./Update-ReleaseChangeLog.ps1 -Version 1.0.21 -IncludeMergeCommits

.NOTES
Δημιουργεί το αρχείο changelog_updated.flag με 'true' ή 'false'.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Version,

    [Parameter()]
    [string]$ChangelogPath,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$UpdatedFlagPath = './changelog_updated.flag',

    [Parameter()]
    [switch]$IncludeMergeCommits
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-PreviousReleaseTag {
    <#
    .SYNOPSIS
    Εντοπίζει το προηγούμενο semver tag πριν από την έκδοση-στόχο.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$TargetVersion
    )

    $tagOutput = @(git tag --sort=version:refname 2>$null)
    $tags = @($tagOutput | Where-Object { $_ -match '^v\d+\.\d+\.\d+$' })
    if ($tags.Count -eq 0) {
        return $null
    }

    $versionTag = "v$TargetVersion"
    $currentIndex = [array]::IndexOf($tags, $versionTag)
    if ($currentIndex -gt 0) {
        return $tags[$currentIndex - 1]
    }
    if ($currentIndex -eq -1) {
        return $tags[-1]
    }

    return $null
}

if ([string]::IsNullOrWhiteSpace($ChangelogPath)) {
    $ChangelogPath = Join-Path -Path $PSScriptRoot -ChildPath '..' -AdditionalChildPath 'CHANGELOG.md'
}

$manageScriptPath = Join-Path -Path $PSScriptRoot -ChildPath 'Manage-Changelog.ps1'
if (-not (Test-Path -Path $manageScriptPath)) {
    Set-Content -Path $UpdatedFlagPath -Value 'false' -Encoding utf8
    Write-Error "Required script not found: $manageScriptPath"
    exit 1
}

try {
    $previousTag = Get-PreviousReleaseTag -TargetVersion $Version
    $previousLabel = if ($previousTag) { $previousTag } else { 'None' }
    Write-Verbose "Previous tag: $previousLabel | Target version: v$Version"

    $manageSplat = @{
        Version         = $Version
        Action          = 'Update'
        ChangelogPath   = $ChangelogPath
        UpdatedFlagPath = $UpdatedFlagPath
    }
    if ($previousTag) {
        $manageSplat['From'] = $previousTag
    }
    if ($IncludeMergeCommits) {
        $manageSplat['IncludeMergeCommits'] = $true
    }

    & $manageScriptPath @manageSplat
} catch {
    Set-Content -Path $UpdatedFlagPath -Value 'false' -Encoding utf8
    Write-Error "Failed to update changelog: $_"
    exit 1
}
