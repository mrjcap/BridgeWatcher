<#
.SYNOPSIS
Selects affected Pester test files for a set of changed repository paths using an AST reverse-dependency graph and a conservative full-suite force list.

.DESCRIPTION
Analyzes changed files (either provided explicitly via -ChangedFiles or computed via git diff against -BaseRef)
and produces a structured selection result indicating whether the full test suite is required or which specific
test files are affected. Any unknown dependency, missing git history, invalid diff, shared helper change,
configuration change, module loader change, or workflow/test-infrastructure change forces the full suite.

NOTE: PR test selection is designed for early feedback / shadow validation only. It must NEVER narrow the
merge-queue suite or replace full-suite verification before code reaches main.

.PARAMETER RepositoryRoot
Path to the repository root. Defaults to the parent of scripts/.

.PARAMETER BaseRef
Git base ref used to compute changed files when -ChangedFiles is not specified (e.g. origin/main).

.PARAMETER HeadRef
Git head ref used to compute changed files when -ChangedFiles is not specified. Defaults to HEAD.

.PARAMETER ChangedFiles
Optional explicit list of repository-relative changed file paths (overrides git diff discovery).

.PARAMETER ShadowValidateAgainstFullResultPath
Optional path to a JUnit XML report from a full-suite run to verify that the selector did not omit any test file that failed in the full suite.

.PARAMETER OutputJsonPath
Optional path to write the JSON selection report.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent),

    [Parameter()]
    [string]$BaseRef = '',

    [Parameter()]
    [string]$HeadRef = 'HEAD',

    [Parameter()]
    [string[]]$ChangedFiles = @(),

    [Parameter()]
    [string]$ShadowValidateAgainstFullResultPath = '',

    [Parameter()]
    [string]$OutputJsonPath = ''
)

