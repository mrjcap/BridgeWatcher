<#
.SYNOPSIS
  Εξάγει και μορφοποιεί (με emojis) το changelog section για συγκεκριμένη έκδοση.

.DESCRIPTION
  1) Διαβάζει το CHANGELOG.md από το καθορισμένο path.
  2) Εξάγει το section για το δοσμένο version tag (π.χ. v1.0.22).
  3) Αντικαθιστά headers με τα αντίστοιχα emojis.
  4) Επιστρέφει το αποτέλεσμα ή warning/empty αν δεν βρεθεί.

.PARAMETER Version
  Το version tag (π.χ. v1.0.22) που θέλεις να εξάγεις.

.PARAMETER Path
  (Προαιρετικό) Path προς το CHANGELOG.md. Default: ./CHANGELOG.md

.EXAMPLE
  Get-FormattedReleaseNotes -Version v1.2.3

  # Επιστρέφει formatted κείμενο με emojis:
  ## [1.2.3] - 2025-05-01
  ✨ Προστέθηκαν
  - Νέα δυνατότητα X
  🐛 Διορθώσεις
  - Fixed bug Y
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Version,

    [string]$Path = './CHANGELOG.md'
)

# 1. Έλεγχος αρχείου
if (-not (Test-Path $Path)) {
    throw "Το αρχείο '$Path' δεν βρέθηκε."
}

# 2. Κανονικοποίηση version (αφαίρεση προθέματος 'v')
$normalizedVersion = $Version -replace '^v', ''

# 3. Ανάγνωση changelog
$changelog = Get-Content $Path -Raw

# 4. Regex για extraction του section
$sectionPattern = "(## \[$normalizedVersion\][^\r\n]*\r?\n(?:.*?\r?\n)*?)(?=\r?\n## |\Z)"
if ($changelog -notmatch $sectionPattern) {
    Write-Warning "Δεν βρέθηκε changelog entry για '$Version'."
    return ''
}
$section = $matches[1].Trim()

# 5. Mapping headers → emojis
$headerEmojis = @{
    'Προστέθηκαν'            = '✨'
    'Αλλαγές'                = '🔄'
    'Διορθώθηκαν'            = '🐛'
    'Τεκμηρίωση'             = '📝'
    'Καταργήθηκαν'           = '❌'
    'Ασφάλεια'               = '🔒'
    'Βελτιώσεις'             = '⚡'
    'Αφαιρέθηκαν'            = '❌'
    'Υποψήφια προς απόσυρση' = '⚠️'
}

# 6. Εφαρμογή formatting
foreach ($header in $headerEmojis.Keys) {
    $emoji = [regex]::Escape($headerEmojis[$header])
    # Μόνο αν δεν υπάρχει ήδη το emoji
    $pattern = "(^###\s*)(?!$emoji\s)($header)"
    $section = [regex]::Replace(
        $section,
        $pattern,
        "`$1$emoji $header",
        'Multiline'
    )
}

# 7. Επιστροφή αποτελέσματος
return $section

