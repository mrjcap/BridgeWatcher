Describe 'Module Cmdlet Exports' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force
    }

    It 'Exports Update-BridgeStatus cmdlet' {
        (Get-Command -Module BridgeWatcher).Name | Should -Contain 'Update-BridgeStatus'
    }

    It 'Does not export Get-BridgeStatusComparison cmdlet' {
        (Get-Command -Module BridgeWatcher).Name | Should -Not -Contain 'Get-BridgeStatusComparison'
    }
}
