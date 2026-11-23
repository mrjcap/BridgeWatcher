$ErrorActionPreference = 'Stop'

Import-Module Pester -MinimumVersion 5.0 -Force

Write-Output 'Running PSScriptAnalyzer...'
$lint = @(
    Invoke-ScriptAnalyzer -Path ./BridgeWatcher -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path ./Tests -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path ./run.ps1 -Settings ./PSScriptAnalyzerSettings.psd1
    Invoke-ScriptAnalyzer -Path ./scripts -Recurse -Settings ./PSScriptAnalyzerSettings.psd1 -Severity Error,Warning
)
if ($lint) {
    $lint | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -Wrap
    throw 'GATE FAILED: PSScriptAnalyzer findings found.'
}

Write-Output 'Running Pester...'
Import-Module './BridgeWatcher/BridgeWatcher.psd1' -Force
$config = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile './Tests/PesterConfiguration.psd1')
$r = Invoke-Pester -Configuration $config
if ($r.Result -ne 'Passed') { throw 'GATE FAILED: Tests did not pass.' }
if ($r.CodeCoverage.CoveragePercent -lt 100) { throw 'GATE FAILED: Coverage < 100%.' }

Write-Output 'GATE PASSED'
