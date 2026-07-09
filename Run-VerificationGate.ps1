$lint1 = Invoke-ScriptAnalyzer -Path ./BridgeWatcher -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
$lint2 = Invoke-ScriptAnalyzer -Path ./Tests -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
$lint = @()
if ($lint1) { $lint += $lint1 }
if ($lint2) { $lint += $lint2 }
if ($lint) {
    $lint | Format-Table
    throw "GATE FAILED: Linter warnings found."
}
Write-Output "Linter passed!"
Import-Module 'C:\Users\jcap\Documents\PowerShell\Modules\Pester\5.8.0\Pester.psd1' -Force
Import-Module './BridgeWatcher/BridgeWatcher.psd1' -Force
$config = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile './Tests/PesterConfiguration.psd1')
$r = Invoke-Pester -Configuration $config
if ($r.FailedCount -gt 0) {
    throw "GATE FAILED: Tests failed."
}
if ($r.CodeCoverage.CoveragePercent -lt 100) {
    throw "GATE FAILED: Coverage < 100%."
}
Write-Output "All tests and coverage passed!"
