<#
.SYNOPSIS
Runs the BridgeWatcher Pester test suite with process-isolated sharding, inventory verification, deterministic shuffling, and exact command-level coverage aggregation.

.DESCRIPTION
Orchestrates Pester 5/6 execution across one or more isolated PowerShell worker processes.
Verifies that shard assignments cover 100% of intended tracked test files without omissions or duplicates,
supports timing-balanced shard allocation with a deterministic fallback for unmeasured files,
merges exact command-level coverage into JaCoCo XML and JUnit test results across shards,
and optionally includes Integration-tagged tests for full-suite verification.

.PARAMETER RepositoryRoot
Path to the repository root containing BridgeWatcher and Tests directories. Defaults to the parent of scripts/.

.PARAMETER ShardCount
Total number of shards to partition the unit test inventory into. Defaults to 1.

.PARAMETER ShardIndex
Zero-based shard index to execute when running a single shard (used with matrix jobs). Ignored when -RunAllShardsInParallel is specified.

.PARAMETER RunAllShardsInParallel
Runs all shards concurrently in isolated child pwsh processes and merges their JUnit XML, JaCoCo coverage XML, and per-file timings.

.PARAMETER Workers
Maximum concurrent child worker processes when -RunAllShardsInParallel is specified. Defaults to 0 (matches [Environment]::ProcessorCount).

.PARAMETER IncludeIntegration
Explicitly includes Integration-tagged test files (excluded from the standard Pester configuration) in execution and inventory accounting.

.PARAMETER IntegrationOnly
Runs only Integration-tagged test files (without enforcing unit-test code coverage threshold).

.PARAMETER Shuffle
Randomizes test file, Describe/Context, and It execution order using Pester's supported Shuffle mechanism with a recorded reproducible seed.

.PARAMETER Seed
Explicit integer seed for -Shuffle. Defaults to 0, which generates and prints a reproducible seed.

.PARAMETER TimingsPath
Optional path to a JSON file mapping relative test paths (e.g. Tests/Foo.Tests.ps1) to historical durations in seconds for balanced shard assignment.

.PARAMETER RecordTimingsPath
Optional path to write measured per-file durations JSON after execution.

.PARAMETER TestFiles
Optional explicit list of test file paths to run instead of discovering all tracked test files.

.PARAMETER CoverageOutputPath
Path to write the merged JaCoCo XML coverage report. Defaults to coverage.xml in RepositoryRoot.

.PARAMETER TestResultOutputPath
Path to write the merged JUnit XML test report. Defaults to testResults.xml in RepositoryRoot.

.PARAMETER CoverageThreshold
Minimum required code coverage percentage across the full configured coverage scope. Defaults to 100.

.PARAMETER SkipCoverage
Disables code coverage collection (for example during standalone integration runs or timing diagnostics).

.PARAMETER MaxDurationSeconds
Optional enforced wall-clock duration budget in seconds. Correctness results are always preserved and reported before failing on budget overrun.

.PARAMETER WorkerOutputDirectory
Internal parameter used by child worker processes to write per-shard coverage, JUnit, and timing files.

.PARAMETER WorkerManifestPath
Internal parameter used by child worker processes pointing to a JSON file listing test paths assigned to that worker.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepositoryRoot = (Split-Path -Path $PSScriptRoot -Parent),

    [Parameter()]
    [ValidateRange(1, 64)]
    [int]$ShardCount = 1,

    [Parameter()]
    [ValidateRange(0, 63)]
    [int]$ShardIndex = 0,

    [Parameter()]
    [switch]$RunAllShardsInParallel,

    [Parameter()]
    [ValidateRange(0, 64)]
    [int]$Workers = 0,

    [Parameter()]
    [switch]$IncludeIntegration,

    [Parameter()]
    [switch]$IntegrationOnly,

    [Parameter()]
    [switch]$Shuffle,

    [Parameter()]
    [int]$Seed = 0,

    [Parameter()]
    [string]$TimingsPath = '',

    [Parameter()]
    [string]$RecordTimingsPath = '',

    [Parameter()]
    [string[]]$TestFiles = @(),

    [Parameter()]
    [string]$CoverageOutputPath = '',

    [Parameter()]
    [string]$TestResultOutputPath = '',

    [Parameter()]
    [ValidateRange(0, 100)]
    [double]$CoverageThreshold = 100,

    [Parameter()]
    [switch]$SkipCoverage,

    [Parameter()]
    [ValidateRange(0, 3600)]
    [int]$MaxDurationSeconds = 0,

    [Parameter()]
    [string]$WorkerOutputDirectory = '',

    [Parameter()]
    [string]$WorkerManifestPath = ''
)

$ErrorActionPreference = 'Stop'

<#
.SYNOPSIS
Converts an absolute file path to a normalized repository-relative forward-slash path.
.PARAMETER Path
Full or relative path to normalize.
.PARAMETER Root
Resolved repository root path.
#>
function ConvertTo-RepoRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [string]$Root
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path).Replace('\', '/')
    $fullRoot = [System.IO.Path]::GetFullPath($Root).Replace('\', '/').TrimEnd('/') + '/'
    if ($fullPath.StartsWith($fullRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $fullPath.Substring($fullRoot.Length)
    }
    return $fullPath
}

<#
.SYNOPSIS
Determines whether a Pester test file defines an Integration-tagged block.
.PARAMETER FilePath
Path to the .Tests.ps1 file to inspect via the PowerShell AST.
#>
function Test-IsIntegrationTestFile {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $tokens = $null
    $errors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($FilePath, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        $messages = ($errors | ForEach-Object { $_.Message }) -join '; '
        throw "PowerShell syntax error in '$FilePath': $messages"
    }

    $commands = $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.CommandAst] -and
        $node.GetCommandName() -in @('Describe', 'Context', 'It')
    }, $true)

    foreach ($cmd in $commands) {
        for ($i = 1; $i -lt $cmd.CommandElements.Count; $i++) {
            $el = $cmd.CommandElements[$i]
            if ($el -is [System.Management.Automation.Language.CommandParameterAst] -and $el.ParameterName -eq 'Tag') {
                if (($i + 1) -lt $cmd.CommandElements.Count) {
                    $argText = $cmd.CommandElements[$i + 1].Extent.Text
                    if ($argText -match "(?i)['""]?Integration['""]?") {
                        return $true
                    }
                }
            }
        }
    }
    return $false
}

