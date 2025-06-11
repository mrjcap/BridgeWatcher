<#
.SYNOPSIS
Comprehensive test script για έλεγχο της μορφής του CHANGELOG.md και άλλων markdown αρχείων.

.DESCRIPTION
Το script ελέγχει αν το CHANGELOG.md και άλλα αρχεία ακολουθούν τη σωστή μορφή:
- Keep a Changelog format (https://keepachangelog.com/el/1.1.0/)
- Semantic Versioning (https://semver.org/spec/v2.0.0.html)
- Ελληνικοί τίτλοι με emojis
- Σωστή δομή sections
- Σωστές ημερομηνίες και version formats

.PARAMETER ChangelogPath
Η διαδρομή προς το CHANGELOG.md αρχείο. Default: "./CHANGELOG.md"

.PARAMETER CheckReadme
Αν ενεργοποιηθεί, ελέγχει και το README.md

.PARAMETER CheckAllMarkdown
Αν ενεργοποιηθεί, ελέγχει όλα τα .md αρχεία στο workspace

.PARAMETER Strict
Αν ενεργοποιηθεί, κάνει πιο αυστηρούς ελέγχους

.PARAMETER ExportReport
Αν ενεργοποιηθεί, εξάγει αναφορά σε JSON format

.EXAMPLE
.\Test-ChangelogFormatValidation.ps1

.EXAMPLE
.\Test-ChangelogFormatValidation.ps1 -CheckAllMarkdown -Strict

.EXAMPLE
.\Test-ChangelogFormatValidation.ps1 -ExportReport -Verbose

.NOTES
Το script χρησιμοποιεί τις προδιαγραφές που περιγράφηκαν στο user request.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ChangelogPath = "./CHANGELOG.md",

    [Parameter()]
    [switch]$CheckReadme,

    [Parameter()]
    [switch]$CheckAllMarkdown,

    [Parameter()]
    [switch]$Strict,

    [Parameter()]
    [switch]$ExportReport
)

# Import της υπάρχουσας function αν υπάρχει
if (Test-Path "./scripts/Update-ChangelogFormat.ps1") {
    . "./scripts/Update-ChangelogFormat.ps1"
}

function Test-ChangelogStructure {
    <#
    .SYNOPSIS
    Ελέγχει τη βασική δομή του changelog
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,
        [Parameter()]
        [switch]$Strict
    )

    $issues = @()
    $warnings = @()
    $passes = @()

    try {
        $content = Get-Content $FilePath -Raw -Encoding UTF8

        # 1. Έλεγχος κύριου header
        if ($content -match '# Αρχείο Αλλαγών \(Changelog\)') {
            $passes += "✅ Σωστός κύριος τίτλος"
        } else {
            $issues += "❌ Λείπει ο σωστός κύριος τίτλος '# Αρχείο Αλλαγών (Changelog)'"
        }

        # 2. Έλεγχος αναφοράς σε Keep a Changelog
        if ($content -match 'Keep a Changelog.*keepachangelog\.com') {
            $passes += "✅ Αναφορά σε Keep a Changelog"
        } else {
            $issues += "❌ Λείπει αναφορά στο Keep a Changelog (https://keepachangelog.com/el/1.1.0/)"
        }

        # 3. Έλεγχος αναφοράς σε Semantic Versioning
        if ($content -match 'Semantic Versioning.*semver\.org') {
            $passes += "✅ Αναφορά σε Semantic Versioning"
        } else {
            $issues += "❌ Λείπει αναφορά στο Semantic Versioning (https://semver.org/spec/v2.0.0.html)"
        }

        # 4. Έλεγχος version entries format
        $versionPattern = '## \[(\d+\.\d+\.\d+)\] - (\d{4}-\d{2}-\d{2})'
        $versionMatches = [regex]::Matches($content, $versionPattern)

        if ($versionMatches.Count -eq 0) {
            $issues += "❌ Δεν βρέθηκαν έγκυρα version entries (format: ## [X.Y.Z] - YYYY-MM-DD)"
        } else {
            $passes += "✅ Βρέθηκαν $($versionMatches.Count) έγκυρα version entries"

            # Έλεγχος ημερομηνιών
            foreach ($match in $versionMatches) {
                $version = $match.Groups[1].Value
                $dateStr = $match.Groups[2].Value

                try {
                    $date = [DateTime]::ParseExact($dateStr, 'yyyy-MM-dd', $null)
                    if ($date -gt (Get-Date)) {
                        $warnings += "⚠️ Μελλοντική ημερομηνία για έκδοση $version ($dateStr)"
                    }
                } catch {
                    $issues += "❌ Άκυρη ημερομηνία για έκδοση $version ($dateStr)"
                }
            }
        }

        # 5. Έλεγχος sections με emojis
        $expectedSections = @(
            '### ✨ Προστέθηκαν',
            '### 🔄 Αλλαγές',
            '### ⚠️ Υποψήφια προς απόσυρση',
            '### ❌ Αφαιρέθηκαν',
            '### 🐛 Διορθώθηκαν',
            '### 🔒 Ασφάλεια',
            '### 📝 Τεκμηρίωση',
            '### 🔧 CI & Συντήρηση'
        )

        $foundSectionsWithEmojis = 0
        foreach ($section in $expectedSections) {
            if ($content -match [regex]::Escape($section)) {
                $foundSectionsWithEmojis++
            }
        }

        if ($foundSectionsWithEmojis -gt 0) {
            $passes += "✅ Βρέθηκαν $foundSectionsWithEmojis sections με emojis"
        }

        # 6. Έλεγχος για sections χωρίς emojis
        $sectionsWithoutEmojis = @(
            '### Προστέθηκαν',
            '### Αλλαγές',
            '### Διορθώθηκαν',
            '### Τεκμηρίωση',
            '### Αφαιρέθηκαν',
            '### Ασφάλεια'
        )

        $foundWithoutEmojis = 0
        foreach ($section in $sectionsWithoutEmojis) {
            if ($content -match "^$([regex]::Escape($section))$" -and
                $content -notmatch "^$([regex]::Escape($section.Insert(4, ' ✨|🔄|🐛|📝|❌|🔒')))") {
                $foundWithoutEmojis++
            }
        }

        if ($foundWithoutEmojis -gt 0) {
            $warnings += "⚠️ Βρέθηκαν $foundWithoutEmojis sections χωρίς emojis"
        }

        # 7. Έλεγχος για σωστή σειρά versions (descending)
        if ($versionMatches.Count -gt 1) {
            $versions = $versionMatches | ForEach-Object {
                [Version]$_.Groups[1].Value
            }

            $sortedVersions = $versions | Sort-Object -Descending
            $isCorrectOrder = $true

            for ($i = 0; $i -lt $versions.Count; $i++) {
                if ($versions[$i] -ne $sortedVersions[$i]) {
                    $isCorrectOrder = $false
                    break
                }
            }

            if ($isCorrectOrder) {
                $passes += "✅ Versions σε σωστή σειρά (descending)"
            } else {
                $issues += "❌ Versions δεν είναι σε σωστή σειρά (πρέπει να είναι descending)"
            }
        }

        # 8. Strict mode checks
        if ($Strict) {
            # Έλεγχος για κενές γραμμές μεταξύ sections
            $lines = $content -split "`r?`n"
            $inSection = $false
            $previousLineEmpty = $false

            for ($i = 0; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]

                if ($line -match '^### ') {
                    if ($inSection -and -not $previousLineEmpty) {
                        $warnings += "⚠️ Γραμμή $($i + 1): Προτείνεται κενή γραμμή πριν το section '$line'"
                    }
                    $inSection = $true
                }

                $previousLineEmpty = [string]::IsNullOrWhiteSpace($line)
            }

            # Έλεγχος για bullet points format
            $bulletPattern = '^- .+'
            $bulletMatches = [regex]::Matches($content, $bulletPattern, 'Multiline')
            if ($bulletMatches.Count -eq 0) {
                $warnings += "⚠️ Δεν βρέθηκαν bullet points (format: - item)"
            } else {
                $passes += "✅ Βρέθηκαν $($bulletMatches.Count) bullet points"
            }
        }

    } catch {
        $issues += "❌ Σφάλμα ανάλυσης αρχείου: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        FilePath = $FilePath
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
        Warnings = $warnings
        Passes = $passes
        Score = if ($issues.Count -eq 0 -and $warnings.Count -eq 0) { 100 }
                elseif ($issues.Count -eq 0) { 80 }
                else { [Math]::Max(0, 60 - ($issues.Count * 10)) }
    }
}

