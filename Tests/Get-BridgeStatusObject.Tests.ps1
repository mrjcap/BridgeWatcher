Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-BridgeStatusObject' {
    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It 'Δημιουργεί valid object για Ποσειδωνία' {
        $obj = Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' `
            -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'image-bridge-open.php?abc'
        $obj.GefyraName | Should -Be 'Ποσειδωνία'
        $obj.imageUrl | Should -Be 'https://www.topvision.gr/dioriga/image-bridge-open.php?abc'
    }
    It 'Δημιουργεί valid object για Ισθμία με absolute URL' {
        $obj = Get-BridgeStatusObject -Configuration $script:Config -Location 'isthmia' -Status 'Μόνιμα κλειστή' `
            -Timestamp '2025-04-10T14:00:00Z' -ImageSrc 'https://topvision.gr/direct.png'
        $obj.GefyraName | Should -Be 'Ισθμία'
        $obj.imageUrl | Should -Be 'https://topvision.gr/direct.png'
    }

    Context 'Parameter Validation' {
        It 'Ρίχνει σφάλμα για κενό Location' {
            { Get-BridgeStatusObject -Configuration $script:Config -Location '' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για κενό Status' {
            { Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status '' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για κενό Timestamp' {
            { Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για κενό ImageSrc' {
            { Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc '' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για άκυρο BaseUrl' {
            { Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' -BaseUrl 'not-a-valid-url' } | Should -Throw
        }

        It 'Δέχεται έγκυρο BaseUrl' {
            $obj = Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' -BaseUrl 'https://custom.com/'
            $obj.imageUrl | Should -Be 'https://custom.com/test.jpg'
        }

        It 'Ρίχνει σφάλμα INVALID_IMAGE_HOST όταν το absolute ImageSrc δείχνει σε μη έγκριτο host' {
            Mock Get-BridgeImageBuffer { }
            $untrustedSplat = @{
                Configuration = $script:Config
                Location      = 'isthmia'
                Status        = $script:Config.Statuses.ClosedWithSchedule
                Timestamp     = '2025-04-10T13:00:00Z'
                ImageSrc      = 'http://169.254.169.254/latest/meta-data/schedule.php'
            }
            { Get-BridgeStatusObject @untrustedSplat } | Should -Throw -ErrorId '*INVALID_IMAGE_HOST*'
            Should -Invoke -CommandName Get-BridgeImageBuffer -Times 0 -Exactly
        }
    }

    Context 'ClosedWithSchedule Hashing' {
        It 'Υπολογίζει το ImageHash όταν η κατάσταση είναι Κλειστή με πρόγραμμα' {
            $config = New-BridgeConfiguration
            $contentBytes = [System.Text.Encoding]::UTF8.GetBytes("fake image content")
            Mock Get-BridgeImageBuffer {
                return $contentBytes
            }
            $obj = Get-BridgeStatusObject -Location 'isthmia' -Status $config.Statuses.ClosedWithSchedule `
                -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'schedule.php' -Configuration $config
            $obj.ImageHash | Should -Not -BeNullOrEmpty
            $obj.ImageHash | Should -Be '50E7825D3A7F7EF39C0D330A69E9AC35'
            Should -Invoke -CommandName Get-BridgeImageBuffer -Times 1 -Exactly -ParameterFilter {
                $TimeoutSec -eq $config.Defaults.HttpRequestTimeout
            }
        }

        It 'Invalidates only the failed image so OCR cannot reuse an earlier closure schedule' {
            $parameters = @{
                Configuration = $script:Config
                Location      = 'isthmia'
                Status        = $script:Config.Statuses.ClosedWithSchedule
                Timestamp     = '2025-04-10T13:00:00Z'
                ImageSrc      = 'stale-schedule.php'
            }
            Mock Write-BridgeLog { }
            Mock Get-BridgeImageBuffer { return [byte[]]@(1, 2, 3) }
            $previous = Get-BridgeStatusObject @parameters
            $otherUrl = "$($script:Config.Urls.BaseImage)/other-schedule.php"
            $script:BridgeImageBytesByUrl[$otherUrl] = [byte[]]@(9)

            $openParameters = $parameters.Clone()
            $openParameters.Status = $script:Config.Statuses.Open
            $openParameters.ImageSrc = 'image-bridge-open-no-schedule.php?1'
            $null = Get-BridgeStatusObject @openParameters

            Mock Get-BridgeImageBuffer { throw 'Connection timeout' }
            $current = Get-BridgeStatusObject @parameters
            $current.ImageHash | Should -BeNullOrEmpty
            { Get-BridgeCachedImageBytes -Url $current.ImageUrl } | Should -Throw '*Connection timeout*'
            $script:BridgeImageBytesByUrl.ContainsKey($previous.ImageUrl) | Should -BeFalse
            $script:BridgeImageBytesByUrl[$otherUrl][0] | Should -Be 9
        }

        It 'Returns the known status without a hash and warns when the image download fails' {
            $config = New-BridgeConfiguration
            Mock Get-BridgeImageBuffer { throw "Connection timeout" }
            Mock Write-BridgeLog { }
            $obj = Get-BridgeStatusObject -Location 'isthmia' -Status $config.Statuses.ClosedWithSchedule `
                -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'schedule.php' -Configuration $config
            $obj.GefyraStatus | Should -Be $config.Statuses.ClosedWithSchedule
            $obj.ImageHash | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-BridgeLog -Times 1 -ParameterFilter { $Stage -eq 'Σφάλμα' -and $Level -eq 'Warning' }
        }
    }
}
