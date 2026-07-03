Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-BridgeStatusObject' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
    }

    It 'Δημιουργεί valid object για Ποσειδωνία' {
        $obj = Get-BridgeStatusObject -Location 'poseidonia' -Status 'Ανοιχτή' `
            -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'image-bridge-open.php?abc'
        $obj.gefyraName | Should -Be 'Ποσειδωνία'
        $obj.imageUrl | Should -Be 'https://www.topvision.gr/dioriga/image-bridge-open.php?abc'
    }
    It 'Δημιουργεί valid object για Ισθμία με absolute URL' {
        $obj = Get-BridgeStatusObject -Location 'isthmia' -Status 'Μόνιμα κλειστή' `
            -Timestamp '2025-04-10T14:00:00Z' -ImageSrc 'https://topvision.gr/direct.png'
        $obj.gefyraName | Should -Be 'Ισθμία'
        $obj.imageUrl | Should -Be 'https://topvision.gr/direct.png'
    }

    Context 'Parameter Validation' {
        It 'Ρίχνει σφάλμα για κενό Location' {
            { Get-BridgeStatusObject -Location '' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για κενό Status' {
            { Get-BridgeStatusObject -Location 'poseidonia' -Status '' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για κενό Timestamp' {
            { Get-BridgeStatusObject -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για κενό ImageSrc' {
            { Get-BridgeStatusObject -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc '' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για άκυρο BaseUrl' {
            { Get-BridgeStatusObject -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' -BaseUrl 'not-a-valid-url' } | Should -Throw
        }

        It 'Δέχεται έγκυρο BaseUrl' {
            $obj = Get-BridgeStatusObject -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' -BaseUrl 'https://custom.com/'
            $obj.imageUrl | Should -Be 'https://custom.com/test.jpg'
        }
    }

    Context 'ClosedWithSchedule Hashing' {
        It 'Υπολογίζει το ImageHash όταν η κατάσταση είναι Κλειστή με πρόγραμμα' {
            $config = New-BridgeConfiguration
            $contentBytes = [System.Text.Encoding]::UTF8.GetBytes("fake image content")
            Mock Invoke-WebRequest {
                return [pscustomobject]@{ Content = $contentBytes }
            }
            $obj = Get-BridgeStatusObject -Location 'isthmia' -Status $config.Statuses.ClosedWithSchedule `
                -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'schedule.php' -Configuration $config
            $obj.ImageHash | Should -Not -BeNullOrEmpty
            $obj.ImageHash | Should -Be '50E7825D3A7F7EF39C0D330A69E9AC35'
        }

        It 'Θέτει το ImageHash σε $null και καταγράφει προειδοποίηση όταν η λήψη αποτυγχάνει' {
            $config = New-BridgeConfiguration
            Mock Invoke-WebRequest { throw "Connection timeout" }
            Mock Write-BridgeLog { }
            $obj = Get-BridgeStatusObject -Location 'isthmia' -Status $config.Statuses.ClosedWithSchedule `
                -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'schedule.php' -Configuration $config
            $obj.ImageHash | Should -BeNullOrEmpty
            Assert-MockCalled Write-BridgeLog -Times 1 -ParameterFilter { $Stage -eq 'Σφάλμα' -and $Level -eq 'Warning' }
        }
    }
}
