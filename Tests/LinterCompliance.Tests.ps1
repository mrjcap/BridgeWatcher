Describe 'Linter Compliance (PSScriptAnalyzer)' {
    BeforeAll {
        if (-not (Get-Module PSScriptAnalyzer)) {
            Import-Module PSScriptAnalyzer -ErrorAction Stop
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