function Test-ReadmeStructure {
    <#
    .SYNOPSIS
    Ελέγχει τη δομή του README.md
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $issues = @()
    $warnings = @()
    $passes = @()

    try {
        if (-not (Test-Path $FilePath)) {
            $issues += "❌ Το αρχείο README.md δεν βρέθηκε"
            return [PSCustomObject]@{
                FilePath = $FilePath
                IsValid = $false
                Issues = $issues
                Warnings = $warnings
                Passes = $passes
                Score = 0
            }
        }

        $content = Get-Content $FilePath -Raw -Encoding UTF8

        # 1. Κύριος τίτλος
        if ($content -match '^# .+') {
            $passes += "✅ Υπάρχει κύριος τίτλος (H1)"
        } else {
            $issues += "❌ Λείπει κύριος τίτλος (# Title)"
        }

        # 2. Έλεγχος για βασικά sections
        $expectedSections = @(
            'Installation', 'Εγκατάσταση',
            'Usage', 'Χρήση', 'Παραδείγματα',
            'Features', 'Χαρακτηριστικά',
            'Documentation', 'Τεκμηρίωση'
        )

        $foundSections = 0
        foreach ($section in $expectedSections) {
            if ($content -match "## $section|### $section") {
                $foundSections++
            }
        }

        if ($foundSections -gt 0) {
            $passes += "✅ Βρέθηκαν $foundSections βασικά sections"
        } else {
            $warnings += "⚠️ Δεν βρέθηκαν βασικά sections (Installation, Usage, κλπ.)"
        }

        # 3. Έλεγχος για badges
        if ($content -match '!\[.*\]\(.*\)') {
            $passes += "✅ Περιέχει badges/images"
        } else {
            $warnings += "⚠️ Δεν περιέχει badges ή images"
        }

        # 4. Έλεγχος για code blocks
        if ($content -match '```') {
            $passes += "✅ Περιέχει code examples"
        } else {
            $warnings += "⚠️ Δεν περιέχει code examples"
        }

    } catch {
        $issues += "❌ Σφάλμα ανάλυσης README: $($_.Exception.Message)"
    }

    return [PSCustomObject]@{
        FilePath = $FilePath
        IsValid = ($issues.Count -eq 0)
        Issues = $issues
        Warnings = $warnings
        Passes = $passes
        Score = if ($issues.Count -eq 0 -and $warnings.Count -eq 0) { 100 }
                elseif ($issues.Count -eq 0) { 85 }
                else { [Math]::Max(0, 70 - ($issues.Count * 15)) }
    }
}

