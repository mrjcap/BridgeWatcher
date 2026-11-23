$ErrorActionPreference = 'Stop'

$findings = Invoke-ScriptAnalyzer -Path ./staged -Recurse -Settings ./PSScriptAnalyzerSettings.psd1
if ($findings) {
    $findings | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -Wrap
    throw 'PRE-COMMIT FAILED: PSScriptAnalyzer found issues in staged PowerShell files.'
}
