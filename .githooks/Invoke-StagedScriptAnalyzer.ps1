$ErrorActionPreference = 'Stop'

if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
    throw 'PRE-COMMIT FAILED: PSScriptAnalyzer module is not installed. Run Install-Module PSScriptAnalyzer -Scope CurrentUser.'
}

$snapshotRoot = (Get-Location).Path
$stagedRoot = Join-Path -Path $snapshotRoot -ChildPath 'staged'
$pathsFile = Join-Path -Path $snapshotRoot -ChildPath 'paths'
$changedPaths = [IO.File]::ReadAllText($pathsFile).Split([char]0, [StringSplitOptions]::RemoveEmptyEntries)
if ($changedPaths.Count -eq 0) {
    return
}
Import-Module -Name (Join-Path -Path $stagedRoot -ChildPath 'Tests/Review/PowerShellStyle.psm1') -Force

$allPaths = @(Get-ChildItem -LiteralPath $stagedRoot -Recurse -File -Force |
        Where-Object -FilterScript { $_.Extension -in '.ps1', '.psm1', '.psd1' } |
        ForEach-Object -Process { [IO.Path]::GetRelativePath($stagedRoot, $_.FullName).Replace('\', '/') })
$strictFindings = @(Get-PowerShellStyleFinding -RepositoryRoot $stagedRoot -Paths $allPaths)
if ($strictFindings.Count -gt 0) {
    $messages = $strictFindings | ForEach-Object -Process { "$($_.Path):$($_.Line) [$($_.Rule)] $($_.Message)" }
    throw ("PRE-COMMIT FAILED: strict PowerShell policy.`n" + ($messages -join "`n"))
}

$customRulePath = Join-Path -Path $stagedRoot -ChildPath 'scripts/NoCodeCommentsRule.psm1'
$hasCustomRule = Test-Path -LiteralPath $customRulePath -PathType Leaf
$findings = @(
    Invoke-PowerShellPolicyLint -RepositoryRoot $stagedRoot -Paths $changedPaths
    foreach ($path in $changedPaths) {
        $file = Join-Path -Path $stagedRoot -ChildPath $path
        if ($hasCustomRule) {
            Invoke-ScriptAnalyzer -Path $file -CustomRulePath $customRulePath -IncludeRule Measure-NoCodeComment
        }
        if ($path -match '^(BridgeWatcher|Tests)/') {
            Invoke-ScriptAnalyzer -Path $file -IncludeRule PSUseBOMForUnicodeEncodedFile
        }
    }
)
if ($findings.Count -gt 0) {
    $findings | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -Wrap
    throw "PRE-COMMIT FAILED: $($findings.Count) PSScriptAnalyzer finding(s) in staged PowerShell files."
}

Write-Output -InputObject "PRE-COMMIT PASSED: checked $($changedPaths.Count) staged PowerShell file(s)."
