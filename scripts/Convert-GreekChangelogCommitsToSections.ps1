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
    "Προστέθηκαν"            = @(
        "^feat:",
        "^feat\(",
        "^προστέθ",
        "^προσθήκη",
        "^νέο",
        "^υποστήριξη",
        "^προσθήκα",
        "^add",
        "^added",
        "^new "
    )
    "Διορθώθηκαν"            = @(
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
    "Αλλαγές"                = @(
        "^refactor:",
        "^refactor\(",
        "^style:",
        "^style\(",
        "^perf:",
        "^perf\(",
        "^αλλαγ",
        "^τροποπ",
        "^μεταβ",
        "^change",
        "^changed",
        "^refactor",
        "^αναβάθμ",
        "^ανανεώσ"
    )
    "Αφαιρέθηκαν"            = @(
        "^καταργ",
        "^αφαίρ",
        "^διαγρά",
        "^remove",
        "^removed",
        "^deleted"
    )
    "Υποψήφια προς απόσυρση" = @(
        "^υποψήφια προς απόσυρση",
        "^deprecat",
        "^παρωχημ",
        "^απόσυρση"
    )
    "Ασφάλεια"               = @(
        "^ασφάλ",
        "^security",
        "^sec"
    )
    "Τεκμηρίωση"             = @(
        "^docs:",
        "^docs\(",
        "^τεκμηρ",
        "^documentation",
        "^readme",
        "^ενημέρω(ση|θηκε).*changelog"  # Μόνο για explicit changelog updates
    )
}

# Προετοιμασία sections
$sections = @{
    'Προστέθηκαν'            = @()
    'Διορθώθηκαν'            = @()
    'Αλλαγές'                = @()
    'Αφαιρέθηκαν'            = @()
    'Υποψήφια προς απόσυρση' = @()
    'Ασφάλεια'               = @()
    'Τεκμηρίωση'             = @()
    'Άλλο'                   = @()
}

foreach ($msg in $Commits) {
    $matched = $false
    foreach ($section in $patterns.Keys) {
        foreach ($pat in $patterns[$section]) {
            if ($msg.ToLower() -match $pat) {
                $sections[$section] += $msg
                $matched = $true
                break
            }
        }
        if ($matched) { break }
    }
    if (-not $matched) {
        $sections['Άλλο'] += $msg
    }
}

[PSCustomObject]$sections