Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Send-BridgeNotification' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgeNotification.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeClosedNotification.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOpenedNotification.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRGoogleCloud.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
    }

    Context 'Notification Routing' {
        It 'Routes "Closed" notifications to Invoke-BridgeClosedNotification' {
            Mock Invoke-BridgeClosedNotification { }
            Mock Invoke-BridgeOpenedNotification { }

            $state = @( @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή' } )

            $params = @{
                Type      = 'Closed'
                State     = $state
                ApiKey    = 'google-api-key'
                PoUserKey = 'pushover-user-key'
                PoApiKey  = 'pushover-api-key'
            }

            Send-BridgeNotification @params

            Assert-MockCalled Invoke-BridgeClosedNotification -Exactly 1 -ParameterFilter {
                $CurrentState[0].gefyraName -eq 'Ισθμία' -and
                $PoUserKey -eq 'pushover-user-key' -and
                $PoApiKey -eq 'pushover-api-key' -and
                $ApiKey -eq 'google-api-key'
            }
            Assert-MockCalled Invoke-BridgeOpenedNotification -Exactly 0
        }

        It 'Routes "Opened" notifications to Invoke-BridgeOpenedNotification' {
            Mock Invoke-BridgeClosedNotification { }
            Mock Invoke-BridgeOpenedNotification { }

            $state = @( @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' } )

            $params = @{
                Type      = 'Opened'
                State     = $state
                ApiKey    = 'google-api-key'
                PoUserKey = 'pushover-user-key'
                PoApiKey  = 'pushover-api-key'
            }

            Send-BridgeNotification @params

            Assert-MockCalled Invoke-BridgeOpenedNotification -Exactly 1 -ParameterFilter {
                $CurrentState[0].gefyraName -eq 'Ισθμία' -and
                $PoUserKey -eq 'pushover-user-key' -and
                $PoApiKey -eq 'pushover-api-key'
            }
            Assert-MockCalled Invoke-BridgeClosedNotification -Exactly 0
        }
        It 'Executes custom NotificationProvider instead of Send-BridgePushover' {
            Mock Send-BridgePushover { }
            Mock Invoke-BridgeOCRGoogleCloud { return @{ 'Κλειστή για' = '1 ώρα' } }

            $tracker = @{
                Called = $false
                Params = $null
            }
            $customProvider = {
                param($Title, $Message, $Type)
                $tracker.Called = $true
                $tracker.Params = @{ Title = $Title; Message = $Message; Type = $Type }
            }

            $state = @( [pscustomobject]@{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή για συντήρηση'; timestamp = (Get-Date); imageUrl = 'https://example.com/img.jpg' } )

            $params = @{
                Type                 = 'Closed'
                State                = $state
                ApiKey               = 'google-api-key'
                PoUserKey            = 'pushover-user-key'
                PoApiKey             = 'pushover-api-key'
                NotificationProvider = $customProvider
            }

            Send-BridgeNotification @params

            $tracker.Called | Should -Be $true
            $tracker.Params.Title | Should -BeLike '*κλειστή για συντήρηση*'
            $tracker.Params.Type | Should -Be 'Closed'
            Assert-MockCalled Send-BridgePushover -Times 0 -Exactly
        }
    }
}
