<#
.SYNOPSIS
Demo script που δείχνει πώς να χρησιμοποιείτε το Test-ChangelogFormatValidation.ps1

.DESCRIPTION
Αυτό το script παρέχει παραδείγματα χρήσης του comprehensive changelog format validator
με διάφορες επιλογές και σενάρια.

.EXAMPLE
.\Demo-ChangelogValidation.ps1

.NOTES
Χρήσιμο για να δείτε όλες τις δυνατότητες του validation system.
#>

[CmdletBinding()]
param()

Write-Host "🎯 Demo: Comprehensive Changelog Format Validation" -ForegroundColor Cyan
Write-Host "════════════════════════════════════════════════════" -ForegroundColor Cyan

Write-Host "`n📚 Διαθέσιμες επιλογές:" -ForegroundColor Yellow
Write-Host "1. Βασικός έλεγχος CHANGELOG.md" -ForegroundColor White
Write-Host "2. Έλεγχος με README.md" -ForegroundColor White
Write-Host "3. Έλεγχος όλων των markdown αρχείων" -ForegroundColor White
Write-Host "4. Strict mode (πιο αυστηροί έλεγχοι)" -ForegroundColor White
Write-Host "5. Εξαγωγή αναφοράς JSON" -ForegroundColor White
Write-Host "6. Εκτέλεση όλων των παραπάνω" -ForegroundColor White
Write-Host "0. Έξοδος" -ForegroundColor Red

do {
    $choice = Read-Host "`nΕπιλέξτε μια επιλογή (0-6)"

    switch ($choice) {
        "1" {
            Write-Host "`n🔍 Εκτέλεση: Βασικός έλεγχος CHANGELOG.md" -ForegroundColor Green
            Write-Host "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1" -ForegroundColor Gray
            & ".\scripts\Test-ChangelogFormatValidation.ps1"
        }

        "2" {
            Write-Host "`n🔍 Εκτέλεση: Έλεγχος με README.md" -ForegroundColor Green
            Write-Host "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -CheckReadme" -ForegroundColor Gray
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -CheckReadme
        }

        "3" {
            Write-Host "`n🔍 Εκτέλεση: Έλεγχος όλων των markdown αρχείων" -ForegroundColor Green
            Write-Host "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -CheckAllMarkdown" -ForegroundColor Gray
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -CheckAllMarkdown
        }

        "4" {
            Write-Host "`n🔍 Εκτέλεση: Strict mode" -ForegroundColor Green
            Write-Host "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -Strict -Verbose" -ForegroundColor Gray
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -Strict -Verbose
        }

        "5" {
            Write-Host "`n🔍 Εκτέλεση: Εξαγωγή αναφοράς JSON" -ForegroundColor Green
            Write-Host "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -ExportReport" -ForegroundColor Gray
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -ExportReport

            # Εμφάνιση των διαθέσιμων αναφορών
            $reports = Get-ChildItem -Filter "markdown-validation-report-*.json" | Sort-Object LastWriteTime -Descending
            if ($reports) {
                Write-Host "`n📄 Διαθέσιμες αναφορές:" -ForegroundColor Cyan
                $reports | Select-Object -First 5 | ForEach-Object {
                    Write-Host "  • $($_.Name) ($(Get-Date $_.LastWriteTime -Format 'HH:mm:ss'))" -ForegroundColor White
                }
            }
        }

        "6" {
            Write-Host "`n🔍 Εκτέλεση: Πλήρης έλεγχος με όλες τις επιλογές" -ForegroundColor Green
            Write-Host "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -CheckReadme -CheckAllMarkdown -Strict -ExportReport -Verbose" -ForegroundColor Gray
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -CheckReadme -CheckAllMarkdown -Strict -ExportReport -Verbose
        }

        "0" {
            Write-Host "`n👋 Τέλος demo!" -ForegroundColor Green
            break
        }

        default {
            Write-Host "`n❌ Άκυρη επιλογή. Παρακαλώ επιλέξτε 0-6." -ForegroundColor Red
        }
    }

    if ($choice -ne "0") {
        Write-Host "`n" + "─" * 50 -ForegroundColor Gray
        Read-Host "Πατήστε Enter για να συνεχίσετε"
    }

} while ($choice -ne "0")

Write-Host "`n📋 Χρήσιμες πληροφορίες:" -ForegroundColor Yellow
Write-Host "• Το script ελέγχει τη μορφή Keep a Changelog (https://keepachangelog.com/el/1.1.0/)" -ForegroundColor White
Write-Host "• Επαληθεύει Semantic Versioning (https://semver.org/spec/v2.0.0.html)" -ForegroundColor White
Write-Host "• Ελέγχει για ελληνικούς τίτλους με emojis" -ForegroundColor White
Write-Host "• Παράγει αναφορές σε JSON format για CI/CD integration" -ForegroundColor White
Write-Host "• Υποστηρίζει exit codes για automated workflows" -ForegroundColor White

Write-Host "`n🛠️ Integration σε CI/CD:" -ForegroundColor Yellow
Write-Host @"
# GitHub Actions example:
- name: Validate Changelog Format
  run: |
    .\scripts\Test-ChangelogFormatValidation.ps1 -CheckAllMarkdown -ExportReport
    if ($LASTEXITCODE -ne 0) { exit 1 }

# PowerShell script example:
$result = & .\scripts\Test-ChangelogFormatValidation.ps1 -CheckReadme
if ($LASTEXITCODE -ne 0) {
    Write-Error "Changelog validation failed!"
    exit 1
}
"@ -ForegroundColor Gray
