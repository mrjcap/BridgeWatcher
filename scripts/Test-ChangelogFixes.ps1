<#
.SYNOPSIS
Δοκιμάζει τις διορθώσεις στο changelog workflow.

.DESCRIPTION
Εκτελεί tests για να επαληθεύσει ότι όλες οι διορθώσεις στα changelog scripts λειτουργούν σωστά.
#>

[CmdletBinding()]
param()

Write-Host "🧪 Έναρξη tests για τις διορθώσεις changelog..." -ForegroundColor Green

# Test 1: Έλεγχος ότι το Update-ModuleVersion.ps1 έχει διορθωθεί
Write-Host "`n📋 Test 1: Update-ModuleVersion.ps1 function conflicts" -ForegroundColor Cyan
try {
    $content = Get-Content "./scripts/Update-ModuleVersion.ps1" -Raw
    $getFunctionCount = ($content -split "function Get-ModuleVersion").Count - 1
    $setFunctionCount = ($content -split "function Set-ModuleVersion").Count - 1

    if ($getFunctionCount -eq 1 -and $setFunctionCount -eq 1) {
        Write-Host "✅ Function names διορθώθηκαν σωστά" -ForegroundColor Green
    } else {
        Write-Host "❌ Function names δεν διορθώθηκαν σωστά (Get: $getFunctionCount, Set: $setFunctionCount)" -ForegroundColor Red
    }

    # Check for correct function call
    if ($content -match "Set-ModuleVersion -Content") {
        Write-Host "✅ Function call διορθώθηκε σωστά" -ForegroundColor Green
    } else {
        Write-Host "❌ Function call δεν διορθώθηκε" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Σφάλμα στο Test 1: $_" -ForegroundColor Red
}

# Test 2: Έλεγχος ότι το Get-GitCommitsSinceLastRelease.ps1 έχει διορθωθεί
Write-Host "`n📋 Test 2: Get-GitCommitsSinceLastRelease.ps1 exclusion patterns" -ForegroundColor Cyan
try {
    $content = Get-Content "./scripts/Get-GitCommitsSinceLastRelease.ps1" -Raw
    # Ελέγχουμε αν το pattern στο --grep περιέχει fix: ή fix\(
    if ($content -match "--grep=.*fix:|--grep=.*fix\\\(") {
        Write-Host "❌ Το exclusion pattern περιέχει ακόμη 'fix:' - δεν διορθώθηκε" -ForegroundColor Red
    } else {
        Write-Host "✅ Exclusion pattern διορθώθηκε σωστά" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Σφάλμα στο Test 2: $_" -ForegroundColor Red
}

# Test 3: Έλεγχος ότι το Update-Changelog.ps1 προσθέτει emojis
Write-Host "`n📋 Test 3: Update-Changelog.ps1 emoji support" -ForegroundColor Cyan
try {
    $content = Get-Content "./scripts/Update-Changelog.ps1" -Raw
    if ($content -match "✨ Προστέθηκαν" -and $content -match "🐛 Διορθώθηκαν") {
        Write-Host "✅ Emoji support προστέθηκε σωστά" -ForegroundColor Green
    } else {
        Write-Host "❌ Emoji support δεν προστέθηκε" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Σφάλμα στο Test 3: $_" -ForegroundColor Red
}

# Test 4: Έλεγχος ότι το GitHub workflow έχει διορθωθεί
Write-Host "`n📋 Test 4: GitHub workflow PowerShell call" -ForegroundColor Cyan
try {
    $content = Get-Content "./.github/workflows/release.yml" -Raw
    if ($content -match "& ./scripts/Update-ReleaseChangeLog.ps1") {
        Write-Host "✅ GitHub workflow PowerShell call διορθώθηκε" -ForegroundColor Green
    } else {
        Write-Host "❌ GitHub workflow PowerShell call δεν διορθώθηκε" -ForegroundColor Red
    }
} catch {
    Write-Host "❌ Σφάλμα στο Test 4: $_" -ForegroundColor Red
}

# Test 5: Functional test - προσπάθεια να τρέξει τη λογική
Write-Host "`n📋 Test 5: Functional test του Update-ModuleVersion.ps1" -ForegroundColor Cyan
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

    # Εκτέλεση του script
    $result = & "./scripts/Update-ModuleVersion.ps1" -Path $testPsd1Path

    # Έλεγχος αποτελέσματος
    $updatedContent = Get-Content $testPsd1Path -Raw
    if ($updatedContent -match "ModuleVersion = '1\.0\.1'") {
        Write-Host "✅ Update-ModuleVersion.ps1 λειτουργεί σωστά" -ForegroundColor Green
    } else {
        Write-Host "❌ Update-ModuleVersion.ps1 δεν λειτουργεί σωστά" -ForegroundColor Red
    }

    # Cleanup
    Remove-Item $testPsd1Path -ErrorAction SilentlyContinue
} catch {
    Write-Host "❌ Σφάλμα στο Test 5: $_" -ForegroundColor Red
    Remove-Item "./test-module.psd1" -ErrorAction SilentlyContinue
}

Write-Host "`n🎯 Τέλος tests. Ελέγξτε τα αποτελέσματα παραπάνω." -ForegroundColor Green
Write-Host "📋 Περίληψη προβλημάτων που διορθώθηκαν:" -ForegroundColor Yellow
Write-Host "   1. ✅ Διπλή function Get-ModuleVersion στο Update-ModuleVersion.ps1" -ForegroundColor White
Write-Host "   2. ✅ Λάθος exclusion του 'fix:' στο Get-GitCommitsSinceLastRelease.ps1" -ForegroundColor White
Write-Host "   3. ✅ Προσθήκη emojis στα section titles του Update-Changelog.ps1" -ForegroundColor White
Write-Host "   4. ✅ Διόρθωση PowerShell call στο GitHub workflow" -ForegroundColor White
