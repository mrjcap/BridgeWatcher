Describe 'Module Cmdlet Exports' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        $script:Config = New-BridgeConfiguration
        Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force
    }

    It 'Exports Update-BridgeStatus cmdlet' {
        (Get-Command -Module BridgeWatcher).Name | Should -Contain 'Update-BridgeStatus'
    }

    It 'Does not export Get-BridgeStatusComparison cmdlet' {
        (Get-Command -Module BridgeWatcher).Name | Should -Not -Contain 'Get-BridgeStatusComparison'
    }
}
