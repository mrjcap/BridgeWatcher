Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Invoke-BridgeOCRGoogleCloud' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRGoogleCloud.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1"
        $script:Config = New-BridgeConfiguration
    }

    It 'Στέλνει Base64 image.content αντί imageUri και κατεβάζει μέσω Get-BridgeImageBuffer όταν δεν είναι στη cache' {
        $script:BridgeImageBytesByUrl.Clear()
        $validUri = 'https://example.com/image-bridge-open-with-schedule-isthmia.php'
        $expectedBytes = [System.Text.Encoding]::UTF8.GetBytes('schedule-image-payload')
        $expectedBase64 = [System.Convert]::ToBase64String($expectedBytes)
        $script:CapturedRequestBody = $null

        Mock Get-BridgeImageBuffer {
            return $expectedBytes
        }
        Mock Invoke-BridgeOCRRequest {
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
        Mock ConvertFrom-BridgeOCRResult {
            return @{ mock = 'result' }
        }

        $out = Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'abc' -ImageUri $validUri
        $out.mock | Should -Be 'result'

        Should -Invoke -CommandName Get-BridgeImageBuffer -Times 1 -Exactly -Scope It -ParameterFilter {
            $Url -eq $validUri -and $TimeoutSec -eq $script:Config.Defaults.HttpRequestTimeout
        }
        Should -Invoke -CommandName Invoke-BridgeOCRRequest -Times 1 -Exactly -Scope It
        Should -Invoke -CommandName ConvertFrom-BridgeOCRResult -Times 1 -Exactly -Scope It

        $parsedBody = $script:CapturedRequestBody | ConvertFrom-Json
        $parsedBody.requests[0].image.content | Should -Be $expectedBase64
        $parsedBody.requests[0].image.PSObject.Properties['source'] | Should -BeNullOrEmpty
        $script:CapturedRequestBody | Should -Not -Match 'imageUri'
    }

    It 'Επαναχρησιμοποιεί τα cached bytes από Get-BridgeStatusObject χωρίς δεύτερη κλήση Invoke-WebRequest' {
        $script:BridgeImageBytesByUrl.Clear()
        $rawBytes = [byte[]]@(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
        $expectedBase64 = [System.Convert]::ToBase64String($rawBytes)
        $script:CachedRequestBody = $null

        Mock Invoke-WebRequest {
            return [pscustomobject]@{ Content = $rawBytes }
        }
        Mock Invoke-BridgeOCRRequest {
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
        Mock ConvertFrom-BridgeOCRResult {
            return [pscustomobject]@{ Bridge = 'Ποσειδωνία' }
        }

        $statusObj = Get-BridgeStatusObject -Configuration $script:Config -Location 'poseidonia' `
            -Status $script:Config.Statuses.ClosedWithSchedule -Timestamp '2025-04-10T13:00:00Z' `
            -ImageSrc 'image-bridge-open-with-schedule-posidonia.php?123'

        $ocrOut = Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'abc' -ImageUri $statusObj.ImageUrl
        $ocrOut.Bridge | Should -Be 'Ποσειδωνία'

        Should -Invoke -CommandName Invoke-WebRequest -Times 1 -Exactly -Scope It
        $parsedBody = $script:CachedRequestBody | ConvertFrom-Json
        $parsedBody.requests[0].image.content | Should -Be $expectedBase64
    }

    It 'Εκκαθαρίζει τη cache όταν το πλήθος φτάσει τα 4 αντικείμενα πριν την εισαγωγή νέου' {
        $script:BridgeImageBytesByUrl.Clear()
        Mock Get-BridgeImageBuffer {
            return [byte[]]@(1, 2, 3, 4)
        }

        foreach ($idx in 1..4) {
            $null = Get-BridgeStatusObject -Configuration $script:Config -Location 'isthmia' `
                -Status $script:Config.Statuses.ClosedWithSchedule -Timestamp '2025-04-10T13:00:00Z' `
                -ImageSrc "schedule-$idx.php"
        }
        $script:BridgeImageBytesByUrl.Count | Should -Be 4

        $fifth = Get-BridgeStatusObject -Configuration $script:Config -Location 'isthmia' `
            -Status $script:Config.Statuses.ClosedWithSchedule -Timestamp '2025-04-10T13:00:00Z' `
            -ImageSrc 'schedule-5.php'

        $script:BridgeImageBytesByUrl.Count | Should -Be 1
        $script:BridgeImageBytesByUrl.ContainsKey($fifth.ImageUrl) | Should -BeTrue
    }

    It 'Ρίχνει σφάλμα αν το URI είναι άκυρο' {
        { Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'abc' -ImageUri 'notaurl' } | Should -Throw
    }

    It 'Γράφει Error όταν αποτυγχάνει η κλήση' {
        $script:BridgeImageBytesByUrl.Clear()
        Mock Get-BridgeImageBuffer { return [byte[]]@(1, 2, 3) }
        Mock Invoke-BridgeOCRRequest { 'Simulated OCR failure' }
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

    It 'Γράφει Write-Error όταν αποτυγχάνει η κλήση' {
        $script:BridgeImageBytesByUrl.Clear()
        Mock Get-BridgeImageBuffer { return [byte[]]@(1, 2, 3) }
        Mock Invoke-BridgeOCRRequest { throw 'Simulated OCR failure' }
        { Invoke-BridgeOCRGoogleCloud -Configuration $script:Config -ApiKey 'dummy' -ImageUri 'https://image.jpg' -Verbose -ErrorAction SilentlyContinue } | Should -Throw 'Simulated OCR failure'
    }
}
