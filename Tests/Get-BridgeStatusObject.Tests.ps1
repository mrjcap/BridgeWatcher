Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psm1" -Force

Describe 'Get-BridgeStatusObject' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
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
}

