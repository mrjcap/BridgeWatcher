<#
.SYNOPSIS
  Κατηγοριοποιεί commit messages σε sections changelog (Προστέθηκαν, Διορθώθηκαν, κ.λπ.) βασισμένο σε ελληνικά ρήματα και μοτίβα τύπου Keep a Changelog.

.DESCRIPTION
  Mapping με βάση φυσική γλώσσα (Ελληνικά) για changelog και release automation.

.PARAMETER Commits
  Array με commit messages.

.EXAMPLE
  $commits = ./Get-GitCommitsSinceLastRelease.ps1 -To HEAD
  $sections = ./Convert-GreekChangelogCommitsToSections.ps1 -Commits $commits
  $sections.Προστέθηκαν
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string[]]$Commits
)

# Μοτίβα για κάθε κατηγορία (με conventional commits και ελληνικά)
$patterns = @{
    "feat"     = @(
        "^feat:",
        "^feat\(",
        "^προστέθ",
        "^προσθήκη",
        "^νέο",
        "^υποστήριξη",
        "^add",
        "^added",
        "^new "
    )
    "fix"      = @(
        "^fix:",
        "^fix\(",
        "^διορθ",
        "^διόρθ",
        "^fixed",
        "^bug",
        "^σφαλμ",
        "^επιδιορθ",
        "^bugfix",
        "^αποκαταστ"
    )
    "refactor" = @(
        "^refactor:",
        "^refactor\(",
        "^refactor",
        "^αναδιάρθρωση",
        "^βελτίωση"
    )
    "docs"     = @(
        "^docs:",
        "^docs\(",
        "^τεκμηρ",
        "^documentation",
        "^readme"
    )
    "ci"       = @(
        "^ci:",
        "^ci\(",
        "^workflow",
        "^gitlab"
    )
    "build"    = @(
        "^build:",
        "^build\(",
        "^docker",
        "^compose"
    )
    "test"     = @(
        "^test:",
        "^test\(",
        "^testing",
        "^pester",
        "^δοκιμ"
    )
    "chore"    = @(
        "^chore:",
        "^chore\(",
        "^bump",
        "^συντήρ",
        "^καθαρισμ"
    )
    "style"    = @(
        "^style:",
        "^style\("
    )
    "perf"     = @(
        "^perf:",
        "^perf\("
    )
    "revert"   = @(
        "^revert:",
        "^revert\("
    )
}

# Προετοιμασία sections
$sections = @{
    'feat'     = @()
    'fix'      = @()
    'refactor' = @()
    'docs'     = @()
    'ci'       = @()
    'build'    = @()
    'test'     = @()
    'chore'    = @()
    'style'    = @()
    'perf'     = @()
    'revert'   = @()
    'other'    = @()
}

foreach ($msg in $Commits) {
    $greekMsg = & "$PSScriptRoot\Translate-CommitMessage.ps1" -Message $msg
    $matched = $false
    # Strip leading emojis and whitespace for matching
    $cleanMsg = $greekMsg -replace '^[\p{So}\p{Cn}\p{Cs}\p{Cf}]+\s*', ''
    Write-Verbose "Processing commit: $cleanMsg (original: $msg, greek: $greekMsg)"

    foreach ($section in $patterns.Keys) {
        foreach ($pat in $patterns[$section]) {
            if ($cleanMsg.ToLower() -match $pat) {
                Write-Verbose "  Matched pattern '$pat' in section '$section'"
                $sections[$section] += $greekMsg
                $matched = $true
                break
            }
        }
        if ($matched) { break }
    }
    if (-not $matched) {
        Write-Verbose "  No match found, adding to 'other'"
        $sections['other'] += $greekMsg
    }
}

[PSCustomObject]$sections

