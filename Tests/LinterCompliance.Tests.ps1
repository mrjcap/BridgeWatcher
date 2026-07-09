Describe "Linter Compliance (PSScriptAnalyzer)" {
    BeforeAll {
        if (-not (Get-Module PSScriptAnalyzer)) {
            Import-Module PSScriptAnalyzer -ErrorAction Stop
        }
    }
    It "Should pass PSUseBOMForUnicodeEncodedFile checks" {
        $lint = @("$PSScriptRoot\..\BridgeWatcher", "$PSScriptRoot") | Invoke-ScriptAnalyzer -Recurse -Settings "$PSScriptRoot\..\PSScriptAnalyzerSettings.psd1" | Where-Object RuleName -eq "PSUseBOMForUnicodeEncodedFile"
        $lint | Should -BeNullOrEmpty
    }
}