$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Normalizes a repository-relative path to lowercase-safe forward-slash form without leading ./ prefix.
.PARAMETER Path
Relative or absolute path to normalize.
.PARAMETER Root
Repository root directory.
#>
function ConvertTo-NormalizedRelativePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Root
    )

    $trimmed = $Path.Trim().Replace('\', '/')
    if ($trimmed.StartsWith('./')) {
        $trimmed = $trimmed.Substring(2)
    }
    $fullRoot = [System.IO.Path]::GetFullPath($Root).Replace('\', '/').TrimEnd('/') + '/'
    if ([System.IO.Path]::IsPathRooted($Path)) {
        $fullPath = [System.IO.Path]::GetFullPath($Path).Replace('\', '/')
        if ($fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $fullPath.Substring($fullRoot.Length)
        }
    }
    return $trimmed
}

<#
.SYNOPSIS
Returns the explicit list of file patterns that unconditionally force full-suite execution.
#>
function Get-FullSuiteForceRule {
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    return @(
        @{ Pattern = '^BridgeWatcher/BridgeWatcher\.psd1$'; Reason = 'Module manifest changed' }
        @{ Pattern = '^BridgeWatcher/BridgeWatcher\.psm1$'; Reason = 'Module loader changed' }
        @{ Pattern = '^BridgeWatcher/Formats/'; Reason = 'Module format definition changed' }
        @{ Pattern = '^BridgeWatcher/Private/New-BridgeConfiguration\.ps1$'; Reason = 'Shared configuration helper changed' }
        @{ Pattern = '^BridgeWatcher/Private/Write-BridgeLog\.ps1$'; Reason = 'Shared logging helper changed' }
        @{ Pattern = '^BridgeWatcher/Private/Get-BridgeOptionalProperty\.ps1$'; Reason = 'Shared property helper changed' }
        @{ Pattern = '^BridgeWatcher/Private/Get-BridgeHttpExceptionInfo\.ps1$'; Reason = 'Shared HTTP exception helper changed' }
        @{ Pattern = '^PSScriptAnalyzerSettings\.psd1$'; Reason = 'Analyzer configuration changed' }
        @{ Pattern = '^Tests/PesterConfiguration\.psd1$'; Reason = 'Pester configuration changed' }
        @{ Pattern = '^Tests/TestHelper\.ps1$'; Reason = 'Shared test helper changed' }
        @{ Pattern = '^Tests/Review/'; Reason = 'Static review test rule changed' }
        @{ Pattern = '^Tests/ArchitectureConstraints\.Tests\.ps1$'; Reason = 'Architecture test rule changed' }
        @{ Pattern = '^Tests/LinterCompliance\.Tests\.ps1$'; Reason = 'Linter compliance test changed' }
        @{ Pattern = '^Tests/ModuleExports\.Tests\.ps1$'; Reason = 'Module export test changed' }
        @{ Pattern = '^Tests/VulnerabilityReproduction\.Tests\.ps1$'; Reason = 'Security regression suite changed' }
        @{ Pattern = '^gate\.ps1$'; Reason = 'Verification gate script changed' }
        @{ Pattern = '^\.github/workflows/'; Reason = 'CI workflow changed' }
        @{ Pattern = '^\.githooks/'; Reason = 'Git hooks changed' }
        @{ Pattern = '^scripts/Invoke-TestSuite\.ps1$'; Reason = 'Test orchestrator changed' }
        @{ Pattern = '^scripts/Select-AffectedTests\.ps1$'; Reason = 'Test selector changed' }
        @{ Pattern = '^Docker/'; Reason = 'Docker build/runtime file changed' }
        @{ Pattern = '^docker-compose\.yml$'; Reason = 'Docker Compose configuration changed' }
    )
}

<#
.SYNOPSIS
Parses BridgeWatcher source files via the PowerShell AST to build a reverse call dependency graph.
.PARAMETER Root
Repository root directory.
#>
function Get-SourceDependencyGraph {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $sourceFiles = @(
        Get-ChildItem -Path (Join-Path -Path $Root -ChildPath 'BridgeWatcher/Public'), (Join-Path -Path $Root -ChildPath 'BridgeWatcher/Private') -Filter '*.ps1' -File -ErrorAction Stop |
            Sort-Object -Property FullName
    )

    $functionToFile = @{}
    $fileToFunctions = @{}
    $fileCalls = @{}

    foreach ($file in $sourceFiles) {
        $rel = ConvertTo-NormalizedRelativePath -Path $file.FullName -Root $Root
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
        if ($errors -and $errors.Count -gt 0) {
            throw "Failed to parse '$rel' while building dependency graph."
        }

        $defined = [System.Collections.Generic.List[string]]::new()
        $funcAsts = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true)
        foreach ($fn in $funcAsts) {
            $name = $fn.Name
            $defined.Add($name)
            $functionToFile[$name] = $rel
        }
        $fileToFunctions[$rel] = @($defined | Select-Object -Unique)

        $called = [System.Collections.Generic.List[string]]::new()
        $cmdAsts = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)
        foreach ($cmd in $cmdAsts) {
            $cmdName = $cmd.GetCommandName()
            if (-not [string]::IsNullOrWhiteSpace($cmdName)) {
                $called.Add($cmdName)
            }
        }
        $fileCalls[$rel] = @($called | Select-Object -Unique)
    }

    # Build reverse edges: dependencyFile -> list of files that call functions defined in dependencyFile.
    $reverseDeps = @{}
    foreach ($file in $fileToFunctions.Keys) {
        $reverseDeps[$file] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    }

    foreach ($callerFile in $fileCalls.Keys) {
        foreach ($cmdName in $fileCalls[$callerFile]) {
            if ($functionToFile.ContainsKey($cmdName)) {
                $calleeFile = $functionToFile[$cmdName]
                if ($calleeFile -ne $callerFile) {
                    $null = $reverseDeps[$calleeFile].Add($callerFile)
                }
            }
        }
    }

    return [pscustomobject]@{
        SourceFiles     = @($fileToFunctions.Keys | Sort-Object)
        FunctionToFile  = $functionToFile
        FileToFunctions = $fileToFunctions
        ReverseDeps     = $reverseDeps
    }
}

