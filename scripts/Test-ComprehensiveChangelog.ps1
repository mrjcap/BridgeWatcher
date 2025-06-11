<#
.SYNOPSIS
Comprehensive validation για CHANGELOG.md - μορφή ΚΑΙ περιεχόμενο commits

.DESCRIPTION
Αυτό το script συνδυάζει δύο τύπους validation:
1. Format Validation - ελέγχει τη μορφή του changelog (headers, sections, emojis)
2. Content Validation - ελέγχει ποια commits περιλαμβάνονται/εξαιρούνται

Παρέχει comprehensive αξιολόγηση του changelog quality.

.PARAMETER ChangelogPath
Η διαδρομή προς το CHANGELOG.md

.PARAMETER Version
Η έκδοση για την οποία θα γίνει ο έλεγχος

.PARAMETER IncludeFormatValidation
Αν ενεργοποιηθεί, κάνει και format validation

.PARAMETER IncludeContentValidation
Αν ενεργοποιηθεί, κάνει και content validation

.PARAMETER CheckReadme
Αν ενεργοποιηθεί, ελέγχει και το README.md

.PARAMETER Strict
Αν ενεργοποιηθεί, κάνει πιο αυστηρούς ελέγχους

.PARAMETER ExportReport
Αν ενεργοποιηθεί, εξάγει unified αναφορά

.EXAMPLE
.\Test-ComprehensiveChangelog.ps1

.EXAMPLE
.\Test-ComprehensiveChangelog.ps1 -Version "1.0.69" -Strict

.EXAMPLE
.\Test-ComprehensiveChangelog.ps1 -IncludeFormatValidation -IncludeContentValidation -ExportReport -Verbose

.NOTES
Αυτό είναι το "master" validation script που συνδυάζει όλους τους ελέγχους.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$ChangelogPath = "./CHANGELOG.md",

    [Parameter()]
    [string]$Version,

    [Parameter()]
    [switch]$IncludeFormatValidation,

    [Parameter()]
    [switch]$IncludeContentValidation,

    [Parameter()]
    [switch]$CheckReadme,

    [Parameter()]
    [switch]$Strict,

    [Parameter()]
    [switch]$ExportReport
)

function Invoke-FormatValidation {
    <#
    .SYNOPSIS
    Τρέχει το format validation script
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogPath,
        [Parameter()]
        [switch]$CheckReadme,
        [Parameter()]
        [switch]$Strict
    )

    Write-Verbose "🎨 Εκτέλεση Format Validation..."

    try {

        $formatArgs = @{
            "ChangelogPath" = $ChangelogPath
            "ExportReport" = $true
        }

        if ($CheckReadme) { $formatArgs["CheckReadme"] = $true }
        if ($Strict) { $formatArgs["Strict"] = $true }

        # Διαβάζουμε το JSON report
        if (Test-Path "markdown-validation-report-*.json") {
            $latestReport = Get-ChildItem "markdown-validation-report-*.json" |
                           Sort-Object LastWriteTime -Descending |
                           Select-Object -First 1

            $formatData = Get-Content $latestReport.FullName | ConvertFrom-Json
            Remove-Item $latestReport.FullName -ErrorAction SilentlyContinue

            return $formatData
        } else {
            throw "Δεν βρέθηκε format validation report"
        }
    } catch {
        Write-Warning "Format validation απέτυχε: $_"
        return $null
    }
}

function Invoke-ContentValidation {
    <#
    .SYNOPSIS
    Τρέχει το content validation script
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$ChangelogPath,
        [Parameter()]
        [string]$Version,
        [Parameter()]
        [switch]$Strict
    )

    Write-Verbose "📋 Εκτέλεση Content Validation..."

    try {
        $contentArgs = @{
            "ChangelogPath" = $ChangelogPath
            "ExportReport" = $true
        }

        if ($Version) { $contentArgs["Version"] = $Version }
        if ($Strict) { $contentArgs["Strict"] = $true }

        # Διαβάζουμε το JSON report
        if (Test-Path "commit-content-validation-report-*.json") {
            $latestReport = Get-ChildItem "commit-content-validation-report-*.json" |
                           Sort-Object LastWriteTime -Descending |
                           Select-Object -First 1

            $contentData = Get-Content $latestReport.FullName | ConvertFrom-Json
            Remove-Item $latestReport.FullName -ErrorAction SilentlyContinue

            return $contentData
        } else {
            throw "Δεν βρέθηκε content validation report"
        }
    } catch {
        Write-Warning "Content validation απέτυχε: $_"
        return $null
    }
}