<#
.SYNOPSIS
Discovers all tracked test files under Tests/ and classifies unit versus Integration-tagged files.
.PARAMETER Root
Repository root directory.
#>
function Get-TrackedTestInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Root
    )

    $testsDir = Join-Path -Path $Root -ChildPath 'Tests'
    $all = @(
        Get-ChildItem -Path $testsDir -Recurse -File -Filter '*.Tests.ps1' |
            Sort-Object -Property FullName
    )

    $unitFiles = [System.Collections.Generic.List[string]]::new()
    $integrationFiles = [System.Collections.Generic.List[string]]::new()

    foreach ($file in $all) {
        if (Test-IsIntegrationTestFile -FilePath $file.FullName) {
            $integrationFiles.Add($file.FullName)
        } else {
            $unitFiles.Add($file.FullName)
        }
    }

    return [pscustomobject]@{
        AllFiles         = @($all.FullName)
        UnitFiles        = @($unitFiles)
        IntegrationFiles = @($integrationFiles)
    }
}

<#
.SYNOPSIS
Loads historical per-file test timings from JSON if available.
.PARAMETER Path
Path to the timings JSON file.
#>
function Get-HistoricalTestTiming {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter()]
        [string]$Path
    )

    $map = @{}
    if ([string]::IsNullOrWhiteSpace($Path) -or -not (Test-Path -LiteralPath $Path)) {
        return $map
    }

    $raw = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return $map
    }

    $parsed = ConvertFrom-Json -InputObject $raw
    foreach ($prop in $parsed.PSObject.Properties) {
        $val = 0.0
        if ([double]::TryParse([string]$prop.Value, [ref]$val) -and $val -gt 0) {
            $map[$prop.Name.Replace('\', '/')] = $val
        }
    }
    return $map
}

<#
.SYNOPSIS
Partitions test files across shards using longest-processing-time-first balancing and verifies complete coverage.
.PARAMETER Files
List of test file paths to partition.
.PARAMETER Count
Number of shards.
.PARAMETER Root
Repository root path used to normalize keys against TimingsMap.
.PARAMETER TimingsMap
Hashtable of relative file path to estimated duration in seconds.
#>
function Split-TestFilesIntoShard {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Files,

        [Parameter(Mandatory)]
        [int]$Count,

        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter()]
        [hashtable]$TimingsMap = @{}
    )

    $defaultWeight = 0.5
    $effectiveCount = [Math]::Min($Count, [Math]::Max(1, $Files.Count))

    $weighted = foreach ($file in $Files) {
        $rel = ConvertTo-RepoRelativePath -Path $file -Root $Root
        $weight = if ($TimingsMap.ContainsKey($rel)) { [double]$TimingsMap[$rel] } else { $defaultWeight }
        [pscustomobject]@{
            File   = $file
            Rel    = $rel
            Weight = $weight
        }
    }

    $sorted = @($weighted | Sort-Object -Property @{ Expression = 'Weight'; Descending = $true }, @{ Expression = 'Rel'; Descending = $false })

    $shards = [System.Collections.Generic.List[object]]::new()
    for ($i = 0; $i -lt $effectiveCount; $i++) {
        $shards.Add([pscustomobject]@{
            Index       = $i
            TotalWeight = 0.0
            Files       = [System.Collections.Generic.List[string]]::new()
        })
    }

    foreach ($item in $sorted) {
        $target = $shards[0]
        foreach ($candidate in $shards) {
            if ($candidate.TotalWeight -lt $target.TotalWeight) {
                $target = $candidate
            }
        }
        $target.Files.Add($item.File)
        $target.TotalWeight += $item.Weight
    }

    # Verify shard inventory has zero omissions and zero duplicates.
    $assigned = [System.Collections.Generic.List[string]]::new()
    foreach ($shard in $shards) {
        foreach ($f in $shard.Files) {
            $assigned.Add($f)
        }
    }

    $uniqueAssigned = @($assigned | Select-Object -Unique)
    if ($assigned.Count -ne $Files.Count -or $uniqueAssigned.Count -ne $Files.Count) {
        throw "Shard inventory verification failed: expected $($Files.Count) unique files, assigned=$($assigned.Count), unique=$($uniqueAssigned.Count)."
    }

    foreach ($expected in $Files) {
        if ($uniqueAssigned -notcontains $expected) {
            throw "Shard inventory verification failed: missing test file '$expected'."
        }
    }

    return @($shards)
}