<#
.SYNOPSIS
Computes the transitive closure of affected source files and function names from a set of directly modified source files.
.PARAMETER DirectlyChangedSources
Repository-relative paths of directly changed source files.
.PARAMETER Graph
Dependency graph returned by Get-SourceDependencyGraph.
#>
function Get-TransitiveAffectedSource {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string[]]$DirectlyChangedSources,

        [Parameter(Mandatory)]
        [pscustomobject]$Graph
    )

    $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $queue = [System.Collections.Generic.Queue[string]]::new()

    foreach ($src in $DirectlyChangedSources) {
        if ($visited.Add($src)) {
            $queue.Enqueue($src)
        }
    }

    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        if ($Graph.ReverseDeps.ContainsKey($current)) {
            foreach ($dependent in $Graph.ReverseDeps[$current]) {
                if ($visited.Add($dependent)) {
                    $queue.Enqueue($dependent)
                }
            }
        }
    }

    $affectedFunctions = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($src in $visited) {
        if ($Graph.FileToFunctions.ContainsKey($src)) {
            foreach ($fn in $Graph.FileToFunctions[$src]) {
                $null = $affectedFunctions.Add($fn)
            }
        }
    }

    return [pscustomobject]@{
        AffectedSourceFiles = @($visited | Sort-Object)
        AffectedFunctions   = @($affectedFunctions | Sort-Object)
    }
}

