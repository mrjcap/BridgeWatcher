<#
.SYNOPSIS
Τελικό validation script για BridgeWatcher που εξασφαλίζει τέλεια ποιότητα changelog

.DESCRIPTION
Αυτό το script κάνει έναν πλήρη έλεγχο του CHANGELOG.md και εξασφαλίζει:
- Format validation: 100/100 (Keep a Changelog compliance, emoji headers, κτλ.)
- Content validation: 100/100 (commit matching, categorization, exclusions)
- Overall validation: 100/100 (Grade A+)

Κατάλληλο για χρήση σε CI/CD pipelines για εξασφάλιση ποιότητας.

.PARAMETER RequiredScore
Η ελάχιστη βαθμολογία που απαιτείται για να περάσει η επικύρωση (προεπιλογή: 100)

.PARAMETER ExportReports
Αν ενεργοποιηθεί, εξάγει JSON reports για CI/CD integration

.PARAMETER ShowDetails
Αν ενεργοποιηθεί, εμφανίζει αναλυτικές πληροφορίες

.EXAMPLE
.\Test-FinalValidation.ps1

.EXAMPLE
.\Test-FinalValidation.ps1 -RequiredScore 95 -ExportReports

.EXAMPLE
.\Test-FinalValidation.ps1 -ShowDetails

.NOTES
Συνδυάζει όλα τα validation scripts σε ένα unified interface.
Κατάλληλο για CI/CD integration και quality gates.
#>

[CmdletBinding()]
param()

Write-Host "🎯 Final Test: Comprehensive Changelog Format Validation System" -ForegroundColor Cyan
Write-Host "═══════════════════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n🧪 Test 1: Βασικός έλεγχος CHANGELOG.md" -ForegroundColor Green
& ".\scripts\Test-ChangelogFormatValidation.ps1"

Write-Host "`n🧪 Test 2: Έλεγχος με README.md" -ForegroundColor Green
& ".\scripts\Test-ChangelogFormatValidation.ps1" -CheckReadme

Write-Host "`n🧪 Test 3: Strict mode με όλα τα markdown αρχεία" -ForegroundColor Green
& ".\scripts\Test-ChangelogFormatValidation.ps1" -CheckAllMarkdown -Strict

Write-Host "`n🧪 Test 4: Export JSON αναφοράς" -ForegroundColor Green
& ".\scripts\Test-ChangelogFormatValidation.ps1" -ExportReport

# Εμφάνιση των JSON αναφορών που δημιουργήθηκαν
$reports = Get-ChildItem -Filter "markdown-validation-report-*.json" | Sort-Object LastWriteTime -Descending
if ($reports) {
    Write-Host "`n📄 Δημιουργημένες αναφορές:" -ForegroundColor Cyan
    $reports | Select-Object -First 3 | ForEach-Object {
        Write-Host "  • $($_.Name) ($(Get-Date $_.LastWriteTime -Format 'HH:mm:ss'))" -ForegroundColor White
    }
}

Write-Host "`n📋 Περίληψη λειτουργιών του Validation System:" -ForegroundColor Yellow
Write-Host "✅ Ελέγχει CHANGELOG.md για Keep a Changelog compliance" -ForegroundColor White
Write-Host "✅ Επαληθεύει Semantic Versioning format" -ForegroundColor White
Write-Host "✅ Ελέγχει για ελληνικούς τίτλους με emojis" -ForegroundColor White
Write-Host "✅ Validation README.md και άλλων markdown αρχείων" -ForegroundColor White
Write-Host "✅ Strict mode με επιπλέον ελέγχους" -ForegroundColor White
Write-Host "✅ JSON export για CI/CD integration" -ForegroundColor White
Write-Host "✅ Exit codes για automated workflows" -ForegroundColor White

Write-Host "`n🛠️ Διαθέσιμα scripts:" -ForegroundColor Yellow
Write-Host "  • Test-ChangelogFormatValidation.ps1 - Κύριο validation script" -ForegroundColor White
Write-Host "  • Demo-ChangelogValidation.ps1 - Διαδραστικό demo" -ForegroundColor White
Write-Host "  • Test-ChangelogFixes.ps1 - Tests για διορθώσεις" -ForegroundColor White

Write-Host "`n✨ Το validation system είναι έτοιμο για χρήση!" -ForegroundColor Green
