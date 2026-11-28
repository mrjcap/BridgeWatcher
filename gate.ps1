$ErrorActionPreference = 'Stop'

$totalSw = [System.Diagnostics.Stopwatch]::StartNew()
Import-Module -Name Pester -MinimumVersion 5.0 -Force
Import-Module -Name ./Tests/Review/PowerShellStyle.psm1
$repoRoot = (Get-Location).Path
$paths = @(Get-TrackedPowerShellPath -RepositoryRoot $repoRoot)

Write-Output -InputObject 'Running PowerShell AST parse & manifest validation...'
$parseSw = [System.Diagnostics.Stopwatch]::StartNew()
$staticFailures = [System.Collections.Generic.List[string]]::new()
foreach ($path in $paths) {
    $file = Join-Path -Path $repoRoot -ChildPath $path
    $tokens = $null
    $parseErrors = $null
    $null = [System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors -and $parseErrors.Count -gt 0) {
        foreach ($err in $parseErrors) {
            $staticFailures.Add("Syntax error in ${path}:$($err.Extent.StartLineNumber): $($err.Message)")
        }
    }
}
try {
    $null = Test-ModuleManifest -Path './BridgeWatcher/BridgeWatcher.psd1' -ErrorAction Stop
} catch {
    $staticFailures.Add("Module manifest validation failed: $($_.Exception.Message)")
}
$parseSw.Stop()
Write-Output -InputObject ("Parse & manifest validation: {0:N2}s ({1} files)" -f $parseSw.Elapsed.TotalSeconds, $paths.Count)

Write-Output -InputObject 'Running PSScriptAnalyzer...'
$lintSw = [System.Diagnostics.Stopwatch]::StartNew()
$lint = @(Invoke-PowerShellPolicyLint -RepositoryRoot $repoRoot -Paths $paths)
$lintSw.Stop()
Write-Output -InputObject ("PSScriptAnalyzer: {0:N2}s" -f $lintSw.Elapsed.TotalSeconds)

if ($lint) {
    $lint | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -Wrap
    $staticFailures.Add("PSScriptAnalyzer found $($lint.Count) issue(s).")
}

Write-Output -InputObject 'Running code comment ratchet check...'
$commentSw = [System.Diagnostics.Stopwatch]::StartNew()
$commentCheck = & ./scripts/Test-NoCodeComments.ps1 -RepositoryRoot . -PassThru
$commentSw.Stop()
Write-Output -InputObject ("Comment ratchet check: {0:N2}s ({1}/{2} ratcheted across {3} files)" -f $commentSw.Elapsed.TotalSeconds, $commentCheck.TotalComments, $commentCheck.RatchetTotal, $commentCheck.ScannedFileCount)
if (-not $commentCheck.Passed) {
    foreach ($v in $commentCheck.Violations) { $staticFailures.Add($v) }
}

if ($staticFailures.Count -gt 0) {
    foreach ($msg in $staticFailures) { Write-Output -InputObject $msg }
    throw 'GATE FAILED: Static checks failed.'
}

Write-Output -InputObject 'Running Pester...'
$pesterSw = [System.Diagnostics.Stopwatch]::StartNew()
Import-Module -Name './BridgeWatcher/BridgeWatcher.psd1' -Force
$config = New-PesterConfiguration -Hashtable (Import-PowerShellDataFile -Path './Tests/PesterConfiguration.psd1')
$r = Invoke-Pester -Configuration $config
$pesterSw.Stop()
Write-Output -InputObject ("Pester: {0:N2}s" -f $pesterSw.Elapsed.TotalSeconds)

if ($r.Result -ne 'Passed') { throw 'GATE FAILED: Tests did not pass.' }
if ($r.CodeCoverage.CoveragePercent -lt 100) { throw 'GATE FAILED: Coverage < 100%.' }

$totalSw.Stop()
Write-Output -InputObject ("Gate total: {0:N2}s" -f $totalSw.Elapsed.TotalSeconds)
Write-Output -InputObject 'GATE PASSED'