<#
.SYNOPSIS
Selects affected test files for the given changed paths, falling back to the full suite whenever impact is uncertain.
.PARAMETER Root
Repository root directory.
.PARAMETER Paths
List of repository-relative changed file paths.
.PARAMETER ExcludeTestFiles
Optional test files to conceal from selection (ONLY for negative validation experiments proving omission detection).
#>
function Select-AffectedTestFile {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter()]
        [string[]]$Paths = @(),

        [Parameter()]
        [string[]]$ExcludeTestFiles = @()
    )

    $allTests = @(
        Get-ChildItem -Path (Join-Path -Path $Root -ChildPath 'Tests') -Recurse -File -Filter '*.Tests.ps1' |
            Sort-Object -Property FullName |
            ForEach-Object { ConvertTo-NormalizedRelativePath -Path $_.FullName -Root $Root }
    )

    $normalizedChanged = @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { ConvertTo-NormalizedRelativePath -Path $_ -Root $Root } | Select-Object -Unique)

    if ($normalizedChanged.Count -eq 0) {
        return [pscustomobject]@{
            Mode            = 'FullSuite'
            FullSuite       = $true
            Reasons         = @('No changed files detected or diff unavailable; forcing full suite.')
            ChangedFiles    = @()
            AffectedSources = @()
            SelectedTests   = $allTests
            TotalTests      = $allTests.Count
        }
    }

    $forceRules = Get-FullSuiteForceRule
    $forceReasons = [System.Collections.Generic.List[string]]::new()

    foreach ($file in $normalizedChanged) {
        foreach ($rule in $forceRules) {
            if ($file -match $rule.Pattern) {
                $forceReasons.Add("$($rule.Reason): $file")
            }
        }
    }

    if ($forceReasons.Count -gt 0) {
        return [pscustomobject]@{
            Mode            = 'FullSuite'
            FullSuite       = $true
            Reasons         = @($forceReasons | Select-Object -Unique)
            ChangedFiles    = $normalizedChanged
            AffectedSources = @()
            SelectedTests   = $allTests
            TotalTests      = $allTests.Count
        }
    }

    $graph = Get-SourceDependencyGraph -Root $Root
    $selectedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $directSources = [System.Collections.Generic.List[string]]::new()
    $unknownFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($file in $normalizedChanged) {
        if ($file -match '^BridgeWatcher/(Public|Private)/.+\.ps1$') {
            if ($graph.FileToFunctions.ContainsKey($file)) {
                $directSources.Add($file)
            } else {
                # Deleted or unknown module source file: force full suite.
                $unknownFiles.Add($file)
            }
        } elseif ($file -eq 'run.ps1') {
            $null = $selectedSet.Add('Tests/RunScript.Tests.ps1')
            $null = $selectedSet.Add('Tests/LinterCompliance.Tests.ps1')
        } elseif ($file -match '^Tests/.+\.Tests\.ps1$') {
            if ($allTests -contains $file) {
                $null = $selectedSet.Add($file)
                $null = $selectedSet.Add('Tests/LinterCompliance.Tests.ps1')
                $null = $selectedSet.Add('Tests/Review/PesterScope.Tests.ps1')
            } else {
                $unknownFiles.Add($file)
            }
        } elseif ($file -match '^scripts/Get-GitCommitsSinceLastRelease\.ps1$') {
            $null = $selectedSet.Add('Tests/Get-GitCommitsSinceLastRelease.Tests.ps1')
            $null = $selectedSet.Add('Tests/LinterCompliance.Tests.ps1')
        } elseif ($file -match '^(README\.md|CHANGELOG\.md|LICENSE|docs/)') {
            # Pure documentation changes still run workflow/lint verification if any; never return empty.
            $null = $selectedSet.Add('Tests/DockerBuildWorkflow.Tests.ps1')
        } else {
            $unknownFiles.Add($file)
        }
    }

    if ($unknownFiles.Count -gt 0) {
        return [pscustomobject]@{
            Mode            = 'FullSuite'
            FullSuite       = $true
            Reasons         = @("Unmapped or uncertain dependency change(s): $($unknownFiles -join ', ')")
            ChangedFiles    = $normalizedChanged
            AffectedSources = @()
            SelectedTests   = $allTests
            TotalTests      = $allTests.Count
        }
    }

    $affectedSources = @()
    if ($directSources.Count -gt 0) {
        $closure = Get-TransitiveAffectedSource -DirectlyChangedSources @($directSources) -Graph $graph
        $affectedSources = $closure.AffectedSourceFiles

        # Always include repo-wide structural/security/lint checks whenever module code changes.
        foreach ($reviewTest in $allTests) {
            if ($reviewTest -match '^Tests/Review/' -or $reviewTest -in @(
                    'Tests/ArchitectureConstraints.Tests.ps1',
                    'Tests/LinterCompliance.Tests.ps1',
                    'Tests/ModuleExports.Tests.ps1',
                    'Tests/VulnerabilityReproduction.Tests.ps1'
                )) {
                $null = $selectedSet.Add($reviewTest)
            }
        }

        # Select any test file that references an affected function name or source file basename.
        $baseNames = @($affectedSources | ForEach-Object { [System.IO.Path]::GetFileNameWithoutExtension($_) })
        $matchTokens = @($closure.AffectedFunctions) + $baseNames | Select-Object -Unique

        foreach ($testRel in $allTests) {
            $fullTestPath = Join-Path -Path $Root -ChildPath $testRel
            $content = Get-Content -LiteralPath $fullTestPath -Raw
            foreach ($tok in $matchTokens) {
                $escaped = [regex]::Escape($tok)
                if ($content -match "(?<![A-Za-z0-9_-])$escaped(?![A-Za-z0-9_-])") {
                    $null = $selectedSet.Add($testRel)
                    break
                }
            }
        }
    }

    if ($ExcludeTestFiles.Count -gt 0) {
        foreach ($ex in $ExcludeTestFiles) {
            $normEx = ConvertTo-NormalizedRelativePath -Path $ex -Root $Root
            $null = $selectedSet.Remove($normEx)
        }
    }

    $selectedList = @($selectedSet | Sort-Object)
    if ($selectedList.Count -eq 0) {
        return [pscustomobject]@{
            Mode            = 'FullSuite'
            FullSuite       = $true
            Reasons         = @('Selection resolved to zero tests; refusing empty run and forcing full suite.')
            ChangedFiles    = $normalizedChanged
            AffectedSources = $affectedSources
            SelectedTests   = $allTests
            TotalTests      = $allTests.Count
        }
    }

    return [pscustomobject]@{
        Mode            = 'Selected'
        FullSuite       = $false
        Reasons         = @("Resolved $($selectedList.Count) of $($allTests.Count) tests from AST dependency graph.")
        ChangedFiles    = $normalizedChanged
        AffectedSources = $affectedSources
        SelectedTests   = $selectedList
        TotalTests      = $allTests.Count
    }
}

