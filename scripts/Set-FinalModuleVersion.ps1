[CmdletBinding()]
<#
.SYNOPSIS
Ενημερώνει την έκδοση του module στο manifest και ορίζει environment variable.

.DESCRIPTION
Η Set-FinalModuleVersion τροποποιεί το ModuleVersion στο αρχείο .psd1
και προαιρετικά ορίζει την έκδοση ως GitHub Actions environment variable.

.PARAMETER Version
Η ακριβής έκδοση που θα οριστεί (π.χ. 1.2.4).

.PARAMETER Path
Η διαδρομή του module manifest αρχείου.

.OUTPUTS
None.

.EXAMPLE
Set-FinalModuleVersion -Version '1.2.4'
# Ενημερώνει το ModuleVersion στο BridgeWatcher.psd1

.EXAMPLE
Set-FinalModuleVersion -Version '2.0.0' -Path './Custom/Module.psd1'
# Ενημερώνει το ModuleVersion στο καθορισμένο αρχείο

.NOTES
Διατηρεί τα single quotes γύρω από την έκδοση στο PSD1 αρχείο.
#>
param (
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,
    [Parameter()]
    [ValidateScript({
            if (-not (Test-Path $_ -PathType Leaf)) {
                throw "Το αρχείο '$_' δεν βρέθηκε."
            }
            if ($_ -notmatch '\.psd1$') {
                throw 'Το αρχείο πρέπει να έχει κατάληξη .psd1'
            }
            $true
        })]
    [string]$Path = './BridgeWatcher.psd1'
)

# Βήμα 1: Ανάγνωση περιεχομένου
$writeBridgeLogSplat = @{
    Message = "📖 Ανάγνωση αρχείου: $Path"
}
Write-Verbose @writeBridgeLogSplat

$getContentSplat = @{
    Path     = $Path
    Raw      = $true
    Encoding = 'utf8BOM'
}
$content = Get-Content @getContentSplat

# Βήμα 2: Έλεγχος ύπαρξης ModuleVersion
if ($content -notmatch "ModuleVersion\s*=\s*'[^']+'") {
    $errorRecord = [System.Management.Automation.ErrorRecord]::new(
        ([System.Exception]::new('Δεν βρέθηκε το ModuleVersion στο αρχείο.')),
        'ModuleVersionNotFound',
        [System.Management.Automation.ErrorCategory]::InvalidData,
        $Path
    )
    $PSCmdlet.ThrowTerminatingError($errorRecord)
}

# Βήμα 3: Αντικατάσταση έκδοσης
$pattern = "ModuleVersion\s*=\s*'[^']+'"
$replacement = "ModuleVersion = '$Version'"
$newContent = $content -replace $pattern, $replacement

$writeBridgeLogSplat = @{
    Message = "✏️ Αντικατάσταση: ModuleVersion = '$Version'"
}
Write-Verbose @writeBridgeLogSplat

# Βήμα 4: Αποθήκευση αλλαγών
$setContentSplat = @{
    Path      = $Path
    Value     = $newContent
    Encoding  = 'utf8BOM'
    NoNewline = $true
}
Set-Content @setContentSplat

$writeBridgeLogSplat = @{
    Message = '💾 Αρχείο ενημερώθηκε επιτυχώς'
}
Write-Verbose @writeBridgeLogSplat

# Βήμα 5: GitHub Actions Environment Variable
if ($env:GITHUB_ENV) {
    $addContentSplat = @{
        Path     = $env:GITHUB_ENV
        Value    = "new_version=$Version"
        Encoding = 'UTF8'
    }
    Add-Content @addContentSplat
    $writeBridgeLogSplat = @{
        Message = "🚀 GitHub Actions ENV: new_version=$Version"
    }
    Write-Verbose @writeBridgeLogSplat
}