<#
.SYNOPSIS
Writes merged command-level coverage records into Pester-compatible JaCoCo XML.
.PARAMETER MergedCommands
List of merged command records with File, StartLine, Function, and HitCount.
.PARAMETER ReportRoot
Repository root path stripped from file paths for JaCoCo package and class names.
.PARAMETER OutputPath
Destination path for coverage.xml.
.PARAMETER ElapsedMilliseconds
Total execution duration in milliseconds for JaCoCo sessioninfo metadata.
#>
function Export-MergedJaCoCoXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object[]]$MergedCommands,

        [Parameter(Mandatory)]
        [string]$ReportRoot,

        [Parameter(Mandatory)]
        [string]$OutputPath,

        [Parameter(Mandatory)]
        [long]$ElapsedMilliseconds
    )

    $endTime = [System.DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $startTime = [Math]::Max([long]0, ($endTime - $ElapsedMilliseconds))

    $packages = [ordered]@{}
    foreach ($cmd in $MergedCommands) {
        $relFile = ConvertTo-RepoRelativePath -Path $cmd.File -Root $ReportRoot
        $lastSlash = $relFile.LastIndexOf('/')
        $pkgName = if ($lastSlash -gt 0) { $relFile.Substring(0, $lastSlash) } else { '.' }
        $fileName = if ($lastSlash -ge 0) { $relFile.Substring($lastSlash + 1) } else { $relFile }
        $className = if ($relFile.LastIndexOf('.') -gt 0) { $relFile.Substring(0, $relFile.LastIndexOf('.')) } else { $relFile }
        $funcName = if ([string]::IsNullOrWhiteSpace($cmd.Function)) { '<script>' } else { $cmd.Function }
        $lineKey = [string]$cmd.StartLine
        $isHit = ([int]$cmd.HitCount) -gt 0

        if (-not $packages.Contains($pkgName)) {
            $packages[$pkgName] = [ordered]@{}
        }
        if (-not $packages[$pkgName].Contains($relFile)) {
            $packages[$pkgName][$relFile] = @{
                ClassName  = $className
                SourceFile = $fileName
                Methods    = [ordered]@{}
                Lines      = [ordered]@{}
            }
        }

        $fileRec = $packages[$pkgName][$relFile]
        if (-not $fileRec.Methods.Contains($funcName)) {
            $fileRec.Methods[$funcName] = @{
                FirstLine = [int]$cmd.StartLine
                Lines     = @{}
                InstrCov  = 0
                InstrMiss = 0
            }
        }
        $methodRec = $fileRec.Methods[$funcName]
        if ([int]$cmd.StartLine -lt $methodRec.FirstLine) {
            $methodRec.FirstLine = [int]$cmd.StartLine
        }
        if ($isHit) { $methodRec.InstrCov++ } else { $methodRec.InstrMiss++ }
        if (-not $methodRec.Lines.ContainsKey($lineKey)) { $methodRec.Lines[$lineKey] = $false }
        if ($isHit) { $methodRec.Lines[$lineKey] = $true }

        if (-not $fileRec.Lines.Contains($lineKey)) {
            $fileRec.Lines[$lineKey] = @{ Cov = 0; Miss = 0 }
        }
        if ($isHit) { $fileRec.Lines[$lineKey].Cov++ } else { $fileRec.Lines[$lineKey].Miss++ }
    }

    $sb = [System.Text.StringBuilder]::new()
    $null = $sb.AppendLine('<?xml version="1.0" encoding="utf-8" standalone="no"?>')
    $null = $sb.AppendLine('<!DOCTYPE report PUBLIC "-//JACOCO//DTD Report 1.1//EN" "report.dtd"[]>')
    $null = $sb.AppendLine('<report name="Pester ()">')
    $null = $sb.AppendLine("  <sessioninfo id=`"this`" start=`"$startTime`" dump=`"$endTime`" />")

    $repInstrCov = 0; $repInstrMiss = 0
    $repLineCov = 0; $repLineMiss = 0
    $repMethCov = 0; $repMethMiss = 0
    $repClassCov = 0; $repClassMiss = 0

    foreach ($pkgName in ($packages.Keys | Sort-Object)) {
        $escapedPkg = [System.Security.SecurityElement]::Escape($pkgName)
        $null = $sb.AppendLine("  <package name=`"$escapedPkg`">")
        $pkgInstrCov = 0; $pkgInstrMiss = 0
        $pkgLineCov = 0; $pkgLineMiss = 0
        $pkgMethCov = 0; $pkgMethMiss = 0
        $pkgClassCov = 0; $pkgClassMiss = 0

        $sortedFiles = @($packages[$pkgName].Keys | Sort-Object)
        foreach ($relFile in $sortedFiles) {
            $fileRec = $packages[$pkgName][$relFile]
            $escClass = [System.Security.SecurityElement]::Escape($fileRec.ClassName)
            $escSrc = [System.Security.SecurityElement]::Escape($fileRec.SourceFile)
            $null = $sb.AppendLine("    <class name=`"$escClass`" sourcefilename=`"$escSrc`">")

            $fInstrCov = 0; $fInstrMiss = 0
            $fLineCov = 0; $fLineMiss = 0
            $fMethCov = 0; $fMethMiss = 0

            foreach ($mName in $fileRec.Methods.Keys) {
                $m = $fileRec.Methods[$mName]
                $escMeth = [System.Security.SecurityElement]::Escape($mName)
                $mLineCov = @($m.Lines.Values | Where-Object { $_ }).Count
                $mLineMiss = $m.Lines.Count - $mLineCov
                $mCovFlag = if ($m.InstrCov -gt 0) { 1 } else { 0 }
                $mMissFlag = 1 - $mCovFlag
                $fMethCov += $mCovFlag
                $fMethMiss += $mMissFlag

                $null = $sb.AppendLine("      <method name=`"$escMeth`" desc=`"()`" line=`"$($m.FirstLine)`">")
                $null = $sb.AppendLine("        <counter type=`"INSTRUCTION`" missed=`"$($m.InstrMiss)`" covered=`"$($m.InstrCov)`" />")
                $null = $sb.AppendLine("        <counter type=`"LINE`" missed=`"$mLineMiss`" covered=`"$mLineCov`" />")
                $null = $sb.AppendLine("        <counter type=`"METHOD`" missed=`"$mMissFlag`" covered=`"$mCovFlag`" />")
                $null = $sb.AppendLine('      </method>')
            }

            foreach ($lk in $fileRec.Lines.Keys) {
                $l = $fileRec.Lines[$lk]
                $fInstrCov += $l.Cov
                $fInstrMiss += $l.Miss
                if ($l.Cov -gt 0) { $fLineCov++ } else { $fLineMiss++ }
            }
            $fClassCov = if ($fInstrCov -gt 0) { 1 } else { 0 }
            $fClassMiss = 1 - $fClassCov

            $null = $sb.AppendLine("      <counter type=`"INSTRUCTION`" missed=`"$fInstrMiss`" covered=`"$fInstrCov`" />")
            $null = $sb.AppendLine("      <counter type=`"LINE`" missed=`"$fLineMiss`" covered=`"$fLineCov`" />")
            $null = $sb.AppendLine("      <counter type=`"METHOD`" missed=`"$fMethMiss`" covered=`"$fMethCov`" />")
            $null = $sb.AppendLine("      <counter type=`"CLASS`" missed=`"$fClassMiss`" covered=`"$fClassCov`" />")
            $null = $sb.AppendLine('    </class>')

            $pkgInstrCov += $fInstrCov; $pkgInstrMiss += $fInstrMiss
            $pkgLineCov += $fLineCov; $pkgLineMiss += $fLineMiss
            $pkgMethCov += $fMethCov; $pkgMethMiss += $fMethMiss
            $pkgClassCov += $fClassCov; $pkgClassMiss += $fClassMiss
        }

        foreach ($relFile in $sortedFiles) {
            $fileRec = $packages[$pkgName][$relFile]
            $escSrc = [System.Security.SecurityElement]::Escape($fileRec.SourceFile)
            $null = $sb.AppendLine("    <sourcefile name=`"$escSrc`">")
            $fInstrCov = 0; $fInstrMiss = 0
            $fLineCov = 0; $fLineMiss = 0
            foreach ($lk in ($fileRec.Lines.Keys | Sort-Object -Property { [int]$_ })) {
                $l = $fileRec.Lines[$lk]
                $fInstrCov += $l.Cov
                $fInstrMiss += $l.Miss
                if ($l.Cov -gt 0) { $fLineCov++ } else { $fLineMiss++ }
                $null = $sb.AppendLine("      <line nr=`"$lk`" mi=`"$($l.Miss)`" ci=`"$($l.Cov)`" mb=`"0`" cb=`"0`" />")
            }
            $fMethCov = @($fileRec.Methods.Values | Where-Object { $_.InstrCov -gt 0 }).Count
            $fMethMiss = $fileRec.Methods.Count - $fMethCov
            $fClassCov = if ($fInstrCov -gt 0) { 1 } else { 0 }
            $fClassMiss = 1 - $fClassCov
            $null = $sb.AppendLine("      <counter type=`"INSTRUCTION`" missed=`"$fInstrMiss`" covered=`"$fInstrCov`" />")
            $null = $sb.AppendLine("      <counter type=`"LINE`" missed=`"$fLineMiss`" covered=`"$fLineCov`" />")
            $null = $sb.AppendLine("      <counter type=`"METHOD`" missed=`"$fMethMiss`" covered=`"$fMethCov`" />")
            $null = $sb.AppendLine("      <counter type=`"CLASS`" missed=`"$fClassMiss`" covered=`"$fClassCov`" />")
            $null = $sb.AppendLine('    </sourcefile>')
        }

        $null = $sb.AppendLine("    <counter type=`"INSTRUCTION`" missed=`"$pkgInstrMiss`" covered=`"$pkgInstrCov`" />")
        $null = $sb.AppendLine("    <counter type=`"LINE`" missed=`"$pkgLineMiss`" covered=`"$pkgLineCov`" />")
        $null = $sb.AppendLine("    <counter type=`"METHOD`" missed=`"$pkgMethMiss`" covered=`"$pkgMethCov`" />")
        $null = $sb.AppendLine("    <counter type=`"CLASS`" missed=`"$pkgClassMiss`" covered=`"$pkgClassCov`" />")
        $null = $sb.AppendLine('  </package>')

        $repInstrCov += $pkgInstrCov; $repInstrMiss += $pkgInstrMiss
        $repLineCov += $pkgLineCov; $repLineMiss += $pkgLineMiss
        $repMethCov += $pkgMethCov; $repMethMiss += $pkgMethMiss
        $repClassCov += $pkgClassCov; $repClassMiss += $pkgClassMiss
    }

    $null = $sb.AppendLine("  <counter type=`"INSTRUCTION`" missed=`"$repInstrMiss`" covered=`"$repInstrCov`" />")
    $null = $sb.AppendLine("  <counter type=`"LINE`" missed=`"$repLineMiss`" covered=`"$repLineCov`" />")
    $null = $sb.AppendLine("  <counter type=`"METHOD`" missed=`"$repMethMiss`" covered=`"$repMethCov`" />")
    $null = $sb.AppendLine("  <counter type=`"CLASS`" missed=`"$repClassMiss`" covered=`"$repClassCov`" />")
    $null = $sb.AppendLine('</report>')

    $utf8Bom = [System.Text.UTF8Encoding]::new($true)
    [System.IO.File]::WriteAllText($OutputPath, $sb.ToString(), $utf8Bom)
}