<#
.SYNOPSIS
Validates a selector result against a full-suite JUnit XML report and detects any failing test omitted by the selector.
.PARAMETER Selection
Selection object returned by Select-AffectedTestFile.
.PARAMETER FullJUnitXmlPath
Path to the JUnit XML output from a full-suite run.
.PARAMETER Root
Repository root directory.
#>
function Test-SelectionAgainstFullResult {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [pscustomobject]$Selection,

        [Parameter(Mandatory)]
        [string]$FullJUnitXmlPath,

        [Parameter(Mandatory)]
        [string]$Root
    )

    if (-not (Test-Path -LiteralPath $FullJUnitXmlPath)) {
        throw "Full-suite JUnit XML not found at '$FullJUnitXmlPath'."
    }

    [xml]$doc = Get-Content -LiteralPath $FullJUnitXmlPath -Raw
    $failedTestFiles = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($suite in $doc.SelectNodes('/testsuites/testsuite')) {
        $failCount = [int]$suite.GetAttribute('failures')
        $errCount = [int]$suite.GetAttribute('errors')
        if ($failCount -gt 0 -or $errCount -gt 0) {
            $suiteName = $suite.GetAttribute('name')
            $normSuite = ConvertTo-NormalizedRelativePath -Path $suiteName -Root $Root
            $null = $failedTestFiles.Add($normSuite)
        }
    }

    $omitted = [System.Collections.Generic.List[string]]::new()
    foreach ($failedFile in $failedTestFiles) {
        if ($Selection.SelectedTests -notcontains $failedFile) {
            $omitted.Add($failedFile)
        }
    }

    return [pscustomobject]@{
        Passed          = ($omitted.Count -eq 0)
        FailedTestFiles = @($failedTestFiles | Sort-Object)
        OmittedFailures = @($omitted | Sort-Object)
    }
}

# ---- Entry Point ----
if ($MyInvocation.InvocationName -eq '.') {
    return
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
$effectiveChanged = @($ChangedFiles)

if ($effectiveChanged.Count -eq 0 -and -not [string]::IsNullOrWhiteSpace($BaseRef)) {
    Push-Location -LiteralPath $resolvedRoot
    try {
        $mergeBase = (& git merge-base $BaseRef $HeadRef 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($mergeBase)) {
            $diffOut = @(& git diff --name-only "$mergeBase..$HeadRef" 2>$null)
            if ($LASTEXITCODE -eq 0) {
                $effectiveChanged = @($diffOut)
            }
        }
    } finally {
        Pop-Location
    }
}

$selection = Select-AffectedTestFile -Root $resolvedRoot -Paths $effectiveChanged

if (-not [string]::IsNullOrWhiteSpace($OutputJsonPath)) {
    ConvertTo-Json -InputObject $selection -Depth 5 | Set-Content -LiteralPath $OutputJsonPath -Encoding utf8
}

Write-Output "Test selection mode=$($selection.Mode) selected=$($selection.SelectedTests.Count)/$($selection.TotalTests) reasons=$($selection.Reasons -join '; ')"

if (-not [string]::IsNullOrWhiteSpace($ShadowValidateAgainstFullResultPath)) {
    $validation = Test-SelectionAgainstFullResult -Selection $selection -FullJUnitXmlPath $ShadowValidateAgainstFullResultPath -Root $resolvedRoot
    if (-not $validation.Passed) {
        throw "SELECTOR OMISSION DETECTED: Full suite failed in $($validation.OmittedFailures -join ', ') which was NOT selected by Select-AffectedTests!"
    }
    Write-Output "Shadow validation passed: all $($validation.FailedTestFiles.Count) failing full-suite file(s) were covered by selection."
}
