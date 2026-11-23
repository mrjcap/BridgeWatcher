Describe 'Linter Compliance (PSScriptAnalyzer)' {
    BeforeAll {
        if (-not (Get-Module PSScriptAnalyzer)) {
            Import-Module PSScriptAnalyzer -ErrorAction Stop
        }
    }

    It 'Has no findings under the CI PSScriptAnalyzer settings' {
        $repoRoot = Split-Path -Path $PSScriptRoot -Parent
        $settings = Join-Path -Path $repoRoot -ChildPath 'PSScriptAnalyzerSettings.psd1'
        $lint = @(
            Invoke-ScriptAnalyzer -Path (Join-Path -Path $repoRoot -ChildPath 'BridgeWatcher') -Recurse -Settings $settings -ErrorAction Stop
            Invoke-ScriptAnalyzer -Path $PSScriptRoot -Recurse -Settings $settings -ErrorAction Stop
            Invoke-ScriptAnalyzer -Path (Join-Path -Path $repoRoot -ChildPath 'run.ps1') -Settings $settings -ErrorAction Stop
            Invoke-ScriptAnalyzer -Path (Join-Path -Path $repoRoot -ChildPath 'scripts') -Recurse -Settings $settings -Severity Error,Warning -ErrorAction Stop
        )
        if ($lint) {
            throw ($lint | Format-Table -Property ScriptName, Line, Severity, RuleName, Message -Wrap | Out-String)
        }
    }

    It 'Should pass PSUseBOMForUnicodeEncodedFile checks' {
        $modulePath = Join-Path (Join-Path $PSScriptRoot '..') 'BridgeWatcher'
        $lint = @($modulePath, $PSScriptRoot) |
            Invoke-ScriptAnalyzer -Recurse -IncludeRule PSUseBOMForUnicodeEncodedFile
        $lint | Should -BeNullOrEmpty
    }

    It 'Should detect non-BOM Unicode files when PSUseBOMForUnicodeEncodedFile is active' {
        $nonBomFile = Join-Path $TestDrive 'non-bom-greek.ps1'
        $utf8NoBom = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($nonBomFile, '$bridgeLabel = "Γέφυρα Ισθμίας"', $utf8NoBom)

        $lint = Invoke-ScriptAnalyzer -Path $nonBomFile -IncludeRule PSUseBOMForUnicodeEncodedFile
        $lint | Should -Not -BeNullOrEmpty
        $lint[0].RuleName | Should -Be 'PSUseBOMForUnicodeEncodedFile'
    }
}
