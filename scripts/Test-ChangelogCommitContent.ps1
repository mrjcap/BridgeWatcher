<#
.SYNOPSIS
Ελέγχει το περιεχόμενο των commits που περιλαμβάνονται στο CHANGELOG.md

.DESCRIPTION
Αυτό το script επαληθεύει ότι τα σωστά commits περιλαμβάνονται στο changelog:
- Ελέγχει ότι τα user-facing commits δεν εξαιρούνται λανθασμένα
- Επαληθεύει ότι τα housekeeping commits δεν περιλαμβάνονται
- Ελέγχει τη σωστή κατηγοριοποίηση των commits σε sections
- Εντοπίζει commits που λείπουν ή περιλαμβάνονται λανθασμένα

.PARAMETER ChangelogPath
Η διαδρομή προς το CHANGELOG.md

.PARAMETER Version
Η έκδοση για την οποία θα γίνει ο έλεγχος (προεπιλογή: τελευταία έκδοση)

.PARAMETER CheckLastCommits
Αριθμός των τελευταίων commits που θα ελεγχθούν (προεπιλογή: όλα από το τελευταίο tag)

.PARAMETER Strict
Αν ενεργοποιηθεί, κάνει πιο αυστηρούς ελέγχους

.PARAMETER ExportReport
Αν ενεργοποιηθεί, εξάγει αναλυτική αναφορά

.EXAMPLE
.\Test-ChangelogCommitContent.ps1

.EXAMPLE
.\Test-ChangelogCommitContent.ps1 -Version "1.0.69" -Strict

.EXAMPLE
.\Test-ChangelogCommitContent.ps1 -ExportReport -Verbose

.NOTES
Αυτό το script συμπληρώνει το Test-ChangelogFormatValidation.ps1 που ελέγχει τη μορφή.
Εδώ ελέγχουμε το περιεχόμενο - ποια commits περιλαμβάνονται/εξαιρούνται.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ChangelogPath = "./CHANGELOG.md",

    [Parameter()]
    [string]$Version,

    [Parameter()]
    [int]$CheckLastCommits = 0,

    [Parameter()]
    [switch]$Strict,

    [Parameter()]
    [switch]$ExportReport
)

function Get-CommitsFromChangelog {
    <#
    .SYNOPSIS
    Εξάγει τα commit messages από μια συγκεκριμένη έκδοση στο changelog
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogPath,
        [Parameter(Mandatory)]
        [string]$Version
    )

    if (-not (Test-Path $ChangelogPath)) {
        throw "Το αρχείο changelog δεν βρέθηκε: $ChangelogPath"
    }

    $content = Get-Content $ChangelogPath -Raw -Encoding UTF8

    # Βρες το section για την έκδοση
    $versionPattern = "## \[$([regex]::Escape($Version))\].*?(?=## \[|\z)"
    $versionMatch = [regex]::Match($content, $versionPattern, 'Singleline')

    if (-not $versionMatch.Success) {
        throw "Δεν βρέθηκε η έκδοση $Version στο changelog"
    }

    $versionContent = $versionMatch.Value

    # Εξαγωγή bullet points (commit messages)
    $bulletPattern = '^- (.+)$'
    $bulletMatches = [regex]::Matches($versionContent, $bulletPattern, 'Multiline')

    $commits = @()
    foreach ($match in $bulletMatches) {
        $commit = $match.Groups[1].Value.Trim()
        # Καθαρισμός από markdown formatting
        $commit = $commit -replace '\*\*(.*?)\*\*', '$1'  # **bold** -> bold
        $commit = $commit -replace '`(.*?)`', '$1'        # `code` -> code
        $commits += $commit
    }

    return $commits
}

