$ErrorActionPreference = 'Stop'

Describe 'Invoke-TestSuite Orchestrator' {
    BeforeAll {
        $script:repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $script:repoRoot -ChildPath 'scripts/Invoke-TestSuite.ps1')
    }

    Context 'Test inventory accounting' {
        It 'Accounts for every tracked test file and explicitly separates Integration-tagged tests' {
            $inventory = Get-TrackedTestInventory -Root $script:repoRoot

            $inventory.AllFiles.Count | Should -BeGreaterThan 0
            $inventory.UnitFiles.Count | Should -BeGreaterThan 0
            $inventory.IntegrationFiles.Count | Should -BeGreaterThan 0
            ($inventory.UnitFiles.Count + $inventory.IntegrationFiles.Count) | Should -Be $inventory.AllFiles.Count

            $integrationNames = @($inventory.IntegrationFiles | ForEach-Object { Split-Path -Path $_ -Leaf })
            $integrationNames | Should -Contain 'Integration.Tests.ps1'

            $unitNames = @($inventory.UnitFiles | ForEach-Object { Split-Path -Path $_ -Leaf })
            $unitNames | Should -Not -Contain 'Integration.Tests.ps1'
        }
    }

    Context 'Balanced shard partitioning and completeness verification' {
        It 'Balances heavy test files across shards using LPT timings and falls back safely for unmeasured files' {
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

            $shards.Count | Should -Be 2
            $allAssigned = @($shards | ForEach-Object { $_.Files })
            $allAssigned.Count | Should -Be $files.Count
            @($allAssigned | Select-Object -Unique).Count | Should -Be $files.Count

            # Heaviest two files must land in different shards
            $shard0Names = @($shards[0].Files | ForEach-Object { Split-Path -Path $_ -Leaf })
            $shard1Names = @($shards[1].Files | ForEach-Object { Split-Path -Path $_ -Leaf })
            (($shard0Names -contains 'SlowA.Tests.ps1') -xor ($shard1Names -contains 'SlowA.Tests.ps1')) | Should -BeTrue
            (($shard0Names -contains 'SlowB.Tests.ps1') -xor ($shard1Names -contains 'SlowB.Tests.ps1')) | Should -BeTrue
            (($shard0Names -contains 'SlowA.Tests.ps1') -and ($shard0Names -contains 'SlowB.Tests.ps1')) | Should -BeFalse
            (($shard1Names -contains 'SlowA.Tests.ps1') -and ($shard1Names -contains 'SlowB.Tests.ps1')) | Should -BeFalse
        }

        It 'Rejects duplicate test files in the input inventory' {
            $root = Join-Path -Path $TestDrive -ChildPath 'dup-repo'
            $f1 = Join-Path -Path $root -ChildPath 'Tests/Alpha.Tests.ps1'
            { Split-TestFilesIntoShard -Files @($f1, $f1) -Count 2 -Root $root -TimingsMap @{} } | Should -Throw -ExpectedMessage '*Shard inventory verification failed*'
        }

        It 'Loads valid historical timings JSON and ignores missing files safely' {
            $missing = Get-HistoricalTestTiming -Path (Join-Path -Path $TestDrive -ChildPath 'does-not-exist.json')
            $missing.Count | Should -Be 0

            $timingsFile = Join-Path -Path $TestDrive -ChildPath 'timings.json'
            '{"Tests/A.Tests.ps1": 4.25, "Tests/B.Tests.ps1": 0}' | Set-Content -LiteralPath $timingsFile -Encoding utf8
            $loaded = Get-HistoricalTestTiming -Path $timingsFile
            $loaded['Tests/A.Tests.ps1'] | Should -Be 4.25
            $loaded.ContainsKey('Tests/B.Tests.ps1') | Should -BeFalse
        }
    }

    Context 'Command-level coverage and JUnit aggregation' {
        It 'Unions command hits across shards while enforcing identical denominators and exports JaCoCo XML' {
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
            $merged.CommandsAnalyzed | Should -Be 2
            $merged.CommandsExecuted | Should -Be 2
            $merged.CommandsMissed | Should -Be 0
            $merged.CoveragePercent | Should -Be 100

            Export-MergedJaCoCoXml -MergedCommands $merged.Commands -ReportRoot $fakeRoot -OutputPath $jacocoOut -ElapsedMilliseconds 1200
            Test-Path -LiteralPath $jacocoOut | Should -BeTrue
            [xml]$doc = Get-Content -LiteralPath $jacocoOut -Raw
            $instrCounter = $doc.SelectSingleNode('/report/counter[@type="INSTRUCTION"]')
            $instrCounter.GetAttribute('covered') | Should -Be '2'
            $instrCounter.GetAttribute('missed') | Should -Be '0'
        }

        It 'Fails loudly when shard coverage denominators do not match' {
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

        It 'Merges JUnit XML reports from multiple shards preserving test counts, failures, and durations' {
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
            $doc.DocumentElement.GetAttribute('tests') | Should -Be '5'
            $doc.DocumentElement.GetAttribute('failures') | Should -Be '1'
            $doc.DocumentElement.GetAttribute('disabled') | Should -Be '1'
            $doc.DocumentElement.GetAttribute('time') | Should -Be '2.000'
        }
    }
}
