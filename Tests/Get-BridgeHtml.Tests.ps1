Import-Module "$PSScriptRoot\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeHtml' {

        Context 'Επιτυχής ανάκτηση HTML' {
            It 'Επιστρέφει το HTML όταν το Invoke-WebRequest πετυχαίνει' {
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = '<html>ok</html>' } }
                $result = Get-BridgeHtml
                $result | Should -Be '<html>ok</html>'
            }
            It 'Καλεί το Invoke-WebRequest με το default URL' {
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = 'test' } }
                Get-BridgeHtml
                Assert-MockCalled Invoke-WebRequest -ParameterFilter { $Uri -eq 'https://www.topvision.gr/dioriga/' }
            }
            It 'Καλεί το Invoke-WebRequest με custom URL' {
                Mock Invoke-WebRequest { [PSCustomObject]@{ Content = 'custom' } }
                $customUrl = 'https://example.com/bridge'
                Get-BridgeHtml -Uri $customUrl
                Assert-MockCalled Invoke-WebRequest -ParameterFilter { $Uri -eq $customUrl }
            }
        }
        Context 'Σφάλμα κατά την ανάκτηση HTML' {
            It "Γράφει Exception όταν το Invoke-WebRequest αποτυγχάνει" {
                Mock Invoke-WebRequest { throw 'Network error!' }
                {Get-BridgeHtml }| Should -Throw "Αποτυχία λήψης HTML: Network error!"
            }
        }
    }
}