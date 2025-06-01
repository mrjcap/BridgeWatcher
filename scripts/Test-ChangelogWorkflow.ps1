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
    [OutputType([PSCustomObject])]
    param (
        [Parameter(Mandatory)]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$TestVersion,

        [switch]$DryRun
    )

    begin {
        $results = [PSCustomObject]@{
            Success = $false
            Steps = @()
            LastTag = $null
            CommitsFound = 0
            ChangelogUpdated = $false
            Errors = @()
        }

        Write-Verbose "🚀 Ξεκινάει test του changelog workflow..."
    }

    process {
        try {
            # Βήμα 1: Εύρεση τελευταίου tag
            Write-Verbose "📍 Βήμα 1: Εύρεση τελευταίου tag"
            $lastTag = git describe --tags --abbrev=0 2>$null
            $results.LastTag = $lastTag
            
            if ($lastTag) {
                Write-Verbose "✅ Τελευταίο tag: $lastTag"
                $results.Steps += "✅ Βρέθηκε τελευταίο tag: $lastTag"
            } else {
                Write-Warning "⚠️ Δεν βρέθηκε τελευταίο tag - πρώτο release"
                $results.Steps += "⚠️ Πρώτο release (δεν υπάρχει tag)"
            }

            # Βήμα 2: Έλεγχος commits
            Write-Verbose "📊 Βήμα 2: Έλεγχος νέων commits"
            if ($lastTag) {
                $commitCount = git rev-list --count "$lastTag..HEAD"
                $results.CommitsFound = [int]$commitCount
                
                if ([int]$commitCount -gt 0) {
                    Write-Verbose "📝 Βρέθηκαν $commitCount νέα commits:"
                    git log --oneline "$lastTag..HEAD" | ForEach-Object { 
                        Write-Verbose "  • $_"
                    }
                    $results.Steps += "✅ Βρέθηκαν $commitCount νέα commits"
                } else {
                    Write-Verbose "ℹ️ Δεν υπάρχουν νέα commits"
                    $results.Steps += "ℹ️ Δεν υπάρχουν νέα commits"
                    return $results
                }
            } else {
                # Πρώτο release - μέτρα όλα τα commits
                $commitCount = git rev-list --count HEAD
                $results.CommitsFound = [int]$commitCount
                Write-Verbose "📝 Πρώτο release - $commitCount συνολικά commits"
                $results.Steps += "✅ Πρώτο release με $commitCount commits"
            }

            # Βήμα 3: Test του changelog generation
            Write-Verbose "📝 Βήμα 3: Test changelog generation"
            if (-not $DryRun) {
                if (Test-Path './scripts/Update-ReleaseChangeLog.ps1') {
                    Write-Verbose "🔧 Εκτέλεση Update-ReleaseChangeLog..."
                    
                    $updateSplat = @{
                        Version = $TestVersion
                        Verbose = $true
                    }
                    
                    & ./scripts/Update-ReleaseChangeLog.ps1 @updateSplat
                    
                    if (Test-Path './changelog_updated.flag') {
                        $flagContent = Get-Content './changelog_updated.flag' -Raw
                        $results.ChangelogUpdated = $flagContent.Trim() -eq 'true'
                        
                        if ($results.ChangelogUpdated) {
                            Write-Verbose "✅ Changelog ενημερώθηκε επιτυχώς"
                            $results.Steps += "✅ Changelog generation επιτυχές"
                        } else {
                            Write-Verbose "ℹ️ Changelog δεν χρειαζόταν ενημέρωση"
                            $results.Steps += "ℹ️ Changelog ήδη ενημερωμένο"
                        }
                    }
                } else {
                    $errorMSG = "❌ Δεν βρέθηκε το script Update-ReleaseChangeLog.ps1"
                    $results.Errors += $errorMSG
                    Write-Error $errorMSG
                }
            } else {
                Write-Verbose "🔍 DryRun: Θα εκτελούνταν Update-ReleaseChangeLog"
                $results.Steps += "🔍 DryRun: Changelog generation (simulated)"
            }

            # Βήμα 4: Validation
            Write-Verbose "🔍 Βήμα 4: Validation changelog format"
            if (Test-Path './CHANGELOG.md' -and (Test-Path './scripts/Update-ChangelogFormat.ps1')) {
                . './scripts/Update-ChangelogFormat.ps1'
                $validationResult = Test-ChangelogFormat -ChangelogPath './CHANGELOG.md'
                
                if ($validationResult.IsValid) {
                    Write-Verbose "✅ Changelog format έγκυρο"
                    $results.Steps += "✅ Changelog validation πέρασε"
                } else {
                    Write-Warning "⚠️ Changelog format χρειάζεται βελτιώσεις:"
                    $validationResult.Issues | ForEach-Object { Write-Warning "  • $_" }
                    $validationResult.Warnings | ForEach-Object { Write-Warning "  • $_" }
                    $results.Steps += "⚠️ Changelog format χρειάζεται βελτιώσεις"
                }
            }

            $results.Success = $results.Errors.Count -eq 0

        } catch {
            $errorMSG = "❌ Σφάλμα: $($_.Exception.Message)"
            $results.Errors += $errorMSG
            Write-Error $errorMSG
        } finally {
            # Cleanup
            Remove-Item './changelog_updated.flag' -ErrorAction SilentlyContinue
        }
    }

    end {
        Write-Verbose "`n📊 Περίληψη Test:"
        Write-Verbose "  • Τελευταίο tag: $(if ($results.LastTag) { $results.LastTag } else { 'N/A' })"
        Write-Verbose "  • Νέα commits: $($results.CommitsFound)"
        Write-Verbose "  • Changelog ενημερώθηκε: $(if ($results.ChangelogUpdated) { 'Ναι' } else { 'Όχι' })"
        
        if ($results.Success) {
            Write-Verbose "  • Αποτέλεσμα: ✅ Επιτυχία"
        } else {
            Write-Error "  • Αποτέλεσμα: ❌ Αποτυχία"
        }

        if ($results.Errors) {
            Write-Error "`n❌ Σφάλματα:"
            $results.Errors | ForEach-Object { Write-Error "  • $_" }
        }

        return $results
    }
}

