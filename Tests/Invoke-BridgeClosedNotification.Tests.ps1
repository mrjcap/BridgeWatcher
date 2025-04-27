Import-Module "$PSScriptRoot\..\src\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Invoke-BridgeClosedNotification' {
        Context 'Όταν η γέφυρα είναι κλειστή' {
            It 'Καλεί OCR και στέλνει Pushover' {
                Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
                    return @{ 'Κλειστή για' = '1 ώρα' }
                }
                Mock -CommandName Send-BridgePushover -MockWith { }
                $params = @{
                    CurrentState = @(
                        @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα'; imageUrl = 'img.jpg'; timestamp = (Get-Date) }
                    )
                    ApiKey       = 'dummy'
                    PoUserKey    = 'dummy'
                    PoApiKey     = 'dummy'
                }
                Invoke-BridgeClosedNotification @params
                Assert-MockCalled -CommandName Invoke-BridgeOCRGoogleCloud -Exactly 1
                Assert-MockCalled -CommandName Send-BridgePushover -Exactly 1
            }
            It 'Γράφει debug για μόνιμα κλειστή γέφυρα' {
                $entry = [pscustomobject]@{
                    gefyraName   = 'Ισθμία'
                    gefyraStatus = 'Μόνιμα κλειστή'
                }
                Mock -CommandName Send-BridgePushover
                Mock -CommandName Write-Debug
                Invoke-BridgeClosedNotification -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose
                Assert-MockCalled -CommandName Write-Debug -Exactly 1 -Scope It
            }
            It 'Γράφει warning όταν αποτυγχάνει η OCR' {
                Mock Invoke-BridgeOCRGoogleCloud { throw 'Fake OCR failure' }
                $entry = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = Get-Date; imageUrl = 'x.jpg' }
                { Invoke-BridgeClosedNotification -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose } | Should -Not -Throw
            }
            It 'Γράφει debug και δεν καλεί Send-BridgePushover για άγνωστη κατάσταση' {
                # Arrange
                $entry = [pscustomobject]@{
                    gefyraName   = 'Ισθμία'
                    gefyraStatus = 'Μπερδεμένη'
                    timestamp    = (Get-Date)
                    imageUrl     = 'https://example.com/image.jpg'
                }
                Mock Send-BridgePushover { throw 'Δεν έπρεπε να εκτελεστεί!' }
                # Act
                { Invoke-BridgeClosedNotification -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose -Debug } | Should -Not -Throw
            }
        }
    }
}