function Test-AllMarkdownFiles {
    <#
    .SYNOPSIS
    Ελέγχει όλα τα markdown αρχεία στο workspace
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [string]$WorkspacePath = "."
    )

    $results = @()

    # Βρες όλα τα .md αρχεία
    $mdFiles = Get-ChildItem -Path $WorkspacePath -Recurse -Filter "*.md" |
               Where-Object { $_.Name -ne "CHANGELOG.md" -and $_.Name -ne "README.md" }

    foreach ($file in $mdFiles) {
        Write-Verbose "📝 Ελέγχω $($file.FullName)"

        $issues = @()
        $warnings = @()
        $passes = @()

        try {
            $content = Get-Content $file.FullName -Raw -Encoding UTF8

            # Βασικοί έλεγχοι για markdown
            if ($content -match '^# .+') {
                $passes += "✅ Έχει κύριο τίτλο"
            } else {
                $warnings += "⚠️ Δεν έχει κύριο τίτλο (H1)"
            }

            if ($content.Length -lt 50) {
                $warnings += "⚠️ Πολύ μικρό περιεχόμενο (< 50 χαρακτήρες)"
            } else {
                $passes += "✅ Επαρκές περιεχόμενο"
            }

            # Έλεγχος για ελληνικά
            if ($content -match '[α-ωΑ-Ω]') {
                $passes += "✅ Περιέχει ελληνικό κείμενο"
            }

        } catch {
            $issues += "❌ Σφάλμα ανάλυσης: $($_.Exception.Message)"
        }

        $results += [PSCustomObject]@{
            FilePath = $file.FullName
            IsValid = ($issues.Count -eq 0)
            Issues = $issues
            Warnings = $warnings
            Passes = $passes
            Score = if ($issues.Count -eq 0 -and $warnings.Count -eq 0) { 100 }
                    elseif ($issues.Count -eq 0) { 75 }
                    else { 50 }
        }
    }

    return $results
}

