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

Write-Verbose "🎯 Demo: Comprehensive Changelog Format Validation"
Write-Verbose "════════════════════════════════════════════════════"

Write-Verbose "`n📚 Διαθέσιμες επιλογές:"
Write-Verbose "1. Βασικός έλεγχος CHANGELOG.md"
Write-Verbose "2. Έλεγχος με README.md"
Write-Verbose "3. Έλεγχος όλων των markdown αρχείων"
Write-Verbose "4. Strict mode (πιο αυστηροί έλεγχοι)"
Write-Verbose "5. Εξαγωγή αναφοράς JSON"
Write-Verbose "6. Εκτέλεση όλων των παραπάνω"
Write-Verbose "0. Έξοδος"

do {
    $choice = Read-Host "`nΕπιλέξτε μια επιλογή (0-6)"

    switch ($choice) {
        "1" {
            Write-Verbose "`n🔍 Εκτέλεση: Βασικός έλεγχος CHANGELOG.md"
            Write-Verbose "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1"
            & ".\scripts\Test-ChangelogFormatValidation.ps1"
        }

        "2" {
            Write-Verbose "`n🔍 Εκτέλεση: Έλεγχος με README.md"
            Write-Verbose "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -CheckReadme"
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -CheckReadme
        }

        "3" {
            Write-Verbose "`n🔍 Εκτέλεση: Έλεγχος όλων των markdown αρχείων"
            Write-Verbose "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -CheckAllMarkdown"
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -CheckAllMarkdown
        }

        "4" {
            Write-Verbose "`n🔍 Εκτέλεση: Strict mode"
            Write-Verbose "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -Strict -Verbose"
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -Strict -Verbose
        }

        "5" {
            Write-Verbose "`n🔍 Εκτέλεση: Εξαγωγή αναφοράς JSON"
            Write-Verbose "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -ExportReport"
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -ExportReport

            # Εμφάνιση των διαθέσιμων αναφορών
            $reports = Get-ChildItem -Filter "markdown-validation-report-*.json" | Sort-Object LastWriteTime -Descending
            if ($reports) {
                Write-Verbose "`n📄 Διαθέσιμες αναφορές:"
                $reports | Select-Object -First 5 | ForEach-Object {
                    Write-Verbose "  • $($_.Name) ($(Get-Date $_.LastWriteTime -Format 'HH:mm:ss'))"
                }
            }
        }

        "6" {
            Write-Verbose "`n🔍 Εκτέλεση: Πλήρης έλεγχος με όλες τις επιλογές"
            Write-Verbose "Εντολή: .\scripts\Test-ChangelogFormatValidation.ps1 -CheckReadme -CheckAllMarkdown -Strict -ExportReport -Verbose"
            & ".\scripts\Test-ChangelogFormatValidation.ps1" -CheckReadme -CheckAllMarkdown -Strict -ExportReport -Verbose
        }

        "0" {
            Write-Verbose "`n👋 Τέλος demo!"
            break
        }

        default {
            Write-Verbose "`n❌ Άκυρη επιλογή. Παρακαλώ επιλέξτε 0-6."
        }
    }

    if ($choice -ne "0") {
        Read-Host "Πατήστε Enter για να συνεχίσετε"
    }

} while ($choice -ne "0")

Write-Verbose "`n📋 Χρήσιμες πληροφορίες:"
Write-Verbose "• Το script ελέγχει τη μορφή Keep a Changelog (https://keepachangelog.com/el/1.1.0/)"
Write-Verbose "• Επαληθεύει Semantic Versioning (https://semver.org/spec/v2.0.0.html)"
Write-Verbose "• Ελέγχει για ελληνικούς τίτλους με emojis"
Write-Verbose "• Παράγει αναφορές σε JSON format για CI/CD integration"
Write-Verbose "• Υποστηρίζει exit codes για automated workflows"

Write-Verbose "`n🛠️ Integration σε CI/CD:"
Write-Verbose @"
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
"@
