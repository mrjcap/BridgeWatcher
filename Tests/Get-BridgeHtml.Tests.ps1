Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeHtml' {

        Context 'Επιτυχής ανάκτηση HTML' {
            It 'Επιστρέφει BridgeResult με HTML όταν το Invoke-WebRequest πετυχαίνει' {
                Mock Invoke-WebRequest { [pscustomobject]@{ Content = '<html>ok</html>' } }
                $result = Get-BridgeHtml

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $true
                $result.Data | Should -Be '<html>ok</html>'
                $result.ErrorMessage | Should -Be ''
                $result.ErrorCode | Should -Be ''
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
            It "Επιστρέφει BridgeResult με σφάλμα όταν το Invoke-WebRequest αποτυγχάνει" {
                Mock Invoke-WebRequest { throw 'Network error!' }
                Mock Write-BridgeLog

                $result = Get-BridgeHtml

                $result | Should -Not -BeNullOrEmpty
                $result.Success | Should -Be $false
                $result.ErrorMessage | Should -Be 'Network error!'
                $result.ErrorCode | Should -Be 'HTTP_ERROR'
                Assert-MockCalled Write-BridgeLog -Exactly 2
            }
        }
    }
}

