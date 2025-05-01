Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'New-BridgeStatusObject' {
        It 'Δημιουργεί valid object για Ποσειδωνία' {
            $obj = New-BridgeStatusObject -Location 'poseidonia' -Status 'Ανοιχτή' `
                -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'image-bridge-open.php?abc'
            $obj.gefyraName | Should -Be 'Ποσειδωνία'
            $obj.imageUrl | Should -Be 'https://www.topvision.gr/dioriga/image-bridge-open.php?abc'
        }
        It 'Δημιουργεί valid object για Ισθμία με absolute URL' {
            $obj = New-BridgeStatusObject -Location 'isthmia' -Status 'Μόνιμα κλειστή' `
                -Timestamp '2025-04-10T14:00:00Z' -ImageSrc 'https://topvision.gr/direct.png'
            $obj.gefyraName | Should -Be 'Ισθμία'
            $obj.imageUrl | Should -Be 'https://topvision.gr/direct.png'
        }
    }
}