function Get-ActualCommitsForVersion {
    <#
    .SYNOPSIS
    Παίρνει τα πραγματικά commits από το git για μια έκδοση
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Version,
        [Parameter()]
        [int]$CheckLastCommits = 0
    )

    try {
        # Βρες το tag της έκδοσης
        $versionTag = "v$Version"
        $tagExists = git tag -l $versionTag

        if ($tagExists) {
            # Αν υπάρχει tag, πάρε commits από το προηγούμενο tag
            $previousTag = git describe --tags --abbrev=0 "$versionTag^" 2>$null
            if ($previousTag) {
                $range = "$previousTag..$versionTag"
            } else {
                # Πρώτο tag - πάρε όλα τα commits
                $range = $versionTag
            }
        } else {
            # Αν δεν υπάρχει tag, πάρε από το τελευταίο tag μέχρι HEAD
            $lastTag = git describe --tags --abbrev=0 2>$null
            if ($lastTag) {
                $range = "$lastTag..HEAD"
            } else {
                $range = "HEAD"
            }
        }

        Write-Verbose "🔍 Λαμβάνω commits για range: $range"

        # Πάρε τα commits με τα ίδια filters που χρησιμοποιεί το Update-ReleaseChangeLog.ps1
        $gitArgs = @($range, '--pretty=format:%s', '--no-merges')
          # Exclude housekeeping commits (όπως στο Get-GitCommitsSinceLastRelease.ps1)
        $gitArgs += @(
            '--invert-grep',
            '--grep=^(chore:|chore\(|ci:|ci\(|docs:|docs\(|build:|test:|refactor:|perf:|style:|Ενημέρωση|Προσθήκη συγχρονισμού|\[skip ci\]|Update changelog)',
            '--extended-regexp'
        )

        $actualCommits = git log @gitArgs 2>$null | Where-Object { $_.Trim() }

        if ($CheckLastCommits -gt 0 -and $actualCommits.Count -gt $CheckLastCommits) {
            $actualCommits = $actualCommits | Select-Object -First $CheckLastCommits
        }

        return @($actualCommits)
    } catch {
        Write-Warning "Σφάλμα λήψης commits: $_"
        return @()
    }
}

function Test-CommitCategorization {
    <#
    .SYNOPSIS
    Ελέγχει αν τα commits έχουν κατηγοριοποιηθεί σωστά στα sections
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ChangelogCommits,
        [Parameter(Mandatory)]
        [string[]]$ActualCommits
    )

    $issues = @()
    $warnings = @()
    $passes = @()

    # Import patterns από το Convert-GreekChangelogCommitsToSections.ps1
    $patterns = @{
        "Προστέθηκαν"            = @("^προστέθ", "^προσθήκη", "^νέο", "^υποστήριξη", "^προσθήκα", "^add", "^added", "^new ")
        "Διορθώθηκαν"            = @("^διορθ", "^διόρθ", "^fix", "^fixed", "^bug", "^σφαλμ", "^επιδιορθ", "^bugfix", "^αποκαταστ")
        "Αλλαγές"                = @("^αλλαγ", "^τροποπ", "^μεταβ", "^change", "^changed", "^refactor", "^αναβάθμ", "^ανανεώσ")
        "Αφαιρέθηκαν"            = @("^καταργ", "^αφαίρ", "^διαγρά", "^remove", "^removed", "^deleted")
        "Υποψήφια προς απόσυρση" = @("^υποψήφια προς απόσυρση", "^deprecat", "^παρωχημ", "^απόσυρση")
        "Ασφάλεια"               = @("^ασφάλ", "^security", "^sec")
        "Τεκμηρίωση"             = @("^τεκμηρ", "^docs", "^documentation", "^readme", "^ενημέρω(ση|θηκε).*changelog", "changelog")
    }

    # Ελέγχουμε κάθε actual commit
    foreach ($actualCommit in $ActualCommits) {
        $foundInChangelog = $false
        $expectedCategory = "Άλλο"

        # Βρες την αναμενόμενη κατηγορία για αυτό το commit
        foreach ($category in $patterns.Keys) {
            foreach ($pattern in $patterns[$category]) {
                if ($actualCommit.ToLower() -match $pattern) {
                    $expectedCategory = $category
                    break
                }
            }
            if ($expectedCategory -ne "Άλλο") { break }
        }

        # Ελέγχουμε αν το commit υπάρχει στο changelog
        foreach ($changelogCommit in $ChangelogCommits) {
            if ($changelogCommit -like "*$actualCommit*" -or $actualCommit -like "*$changelogCommit*") {
                $foundInChangelog = $true
                break
            }
        }

        if (-not $foundInChangelog) {
            if ($expectedCategory -ne "Άλλο") {
                $issues += "❌ Λείπει user-facing commit: '$actualCommit' (αναμενόμενη κατηγορία: $expectedCategory)"
            } else {
                $warnings += "⚠️ Πιθανώς λείπει commit: '$actualCommit' (δεν κατηγοριοποιήθηκε)"
            }
        } else {
            $passes += "✅ Βρέθηκε commit: '$actualCommit'"
        }
    }

    # Ελέγχουμε για commits στο changelog που δεν υπάρχουν στα actual
    foreach ($changelogCommit in $ChangelogCommits) {
        $foundInActual = $false
        foreach ($actualCommit in $ActualCommits) {
            if ($changelogCommit -like "*$actualCommit*" -or $actualCommit -like "*$changelogCommit*") {
                $foundInActual = $true
                break
            }
        }

        if (-not $foundInActual) {
            $warnings += "⚠️ Commit στο changelog δεν βρέθηκε στα actual commits: '$changelogCommit'"
        }
    }

    return [PSCustomObject]@{
        Issues = $issues
        Warnings = $warnings
        Passes = $passes
    }
}

