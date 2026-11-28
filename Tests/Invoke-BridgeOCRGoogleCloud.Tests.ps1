Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'Invoke-BridgeOCRGoogleCloud' -Fixture {
    BeforeAll -Scriptblock {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRGoogleCloud.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeHttpExceptionInfo.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It -Name 'Στέλνει Base64 image.content αντί imageUri και κατεβάζει μέσω Get-BridgeImageBuffer όταν δεν είναι στη cache' -Test {
        $script:BridgeImageBytesByUrl.Clear()
        $validUri = 'https://example.com/image-bridge-open-with-schedule-isthmia.php'
        $expectedBytes = [System.Text.Encoding]::UTF8.GetBytes('schedule-image-payload')
        $expectedBase64 = [System.Convert]::ToBase64String($expectedBytes)
        $script:CapturedRequestBody = $null

        Mock -CommandName Get-BridgeImageBuffer -MockWith {
            return $expectedBytes
        }
        Mock -CommandName Invoke-BridgeOCRRequest -MockWith {
            $script:CapturedRequestBody = $RequestBody
            return @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{
                                description = @(
                                    'Από', '01/01/2025', '10:00', 'Έως', '01/01/2025', '10:30'
                                )
                            }
                        )
                    }
                )
            }
        }
        Mock -CommandName ConvertFrom-BridgeOCRResult -MockWith {
            return @{ mock = 'result' }
        }

        $out = Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'abc' -ImageUri $validUri
        $out.mock | Should -Be -ExpectedValue 'result'

        Should -Invoke -CommandName Get-BridgeImageBuffer -Times 1 -Exactly -Scope It -ParameterFilter {
            $Url -eq $validUri -and $TimeoutSec -eq $script:Config.Defaults.HttpRequestTimeout
        }
        Should -Invoke -CommandName Invoke-BridgeOCRRequest -Times 1 -Exactly -Scope It
        Should -Invoke -CommandName ConvertFrom-BridgeOCRResult -Times 1 -Exactly -Scope It

        $parsedBody = $script:CapturedRequestBody | ConvertFrom-Json
        $parsedBody.requests[0].image.content | Should -Be -ExpectedValue $expectedBase64
        $parsedBody.requests[0].image.PSObject.Properties['source'] | Should -BeNullOrEmpty
        $script:CapturedRequestBody | Should -Not -Match -RegularExpression 'imageUri'
    }

    It -Name 'Επαναχρησιμοποιεί τα cached bytes από Get-BridgeStatusObject χωρίς δεύτερη κλήση Invoke-WebRequest' -Test {
        $script:BridgeImageBytesByUrl.Clear()
        $rawBytes = [byte[]]@(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
        $expectedBase64 = [System.Convert]::ToBase64String($rawBytes)
        $script:CachedRequestBody = $null

        Mock -CommandName Invoke-WebRequest -MockWith {
            return [pscustomobject]@{ Content = $rawBytes }
        }
        Mock -CommandName Invoke-BridgeOCRRequest -MockWith {
            $script:CachedRequestBody = $RequestBody
            return @{
                responses = @(
                    @{
                        textAnnotations = @(
                            @{ description = 'Από 01/01/2025 10:00 Έως 01/01/2025 10:30' }
                        )
                    }
                )
            }
        }
        Mock -CommandName ConvertFrom-BridgeOCRResult -MockWith {
            return [pscustomobject]@{ Bridge = 'Ποσειδωνία' }
        }

        $statusObj = Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' `
            -Status $script:Config.Statuses.ClosedWithSchedule -Timestamp '2025-04-10T13:00:00Z' `
            -ImageSrc 'image-bridge-open-with-schedule-posidonia.php?123'

        $ocrOut = Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'abc' -ImageUri $statusObj.ImageUrl
        $ocrOut.Bridge | Should -Be -ExpectedValue 'Ποσειδωνία'

        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly -Scope It
        $parsedBody = $script:CachedRequestBody | ConvertFrom-Json
        $parsedBody.requests[0].image.content | Should -Be -ExpectedValue $expectedBase64
    }

    It -Name 'Εκκαθαρίζει τη cache όταν το πλήθος φτάσει τα 4 αντικείμενα πριν την εισαγωγή νέου' -Test {
        $script:BridgeImageBytesByUrl.Clear()
        Mock -CommandName Get-BridgeImageBuffer -MockWith {
            return [byte[]]@(1, 2, 3, 4)
        }

        foreach ($idx in 1..4) {
            $null = Get-BridgeStatusObject -Configuration $script:Config -Location 'isthmia' `
                -Status $script:Config.Statuses.ClosedWithSchedule -Timestamp '2025-04-10T13:00:00Z' `
                -ImageSrc "schedule-$idx.php"
        }
        $script:BridgeImageBytesByUrl.Count | Should -Be -ExpectedValue 4

        $fifth = Get-BridgeStatusObject -Configuration $script:Config -Location 'isthmia' `
            -Status $script:Config.Statuses.ClosedWithSchedule -Timestamp '2025-04-10T13:00:00Z' `
            -ImageSrc 'schedule-5.php'

        $script:BridgeImageBytesByUrl.Count | Should -Be -ExpectedValue 1
        $script:BridgeImageBytesByUrl.ContainsKey($fifth.ImageUrl) | Should -BeTrue
    }

    It -Name 'Ρίχνει σφάλμα αν το URI είναι άκυρο' -Test {
        { Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'abc' -ImageUri 'notaurl' } | Should -Throw
    }

    It -Name 'Γράφει Error όταν αποτυγχάνει η κλήση' -Test {
        $script:BridgeImageBytesByUrl.Clear()
        Mock -CommandName Get-BridgeImageBuffer -MockWith { return [byte[]]@(1, 2, 3) }
        Mock -CommandName Invoke-BridgeOCRRequest -MockWith { 'Simulated OCR failure' }
        $invokeOCRGoogleCloudSplat = @{
            ApiKey        = 'dummy'
            Configuration = $script:Config
            ImageUri      = 'https://image.jpg'
            Verbose       = $true
            ErrorAction   = 'SilentlyContinue'
            ErrorVariable = 'myErr'
        }
        { Invoke-BridgeOCRGoogleCloud @invokeOCRGoogleCloudSplat } 2>&1 | Out-Null
    }

    It -Name 'Γράφει Write-Error όταν αποτυγχάνει η κλήση' -Test {
        $script:BridgeImageBytesByUrl.Clear()
        Mock -CommandName Get-BridgeImageBuffer -MockWith { return [byte[]]@(1, 2, 3) }
        Mock -CommandName Invoke-BridgeOCRRequest -MockWith { throw 'Simulated OCR failure' }
        { Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'dummy' -ImageUri 'https://image.jpg' -Verbose -ErrorAction SilentlyContinue } | Should -Throw -ExpectedMessage 'Simulated OCR failure'
    }
}
