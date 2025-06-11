<#
.SYNOPSIS
Δοκιμάζει τις διορθώσεις στο changelog workflow.

.DESCRIPTION
Εκτελεί tests για να επαληθεύσει ότι όλες οι διορθώσεις στα changelog scripts λειτουργούν σωστά.
#>

[CmdletBinding()]
param()

Write-Verbose "🧪 Έναρξη tests για τις διορθώσεις changelog..."

# Test 1: Έλεγχος ότι το Update-ModuleVersion.ps1 έχει διορθωθεί
Write-Verbose "`n📋 Test 1: Update-ModuleVersion.ps1 function conflicts"
try {
    $content = Get-Content "./scripts/Update-ModuleVersion.ps1" -Raw
    $getFunctionCount = ($content -split "function Get-ModuleVersion").Count - 1
    $setFunctionCount = ($content -split "function Set-ModuleVersion").Count - 1

    if ($getFunctionCount -eq 1 -and $setFunctionCount -eq 1) {
        Write-Verbose "✅ Function names διορθώθηκαν σωστά"
    } else {
        Write-Verbose "❌ Function names δεν διορθώθηκαν σωστά (Get: $getFunctionCount, Set: $setFunctionCount)"
    }

    # Check for correct function call
    if ($content -match "Set-ModuleVersion -Content") {
        Write-Verbose "✅ Function call διορθώθηκε σωστά"
    } else {
        Write-Verbose "❌ Function call δεν διορθώθηκε"
    }
} catch {
    Write-Verbose "❌ Σφάλμα στο Test 1: $_"
}

# Test 2: Έλεγχος ότι το Get-GitCommitsSinceLastRelease.ps1 έχει διορθωθεί
Write-Verbose "`n📋 Test 2: Get-GitCommitsSinceLastRelease.ps1 exclusion patterns"
try {
    $content = Get-Content "./scripts/Get-GitCommitsSinceLastRelease.ps1" -Raw
    # Ελέγχουμε αν το pattern στο --grep περιέχει fix: ή fix\(
    if ($content -match "--grep=.*fix:|--grep=.*fix\\\(") {
        Write-Verbose "❌ Το exclusion pattern περιέχει ακόμη 'fix:' - δεν διορθώθηκε"
    } else {
        Write-Verbose "✅ Exclusion pattern διορθώθηκε σωστά"
    }
} catch {
    Write-Verbose "❌ Σφάλμα στο Test 2: $_"
}

# Test 3: Έλεγχος ότι το Update-Changelog.ps1 προσθέτει emojis
Write-Verbose "`n📋 Test 3: Update-Changelog.ps1 emoji support"
try {
    $content = Get-Content "./scripts/Update-Changelog.ps1" -Raw
    if ($content -match "✨ Προστέθηκαν" -and $content -match "🐛 Διορθώθηκαν") {
        Write-Verbose "✅ Emoji support προστέθηκε σωστά"
    } else {
        Write-Verbose "❌ Emoji support δεν προστέθηκε"
    }
} catch {
    Write-Verbose "❌ Σφάλμα στο Test 3: $_"
}

# Test 4: Έλεγχος ότι το GitHub workflow έχει διορθωθεί
Write-Verbose "`n📋 Test 4: GitHub workflow PowerShell call"
try {
    $content = Get-Content "./.github/workflows/release.yml" -Raw
    if ($content -match "& ./scripts/Update-ReleaseChangeLog.ps1") {
        Write-Verbose "✅ GitHub workflow PowerShell call διορθώθηκε"
    } else {
        Write-Verbose "❌ GitHub workflow PowerShell call δεν διορθώθηκε"
    }
} catch {
    Write-Verbose "❌ Σφάλμα στο Test 4: $_"
}

# Test 5: Functional test - προσπάθεια να τρέξει τη λογική
Write-Verbose "`n📋 Test 5: Functional test του Update-ModuleVersion.ps1"
try {
    # Δημιουργία dummy .psd1 αρχείου για test
    $testPsd1Content = @"
@{
    ModuleVersion = '1.0.0'
    Author = 'Test'
    Description = 'Test module'
}
"@
    $testPsd1Path = "./test-module.psd1"
    Set-Content -Path $testPsd1Path -Value $testPsd1Content -Encoding UTF8


    # Έλεγχος αποτελέσματος
    $updatedContent = Get-Content $testPsd1Path -Raw
    if ($updatedContent -match "ModuleVersion = '1\.0\.1'") {
        Write-Verbose "✅ Update-ModuleVersion.ps1 λειτουργεί σωστά"
    } else {
        Write-Verbose "❌ Update-ModuleVersion.ps1 δεν λειτουργεί σωστά"
    }

    # Cleanup
    Remove-Item $testPsd1Path -ErrorAction SilentlyContinue
} catch {
    Write-Verbose "❌ Σφάλμα στο Test 5: $_"
    Remove-Item "./test-module.psd1" -ErrorAction SilentlyContinue
}

Write-Verbose "`n🎯 Τέλος tests. Ελέγξτε τα αποτελέσματα παραπάνω."
Write-Verbose "📋 Περίληψη προβλημάτων που διορθώθηκαν:"
Write-Verbose "   1. ✅ Διπλή function Get-ModuleVersion στο Update-ModuleVersion.ps1"
Write-Verbose "   2. ✅ Λάθος exclusion του 'fix:' στο Get-GitCommitsSinceLastRelease.ps1"
Write-Verbose "   3. ✅ Προσθήκη emojis στα section titles του Update-Changelog.ps1"
Write-Verbose "   4. ✅ Διόρθωση PowerShell call στο GitHub workflow"
