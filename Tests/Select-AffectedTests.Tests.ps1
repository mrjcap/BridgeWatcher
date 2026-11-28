$ErrorActionPreference = 'Stop'

Describe -Name 'Select-AffectedTests PR Test Selector' -Fixture {
    BeforeAll -Scriptblock {
        $script:repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $script:repoRoot -ChildPath 'scripts/Select-AffectedTests.ps1')
    }

    Context -Name 'Full-suite force rules and safety fallbacks' -Fixture {
        It -Name 'Forces full suite when changed files list is empty (missing history or invalid diff)' -Test {
            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @()
            $sel.FullSuite | Should -BeTrue
            $sel.Mode | Should -Be -ExpectedValue 'FullSuite'
            $sel.SelectedTests.Count | Should -Be -ExpectedValue $sel.TotalTests
            $sel.SelectedTests.Count | Should -BeGreaterThan -ExpectedValue 0
        }

        It -Name 'Forces full suite on module manifest, loader, shared helper, config, and workflow changes' -Test {
            $forcePaths = @(
                'BridgeWatcher/BridgeWatcher.psd1',
                'BridgeWatcher/BridgeWatcher.psm1',
                'BridgeWatcher/Private/New-BridgeConfiguration.ps1',
                'BridgeWatcher/Private/Write-BridgeLog.ps1',
                'PSScriptAnalyzerSettings.psd1',
                'Tests/PesterConfiguration.psd1',
                'Tests/TestHelper.ps1',
                'Tests/Review/CommentHelp.Tests.ps1',
                '.github/workflows/ci.yml',
                'scripts/Invoke-TestSuite.ps1',
                'scripts/Select-AffectedTests.ps1',
                'gate.ps1'
            )

            foreach ($p in $forcePaths) {
                $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @($p)
                $sel.FullSuite | Should -BeTrue -Because "Change to '$p' must force full suite"
                $sel.SelectedTests.Count | Should -Be -ExpectedValue $sel.TotalTests
            }
        }

        It -Name 'Forces full suite for unknown or unmapped repository files rather than returning an empty set' -Test {
            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @('some-unknown-tool.config')
            $sel.FullSuite | Should -BeTrue
            $sel.SelectedTests.Count | Should -Be -ExpectedValue $sel.TotalTests
        }
    }

    Context -Name 'AST transitive dependency selection' -Fixture {
        It -Name 'Selects direct and transitive dependent tests when a private helper changes' -Test {
            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @('BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1')
            $sel.FullSuite | Should -BeFalse
            $sel.Mode | Should -Be -ExpectedValue 'Selected'
            $sel.AffectedSources | Should -Contain -ExpectedValue 'BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1'
            $sel.AffectedSources | Should -Contain -ExpectedValue 'BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1'
            $sel.SelectedTests | Should -Contain -ExpectedValue 'Tests/ConvertTo-BridgeTimeRange.Tests.ps1'
            $sel.SelectedTests | Should -Contain -ExpectedValue 'Tests/ConvertFrom-BridgeOCRResult.Tests.ps1'
            $sel.SelectedTests | Should -Contain -ExpectedValue 'Tests/LinterCompliance.Tests.ps1'
            $sel.SelectedTests | Should -Contain -ExpectedValue 'Tests/Review/CommentHelp.Tests.ps1'
            $sel.SelectedTests.Count | Should -BeLessThan -ExpectedValue $sel.TotalTests
        }

        It -Name 'Selects only the modified test file plus lint and scope checks when a single unit test changes' -Test {
            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @('Tests/Get-BridgeStatusAdvice.Tests.ps1')
            $sel.FullSuite | Should -BeFalse
            $sel.SelectedTests | Should -Contain -ExpectedValue 'Tests/Get-BridgeStatusAdvice.Tests.ps1'
            $sel.SelectedTests | Should -Contain -ExpectedValue 'Tests/LinterCompliance.Tests.ps1'
            $sel.SelectedTests | Should -Contain -ExpectedValue 'Tests/Review/PesterScope.Tests.ps1'
            $sel.SelectedTests.Count | Should -Be -ExpectedValue 3
        }
    }

    Context -Name 'Shadow validation and omission detection' -Fixture {
        It -Name 'Passes shadow validation when every failing full-suite test file was selected' -Test {
            $junitPath = Join-Path -Path $TestDrive -ChildPath 'full-pass-shadow.xml'
            $fullTestPath = Join-Path -Path $script:repoRoot -ChildPath 'Tests/ConvertTo-BridgeTimeRange.Tests.ps1'
            @"
<?xml version="1.0" encoding="utf-8"?>
<testsuites tests="2" failures="1" errors="0">
  <testsuite name="$fullTestPath" tests="2" failures="1" errors="0" />
</testsuites>
"@ | Set-Content -LiteralPath $junitPath -Encoding utf8

            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @('BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1')
            $val = Test-SelectionAgainstFullResult -Selection $sel -FullJUnitXmlPath $junitPath -Root $script:repoRoot
            $val.Passed | Should -BeTrue
            $val.OmittedFailures.Count | Should -Be -ExpectedValue 0
        }

        It -Name 'Detects and reports an omission when a real affected failing test is concealed from the selector' -Test {
            $junitPath = Join-Path -Path $TestDrive -ChildPath 'full-omission-shadow.xml'
            $fullTestPath = Join-Path -Path $script:repoRoot -ChildPath 'Tests/ConvertFrom-BridgeOCRResult.Tests.ps1'
            @"
<?xml version="1.0" encoding="utf-8"?>
<testsuites tests="2" failures="1" errors="0">
  <testsuite name="$fullTestPath" tests="2" failures="1" errors="0" />
</testsuites>
"@ | Set-Content -LiteralPath $junitPath -Encoding utf8

            $concealed = Select-AffectedTestFile `
                -Root $script:repoRoot `
                -Paths @('BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1') `
                -ExcludeTestFiles @('Tests/ConvertFrom-BridgeOCRResult.Tests.ps1')

            $val = Test-SelectionAgainstFullResult -Selection $concealed -FullJUnitXmlPath $junitPath -Root $script:repoRoot
            $val.Passed | Should -BeFalse
            $val.OmittedFailures | Should -Contain -ExpectedValue 'Tests/ConvertFrom-BridgeOCRResult.Tests.ps1'
        }
    }
}