function Show-TestResults {
    <#
    .SYNOPSIS
    Εμφανίζει τα αποτελέσματα των tests με χρώματα
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [PSCustomObject[]]$Results,
        [Parameter()]
        [switch]$ShowDetails
    )

    Write-Host "`n🎯 Αποτελέσματα Ελέγχου Markdown Format" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════════" -ForegroundColor Cyan

    $totalFiles = $Results.Count
    $validFiles = ($Results | Where-Object { $_.IsValid }).Count
    $avgScore = if ($totalFiles -gt 0) { [Math]::Round(($Results | Measure-Object Score -Average).Average, 1) } else { 0 }

    Write-Host "`n📊 Περίληψη:" -ForegroundColor Yellow
    Write-Host "  • Συνολικά αρχεία: $totalFiles"
    Write-Host "  • Έγκυρα αρχεία: $validFiles"
    Write-Host "  • Ποσοστό επιτυχίας: $([Math]::Round($validFiles / $totalFiles * 100, 1))%"
    Write-Host "  • Μέσος όρος score: $avgScore/100"

    foreach ($result in $Results) {
        $fileName = Split-Path $result.FilePath -Leaf
        $statusIcon = if ($result.IsValid) { "✅" } else { "❌" }
        $scoreColor = if ($result.Score -ge 90) { "Green" }
                     elseif ($result.Score -ge 70) { "Yellow" }
                     else { "Red" }

        Write-Host "`n$statusIcon $fileName " -NoNewline
        Write-Host "($($result.Score)/100)" -ForegroundColor $scoreColor

        if ($ShowDetails -or -not $result.IsValid) {
            if ($result.Issues.Count -gt 0) {
                Write-Host "   Issues:" -ForegroundColor Red
                $result.Issues | ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
            }

            if ($result.Warnings.Count -gt 0) {
                Write-Host "   Warnings:" -ForegroundColor Yellow
                $result.Warnings | ForEach-Object { Write-Host "     $_" -ForegroundColor Yellow }
            }

            if ($ShowDetails -and $result.Passes.Count -gt 0) {
                Write-Host "   Passes:" -ForegroundColor Green
                $result.Passes | ForEach-Object { Write-Host "     $_" -ForegroundColor Green }
            }
        }
    }
}

# ═══════════════════════════════════════════════════════════════════
# MAIN SCRIPT EXECUTION
# ═══════════════════════════════════════════════════════════════════

Write-Host "🧪 Έναρξη Comprehensive Markdown Format Validation" -ForegroundColor Green
Write-Host "══════════════════════════════════════════════════════" -ForegroundColor Green

$allResults = @()

# 1. Έλεγχος CHANGELOG.md
if (Test-Path $ChangelogPath) {
    Write-Verbose "📋 Ελέγχω CHANGELOG.md..."
    $changelogResult = Test-ChangelogStructure -FilePath $ChangelogPath -Strict:$Strict
    $allResults += $changelogResult
} else {
    Write-Warning "⚠️ Το αρχείο CHANGELOG.md δεν βρέθηκε στο: $ChangelogPath"
    $allResults += [PSCustomObject]@{
        FilePath = $ChangelogPath
        IsValid = $false
        Issues = @("❌ Το αρχείο δεν βρέθηκε")
        Warnings = @()
        Passes = @()
        Score = 0
    }
}

# 2. Έλεγχος README.md (αν ζητήθηκε)
if ($CheckReadme) {
    Write-Verbose "📖 Ελέγχω README.md..."
    $readmeResult = Test-ReadmeStructure -FilePath "./README.md"
    $allResults += $readmeResult
}

# 3. Έλεγχος όλων των markdown αρχείων (αν ζητήθηκε)
if ($CheckAllMarkdown) {
    Write-Verbose "📁 Ελέγχω όλα τα markdown αρχεία..."
    $allMdResults = Test-AllMarkdownFiles
    $allResults += $allMdResults
}

# 4. Εμφάνιση αποτελεσμάτων
$showDetails = $VerbosePreference -eq 'Continue'
Show-TestResults -Results $allResults -ShowDetails:$showDetails

# 5. Export αναφοράς (αν ζητήθηκε)
if ($ExportReport) {
    $reportPath = "./markdown-validation-report-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
    $report = [PSCustomObject]@{
        Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
        Parameters = @{
            ChangelogPath = $ChangelogPath
            CheckReadme = $CheckReadme.IsPresent
            CheckAllMarkdown = $CheckAllMarkdown.IsPresent
            Strict = $Strict.IsPresent
        }
        Results = $allResults
        Summary = @{
            TotalFiles = $allResults.Count
            ValidFiles = ($allResults | Where-Object { $_.IsValid }).Count
            AverageScore = if ($allResults.Count -gt 0) { [Math]::Round(($allResults | Measure-Object Score -Average).Average, 1) } else { 0 }
        }
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content $reportPath -Encoding UTF8
    Write-Host "`n📄 Αναφορά εξήχθη στο: $reportPath" -ForegroundColor Cyan
}

# 6. Return code για CI/CD
$hasErrors = ($allResults | Where-Object { -not $_.IsValid }).Count -gt 0
if ($hasErrors) {
    Write-Host "`n❌ Validation απέτυχε!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "`n✅ Όλοι οι έλεγχοι πέρασαν επιτυχώς!" -ForegroundColor Green
    exit 0
}
