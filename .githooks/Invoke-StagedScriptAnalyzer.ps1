$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    throw 'PRE-COMMIT FAILED: PSScriptAnalyzer module is not installed. Run Install-Module PSScriptAnalyzer -Scope CurrentUser.'
}

$stagedRoot = Join-Path -Path (Get-Location).Path -ChildPath 'staged'
$settingsPath = Join-Path -Path (Get-Location).Path -ChildPath 'PSScriptAnalyzerSettings.psd1'

if (-not (Test-Path -LiteralPath $stagedRoot)) {
    return
}

$stagedFiles = @(
    Get-ChildItem -Path $stagedRoot -Recurse -File -Force -Include '*.ps1', '*.psm1', '*.psd1' |
        Sort-Object -Property FullName
)
if ($stagedFiles.Count -eq 0) {
    return
}

$sw = [System.Diagnostics.Stopwatch]::StartNew()
$failures = [System.Collections.Generic.List[string]]::new()
$findings = [System.Collections.Generic.List[object]]::new()

foreach ($file in $stagedFiles) {
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $rel = $file.FullName.Substring($stagedRoot.Length).TrimStart('\', '/')
        foreach ($err in $parseErrors) {
            $failures.Add("Syntax error in ${rel}:$($err.Extent.StartLineNumber): $($err.Message)")
        }
    }
}

$customRulePath = Join-Path -Path $PSScriptRoot -ChildPath '../scripts/NoCodeCommentsRule.psm1'
$hasCustomRule = Test-Path -LiteralPath $customRulePath -PathType Leaf

foreach ($file in $stagedFiles) {
    $rel = $file.FullName.Substring($stagedRoot.Length).TrimStart('\', '/').Replace('\', '/')
    if ($rel -match '^scripts/') {
        $res = @(Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath -Severity Error, Warning)
    } else {
        $res = @(Invoke-ScriptAnalyzer -Path $file.FullName -Settings $settingsPath)
    }
    foreach ($item in $res) { $findings.Add($item) }

    if ($hasCustomRule) {
        $commentRes = @(Invoke-ScriptAnalyzer -Path $file.FullName -CustomRulePath $customRulePath -IncludeRule Measure-NoCodeComment)
        foreach ($item in $commentRes) { $findings.Add($item) }
    }

    if ($rel -match '^(BridgeWatcher|Tests)/') {
        $bomRes = @(Invoke-ScriptAnalyzer -Path $file.FullName -IncludeRule PSUseBOMForUnicodeEncodedFile)
        foreach ($item in $bomRes) { $findings.Add($item) }
    }
}

$sw.Stop()
$elapsedSec = [Math]::Round($sw.Elapsed.TotalSeconds, 2)

if ($failures.Count -gt 0) {
    foreach ($msg in $failures) {
        Write-Output $msg
    }
}

if ($findings.Count -gt 0) {
    $findings | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -Wrap
}

if ($failures.Count -gt 0 -or $findings.Count -gt 0) {
    throw "PRE-COMMIT FAILED (${elapsedSec}s): $($failures.Count) syntax error(s) and $($findings.Count) PSScriptAnalyzer finding(s) in staged PowerShell files."
}

Write-Output "PRE-COMMIT PASSED: checked $($stagedFiles.Count) staged PowerShell file(s) in ${elapsedSec}s."
