Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Invoke-BridgeClosedNotification' {

    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeClosedNotification.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRGoogleCloud.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"
        $script:Config = New-BridgeConfiguration
    }



    Context 'Όταν η γέφυρα είναι κλειστή' {

        It 'Καλεί OCR και στέλνει Pushover' {

            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {

                return @{ 'Κλειστή για' = '1 ώρα' }

            }

            Mock -CommandName Send-BridgePushover -MockWith { }

            $params = @{

                CurrentState = @(

                    @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; imageUrl = 'https://example.com/img.jpg'; timestamp = (Get-Date) }

                )

                ApiKey       = 'dummy'
                PoUserKey    = 'dummy'
                PoApiKey     = 'dummy'
                Configuration = $script:Config

            }

            Invoke-BridgeClosedNotification @params -Configuration $script:Config

            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 1 -Exactly

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly

        }

        It 'Στέλνει debug log και Pushover notification χωρίς OCR' {

            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Κλειστή για συντήρηση'

                timestamp    = (Get-Date)

                imageUrl     = 'https://example.com/image.jpg'

            }

            Mock Send-BridgePushover -MockWith { }

            Mock Write-BridgeLog -MockWith { }

            Mock Invoke-BridgeOCRGoogleCloud { throw 'Δεν πρέπει να κληθεί OCR!' }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose -Debug

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly

            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -ParameterFilter { $Message -like '*κλειστή για συντήρηση*' }

            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 0 -Exactly

        }

        It 'Γράφει debug για μόνιμα κλειστή γέφυρα' {

            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Μόνιμα κλειστή'

            }

            Mock -CommandName Send-BridgePushover

            Mock -CommandName Write-Debug

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose

            Should -Invoke -CommandName Write-Debug -Times 1 -Exactly -Scope It

        }

        It 'Γράφει warning όταν αποτυγχάνει η OCR' {

            Mock Invoke-BridgeOCRGoogleCloud { throw 'Fake OCR failure' }
            Mock Send-BridgePushover -MockWith { }

            $entry = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = Get-Date; imageUrl = 'https://example.com/x.jpg' }

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose } | Should -Not -Throw

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly
        }

        It 'Στέλνει fallback ειδοποίηση όταν το OCR επιστρέφει $null' {

            Mock Invoke-BridgeOCRGoogleCloud { $null }
            Mock Send-BridgePushover -MockWith { }

            $entry = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = Get-Date; imageUrl = 'https://example.com/x.jpg' }

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose } | Should -Not -Throw

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly
        }


        It 'Γράφει debug και δεν καλεί Send-BridgePushover για άγνωστη κατάσταση' {

            # Arrange

            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Μπερδεμένη'

                timestamp    = (Get-Date)

                imageUrl     = 'https://example.com/image.jpg'

            }

            Mock Send-BridgePushover { throw 'Δεν έπρεπε να εκτελεστεί!' }

            # Act

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose -Debug } | Should -Not -Throw

        }

        It 'Χρησιμοποιεί NotificationProvider αντί Pushover όταν παρέχεται' {

            $script:providerCalled = $false
            $script:providerTitle = ''
            $script:providerMessage = ''

            $provider = {
                param([string]$Title, [string]$Message, [string]$Type)
                $null = $Type
                $script:providerCalled = $true
                $script:providerTitle = $Title
                $script:providerMessage = $Message
            }

            $entry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή για συντήρηση'
                timestamp    = (Get-Date)
                imageUrl     = 'https://example.com/image.jpg'
            }

            Mock Send-BridgePushover { throw 'Δεν έπρεπε να κληθεί Pushover!' }
            Mock Write-BridgeLog { }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -NotificationProvider $provider

            $script:providerCalled | Should -BeTrue
            $script:providerTitle | Should -BeLike '*κλειστή για συντήρηση*'
        }

    }

}

