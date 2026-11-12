$ErrorActionPreference = 'Stop'

Import-Module Pester -MinimumVersion 5.0 -Force

Write-Output 'Running PSScriptAnalyzer...'
$lint = @(
    Invoke-ScriptAnalyzer -Path ./BridgeWatcher -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path ./Tests -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
) | Where-Object { $_ }
if ($lint) {
    $lint | Format-Table
    throw 'GATE FAILED: Linter warnings found.'
}

Write-Output 'Running Pester...'
Import-Module './BridgeWatcher/BridgeWatcher.psd1' -Force
$config = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile './Tests/PesterConfiguration.psd1')
$r = Invoke-Pester -Configuration $config
if ($r.FailedCount -gt 0) { throw 'GATE FAILED: Tests failed.' }
if ($r.CodeCoverage.CoveragePercent -lt 100) { throw 'GATE FAILED: Coverage < 100%.' }

Write-Output 'GATE PASSED'
