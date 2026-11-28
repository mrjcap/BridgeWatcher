Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'Get-BridgeStatusObject' -Fixture {
    BeforeAll -Scriptblock {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It -Name 'Δημιουργεί valid object για Ποσειδωνία' -Test {
        $obj = Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' `
            -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'image-bridge-open.php?abc'
        $obj.GefyraName | Should -Be -ExpectedValue 'Ποσειδωνία'
        $obj.imageUrl | Should -Be -ExpectedValue 'https://www.topvision.gr/dioriga/image-bridge-open.php?abc'
    }
    It -Name 'Δημιουργεί valid object για Ισθμία με absolute URL' -Test {
        $obj = Get-BridgeStatusObject -Configuration $script:Config -Location 'isthmia' -Status 'Μόνιμα κλειστή' `
            -Timestamp '2025-04-10T14:00:00Z' -ImageSrc 'https://topvision.gr/direct.png'
        $obj.GefyraName | Should -Be -ExpectedValue 'Ισθμία'
        $obj.imageUrl | Should -Be -ExpectedValue 'https://topvision.gr/direct.png'
    }

    Context -Name 'Parameter Validation' -Fixture {
        It -Name 'Ρίχνει σφάλμα για κενό Location' -Test {
            { Get-BridgeStatusObject -Configuration $script:Config -Location '' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It -Name 'Ρίχνει σφάλμα για κενό Status' -Test {
            { Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status '' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It -Name 'Ρίχνει σφάλμα για κενό Timestamp' -Test {
            { Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '' -ImageSrc 'test.jpg' } | Should -Throw
        }

        It -Name 'Ρίχνει σφάλμα για κενό ImageSrc' -Test {
            { Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc '' } | Should -Throw
        }

        It -Name 'Ρίχνει σφάλμα για άκυρο BaseUrl' -Test {
            { Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' -BaseUrl 'not-a-valid-url' } | Should -Throw
        }

        It -Name 'Δέχεται έγκυρο BaseUrl' -Test {
            $obj = Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' -Status 'Ανοιχτή' -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'test.jpg' -BaseUrl 'https://custom.com/'
            $obj.imageUrl | Should -Be -ExpectedValue 'https://custom.com/test.jpg'
        }

        It -Name 'Ρίχνει σφάλμα INVALID_IMAGE_HOST όταν το absolute ImageSrc δείχνει σε μη έγκριτο host' -Test {
            Mock -CommandName Get-BridgeImageBuffer -MockWith { }
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

    Context -Name 'ClosedWithSchedule Hashing' -Fixture {
        It -Name 'Υπολογίζει το ImageHash όταν η κατάσταση είναι Κλειστή με πρόγραμμα' -Test {
            $config = New-BridgeConfiguration
            $contentBytes = [System.Text.Encoding]::UTF8.GetBytes("fake image content")
            Mock -CommandName Get-BridgeImageBuffer -MockWith {
                return $contentBytes
            }
            $obj = Get-BridgeStatusObject -Location 'isthmia' -Status $config.Statuses.ClosedWithSchedule `
                -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'schedule.php' -Configuration $config
            $obj.ImageHash | Should -Not -BeNullOrEmpty
            $obj.ImageHash | Should -Be -ExpectedValue '50E7825D3A7F7EF39C0D330A69E9AC35'
            Should -Invoke -CommandName Get-BridgeImageBuffer -Times 1 -Exactly -ParameterFilter {
                $TimeoutSec -eq $config.Defaults.HttpRequestTimeout
            }
        }

        It -Name 'Invalidates only the failed image so OCR cannot reuse an earlier closure schedule' -Test {
            $parameters = @{
                Configuration = $script:Config
                Location      = 'isthmia'
                Status        = $script:Config.Statuses.ClosedWithSchedule
                Timestamp     = '2025-04-10T13:00:00Z'
                ImageSrc      = 'stale-schedule.php'
            }
            Mock -CommandName Write-BridgeLog -MockWith { }
            Mock -CommandName Get-BridgeImageBuffer -MockWith { return [byte[]]@(1, 2, 3) }
            $previous = Get-BridgeStatusObject @parameters
            $otherUrl = "$($script:Config.Urls.BaseImage)/other-schedule.php"
            $script:BridgeImageBytesByUrl[$otherUrl] = [byte[]]@(9)

            $openParameters = $parameters.Clone()
            $openParameters.Status = $script:Config.Statuses.Open
            $openParameters.ImageSrc = 'image-bridge-open-no-schedule.php?1'
            $null = Get-BridgeStatusObject @openParameters

            Mock -CommandName Get-BridgeImageBuffer -MockWith { throw 'Connection timeout' }
            $current = Get-BridgeStatusObject @parameters
            $current.ImageHash | Should -BeNullOrEmpty
            { Get-BridgeCachedImageBytes -Url $current.ImageUrl } | Should -Throw -ExpectedMessage '*Connection timeout*'
            $script:BridgeImageBytesByUrl.ContainsKey($previous.ImageUrl) | Should -BeFalse
            $script:BridgeImageBytesByUrl[$otherUrl][0] | Should -Be -ExpectedValue 9
        }

        It -Name 'Returns the known status without a hash and warns when the image download fails' -Test {
            $config = New-BridgeConfiguration
            Mock -CommandName Get-BridgeImageBuffer -MockWith { throw "Connection timeout" }
            Mock -CommandName Write-BridgeLog -MockWith { }
            $obj = Get-BridgeStatusObject -Location 'isthmia' -Status $config.Statuses.ClosedWithSchedule `
                -Timestamp '2025-04-10T13:00:00Z' -ImageSrc 'schedule.php' -Configuration $config
            $obj.GefyraStatus | Should -Be -ExpectedValue $config.Statuses.ClosedWithSchedule
            $obj.ImageHash | Should -BeNullOrEmpty
            Should -Invoke -CommandName Write-BridgeLog -Times 1 -ParameterFilter { $Stage -eq 'Σφάλμα' -and $Level -eq 'Warning' }
        }
    }
}