function Compare-ChangelogApproach {
    [CmdletBinding()]
    <#
    .SYNOPSIS
    Συγκρίνει τις δύο προσεγγίσεις changelog generation.

    .DESCRIPTION
    Η Compare-ChangelogApproach αναλύει τα πλεονεκτήματα και μειονεκτήματα
    κάθε προσέγγισης για να βοηθήσει στην επιλογή.

    .OUTPUTS
    [PSCustomObject[]] Σύγκριση των προσεγγίσεων.

    .EXAMPLE
    Compare-ChangelogApproach | Format-Table -AutoSize

    .NOTES
    Χρήσιμο για την επιλογή της κατάλληλης στρατηγικής.
    #>
    [OutputType([PSCustomObject[]])]
    param()

    $comparison = @(
        [PSCustomObject]@{
            Κριτήριο = 'Έλεγχος Περιεχομένου'
            PowerShell = '🟢 Πλήρης έλεγχος'
            mikepenz = '🟡 Περιορισμένος'
            Σύσταση = 'PowerShell για custom needs'
        },
        [PSCustomObject]@{
            Κριτήριο = 'Ελληνικά Μηνύματα'
            PowerShell = '🟢 Native support'
            mikepenz = '🟡 Regex rules'
            Σύσταση = 'PowerShell για πλήρη ελληνικά'
        },
        [PSCustomObject]@{
            Κριτήριο = 'Διατήρηση Παλιών'
            PowerShell = '🟢 Εγγυημένη'
            mikepenz = '⚠️ Εξαρτάται από mode'
            Σύσταση = 'PowerShell για ασφάλεια'
        },
        [PSCustomObject]@{
            Κριτήριο = 'Setup Complexity'
            PowerShell = '🟡 Μέτρια'
            mikepenz = '🟢 Απλό'
            Σύσταση = 'mikepenz για απλότητα'
        },
        [PSCustomObject]@{
            Κριτήριο = 'Debugging'
            PowerShell = '🟢 Εύκολο'
            mikepenz = '🔴 Δύσκολο'
            Σύσταση = 'PowerShell για development'
        },
        [PSCustomObject]@{
            Κριτήριο = 'Maintenance'
            PowerShell = '🟡 Manual updates'
            mikepenz = '🟢 Auto-maintained'
            Σύσταση = 'mikepenz για production'
        },
        [PSCustomObject]@{
            Κριτήριο = 'Performance'
            PowerShell = '🟢 Γρήγορο'
            mikepenz = '🟡 Μέτριο'
            Σύσταση = 'PowerShell για μεγάλα repos'
        }
    )

    Write-Verbose "📊 Σύγκριση Προσεγγίσεων Changelog Generation`n"
    
    return $comparison
}

# Εκτέλεση demonstration αν το script καλείται απευθείας
if ($MyInvocation.InvocationName -ne '.') {
    Write-Verbose "🎯 BridgeWatcher Changelog Workflow Analysis`n"
    
    # Εμφάνιση σύγκρισης
    $comparison = Compare-ChangelogApproach
    $comparison | Format-Table -AutoSize
    
    Write-Verbose "`n💡 Συστάσεις:"
    Write-Verbose "• Για το BridgeWatcher: Χρησιμοποιήστε Custom PowerShell"
    Write-Verbose "• Λόγος: Πλήρης έλεγχος ελληνικών και διατήρηση παλιών εγγραφών"
    Write-Verbose "• Alternative: mikepenz με PREPEND mode για απλότητα"
    
    Write-Verbose "`n🧪 Για local testing εκτελέστε:"
    Write-Verbose "Test-ChangelogWorkflow -TestVersion '1.0.99' -DryRun -Verbose"
}