<#
.SYNOPSIS
Merges JUnit XML test result files from multiple shards into a single JUnit XML file.
.PARAMETER InputFiles
Paths to shard JUnit XML files.
.PARAMETER OutputPath
Path to write the merged JUnit XML file.
#>
function Merge-ShardJUnitXml {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$InputFiles,

        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $doc = [xml]'<?xml version="1.0" encoding="utf-8" standalone="no"?><testsuites xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="junit_schema_4.xsd" name="BridgeWatcher" tests="0" errors="0" failures="0" disabled="0" time="0.000"></testsuites>'
    $rootNode = $doc.DocumentElement

    $totalTests = 0
    $totalErrors = 0
    $totalFailures = 0
    $totalDisabled = 0
    $totalTime = 0.0
    $suiteId = 0

    foreach ($file in $InputFiles) {
        if (-not (Test-Path -LiteralPath $file)) {
            throw "Expected shard JUnit XML file not found: $file"
        }
        [xml]$shardDoc = Get-Content -LiteralPath $file -Raw
        $suites = $shardDoc.SelectNodes('/testsuites/testsuite')
        foreach ($suite in $suites) {
            $imported = $doc.ImportNode($suite, $true)
            $imported.SetAttribute('id', [string]$suiteId)
            $suiteId++
            $null = $rootNode.AppendChild($imported)

            $totalTests += [int]$suite.GetAttribute('tests')
            $totalErrors += [int]$suite.GetAttribute('errors')
            $totalFailures += [int]$suite.GetAttribute('failures')
            $disabledAttr = $suite.GetAttribute('disabled')
            if ($disabledAttr) { $totalDisabled += [int]$disabledAttr }
            $timeAttr = $suite.GetAttribute('time')
            if ($timeAttr) {
                $parsedTime = 0.0
                if ([double]::TryParse($timeAttr, [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$parsedTime)) {
                    $totalTime += $parsedTime
                }
            }
        }
    }

    $rootNode.SetAttribute('tests', [string]$totalTests)
    $rootNode.SetAttribute('errors', [string]$totalErrors)
    $rootNode.SetAttribute('failures', [string]$totalFailures)
    $rootNode.SetAttribute('disabled', [string]$totalDisabled)
    $rootNode.SetAttribute('time', $totalTime.ToString('0.000', [System.Globalization.CultureInfo]::InvariantCulture))

    $settings = [System.Xml.XmlWriterSettings]::new()
    $settings.Indent = $true
    $settings.Encoding = [System.Text.UTF8Encoding]::new($true)
    $writer = [System.Xml.XmlWriter]::Create($OutputPath, $settings)
    try {
        $doc.Save($writer)
    } finally {
        $writer.Dispose()
    }
}

<#
.SYNOPSIS
Merges command-level coverage JSON files from multiple shards and verifies denominator integrity.
.PARAMETER InputFiles
Paths to shard coverage JSON files.
#>
function Merge-ShardCoverageData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$InputFiles
    )

    $merged = [ordered]@{}
    $expectedCount = $null

    foreach ($file in $InputFiles) {
        if (-not (Test-Path -LiteralPath $file)) {
            throw "Expected shard coverage JSON file not found: $file"
        }
        $data = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json
        $shardCount = [int]$data.CommandsAnalyzed
        if ($shardCount -le 0) {
            throw "Shard coverage file '$file' reported 0 analyzed commands."
        }
        if ($null -eq $expectedCount) {
            $expectedCount = $shardCount
        } elseif ($shardCount -ne $expectedCount) {
            throw "Shard coverage denominator mismatch in '$file': expected $expectedCount analyzed commands, got $shardCount."
        }

        foreach ($cmd in @($data.Commands)) {
            $key = "$($cmd.File)|$($cmd.StartLine)|$($cmd.EndLine)|$($cmd.StartColumn)|$($cmd.EndColumn)|$($cmd.Function)"
            if (-not $merged.Contains($key)) {
                $merged[$key] = [pscustomobject]@{
                    File        = [string]$cmd.File
                    StartLine   = [int]$cmd.StartLine
                    EndLine     = [int]$cmd.EndLine
                    StartColumn = [int]$cmd.StartColumn
                    EndColumn   = [int]$cmd.EndColumn
                    Function    = [string]$cmd.Function
                    Command     = [string]$cmd.Command
                    HitCount    = [int]$cmd.HitCount
                }
            } else {
                $merged[$key].HitCount += [int]$cmd.HitCount
            }
        }
    }

    if ($merged.Count -ne $expectedCount) {
        throw "Merged coverage command count ($($merged.Count)) does not match per-shard denominator ($expectedCount)."
    }

    $allCommands = @($merged.Values)
    $executed = @($allCommands | Where-Object { $_.HitCount -gt 0 })
    $missed = @($allCommands | Where-Object { $_.HitCount -eq 0 })
    $percent = if ($allCommands.Count -eq 0) { 0.0 } else { ($executed.Count / $allCommands.Count) * 100.0 }

    return [pscustomobject]@{
        CommandsAnalyzed = $allCommands.Count
        CommandsExecuted = $executed.Count
        CommandsMissed   = $missed.Count
        CoveragePercent  = $percent
        MissedCommands   = $missed
        Commands         = $allCommands
    }
}