function Show-ComprehensiveResult {
    <#
    .SYNOPSIS
    Εμφανίζει τα συνολικά αποτελέσματα
    #>
    [OutputType([int])]
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$FormatResults,
        [Parameter()]
        [PSCustomObject]$ContentResults
    )

    Write-Verbose "`n🎯 Comprehensive Changelog Validation Results"
    Write-Verbose "═══════════════════════════════════════════════════"

    $overallScore = 0
    $validationCount = 0

    # Format validation results
    if ($FormatResults) {
        $validationCount++
        $formatScore = if ($FormatResults.Summary) { $FormatResults.Summary.AverageScore } else { 0 }
        $overallScore += $formatScore

        Write-Verbose "`n📐 Format Validation:"
        Write-Verbose "   Score: $formatScore/100"
        Write-Verbose "   Valid Files: $($FormatResults.Summary.ValidFiles)/$($FormatResults.Summary.TotalFiles)"

        if ($formatScore -ge 90) {
            Write-Verbose "   Status: ✅ Εξαιρετικό"
        } elseif ($formatScore -ge 80) {
            Write-Verbose "   Status: ✅ Καλό"
        } elseif ($formatScore -ge 70) {
            Write-Verbose "   Status: ⚠️ Αποδεκτό"
        } else {
            Write-Verbose "   Status: ❌ Χρειάζεται βελτίωση"
        }
    }

    # Content validation results
    if ($ContentResults) {
        $validationCount++
        $contentScore = $ContentResults.Results.Score
        $overallScore += $contentScore

        Write-Verbose "`n📋 Content Validation:"
        Write-Verbose "   Score: $contentScore/100"
        Write-Verbose "   Version: $($ContentResults.Results.Version)"
        Write-Verbose "   Changelog Commits: $($ContentResults.Results.ChangelogCommits.Count)"
        Write-Verbose "   Actual Commits: $($ContentResults.Results.ActualCommits.Count)"
        Write-Verbose "   Issues: $($ContentResults.Results.TotalIssues)"
        Write-Verbose "   Warnings: $($ContentResults.Results.TotalWarnings)"

        if ($contentScore -ge 90) {
            Write-Verbose "   Status: ✅ Εξαιρετικό"
        } elseif ($contentScore -ge 80) {
            Write-Verbose "   Status: ✅ Καλό"
        } elseif ($contentScore -ge 70) {
            Write-Verbose "   Status: ⚠️ Αποδεκτό"
        } else {
            Write-Verbose "   Status: ❌ Χρειάζεται βελτίωση"
        }
    }

    # Overall assessment
    if ($validationCount -gt 0) {
        $averageScore = [Math]::Round($overallScore / $validationCount, 1)

        Write-Verbose "`n🏆 Συνολική Αξιολόγηση:"
        Write-Verbose "   Overall Score: $averageScore/100"

        if ($averageScore -ge 95) {
            Write-Verbose "   Grade: 🏆 A+ (Εξαιρετικό)"
        } elseif ($averageScore -ge 90) {
            Write-Verbose "   Grade: 🥇 A (Πολύ καλό)"
        } elseif ($averageScore -ge 80) {
            Write-Verbose "   Grade: 🥈 B (Καλό)"
        } elseif ($averageScore -ge 70) {
            Write-Verbose "   Grade: 🥉 C (Αποδεκτό)"
        } else {
            Write-Verbose "   Grade: ❌ F (Απαιτούνται βελτιώσεις)"
        }

        return $averageScore
    }

    return 0
}