function Test-HousekeepingExclusion {
    <#
    .SYNOPSIS
    Ελέγχει ότι τα housekeeping commits έχουν εξαιρεθεί σωστά
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$ChangelogCommits
    )

    $issues = @()
    $warnings = @()
    $passes = @()

    # Patterns που πρέπει να εξαιρούνται (από Get-GitCommitsSinceLastRelease.ps1)
    $housekeepingPatterns = @(
        '^chore:', '^chore\(',
        '^ci:', '^ci\(',
        '^docs:', '^build:', '^test:',
        '^refactor:', '^perf:', '^style:',
        '^Ενημέρωση', '^Προσθήκη συγχρονισμού'
    )

    foreach ($commit in $ChangelogCommits) {
        $isHousekeeping = $false
        $matchedPattern = ""

        foreach ($pattern in $housekeepingPatterns) {
            if ($commit -match $pattern) {
                $isHousekeeping = $true
                $matchedPattern = $pattern
                break
            }
        }

        if ($isHousekeeping) {
            $issues += "❌ Housekeeping commit δεν έπρεπε να περιλαμβάνεται: '$commit' (pattern: $matchedPattern)"
        } else {
            $passes += "✅ User-facing commit: '$commit'"
        }
    }

    if ($issues.Count -eq 0) {
        $passes += "✅ Κανένα housekeeping commit δεν περιλαμβάνεται λανθασμένα"
    }

    return [PSCustomObject]@{
        Issues = $issues
        Warnings = $warnings
        Passes = $passes
    }
}

