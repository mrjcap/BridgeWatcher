function Test-ChangelogWorkflow {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Δοκιμάζει το changelog workflow τοπικά πριν το deployment.

    .DESCRIPTION
    Η Test-ChangelogWorkflow εκτελεί όλα τα βήματα του changelog generation
    τοπικά για επαλήθευση της λειτουργικότητας.

    .PARAMETER TestVersion
    Η έκδοση test που θα χρησιμοποιηθεί.

    .PARAMETER DryRun
    Αν ενεργοποιηθεί, δεν κάνει πραγματικές αλλαγές.

    .OUTPUTS
    [PSCustomObject] Αποτελέσματα του test.

    .EXAMPLE
    Test-ChangelogWorkflow -TestVersion '1.0.99' -DryRun

    .EXAMPLE
    Test-ChangelogWorkflow -TestVersion '1.0.99' -Verbose

    .NOTES
    Χρήσιμο για debugging του workflow πριν το GitHub Actions.
    #>
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$TestVersion,

        [switch]$DryRun
    )

    begin {
        $results = [PSCustomObject]@{
            Success             = $false
            Steps               = @()
            LastTag             = $null
            CommitsFound        = 0
            ChangelogUpdated    = $false
            Errors              = @()
        }

        Write-Verbose "🚀 Ξεκινάει test του changelog workflow..."
    }

    process {
        try {
            # Βήμα 1:Εύρεση τελευταίου tag
            Write-Verbose "📍 Βήμα 1: Εύρεση τελευταίου tag"
            $lastTag            = git describe --tags --abbrev    = 0 2>$null
            $results.LastTag    = $lastTag

            if ($lastTag) {
                Write-Host "✅ Τελευταίο tag: $lastTag" -ForegroundColor Green
                $results.Steps    += "✅ Βρέθηκε τελευταίο tag: $lastTag"
            } else {
                Write-Host "⚠️ Δεν βρέθηκε τελευταίο tag - πρώτο release" -ForegroundColor Yellow
                $results.Steps    += "⚠️ Πρώτο release (δεν υπάρχει tag)"
            }

            # Βήμα 2:Έλεγχος commits
            Write-Verbose "📊 Βήμα 2: Έλεγχος νέων commits"
            if ($lastTag) {
                $commitCount             = git rev-list --count "$lastTag..HEAD"
                $results.CommitsFound    = [int]$commitCount

                if ([int]$commitCount -gt 0) {
                    Write-Host "📝 Βρέθηκαν $commitCount νέα commits:" -ForegroundColor Cyan
                    git log --oneline "$lastTag..HEAD" | ForEach-Object {
                        Write-Host "  • $_" -ForegroundColor White
                    }
                    $results.Steps    += "✅ Βρέθηκαν $commitCount νέα commits"
                } else {
                    Write-Host "ℹ️ Δεν υπάρχουν νέα commits" -ForegroundColor Blue
                    $results.Steps    += "ℹ️ Δεν υπάρχουν νέα commits"
                    return $results
                }
            } else {
                # Πρώτο release - μέτρα όλα τα commits
                $commitCount             = git rev-list --count HEAD
                $results.CommitsFound    = [int]$commitCount
                Write-Host "📝 Πρώτο release - $commitCount συνολικά commits" -ForegroundColor Cyan
                $results.Steps    += "✅ Πρώτο release με $commitCount commits"
            }

            # Βήμα 3:Test του changelog generation
            Write-Verbose "📝 Βήμα 3: Test changelog generation"
            if (-not $DryRun) {
                if (Test-Path './scripts/Update-ReleaseChangeLog.ps1') {
                    Write-Host "🔧 Εκτέλεση Update-ReleaseChangeLog..." -ForegroundColor Yellow

                    $updateSplat = @{
                        Version    = $TestVersion
                        Verbose    = $true
                    }

                    & ./scripts/Update-ReleaseChangeLog.ps1 @updateSplat

                    if (Test-Path './changelog_updated.flag') {
                        $flagContent                 = Get-Content './changelog_updated.flag' -Raw
                        $results.ChangelogUpdated    = $flagContent.Trim() -eq 'true'

                        if ($results.ChangelogUpdated) {
                            Write-Host "✅ Changelog ενημερώθηκε επιτυχώς" -ForegroundColor Green
                            $results.Steps    += "✅ Changelog generation επιτυχές"
                        } else {
                            Write-Host "ℹ️ Changelog δεν χρειαζόταν ενημέρωση" -ForegroundColor Blue
                            $results.Steps    += "ℹ️ Changelog ήδη ενημερωμένο"
                        }
                    }
                } else {
                    $errorMSG           = "❌ Δεν βρέθηκε το script Update-ReleaseChangeLog.ps1"
                    $results.Errors    += $errorMSG
                    Write-Error $errorMSG
                }
            } else {
                Write-Host "🔍 DryRun: Θα εκτελούνταν Update-ReleaseChangeLog" -ForegroundColor Magenta
                $results.Steps    += "🔍 DryRun: Changelog generation (simulated)"
            }

            # Βήμα 4:Validation
            Write-Verbose "🔍 Βήμα 4: Validation changelog format"
            if ((Test-Path './CHANGELOG.md') -and (Test-Path './scripts/Update-ChangelogFormat.ps1')) {
                . './scripts/Update-ChangelogFormat.ps1'
                $validationResult    = Test-ChangelogFormat -ChangelogPath './CHANGELOG.md'

                if ($validationResult.IsValid) {
                    Write-Host "✅ Changelog format έγκυρο" -ForegroundColor Green
                    $results.Steps    += "✅ Changelog validation πέρασε"
                } else {
                    Write-Host "⚠️ Changelog format χρειάζεται βελτιώσεις:" -ForegroundColor Yellow
                    $validationResult.Issues | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
                    $validationResult.Warnings | ForEach-Object { Write-Host "  • $_" -ForegroundColor Yellow }
                    $results.Steps    += "⚠️ Changelog format χρειάζεται βελτιώσεις"
                }
            }

            $results.Success    = $results.Errors.Count -eq 0

        } catch {
            $errorMSG           = "❌ Σφάλμα: $($_.Exception.Message)"
            $results.Errors    += $errorMSG
            Write-Error $errorMSG
        } finally {
            # Cleanup
            Remove-Item './changelog_updated.flag' -ErrorAction SilentlyContinue
        }
    }

    end {
        Write-Host "`n📊 Περίληψη Test:" -ForegroundColor Yellow
        Write-Host "  • Τελευταίο tag: $(if ($results.LastTag) { $results.LastTag } else { 'N/A' })" -ForegroundColor White
        Write-Host "  • Νέα commits: $($results.CommitsFound)" -ForegroundColor White
        Write-Host "  • Changelog ενημερώθηκε: $(if ($results.ChangelogUpdated) { 'Ναι' } else { 'Όχι' })" -ForegroundColor White
        Write-Host "  • Αποτέλεσμα: $(if ($results.Success) { '✅ Επιτυχία' } else { '❌ Αποτυχία' })" -ForegroundColor $(if ($results.Success) { 'Green' } else { 'Red' })

        if ($results.Errors) {
            Write-Host "`n❌ Σφάλματα:" -ForegroundColor Red
            $results.Errors | ForEach-Object { Write-Host "  • $_" -ForegroundColor Red }
        }

        return $results
    }
}