function Show-Recommendation {
    <#
    .SYNOPSIS
    Δείχνει συστάσεις για βελτίωση
    #>
    [CmdletBinding()]
    param(
        [Parameter()]
        [PSCustomObject]$FormatResults,
        [Parameter()]
        [PSCustomObject]$ContentResults
    )

    Write-Verbose "`n💡 Συστάσεις για Βελτίωση:"

    $hasRecommendations = $false

    # Format recommendations
    if ($FormatResults -and $FormatResults.Summary.AverageScore -lt 90) {
        Write-Verbose "`n📐 Format Validation:"
        Write-Verbose "   • Τρέξτε: .\scripts\Update-ChangelogFormat.ps1 για auto-fix"
        Write-Verbose "   • Ελέγξτε τα emojis στα section headers"
        Write-Verbose "   • Βεβαιωθείτε ότι οι ημερομηνίες είναι σωστές"
        $hasRecommendations = $true
    }

    # Content recommendations
    if ($ContentResults -and $ContentResults.Results.Score -lt 90) {
        Write-Verbose "`n📋 Content Validation:"

        if ($ContentResults.Results.TotalIssues -gt 0) {
            Write-Verbose "   • Ελέγξτε τα exclusion patterns στο Get-GitCommitsSinceLastRelease.ps1"
            Write-Verbose "   • Βεβαιωθείτε ότι τα user-facing commits περιλαμβάνονται"
        }

        if ($ContentResults.Results.TotalWarnings -gt 0) {
            Write-Verbose "   • Εξετάστε τα commit patterns στο Convert-GreekChangelogCommitsToSections.ps1"
            Write-Verbose "   • Ελέγξτε αν χρειάζονται βελτιώσεις στην κατηγοριοποίηση"
        }

        $hasRecommendations = $true
    }

    if (-not $hasRecommendations) {
        Write-Verbose "   🎉 Δεν υπάρχουν συστάσεις - το changelog είναι εξαιρετικό!"
    }
}

# ═══════════════════════════════════════════════════════════════════
# MAIN SCRIPT EXECUTION
# ═══════════════════════════════════════════════════════════════════

Write-Verbose "🚀 Comprehensive Changelog Validation System"
Write-Verbose "═════════════════════════════════════════════════"

$formatResults = $null
$contentResults = $null

try {
    # 1. Format Validation
    if ($IncludeFormatValidation) {
        $formatResults = Invoke-FormatValidation -ChangelogPath $ChangelogPath -CheckReadme:$CheckReadme -Strict:$Strict
    }

    # 2. Content Validation
    if ($IncludeContentValidation) {
        $contentResults = Invoke-ContentValidation -ChangelogPath $ChangelogPath -Version $Version -Strict:$Strict
    }

    # 3. Combined Results
    $overallScore = Show-ComprehensiveResults -FormatResults $formatResults -ContentResults $contentResults

    # 4. Recommendations
    Show-Recommendations -FormatResults $formatResults -ContentResults $contentResults

    # 5. Export unified report
    if ($ExportReport) {
        $reportPath = "./comprehensive-changelog-validation-$(Get-Date -Format 'yyyyMMdd-HHmmss').json"
        $unifiedReport = [PSCustomObject]@{
            Timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
            Parameters = @{
                ChangelogPath = $ChangelogPath
                Version = $Version
                IncludeFormatValidation = $IncludeFormatValidation.IsPresent
                IncludeContentValidation = $IncludeContentValidation.IsPresent
                CheckReadme = $CheckReadme.IsPresent
                Strict = $Strict.IsPresent
            }
            Results = @{
                FormatValidation = $formatResults
                ContentValidation = $contentResults
                OverallScore = $overallScore
            }
        }

        $unifiedReport | ConvertTo-Json -Depth 15 | Set-Content $reportPath -Encoding UTF8
        Write-Verbose "`n📄 Unified report εξήχθη στο: $reportPath"
    }

    # 6. Exit code για CI/CD
    $hasIssues = $false

    if ($formatResults -and $formatResults.Summary.ValidFiles -lt $formatResults.Summary.TotalFiles) {
        $hasIssues = $true
    }

    if ($contentResults -and $contentResults.Results.TotalIssues -gt 0) {
        $hasIssues = $true
    }

    if ($hasIssues) {
        Write-Verbose "`n❌ Comprehensive validation βρήκε issues!"
        exit 1
    } else {
        Write-Verbose "`n✅ Comprehensive validation πέρασε επιτυχώς!"
        exit 0
    }

} catch {
    Write-Error "❌ Σφάλμα comprehensive validation: $($_.Exception.Message)"
    exit 1
}
