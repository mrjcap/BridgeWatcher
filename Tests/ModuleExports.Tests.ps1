Describe -Name 'Module Cmdlet Exports' -Fixture {
    BeforeAll -Scriptblock {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        $script:Config = New-BridgeConfiguration
        Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force
    }

    It -Name 'Exports Update-BridgeStatus cmdlet' -Test {
        (Get-Command -Module BridgeWatcher).Name | Should -Contain -ExpectedValue 'Update-BridgeStatus'
    }

    It -Name 'Does not export Get-BridgeStatusComparison cmdlet' -Test {
        (Get-Command -Module BridgeWatcher).Name | Should -Not -Contain -ExpectedValue 'Get-BridgeStatusComparison'
    }
}
