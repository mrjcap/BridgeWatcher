$ErrorActionPreference = 'Stop'

Describe -Name 'Invoke-TestSuite Orchestrator' -Fixture {
    BeforeAll -Scriptblock {
        $script:repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $script:repoRoot -ChildPath 'scripts/Invoke-TestSuite.ps1')
    }

    Context -Name 'Test inventory accounting' -Fixture {
        It -Name 'Accounts for every tracked test file and explicitly separates Integration-tagged tests' -Test {
            $inventory = Get-TrackedTestInventory -Root $script:repoRoot

            $inventory.AllFiles.Count | Should -BeGreaterThan -ExpectedValue 0
            $inventory.UnitFiles.Count | Should -BeGreaterThan -ExpectedValue 0
            $inventory.IntegrationFiles.Count | Should -BeGreaterThan -ExpectedValue 0
            ($inventory.UnitFiles.Count + $inventory.IntegrationFiles.Count) | Should -Be -ExpectedValue $inventory.AllFiles.Count

            $integrationNames = @($inventory.IntegrationFiles | ForEach-Object -Process { Split-Path -Path $_ -Leaf })
            $integrationNames | Should -Contain -ExpectedValue 'Integration.Tests.ps1'

            $unitNames = @($inventory.UnitFiles | ForEach-Object -Process { Split-Path -Path $_ -Leaf })
            $unitNames | Should -Not -Contain -ExpectedValue 'Integration.Tests.ps1'
        }
    }

    Context -Name 'Balanced shard partitioning and completeness verification' -Fixture {
        It -Name 'Balances heavy test files across shards using LPT timings and falls back safely for unmeasured files' -Test {
            $root = Join-Path -Path $TestDrive -ChildPath 'repo'
            $files = @(
                (Join-Path -Path $root -ChildPath 'Tests/SlowA.Tests.ps1'),
                (Join-Path -Path $root -ChildPath 'Tests/SlowB.Tests.ps1'),
                (Join-Path -Path $root -ChildPath 'Tests/MedC.Tests.ps1'),
                (Join-Path -Path $root -ChildPath 'Tests/FastD.Tests.ps1'),
                (Join-Path -Path $root -ChildPath 'Tests/BrandNewUnmeasured.Tests.ps1')
            )
            $timings = @{
                'Tests/SlowA.Tests.ps1' = 12.0
                'Tests/SlowB.Tests.ps1' = 10.0
                'Tests/MedC.Tests.ps1'  = 5.0
                'Tests/FastD.Tests.ps1' = 1.0
            }

            $shards = Split-TestFilesIntoShard -Files $files -Count 2 -Root $root -TimingsMap $timings

            $shards.Count | Should -Be -ExpectedValue 2
            $allAssigned = @($shards | ForEach-Object -Process { $_.Files })
            $allAssigned.Count | Should -Be -ExpectedValue $files.Count
            @($allAssigned | Select-Object -Unique).Count | Should -Be -ExpectedValue $files.Count

            $shard0Names = @($shards[0].Files | ForEach-Object -Process { Split-Path -Path $_ -Leaf })
            $shard1Names = @($shards[1].Files | ForEach-Object -Process { Split-Path -Path $_ -Leaf })
            (($shard0Names -contains 'SlowA.Tests.ps1') -xor ($shard1Names -contains 'SlowA.Tests.ps1')) | Should -BeTrue
            (($shard0Names -contains 'SlowB.Tests.ps1') -xor ($shard1Names -contains 'SlowB.Tests.ps1')) | Should -BeTrue
            (($shard0Names -contains 'SlowA.Tests.ps1') -and ($shard0Names -contains 'SlowB.Tests.ps1')) | Should -BeFalse
            (($shard1Names -contains 'SlowA.Tests.ps1') -and ($shard1Names -contains 'SlowB.Tests.ps1')) | Should -BeFalse
        }

        It -Name 'Rejects duplicate test files in the input inventory' -Test {
            $root = Join-Path -Path $TestDrive -ChildPath 'dup-repo'
            $f1 = Join-Path -Path $root -ChildPath 'Tests/Alpha.Tests.ps1'
            { Split-TestFilesIntoShard -Files @($f1, $f1) -Count 2 -Root $root -TimingsMap @{} } | Should -Throw -ExpectedMessage '*Shard inventory verification failed*'
        }

        It -Name 'Loads valid historical timings JSON and ignores missing files safely' -Test {
            $missing = Get-HistoricalTestTiming -Path (Join-Path -Path $TestDrive -ChildPath 'does-not-exist.json')
            $missing.Count | Should -Be -ExpectedValue 0

            $timingsFile = Join-Path -Path $TestDrive -ChildPath 'timings.json'
            '{"Tests/A.Tests.ps1": 4.25, "Tests/B.Tests.ps1": 0}' | Set-Content -LiteralPath $timingsFile -Encoding utf8
            $loaded = Get-HistoricalTestTiming -Path $timingsFile
            $loaded['Tests/A.Tests.ps1'] | Should -Be -ExpectedValue 4.25
            $loaded.ContainsKey('Tests/B.Tests.ps1') | Should -BeFalse
        }
    }

    Context -Name 'Command-level coverage and JUnit aggregation' -Fixture {
        It -Name 'Unions command hits across shards while enforcing identical denominators and exports JaCoCo XML' -Test {
            $cov1 = Join-Path -Path $TestDrive -ChildPath 'cov1.json'
            $cov2 = Join-Path -Path $TestDrive -ChildPath 'cov2.json'
            $jacocoOut = Join-Path -Path $TestDrive -ChildPath 'merged-coverage.xml'
            $fakeRoot = Join-Path -Path $TestDrive -ChildPath 'proj'
            $srcFile = Join-Path -Path $fakeRoot -ChildPath 'BridgeWatcher/Public/Test-Demo.ps1'

            @{
                CommandsAnalyzed = 2
                CommandsExecuted = 1
                CommandsMissed   = 1
                Commands         = @(
                    @{ File = $srcFile; StartLine = 10; EndLine = 10; StartColumn = 1; EndColumn = 12; Function = 'Test-Demo'; Command = 'Write-Output 1'; HitCount = 1 },
                    @{ File = $srcFile; StartLine = 11; EndLine = 11; StartColumn = 1; EndColumn = 12; Function = 'Test-Demo'; Command = 'Write-Output 2'; HitCount = 0 }
                )
            } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cov1 -Encoding utf8

            @{
                CommandsAnalyzed = 2
                CommandsExecuted = 1
                CommandsMissed   = 1
                Commands         = @(
                    @{ File = $srcFile; StartLine = 10; EndLine = 10; StartColumn = 1; EndColumn = 12; Function = 'Test-Demo'; Command = 'Write-Output 1'; HitCount = 0 },
                    @{ File = $srcFile; StartLine = 11; EndLine = 11; StartColumn = 1; EndColumn = 12; Function = 'Test-Demo'; Command = 'Write-Output 2'; HitCount = 2 }
                )
            } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cov2 -Encoding utf8

            $merged = Merge-ShardCoverageData -InputFiles @($cov1, $cov2)
            $merged.CommandsAnalyzed | Should -Be -ExpectedValue 2
            $merged.CommandsExecuted | Should -Be -ExpectedValue 2
            $merged.CommandsMissed | Should -Be -ExpectedValue 0
            $merged.CoveragePercent | Should -Be -ExpectedValue 100

            Export-MergedJaCoCoXml -MergedCommands $merged.Commands -ReportRoot $fakeRoot -OutputPath $jacocoOut -ElapsedMilliseconds 1200
            Test-Path -LiteralPath $jacocoOut | Should -BeTrue
            [xml]$doc = Get-Content -LiteralPath $jacocoOut -Raw
            $instrCounter = $doc.SelectSingleNode('/report/counter[@type="INSTRUCTION"]')
            $instrCounter.GetAttribute('covered') | Should -Be -ExpectedValue '2'
            $instrCounter.GetAttribute('missed') | Should -Be -ExpectedValue '0'
        }

        It -Name 'Fails loudly when shard coverage denominators do not match' -Test {
            $cov1 = Join-Path -Path $TestDrive -ChildPath 'mismatch1.json'
            $cov2 = Join-Path -Path $TestDrive -ChildPath 'mismatch2.json'

            @{
                CommandsAnalyzed = 2
                Commands         = @(
                    @{ File = 'a.ps1'; StartLine = 1; EndLine = 1; StartColumn = 1; EndColumn = 5; Function = 'f'; Command = 'c1'; HitCount = 1 },
                    @{ File = 'a.ps1'; StartLine = 2; EndLine = 2; StartColumn = 1; EndColumn = 5; Function = 'f'; Command = 'c2'; HitCount = 1 }
                )
            } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cov1 -Encoding utf8

            @{
                CommandsAnalyzed = 1
                Commands         = @(
                    @{ File = 'a.ps1'; StartLine = 1; EndLine = 1; StartColumn = 1; EndColumn = 5; Function = 'f'; Command = 'c1'; HitCount = 1 }
                )
            } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath $cov2 -Encoding utf8

            { Merge-ShardCoverageData -InputFiles @($cov1, $cov2) } | Should -Throw -ExpectedMessage '*denominator mismatch*'
        }

        It -Name 'Merges JUnit XML reports from multiple shards preserving test counts, failures, and durations' -Test {
            $j1 = Join-Path -Path $TestDrive -ChildPath 'j1.xml'
            $j2 = Join-Path -Path $TestDrive -ChildPath 'j2.xml'
            $mergedOut = Join-Path -Path $TestDrive -ChildPath 'merged-junit.xml'

            '<?xml version="1.0" encoding="utf-8"?><testsuites><testsuite name="Shard0" tests="3" errors="0" failures="0" disabled="0" time="1.250"><testcase name="t1" /></testsuite></testsuites>' |
                Set-Content -LiteralPath $j1 -Encoding utf8
            '<?xml version="1.0" encoding="utf-8"?><testsuites><testsuite name="Shard1" tests="2" errors="0" failures="1" disabled="1" time="0.750"><testcase name="t2" /></testsuite></testsuites>' |
                Set-Content -LiteralPath $j2 -Encoding utf8

            Merge-ShardJUnitXml -InputFiles @($j1, $j2) -OutputPath $mergedOut
            Test-Path -LiteralPath $mergedOut | Should -BeTrue
            [xml]$doc = Get-Content -LiteralPath $mergedOut -Raw
            $doc.DocumentElement.GetAttribute('tests') | Should -Be -ExpectedValue '5'
            $doc.DocumentElement.GetAttribute('failures') | Should -Be -ExpectedValue '1'
            $doc.DocumentElement.GetAttribute('disabled') | Should -Be -ExpectedValue '1'
            $doc.DocumentElement.GetAttribute('time') | Should -Be -ExpectedValue '2.000'
        }

        It -Name 'Merges matrix shard artifact bundles verifying complete inventory, 100% coverage, JUnit, and timings' -Test {
            $fakeRoot = Join-Path -Path $TestDrive -ChildPath 'matrix-proj'
            $srcFile = Join-Path -Path $fakeRoot -ChildPath 'BridgeWatcher/Public/Test-Demo.ps1'
            $t1 = Join-Path -Path $fakeRoot -ChildPath 'Tests/One.Tests.ps1'
            $t2 = Join-Path -Path $fakeRoot -ChildPath 'Tests/Two.Tests.ps1'
            $artifactsRoot = Join-Path -Path $TestDrive -ChildPath 'matrix-artifacts'
            $src0 = Join-Path -Path $TestDrive -ChildPath 'raw-0'
            $src1 = Join-Path -Path $TestDrive -ChildPath 'raw-1'
            $null = New-Item -Path $src0, $src1 -ItemType Directory -Force

            @{ Result = 'Passed'; PassedCount = 2; FailedCount = 0; SkippedCount = 0; NotRunCount = 0; TotalCount = 2; DurationMs = 1200; FilesExecuted = 1 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path -Path $src0 -ChildPath 'summary.json') -Encoding utf8
            @{ Result = 'Passed'; PassedCount = 3; FailedCount = 0; SkippedCount = 0; NotRunCount = 0; TotalCount = 3; DurationMs = 1500; FilesExecuted = 1 } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path -Path $src1 -ChildPath 'summary.json') -Encoding utf8
            '<?xml version="1.0" encoding="utf-8"?><testsuites><testsuite name="S0" tests="2" errors="0" failures="0" disabled="0" time="1.200"><testcase name="a" /></testsuite></testsuites>' | Set-Content -LiteralPath (Join-Path -Path $src0 -ChildPath 'junit.xml') -Encoding utf8
            '<?xml version="1.0" encoding="utf-8"?><testsuites><testsuite name="S1" tests="3" errors="0" failures="0" disabled="0" time="1.500"><testcase name="b" /></testsuite></testsuites>' | Set-Content -LiteralPath (Join-Path -Path $src1 -ChildPath 'junit.xml') -Encoding utf8
            '{"Tests/One.Tests.ps1": 1.2}' | Set-Content -LiteralPath (Join-Path -Path $src0 -ChildPath 'timings.json') -Encoding utf8
            '{"Tests/Two.Tests.ps1": 1.5}' | Set-Content -LiteralPath (Join-Path -Path $src1 -ChildPath 'timings.json') -Encoding utf8
            @{ CommandsAnalyzed = 2; Commands = @(
                @{ File = $srcFile; StartLine = 1; EndLine = 1; StartColumn = 1; EndColumn = 5; Function = 'Test-Demo'; Command = 'c1'; HitCount = 1 },
                @{ File = $srcFile; StartLine = 2; EndLine = 2; StartColumn = 1; EndColumn = 5; Function = 'Test-Demo'; Command = 'c2'; HitCount = 0 }
            ) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path -Path $src0 -ChildPath 'coverage-commands.json') -Encoding utf8
            @{ CommandsAnalyzed = 2; Commands = @(
                @{ File = $srcFile; StartLine = 1; EndLine = 1; StartColumn = 1; EndColumn = 5; Function = 'Test-Demo'; Command = 'c1'; HitCount = 0 },
                @{ File = $srcFile; StartLine = 2; EndLine = 2; StartColumn = 1; EndColumn = 5; Function = 'Test-Demo'; Command = 'c2'; HitCount = 1 }
            ) } | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path -Path $src1 -ChildPath 'coverage-commands.json') -Encoding utf8

            Write-ShardArtifactBundle -SourceDir $src0 -DestinationDir (Join-Path -Path $artifactsRoot -ChildPath 'shard-0') -ShardIndex 0 -ShardCount 2 -AssignedFiles @($t1) -Root $fakeRoot
            Write-ShardArtifactBundle -SourceDir $src1 -DestinationDir (Join-Path -Path $artifactsRoot -ChildPath 'shard-1') -ShardIndex 1 -ShardCount 2 -AssignedFiles @($t2) -Root $fakeRoot

            $outCov = Join-Path -Path $TestDrive -ChildPath 'matrix-cov.xml'
            $outJunit = Join-Path -Path $TestDrive -ChildPath 'matrix-junit.xml'
            $outTimings = Join-Path -Path $TestDrive -ChildPath 'matrix-timings.json'
            $res = Invoke-ShardArtifactMerge `
                -ArtifactsRoot $artifactsRoot `
                -ExpectedShardCount 2 `
                -ExpectedFiles @($t1, $t2) `
                -Root $fakeRoot `
                -CoverageOutputPath $outCov `
                -TestResultOutputPath $outJunit `
                -RecordTimingsPath $outTimings `
                -CoverageThreshold 100

            $res.PassedCount | Should -Be -ExpectedValue 5
            $res.CoveragePercent | Should -Be -ExpectedValue 100
            (Get-Content -LiteralPath $outTimings -Raw | ConvertFrom-Json).'Tests/Two.Tests.ps1' | Should -Be -ExpectedValue 1.5

            $t3 = Join-Path -Path $fakeRoot -ChildPath 'Tests/Omitted.Tests.ps1'
            {
                Invoke-ShardArtifactMerge `
                    -ArtifactsRoot $artifactsRoot `
                    -ExpectedShardCount 2 `
                    -ExpectedFiles @($t1, $t2, $t3) `
                    -Root $fakeRoot `
                    -CoverageOutputPath $outCov `
                    -TestResultOutputPath $outJunit `
                    -CoverageThreshold 100
            } | Should -Throw -ExpectedMessage '*Shard inventory verification failed*'
        }
    }
}
