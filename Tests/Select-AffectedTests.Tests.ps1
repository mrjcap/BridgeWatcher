$ErrorActionPreference = 'Stop'

Describe 'Select-AffectedTests PR Test Selector' {
    BeforeAll {
        $script:repoRoot = Split-Path -Path $PSScriptRoot -Parent
        . (Join-Path -Path $script:repoRoot -ChildPath 'scripts/Select-AffectedTests.ps1')
    }

    Context 'Full-suite force rules and safety fallbacks' {
        It 'Forces full suite when changed files list is empty (missing history or invalid diff)' {
            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @()
            $sel.FullSuite | Should -BeTrue
            $sel.Mode | Should -Be 'FullSuite'
            $sel.SelectedTests.Count | Should -Be $sel.TotalTests
            $sel.SelectedTests.Count | Should -BeGreaterThan 0
        }

        It 'Forces full suite on module manifest, loader, shared helper, config, and workflow changes' {
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
                $sel.SelectedTests.Count | Should -Be $sel.TotalTests
            }
        }

        It 'Forces full suite for unknown or unmapped repository files rather than returning an empty set' {
            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @('some-unknown-tool.config')
            $sel.FullSuite | Should -BeTrue
            $sel.SelectedTests.Count | Should -Be $sel.TotalTests
        }
    }

    Context 'AST transitive dependency selection' {
        It 'Selects direct and transitive dependent tests when a private helper changes' {
            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @('BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1')
            $sel.FullSuite | Should -BeFalse
            $sel.Mode | Should -Be 'Selected'
            $sel.AffectedSources | Should -Contain 'BridgeWatcher/Private/ConvertTo-BridgeTimeRange.ps1'
            $sel.AffectedSources | Should -Contain 'BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1'
            $sel.SelectedTests | Should -Contain 'Tests/ConvertTo-BridgeTimeRange.Tests.ps1'
            $sel.SelectedTests | Should -Contain 'Tests/ConvertFrom-BridgeOCRResult.Tests.ps1'
            $sel.SelectedTests | Should -Contain 'Tests/LinterCompliance.Tests.ps1'
            $sel.SelectedTests | Should -Contain 'Tests/Review/CommentHelp.Tests.ps1'
            $sel.SelectedTests.Count | Should -BeLessThan $sel.TotalTests
        }

        It 'Selects only the modified test file plus lint and scope checks when a single unit test changes' {
            $sel = Select-AffectedTestFile -Root $script:repoRoot -Paths @('Tests/Get-BridgeStatusAdvice.Tests.ps1')
            $sel.FullSuite | Should -BeFalse
            $sel.SelectedTests | Should -Contain 'Tests/Get-BridgeStatusAdvice.Tests.ps1'
            $sel.SelectedTests | Should -Contain 'Tests/LinterCompliance.Tests.ps1'
            $sel.SelectedTests | Should -Contain 'Tests/Review/PesterScope.Tests.ps1'
            $sel.SelectedTests.Count | Should -Be 3
        }
    }

    Context 'Shadow validation and omission detection' {
        It 'Passes shadow validation when every failing full-suite test file was selected' {
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
            $val.OmittedFailures.Count | Should -Be 0
        }

        It 'Detects and reports an omission when a real affected failing test is concealed from the selector' {
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
            $val.OmittedFailures | Should -Contain 'Tests/ConvertFrom-BridgeOCRResult.Tests.ps1'
        }
    }
}