function Show-CommitContentResults {
    <#
    .SYNOPSIS
    Εμφανίζει τα αποτελέσματα του commit content validation
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Results
    )

    Write-Host "`n📋 Αποτελέσματα Ελέγχου Περιεχομένου Commits" -ForegroundColor Cyan
    Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan

    Write-Host "`n📊 Περίληψη:" -ForegroundColor Yellow
    Write-Host "  • Έκδοση: $($Results.Version)"
    Write-Host "  • Commits στο changelog: $($Results.ChangelogCommits.Count)"
    Write-Host "  • Actual commits: $($Results.ActualCommits.Count)"
    Write-Host "  • Issues: $($Results.TotalIssues)"
    Write-Host "  • Warnings: $($Results.TotalWarnings)"
    Write-Host "  • Score: $($Results.Score)/100"

    $statusIcon = if ($Results.IsValid) { "✅" } else { "❌" }
    $scoreColor = if ($Results.Score -ge 90) { "Green" }
                 elseif ($Results.Score -ge 70) { "Yellow" }
                 else { "Red" }

    Write-Host "`n$statusIcon Συνολική Αξιολόγηση: " -NoNewline
    Write-Host "$($Results.Score)/100" -ForegroundColor $scoreColor

    # Εμφάνιση issues
    if ($Results.CategorizationTest.Issues.Count -gt 0) {
        Write-Host "`n❌ Κατηγοριοποίηση Issues:" -ForegroundColor Red
        $Results.CategorizationTest.Issues | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    }

    if ($Results.HousekeepingTest.Issues.Count -gt 0) {
        Write-Host "`n❌ Housekeeping Issues:" -ForegroundColor Red
        $Results.HousekeepingTest.Issues | ForEach-Object { Write-Host "   $_" -ForegroundColor Red }
    }

    # Εμφάνιση warnings
    if ($Results.CategorizationTest.Warnings.Count -gt 0) {
        Write-Host "`n⚠️ Κατηγοριοποίηση Warnings:" -ForegroundColor Yellow
        $Results.CategorizationTest.Warnings | ForEach-Object { Write-Host "   $_" -ForegroundColor Yellow }
    }

    # Εμφάνιση passes (μόνο σε verbose mode)
    if ($VerbosePreference -eq 'Continue') {
        if ($Results.CategorizationTest.Passes.Count -gt 0) {
            Write-Host "`n✅ Επιτυχείς Ελέγχοι:" -ForegroundColor Green
            $Results.CategorizationTest.Passes | ForEach-Object { Write-Host "   $_" -ForegroundColor Green }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# MAIN SCRIPT EXECUTION
# ═══════════════════════════════════════════════════════════════════

Write-Host "🧪 Έναρξη Commit Content Validation" -ForegroundColor Green
Write-Host "═══════════════════════════════════════" -ForegroundColor Green

try {
    # 1. Προσδιορισμός έκδοσης
    if (-not $Version) {
        if (Test-Path $ChangelogPath) {
            $content = Get-Content $ChangelogPath -Raw
            $versionMatch = [regex]::Match($content, '## \[(\d+\.\d+\.\d+)\]')
            if ($versionMatch.Success) {
                $Version = $versionMatch.Groups[1].Value
                Write-Verbose "📋 Αυτόματη ανίχνευση έκδοσης: $Version"
            } else {
                throw "Δεν βρέθηκε έκδοση στο changelog"
            }
        } else {
            throw "Το αρχείο changelog δεν βρέθηκε και δεν δόθηκε έκδοση"
        }
    }

    Write-Verbose "🎯 Ελέγχω περιεχόμενο commits για έκδοση: $Version"

    # 2. Λήψη commits από changelog
    Write-Verbose "📖 Εξαγωγή commits από changelog..."
    $changelogCommits = Get-CommitsFromChangelog -ChangelogPath $ChangelogPath -Version $Version

    # 3. Λήψη πραγματικών commits
    Write-Verbose "🔍 Λήψη πραγματικών commits από git..."
    $actualCommits = Get-ActualCommitsForVersion -Version $Version -CheckLastCommits $CheckLastCommits

    Write-Verbose "📊 Changelog commits: $($changelogCommits.Count), Actual commits: $($actualCommits.Count)"

    # 4. Τεστ κατηγοριοποίησης
    Write-Verbose "🔍 Έλεγχος κατηγοριοποίησης commits..."
    $categorizationTest = Test-CommitCategorization -ChangelogCommits $changelogCommits -ActualCommits $actualCommits

    # 5. Τεστ εξαίρεσης housekeeping
    Write-Verbose "🔍 Έλεγχος εξαίρεσης housekeeping commits..."
    $housekeepingTest = Test-HousekeepingExclusion -ChangelogCommits $changelogCommits

    # 6. Συγκέντρωση αποτελεσμάτων
    $totalIssues = $categorizationTest.Issues.Count + $housekeepingTest.Issues.Count
    $totalWarnings = $categorizationTest.Warnings.Count + $housekeepingTest.Warnings.Count

    $score = if ($totalIssues -eq 0 -and $totalWarnings -eq 0) { 100 }
             elseif ($totalIssues -eq 0) { 85 - ($totalWarnings * 5) }
             else { [Math]::Max(0, 60 - ($totalIssues * 15) - ($totalWarnings * 5)) }

    $results = [PSCustomObject]@{
        Version = $Version
        ChangelogCommits = $changelogCommits
        ActualCommits = $actualCommits
        CategorizationTest = $categorizationTest
        HousekeepingTest = $housekeepingTest
        TotalIssues = $totalIssues
        TotalWarnings = $totalWarnings
        IsValid = ($totalIssues -eq 0)
        Score = $score
    }

    # 7. Εμφάνιση αποτελεσμάτων
    Show-CommitContentResults -Results $results

    # 8. Export αναφοράς
    if ($ExportReport) {
        $reportPath = "./commit-content-validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $report = [PSCustomObject]@{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Parameters = @{
                ChangelogPath = $ChangelogPath
                Version = $Version
                CheckLastCommits = $CheckLastCommits
                Strict = $Strict.IsPresent
            }
            Results = $results
        }

        $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8
        Write-Host "`n📄 Αναφορά εξήχθη στο: $reportPath" -ForegroundColor Cyan
    }

    # 9. Exit code για CI/CD
    if ($results.IsValid) {
        Write-Host "`n✅ Commit content validation πέρασε!" -ForegroundColor Green
        exit 0
    } else {
        Write-Host "`n❌ Commit content validation απέτυχε!" -ForegroundColor Red
        exit 1
    }

} catch {
    Write-Error "❌ Σφάλμα: $($_.Exception.Message)"
    exit 1
}