function Compare-ChangelogApproaches {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Συγκρίνει τις δύο προσεγγίσεις changelog generation.

    .DESCRIPTION
    Η Compare-ChangelogApproaches αναλύει τα πλεονεκτήματα και μειονεκτήματα
    κάθε προσέγγισης για να βοηθήσει στην επιλογή.

    .OUTPUTS
    [PSCustomObject] Σύγκριση των προσεγγίσεων.

    .EXAMPLE
    Compare-ChangelogApproaches | Format-Table -AutoSize

    .NOTES
    Χρήσιμο για την επιλογή της κατάλληλης στρατηγικής.
    #>
    param()

    $comparison = @(
        [PSCustomObject]@{
            Κριτήριο      = 'Έλεγχος Περιεχομένου'
            PowerShell    = '🟢 Πλήρης έλεγχος'
            mikepenz      = '🟡 Περιορισμένος'
            Σύσταση       = 'PowerShell για custom needs'
        },
        [PSCustomObject]@{
            Κριτήριο      = 'Ελληνικά Μηνύματα'
            PowerShell    = '🟢 Native support'
            mikepenz      = '🟡 Regex rules'
            Σύσταση       = 'PowerShell για πλήρη ελληνικά'
        },
        [PSCustomObject]@{
            Κριτήριο      = 'Διατήρηση Παλιών'
            PowerShell    = '🟢 Εγγυημένη'
            mikepenz      = '⚠️ Εξαρτάται από mode'
            Σύσταση       = 'PowerShell για ασφάλεια'
        },
        [PSCustomObject]@{
            Κριτήριο      = 'Setup Complexity'
            PowerShell    = '🟡 Μέτρια'
            mikepenz      = '🟢 Απλό'
            Σύσταση       = 'mikepenz για απλότητα'
        },
        [PSCustomObject]@{
            Κριτήριο      = 'Debugging'
            PowerShell    = '🟢 Εύκολο'
            mikepenz      = '🔴 Δύσκολο'
            Σύσταση       = 'PowerShell για development'
        },
        [PSCustomObject]@{
            Κριτήριο      = 'Maintenance'
            PowerShell    = '🟡 Manual updates'
            mikepenz      = '🟢 Auto-maintained'
            Σύσταση       = 'mikepenz για production'
        },
        [PSCustomObject]@{
            Κριτήριο      = 'Performance'
            PowerShell    = '🟢 Γρήγορο'
            mikepenz      = '🟡 Μέτριο'
            Σύσταση       = 'PowerShell για μεγάλα repos'
        }
    )

    Write-Host "📊 Σύγκριση Προσεγγίσεων Changelog Generation`n" -ForegroundColor Cyan

    return $comparison
}

# Εκτέλεση demonstration αν το script καλείται απευθείας
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "🎯 BridgeWatcher Changelog Workflow Analysis`n" -ForegroundColor Green

    # Εμφάνιση σύγκρισης
    $comparison    = Compare-ChangelogApproaches
    $comparison | Format-Table -AutoSize

    Write-Host "`n💡 Συστάσεις:" -ForegroundColor Yellow
    Write-Host "• Για το BridgeWatcher: Χρησιμοποιήστε Custom PowerShell" -ForegroundColor Green
    Write-Host "• Λόγος: Πλήρης έλεγχος ελληνικών και διατήρηση παλιών εγγραφών" -ForegroundColor White
    Write-Host "• Alternative: mikepenz με PREPEND mode για απλότητα" -ForegroundColor Cyan

    Write-Host "`n🧪 Για local testing εκτελέστε:" -ForegroundColor Magenta
    Write-Host "Test-ChangelogWorkflow -TestVersion '1.0.99' -DryRun -Verbose" -ForegroundColor White
}