$ErrorActionPreference = 'Stop'

$totalSw = [System.Diagnostics.Stopwatch]::StartNew()
Import-Module Pester -MinimumVersion 5.0 -Force

Write-Output 'Running PowerShell AST parse & manifest validation...'
$parseSw = [System.Diagnostics.Stopwatch]::StartNew()
$staticFailures = [System.Collections.Generic.List[string]]::new()
$psFiles = @(
    Get-ChildItem -Path './BridgeWatcher', './Tests', './scripts' -Recurse -File -Include '*.ps1', '*.psm1', '*.psd1'
    Get-Item -LiteralPath './run.ps1', './gate.ps1', './PSScriptAnalyzerSettings.psd1'
)
foreach ($file in $psFiles) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        foreach ($err in $parseErrors) {
            $staticFailures.Add("Syntax error in $($file.FullName):$($err.Extent.StartLineNumber): $($err.Message)")
        }
    }
}
try {
    $null = Test-ModuleManifest -Path './BridgeWatcher/BridgeWatcher.psd1' -ErrorAction Stop
} catch {
    $staticFailures.Add("Module manifest validation failed: $($_.Exception.Message)")
}
$parseSw.Stop()
Write-Output ("Parse & manifest validation: {0:N2}s ({1} files)" -f $parseSw.Elapsed.TotalSeconds, $psFiles.Count)

Write-Output 'Running PSScriptAnalyzer...'
$lintSw = [System.Diagnostics.Stopwatch]::StartNew()
$lint = @(
    Invoke-ScriptAnalyzer -Path ./BridgeWatcher -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path ./Tests -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path ./run.ps1 -Settings ./PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error, Warning
    Invoke-ScriptAnalyzer -Path ./BridgeWatcher -Recurse -IncludeRule PSUseBOMForUnicodeEncodedFile
    Invoke-ScriptAnalyzer -Path ./Tests -Recurse -IncludeRule PSUseBOMForUnicodeEncodedFile
)
$lintSw.Stop()
Write-Output ("PSScriptAnalyzer: {0:N2}s" -f $lintSw.Elapsed.TotalSeconds)

if ($lint) {
    $lint | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -Wrap
    $staticFailures.Add("PSScriptAnalyzer found $($lint.Count) issue(s).")
}

Write-Output 'Running code comment ratchet check...'
$commentSw = [System.Diagnostics.Stopwatch]::StartNew()
$commentCheck = & ./scripts/Test-NoCodeComments.ps1 -RepositoryRoot . -PassThru
$commentSw.Stop()
Write-Output ("Comment ratchet check: {0:N2}s ({1}/{2} ratcheted across {3} files)" -f $commentSw.Elapsed.TotalSeconds, $commentCheck.TotalComments, $commentCheck.RatchetTotal, $commentCheck.ScannedFileCount)
if (-not $commentCheck.Passed) {
    foreach ($v in $commentCheck.Violations) { $staticFailures.Add($v) }
}

if ($staticFailures.Count -gt 0) {
    foreach ($msg in $staticFailures) { Write-Output $msg }
    throw 'GATE FAILED: Static checks failed.'
}

Write-Output 'Running Pester...'
$pesterSw = [System.Diagnostics.Stopwatch]::StartNew()
Import-Module './BridgeWatcher/BridgeWatcher.psd1' -Force
$config = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile './Tests/PesterConfiguration.psd1')
$r = Invoke-Pester -Configuration $config
$pesterSw.Stop()
Write-Output ("Pester: {0:N2}s" -f $pesterSw.Elapsed.TotalSeconds)

if ($r.Result -ne 'Passed') { throw 'GATE FAILED: Tests did not pass.' }
if ($r.CodeCoverage.CoveragePercent -lt 100) { throw 'GATE FAILED: Coverage < 100%.' }

$totalSw.Stop()
Write-Output ("Gate total: {0:N2}s" -f $totalSw.Elapsed.TotalSeconds)
Write-Output 'GATE PASSED'
