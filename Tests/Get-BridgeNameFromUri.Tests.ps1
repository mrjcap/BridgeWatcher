Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-BridgeNameFromUri' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeNameFromUri.ps1"
    }

    Context 'Όταν το URI περιέχει isthmia' {
        It "Επιστρέφει 'Ισθμία' για URI με 'isthmia'" {
            $uri = 'https://somehost.com/images/bridge_isthmia_01.jpg'
            $result = Get-BridgeNameFromUri -ImageUri $uri
            $result | Should -Be 'Ισθμία'
        }

        It "Επιστρέφει 'Ισθμία' για κεφαλαία 'ISTHMIA'" {
            $uri = 'https://example.com/BRIDGE_ISTHMIA_02.JPG'
            $result = Get-BridgeNameFromUri -ImageUri $uri
            $result | Should -Be 'Ισθμία'
        }
    }
    Context 'Όταν το URI περιέχει posidonia' {
        It "Επιστρέφει 'Ποσειδωνία' για URI με 'posidonia'" {
            $uri = 'https://topvision.gr/img/bridge_posidonia_03.png'
            $result = Get-BridgeNameFromUri -ImageUri $uri
            $result | Should -Be 'Ποσειδωνία'
        }

        It "Επιστρέφει 'Ποσειδωνία' για κεφαλαία 'POSIDONIA'" {
            $uri = 'https://example.com/BRIDGE_POSIDONIA_04.JPG'
            $result = Get-BridgeNameFromUri -ImageUri $uri
            $result | Should -Be 'Ποσειδωνία'
        }
    }
    Context 'Unknown/άκυρο URI' {
        It "Επιστρέφει 'Άγνωστη' και γράφει verbose για άγνωστο URI" {
            $uri = 'https://topvision.gr/img/bridge_unknown_999.jpg'
            # Πιάσε το Write-Verbose (χρειάζεται -Verbose switch)
            { Get-BridgeNameFromUri -ImageUri $uri -Verbose } | Should -Not -Throw
            $result = Get-BridgeNameFromUri -ImageUri $uri
            $result | Should -Be 'Άγνωστη'
        }
    }
}
