Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeNameFromUri' {
        Context 'Όταν το URI περιέχει isthmia' {
            It "Επιστρέφει 'Ισθμία' για URI με 'isthmia'" {
                $uri = 'https://somehost.com/images/bridge_isthmia_01.jpg'
                $result = Get-BridgeNameFromUri -ImageUri $uri
                $result | Should -Be 'Ισθμία'
            }
            It "Επιστρέφει 'Ισθμία' για κεφαλαία 'ISTHMIA'" {
                $uri = 'BRIDGE_ISTHMIA_02.JPG'
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
                $uri = 'BRIDGE_POSIDONIA_04.JPG'
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
}