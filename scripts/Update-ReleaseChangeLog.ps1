[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Version,
    
    [switch]$IncludeMergeCommits
)

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$changelogPath = "$scriptRoot\..\CHANGELOG.md"

# Βήμα 1: Αρχικοποίηση changelog αν χρειάζεται
$wasInitialized = Initialize-ChangelogIfNeeded -ChangelogPath $changelogPath -Verbose

# Βήμα 2: Έλεγχος για existing version
if (-not $wasInitialized) {
    $changelogContent = Get-Content $changelogPath -Raw
    if ($changelogContent -match "## \[$Version\]") {
        Write-Warning "Η έκδοση [$Version] υπάρχει ήδη στο CHANGELOG.md"
        'false' | Set-Content './changelog_updated.flag'
        exit 0
    }
}

# Βήμα 3: Λήψη commits
$commitArgs = @{
    To                 = 'HEAD'
    ExcludeBumpCommits = $true
}
if ($IncludeMergeCommits) {
    $commitArgs.IncludeMergeCommits = $true
}

$commits = & "$scriptRoot\Get-GitCommitsSinceLastRelease.ps1" @commitArgs

# Βήμα 4: Έλεγχος για νέα commits
if (-not $commits -or $commits.Count -eq 0) {
    Write-Host 'No new commits since last release.'
    'false' | Set-Content './changelog_updated.flag'
    exit 0
}

# Βήμα 5: Επεξεργασία και ενημέρωση
$sections = & "$scriptRoot\Convert-GreekChangelogCommitsToSections.ps1" -Commits $commits

& "$scriptRoot\Update-Changelog.ps1" `
    -ChangelogPath $changelogPath `
    -Version $Version `
    -Added $sections.'Προστέθηκαν' `
    -Changed $sections.'Αλλαγές' `
    -Deprecated $sections.'Υποψήφια προς απόσυρση' `
    -Removed $sections.'Αφαιρέθηκαν' `
    -Fixed $sections.'Διορθώθηκαν' `
    -Security $sections.'Ασφάλεια' `
    -Documentation $sections.'Τεκμηρίωση'

# Βήμα 6: Set flag
'true' | Set-Content './changelog_updated.flag'
Write-Host "CHANGELOG.md updated for version $Version." -ForegroundColor Green


function Initialize-ChangelogIfNeeded {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory)]
        [string]$ChangelogPath
    )
    
    $initialized = $false
    
    # Check if file exists
    if (-not (Test-Path $ChangelogPath)) {
        $writeBridgeLogSplat = @{
            Message = "Creating new CHANGELOG.md file"
            Level   = 'Info'
        }
        Write-Verbose @writeBridgeLogSplat
        $initialized = $true
    }
    else {
        # Check if file is essentially empty
        $content = Get-Content $ChangelogPath -Raw
        if ([string]::IsNullOrWhiteSpace($content) -or $content.Length -lt 100) {
            $writeBridgeLogSplat = @{
                Message = "CHANGELOG.md is empty, initializing with header"
                Level   = 'Info'
            }
            Write-Verbose @writeBridgeLogSplat
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
    }
    
    return $initialized
}

# Χρήση στο Update-ReleaseChangeLog.ps1
$changelogPath = "$PSScriptRoot\..\CHANGELOG.md"
$wasInitialized = Initialize-ChangelogIfNeeded -ChangelogPath $changelogPath -Verbose