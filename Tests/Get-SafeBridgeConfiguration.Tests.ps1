Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-SafeBridgeConfiguration' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-SafeBridgeConfiguration.ps1"
    }

    It 'Επιστρέφει το Configuration αν πετύχει' {
        $result = Get-SafeBridgeConfiguration
        $result | Should -Not -BeNullOrEmpty
        $result.BridgeNames | Should -Not -BeNullOrEmpty
    }

    It 'Ρίχνει σφάλμα αν αποτύχει η New-BridgeConfiguration' {
        Mock New-BridgeConfiguration { throw "Simulated error" }
        { Get-SafeBridgeConfiguration } | Should -Throw
    }

    It 'Επιστρέφει $null αν αποτύχει η New-BridgeConfiguration (Quiet)' {
        Mock New-BridgeConfiguration { throw "Simulated error" }
        $result = Get-SafeBridgeConfiguration -Quiet
        $result | Should -BeNullOrEmpty
    }
}
