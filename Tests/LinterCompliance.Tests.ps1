Describe -Name 'Linter Compliance (PSScriptAnalyzer)' -Fixture {
    BeforeAll -Scriptblock {
        if (-not (Get-Module -Name PSScriptAnalyzer)) {
            Import-Module -Name PSScriptAnalyzer -ErrorAction Stop
        }
        Import-Module -Name (Join-Path -Path $PSScriptRoot -ChildPath 'Review/PowerShellStyle.psm1')
    }

    It -Name 'Has no findings under the CI PSScriptAnalyzer settings' -Test {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        $paths = @(Get-TrackedPowerShellPath -RepositoryRoot $repoRoot)
        $lint = @(Invoke-PowerShellPolicyLint -RepositoryRoot $repoRoot -Paths $paths)
        if ($lint) {
            throw ($lint | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -Wrap | Out-String)
        }
    }

    It -Name 'Should pass PSUseBOMForUnicodeEncodedFile checks' -Test {
        $modulePath = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath '..') -ChildPath 'BridgeWatcher'
        $lint = @($modulePath, $PSScriptRoot) |
            Invoke-ScriptAnalyzer -Recurse -IncludeRule PSUseBOMForUnicodeEncodedFile
        $lint | Should -BeNullOrEmpty
    }

    It -Name 'blocks <Severity> in <Area> only when covered by the lint policy' -ForEach @(
        @{ Area = 'Tests'; Severity = 'Information'; Source = 'function Get-LintFixture {}'; Rule = 'PSProvideCommentHelp'; Blocks = $true }
        @{ Area = 'scripts'; Severity = 'Information'; Source = 'function Get-LintFixture {}'; Rule = 'PSProvideCommentHelp'; Blocks = $false }
        @{ Area = 'scripts'; Severity = 'Warning'; Source = 'gci -Path .'; Rule = 'PSAvoidUsingCmdletAliases'; Blocks = $true }
        @{ Area = 'scripts'; Severity = 'Error'; Source = "ConvertTo-SecureString -String 'fixture-only' -AsPlainText -Force"; Rule = 'PSAvoidUsingConvertToSecureStringWithPlainText'; Blocks = $true }
    ) -Test {
        $settings = Join-Path -Path $PSScriptRoot -ChildPath '../PSScriptAnalyzerSettings.psd1'
        Copy-Item -LiteralPath $settings -Destination $TestDrive
        $folder = Join-Path -Path $TestDrive -ChildPath $Area
        $null = New-Item -Path $folder -ItemType Directory -Force
        $fixture = "$Area/Fixture.ps1"
        $target = Join-Path -Path $TestDrive -ChildPath $fixture
        Set-Content -LiteralPath $target -Value $Source
        $raw = @(Invoke-ScriptAnalyzer -Path $target -Settings $settings)
        $raw.RuleName | Should -Contain -ExpectedValue $Rule
        $raw.Severity | Should -Contain -ExpectedValue $Severity
        $findings = @(Invoke-PowerShellPolicyLint -RepositoryRoot $TestDrive -Paths $fixture)
        if ($Blocks) {
            $findings.RuleName | Should -Contain -ExpectedValue $Rule
        } else {
            $findings | Should -BeNullOrEmpty
        }
    }

    It -Name 'Should detect non-BOM Unicode files when PSUseBOMForUnicodeEncodedFile is active' -Test {
        $nonBomFile = Join-Path -Path $TestDrive -ChildPath 'non-bom-greek.ps1'
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($nonBomFile, '$bridgeLabel = "Γέφυρα Ισθμίας"', $utf8NoBom)

        $lint = Invoke-ScriptAnalyzer -Path $nonBomFile -IncludeRule PSUseBOMForUnicodeEncodedFile
        $lint | Should -Not -BeNullOrEmpty
        $lint[0].RuleName | Should -Be -ExpectedValue 'PSUseBOMForUnicodeEncodedFile'
    }
}