<#
.SYNOPSIS
Executes a single Pester shard in the current process and emits summary, timing, JUnit, and command-level coverage files.
.PARAMETER AssignedFiles
Array of test file paths assigned to this shard.
.PARAMETER Root
Resolved repository root path.
.PARAMETER OutputDir
Directory for shard output artifacts.
.PARAMETER EnableCoverage
Whether to measure and export command-level coverage.
.PARAMETER IncludeIntegrationTag
Whether to allow Integration-tagged tests to execute.
.PARAMETER EnableShuffle
Whether to enable Pester Shuffle.
.PARAMETER ShuffleSeed
Seed value for Pester Shuffle.
#>
function Invoke-LocalShardWorker {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$AssignedFiles,

        [Parameter(Mandatory)]
        [string]$Root,

        [Parameter(Mandatory)]
        [string]$OutputDir,

        [Parameter()]
        [bool]$EnableCoverage = $true,

        [Parameter()]
        [bool]$IncludeIntegrationTag = $false,

        [Parameter()]
        [bool]$EnableShuffle = $false,

        [Parameter()]
        [int]$ShuffleSeed = 0
    )

    Import-Module -Name Pester -MinimumVersion 5.0 -Force
    Import-Module -Name (Join-Path -Path $Root -ChildPath 'BridgeWatcher/BridgeWatcher.psd1') -Force

    $configPath = Join-Path -Path $Root -ChildPath 'Tests/PesterConfiguration.psd1'
    $configData = Import-PowerShellDataFile -Path $configPath

    $configData.Run.Path = @($AssignedFiles)
    $configData.Run.PassThru = $true
    $configData.Run.Exit = $false
    $configData.Run.Throw = $false

    if ($IncludeIntegrationTag) {
        $configData.Filter.ExcludeTag = @()
    }

    if ($EnableShuffle) {
        $configData.Run.Shuffle = $true
        $configData.Run.ShuffleSeed = $ShuffleSeed
    }

    $junitPath = Join-Path -Path $OutputDir -ChildPath 'junit.xml'
    $configData.TestResult.Enabled = $true
    $configData.TestResult.OutputPath = $junitPath

    $jacocoPath = Join-Path -Path $OutputDir -ChildPath 'coverage.xml'
    if ($EnableCoverage) {
        $configData.CodeCoverage.Enabled = $true
        $configData.CodeCoverage.OutputPath = $jacocoPath
        $configData.CodeCoverage.Path = @(
            (Join-Path -Path $Root -ChildPath 'BridgeWatcher/Public/*.ps1'),
            (Join-Path -Path $Root -ChildPath 'BridgeWatcher/Private/*.ps1')
        )
    } else {
        $configData.CodeCoverage.Enabled = $false
    }

    $configData.Output.Verbosity = 'Normal'

    $pesterConfig = New-PesterConfiguration -Hashtable $configData
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $result = Invoke-Pester -Configuration $pesterConfig
    $sw.Stop()

    # Export per-file timings
    $timings = [ordered]@{}
    foreach ($container in @($result.Containers)) {
        $itemPath = if ($container.Item -is [System.IO.FileInfo]) { $container.Item.FullName } else { [string]$container.Item }
        $rel = ConvertTo-RepoRelativePath -Path $itemPath -Root $Root
        $timings[$rel] = [Math]::Round($container.Duration.TotalSeconds, 3)
    }
    ConvertTo-Json -InputObject $timings -Depth 3 | Set-Content -LiteralPath (Join-Path -Path $OutputDir -ChildPath 'timings.json') -Encoding utf8

    # Export exact command-level coverage
    if ($EnableCoverage) {
        $commands = [System.Collections.Generic.List[object]]::new()
        foreach ($cmd in @($result.CodeCoverage.CommandsExecuted)) {
            $commands.Add([pscustomobject]@{
                File        = [string]$cmd.File
                StartLine   = [int]$cmd.StartLine
                EndLine     = [int]$cmd.EndLine
                StartColumn = [int]$cmd.StartColumn
                EndColumn   = [int]$cmd.EndColumn
                Function    = [string]$cmd.Function
                Command     = [string]$cmd.Command
                HitCount    = [Math]::Max(1, [int]$cmd.HitCount)
            })
        }
        foreach ($cmd in @($result.CodeCoverage.CommandsMissed)) {
            $commands.Add([pscustomobject]@{
                File        = [string]$cmd.File
                StartLine   = [int]$cmd.StartLine
                EndLine     = [int]$cmd.EndLine
                StartColumn = [int]$cmd.StartColumn
                EndColumn   = [int]$cmd.EndColumn
                Function    = [string]$cmd.Function
                Command     = [string]$cmd.Command
                HitCount    = 0
            })
        }
        $covPayload = [pscustomobject]@{
            CommandsAnalyzed = $commands.Count
            CommandsExecuted = @($result.CodeCoverage.CommandsExecuted).Count
            CommandsMissed   = @($result.CodeCoverage.CommandsMissed).Count
            Commands         = @($commands)
        }
        ConvertTo-Json -InputObject $covPayload -Depth 4 -Compress | Set-Content -LiteralPath (Join-Path -Path $OutputDir -ChildPath 'coverage-commands.json') -Encoding utf8
    }

    $summary = [pscustomobject]@{
        Result        = [string]$result.Result
        PassedCount   = [int]$result.PassedCount
        FailedCount   = [int]$result.FailedCount
        SkippedCount  = [int]$result.SkippedCount
        NotRunCount   = [int]$result.NotRunCount
        TotalCount    = [int]$result.TotalCount
        DurationMs    = [long]$sw.ElapsedMilliseconds
        FilesExecuted = @($AssignedFiles).Count
    }
    ConvertTo-Json -InputObject $summary -Depth 3 | Set-Content -LiteralPath (Join-Path -Path $OutputDir -ChildPath 'summary.json') -Encoding utf8

    if ($result.Result -ne 'Passed' -or $result.FailedCount -gt 0) {
        exit 1
    }
}

