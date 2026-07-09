$ErrorActionPreference = 'Stop'

Import-Module 'C:\Users\jcap\Documents\PowerShell\Modules\Pester\5.8.0\Pester.psd1' -Force

Write-Host "Running PSScriptAnalyzer..."
$lint = @(
    Invoke-ScriptAnalyzer -Path ./BridgeWatcher -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path ./Tests -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
) | Where-Object { $_ }
if ($lint) {
    $lint | Format-Table
    throw "GATE FAILED: Linter warnings found."
}

Write-Host "Running Pester..."
Import-Module "./BridgeWatcher/BridgeWatcher.psd1" -Force
$config = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile './Tests/PesterConfiguration.psd1')
$r = Invoke-Pester -Configuration $config
if ($r.FailedCount -gt 0) { throw "GATE FAILED: Tests failed." }
if ($r.CodeCoverage.CoveragePercent -lt 100) { throw "GATE FAILED: Coverage < 100%." }

Write-Host "GATE PASSED"