# ---- Entry Point ----
if ($MyInvocation.InvocationName -eq '.') {
    return
}

$resolvedRoot = (Resolve-Path -LiteralPath $RepositoryRoot).Path
if ([string]::IsNullOrWhiteSpace($CoverageOutputPath)) {
    $CoverageOutputPath = Join-Path -Path $resolvedRoot -ChildPath 'coverage.xml'
}
if ([string]::IsNullOrWhiteSpace($TestResultOutputPath)) {
    $TestResultOutputPath = Join-Path -Path $resolvedRoot -ChildPath 'testResults.xml'
}

# Child worker execution mode
if (-not [string]::IsNullOrWhiteSpace($WorkerManifestPath)) {
    $manifest = Get-Content -LiteralPath $WorkerManifestPath -Raw | ConvertFrom-Json
    $assignedFiles = @($manifest.Files)
    Invoke-LocalShardWorker `
        -AssignedFiles $assignedFiles `
        -Root $resolvedRoot `
        -OutputDir $WorkerOutputDirectory `
        -EnableCoverage (-not $SkipCoverage) `
        -IncludeIntegrationTag ([bool]($IncludeIntegration -or $IntegrationOnly)) `
        -EnableShuffle ([bool]$Shuffle) `
        -ShuffleSeed $Seed
    return
}

$overallSw = [System.Diagnostics.Stopwatch]::StartNew()

$effectiveSeed = $Seed
if ($Shuffle -and $effectiveSeed -eq 0) {
    $effectiveSeed = Get-Random -Minimum 1 -Maximum 2147483647
}

$inventory = Get-TrackedTestInventory -Root $resolvedRoot
$targetFiles = if ($TestFiles.Count -gt 0) {
    @($TestFiles | ForEach-Object { (Resolve-Path -LiteralPath $_).Path } | Select-Object -Unique)
} elseif ($IntegrationOnly) {
    @($inventory.IntegrationFiles)
} elseif ($IncludeIntegration) {
    @($inventory.UnitFiles) + @($inventory.IntegrationFiles)
} else {
    @($inventory.UnitFiles)
}

if ($targetFiles.Count -eq 0) {
    throw 'Test inventory is empty; refusing to report an empty successful run.'
}

$timingsMap = Get-HistoricalTestTiming -Path $TimingsPath
$shards = Split-TestFilesIntoShard -Files $targetFiles -Count $ShardCount -Root $resolvedRoot -TimingsMap $timingsMap

Write-Output "Test inventory: total tracked=$($inventory.AllFiles.Count) (unit=$($inventory.UnitFiles.Count), integration=$($inventory.IntegrationFiles.Count)); selected=$($targetFiles.Count); shards=$($shards.Count)"
if ($Shuffle) {
    $reproCmd = "pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -Shuffle -Seed $effectiveSeed"
    if ($ShardCount -gt 1) {
        $reproCmd += " -ShardCount $ShardCount"
    }
    if ($RunAllShardsInParallel) {
        $reproCmd += ' -RunAllShardsInParallel'
    }
    Write-Output "Randomized order enabled with seed=$effectiveSeed"
    Write-Output "Reproduce locally: $reproCmd"
}

$workRoot = Join-Path -Path ([System.IO.Path]::GetTempPath()) -ChildPath ("bw-testrun-" + [System.Guid]::NewGuid().ToString('N'))
$null = New-Item -Path $workRoot -ItemType Directory -Force

$correctnessFailed = $false
$failureReasons = [System.Collections.Generic.List[string]]::new()

try {
    $shouldEnforceCoverage = (-not $SkipCoverage) -and (-not $IntegrationOnly)

    if (-not $RunAllShardsInParallel) {
        if ($ShardIndex -ge $shards.Count) {
            throw "Requested ShardIndex $ShardIndex is out of range for $($shards.Count) active shard(s)."
        }
        $shard = $shards[$ShardIndex]
        $shardDir = Join-Path -Path $workRoot -ChildPath "shard-$ShardIndex"
        $null = New-Item -Path $shardDir -ItemType Directory -Force

        $singleFailed = $false
        try {
            Invoke-LocalShardWorker `
                -AssignedFiles @($shard.Files) `
                -Root $resolvedRoot `
                -OutputDir $shardDir `
                -EnableCoverage $shouldEnforceCoverage `
                -IncludeIntegrationTag ([bool]($IncludeIntegration -or $IntegrationOnly)) `
                -EnableShuffle ([bool]$Shuffle) `
                -ShuffleSeed $effectiveSeed
        } catch {
            $singleFailed = $true
            $failureReasons.Add($_.Exception.Message)
        }

        if (Test-Path -LiteralPath (Join-Path -Path $shardDir -ChildPath 'junit.xml')) {
            Copy-Item -LiteralPath (Join-Path -Path $shardDir -ChildPath 'junit.xml') -Destination $TestResultOutputPath -Force
        }
        if ($shouldEnforceCoverage -and (Test-Path -LiteralPath (Join-Path -Path $shardDir -ChildPath 'coverage.xml'))) {
            Copy-Item -LiteralPath (Join-Path -Path $shardDir -ChildPath 'coverage.xml') -Destination $CoverageOutputPath -Force
        }
        if (-not [string]::IsNullOrWhiteSpace($RecordTimingsPath) -and (Test-Path -LiteralPath (Join-Path -Path $shardDir -ChildPath 'timings.json'))) {
            Copy-Item -LiteralPath (Join-Path -Path $shardDir -ChildPath 'timings.json') -Destination $RecordTimingsPath -Force
        }

        if ($singleFailed) {
            $correctnessFailed = $true
        } else {
            $summary = Get-Content -LiteralPath (Join-Path -Path $shardDir -ChildPath 'summary.json') -Raw | ConvertFrom-Json
            if ($summary.Result -ne 'Passed' -or $summary.FailedCount -gt 0) {
                $correctnessFailed = $true
                $failureReasons.Add("Shard $ShardIndex failed ($($summary.FailedCount) failed tests).")
            }
            if ($shouldEnforceCoverage -and $shards.Count -eq 1) {
                $cov = Merge-ShardCoverageData -InputFiles @((Join-Path -Path $shardDir -ChildPath 'coverage-commands.json'))
                Write-Output ("Coverage: {0:N2}% ({1}/{2} analyzed commands)" -f $cov.CoveragePercent, $cov.CommandsExecuted, $cov.CommandsAnalyzed)
                if ($cov.CoveragePercent -lt $CoverageThreshold) {
                    $correctnessFailed = $true
                    $failureReasons.Add(("Coverage {0:N2}% is below required {1:N2}%." -f $cov.CoveragePercent, $CoverageThreshold))
                }
            }
        }
    } else {
        $pwshExe = (Get-Process -Id $PID).Path
        $workerLimit = if ($Workers -gt 0) { $Workers } else { [Environment]::ProcessorCount }
        $workerLimit = [Math]::Max(1, [Math]::Min($workerLimit, $shards.Count))
        Write-Output "Running $($shards.Count) process-isolated shards with up to $workerLimit concurrent worker(s)..."

        $pending = [System.Collections.Generic.Queue[object]]::new()
        foreach ($s in $shards) { $pending.Enqueue($s) }

        $active = [System.Collections.Generic.List[object]]::new()
        $completed = [System.Collections.Generic.List[object]]::new()

        while ($pending.Count -gt 0 -or $active.Count -gt 0) {
            while ($pending.Count -gt 0 -and $active.Count -lt $workerLimit) {
                $s = $pending.Dequeue()
                $sDir = Join-Path -Path $workRoot -ChildPath "shard-$($s.Index)"
                $sTmp = Join-Path -Path $sDir -ChildPath 'tmp'
                $null = New-Item -Path $sTmp -ItemType Directory -Force
                $manifestPath = Join-Path -Path $sDir -ChildPath 'manifest.json'
                ConvertTo-Json -InputObject ([pscustomobject]@{ Files = @($s.Files) }) -Depth 3 | Set-Content -LiteralPath $manifestPath -Encoding utf8

                $argList = @(
                    '-NoProfile', '-NonInteractive', '-File', $PSCommandPath,
                    '-RepositoryRoot', $resolvedRoot,
                    '-WorkerOutputDirectory', $sDir,
                    '-WorkerManifestPath', $manifestPath
                )
                if (-not $shouldEnforceCoverage) { $argList += '-SkipCoverage' }
                if ($IncludeIntegration) { $argList += '-IncludeIntegration' }
                if ($IntegrationOnly) { $argList += '-IntegrationOnly' }
                if ($Shuffle) {
                    $argList += '-Shuffle'
                    $argList += '-Seed'
                    $argList += [string]($effectiveSeed + $s.Index)
                }

                $psi = [System.Diagnostics.ProcessStartInfo]::new()
                $psi.FileName = $pwshExe
                foreach ($arg in $argList) { $null = $psi.ArgumentList.Add($arg) }
                $psi.WorkingDirectory = $resolvedRoot
                $psi.UseShellExecute = $false
                $psi.RedirectStandardOutput = $true
                $psi.RedirectStandardError = $true
                # Give each shard its own isolated temporary directory.
                $psi.Environment['TMPDIR'] = $sTmp
                $psi.Environment['TEMP'] = $sTmp
                $psi.Environment['TMP'] = $sTmp

                $proc = [System.Diagnostics.Process]::new()
                $proc.StartInfo = $psi
                $null = $proc.Start()
                $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
                $stderrTask = $proc.StandardError.ReadToEndAsync()

                $active.Add([pscustomobject]@{
                    Shard      = $s
                    Dir        = $sDir
                    Process    = $proc
                    StdoutTask = $stdoutTask
                    StderrTask = $stderrTask
                })
            }

            Start-Sleep -Milliseconds 100
            for ($i = $active.Count - 1; $i -ge 0; $i--) {
                $entry = $active[$i]
                if ($entry.Process.HasExited) {
                    $entry.Process.WaitForExit()
                    $completed.Add($entry)
                    $active.RemoveAt($i)
                }
            }
        }

        $totalPassed = 0
        $totalFailed = 0
        $totalSkipped = 0
        $totalNotRun = 0
        $junitFiles = [System.Collections.Generic.List[string]]::new()
        $covFiles = [System.Collections.Generic.List[string]]::new()
        $mergedTimings = [ordered]@{}

        foreach ($entry in ($completed | Sort-Object -Property { $_.Shard.Index })) {
            $stdout = $entry.StdoutTask.GetAwaiter().GetResult()
            $stderr = $entry.StderrTask.GetAwaiter().GetResult()
            $exitCode = $entry.Process.ExitCode
            $entry.Process.Dispose()

            $summaryPath = Join-Path -Path $entry.Dir -ChildPath 'summary.json'
            $summary = if (Test-Path -LiteralPath $summaryPath) {
                Get-Content -LiteralPath $summaryPath -Raw | ConvertFrom-Json
            } else {
                $null
            }

            if ($summary) {
                $totalPassed += [int]$summary.PassedCount
                $totalFailed += [int]$summary.FailedCount
                $totalSkipped += [int]$summary.SkippedCount
                $totalNotRun += [int]$summary.NotRunCount
                Write-Output ("Shard {0}: Result={1} Passed={2} Failed={3} Skipped={4} Files={5} Duration={6:N2}s" -f $entry.Shard.Index, $summary.Result, $summary.PassedCount, $summary.FailedCount, $summary.SkippedCount, $summary.FilesExecuted, ($summary.DurationMs / 1000.0))
            }

            if ($exitCode -ne 0 -or ($null -eq $summary) -or $summary.Result -ne 'Passed' -or $summary.FailedCount -gt 0) {
                $correctnessFailed = $true
                $failureReasons.Add("Shard $($entry.Shard.Index) failed with exit code $exitCode.")
                if (-not [string]::IsNullOrWhiteSpace($stdout)) { Write-Output $stdout }
                if (-not [string]::IsNullOrWhiteSpace($stderr)) { Write-Output $stderr }
            }

            $jFile = Join-Path -Path $entry.Dir -ChildPath 'junit.xml'
            if (Test-Path -LiteralPath $jFile) { $junitFiles.Add($jFile) }
            $cFile = Join-Path -Path $entry.Dir -ChildPath 'coverage-commands.json'
            if (Test-Path -LiteralPath $cFile) { $covFiles.Add($cFile) }
            $tFile = Join-Path -Path $entry.Dir -ChildPath 'timings.json'
            if (Test-Path -LiteralPath $tFile) {
                $tData = Get-Content -LiteralPath $tFile -Raw | ConvertFrom-Json
                foreach ($prop in $tData.PSObject.Properties) {
                    $mergedTimings[$prop.Name] = $prop.Value
                }
            }
        }

        Write-Output "Merged tests: Passed=$totalPassed Failed=$totalFailed Skipped=$totalSkipped NotRun=$totalNotRun"

        if ($junitFiles.Count -eq $shards.Count) {
            Merge-ShardJUnitXml -InputFiles @($junitFiles) -OutputPath $TestResultOutputPath
        } elseif ($junitFiles.Count -gt 0) {
            Merge-ShardJUnitXml -InputFiles @($junitFiles) -OutputPath $TestResultOutputPath
            $correctnessFailed = $true
            $failureReasons.Add("Only $($junitFiles.Count) of $($shards.Count) shards produced JUnit XML.")
        }

        if (-not [string]::IsNullOrWhiteSpace($RecordTimingsPath)) {
            $sortedTimings = [ordered]@{}
            foreach ($k in ($mergedTimings.Keys | Sort-Object)) {
                $sortedTimings[$k] = $mergedTimings[$k]
            }
            ConvertTo-Json -InputObject $sortedTimings -Depth 3 | Set-Content -LiteralPath $RecordTimingsPath -Encoding utf8
        }

        if ($shouldEnforceCoverage) {
            if ($covFiles.Count -ne $shards.Count) {
                $correctnessFailed = $true
                $failureReasons.Add("Expected $($shards.Count) coverage shard files, found $($covFiles.Count).")
            } else {
                $cov = Merge-ShardCoverageData -InputFiles @($covFiles)
                Export-MergedJaCoCoXml `
                    -MergedCommands $cov.Commands `
                    -ReportRoot $resolvedRoot `
                    -OutputPath $CoverageOutputPath `
                    -ElapsedMilliseconds $overallSw.ElapsedMilliseconds
                Write-Output ("Merged coverage: {0:N2}% ({1}/{2} analyzed commands)" -f $cov.CoveragePercent, $cov.CommandsExecuted, $cov.CommandsAnalyzed)
                if ($cov.CoveragePercent -lt $CoverageThreshold) {
                    $correctnessFailed = $true
                    $failureReasons.Add(("Merged coverage {0:N2}% is below required {1:N2}% ({2} missed commands)." -f $cov.CoveragePercent, $CoverageThreshold, $cov.CommandsMissed))
                    foreach ($mc in ($cov.MissedCommands | Select-Object -First 20)) {
                        Write-Output "  MISSED: $($mc.File):$($mc.StartLine) ($($mc.Function)) $($mc.Command)"
                    }
                }
            }
        }
    }
} finally {
    if (Test-Path -LiteralPath $workRoot) {
        Remove-Item -LiteralPath $workRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

$overallSw.Stop()
$elapsedSeconds = [Math]::Round($overallSw.Elapsed.TotalSeconds, 2)
Write-Output "Test suite completed in ${elapsedSeconds}s"

if ($correctnessFailed) {
    $detail = $failureReasons -join '; '
    throw "TEST SUITE FAILED: $detail"
}

if ($MaxDurationSeconds -gt 0 -and $overallSw.Elapsed.TotalSeconds -gt $MaxDurationSeconds) {
    throw "PERFORMANCE BUDGET EXCEEDED: Test suite took ${elapsedSeconds}s (budget: ${MaxDurationSeconds}s). Correctness passed."
}
