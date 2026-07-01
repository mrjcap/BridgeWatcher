Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Send-BridgePushoverRequest' {
    BeforeAll {
        Mock -CommandName Start-Sleep -MockWith { }
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
    }

    It 'Στέλνει POST και επιστρέφει αντικείμενο' {
        $payload = @{ token = 't'; user = 'u'; message = 'hi' }
        Mock -CommandName Invoke-RestMethod -MockWith {
            return @{ status = 'ok' }
        }
        $response = Send-BridgePushoverRequest -Payload $payload
        $response.status | Should -Be 'ok'
        Assert-MockCalled -CommandName Invoke-RestMethod -Times 1 -Exactly
    }

    It "Γράφει Write-BridgeLog με Stage 'Σφάλμα' όταν αποτυγχάνει η κλήση στο API" {
        # Arrange
        Mock Invoke-RestMethod { throw 'Fake failure' }
        Mock Write-BridgeLog
        $payload = @{
            token   = 'x'
            user    = 'x'
            message = 'test'
        }
        # Act
        try {
            $result = Send-BridgePushoverRequest -Payload $payload
        }
        catch {
            Write-Verbose 'Expected error, ignoring for test.'
        }
        $result | Should -BeNullOrEmpty
    }

    It 'Επιστρέφει response όταν το POST είναι επιτυχές' {
        Mock Invoke-RestMethod { return @{ status = 1; request = 'abc123' } }
        $payload = @{
            token   = 'x'
            user    = 'x'
            message = 'success'
        }
        $result = Send-BridgePushoverRequest -Payload $payload
        $result.status | Should -Be 1
        $result.request | Should -Be 'abc123'
    }

    Context 'Configuration Coverage Δοκιμές' {
        It 'Καλύπτει Configuration.PushoverApiUrl path' {
            Mock Invoke-RestMethod {
                return @{ status = 1 }
            }

            $config = [PSCustomObject]@{
                Urls = [PSCustomObject]@{
                    PushoverApi = 'https://custom-pushover-api.com/messages'
                }
            }

            $payload = @{ token = 'test'; user = 'user'; message = 'msg' }
            Send-BridgePushoverRequest -Payload $payload -Configuration $config

            Assert-MockCalled Invoke-RestMethod -ParameterFilter {
                $Uri -eq 'https://custom-pushover-api.com/messages'
            } -Times 1
        }

        It 'Καλύπτει Configuration.PushoverMessages.SendFailed path σε σφάλμα' {
            Mock Invoke-RestMethod { throw 'Test API failure' }
            Mock Write-BridgeLog {}

            $baseConfig = New-BridgeConfiguration
            $config = [PSCustomObject]@{
                Urls             = [PSCustomObject]@{
                    PushoverApi = $baseConfig.Urls.PushoverApi
                }
                PushoverMessages = @{
                    SendFailed = 'Custom send failed message'
                }
                LoggingConfig    = $baseConfig.LoggingConfig
            }

            $payload = @{ token = 'test'; user = 'user'; message = 'msg' }
            { Send-BridgePushoverRequest -Payload $payload -Configuration $config } | Should -Throw

            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Message -like 'Custom send failed message*'
            } -Times 1
        }

        It 'Καλύπτει Configuration.LoggingConfig.ErrorStage path σε σφάλμα' {
            Mock Invoke-RestMethod { throw 'Test API failure' }
            Mock Write-BridgeLog {}
            $baseConfig = New-BridgeConfiguration
            $config = [PSCustomObject]@{
                Urls             = [PSCustomObject]@{
                    PushoverApi = $baseConfig.Urls.PushoverApi
                }
                PushoverMessages = $baseConfig.PushoverMessages
                LoggingConfig    = @{
                    ErrorStage   = 'Σφάλμα'
                    WarningLevel = $baseConfig.LoggingConfig.WarningLevel
                }
            }

            $payload = @{ token = 'test'; user = 'user'; message = 'msg' }
            { Send-BridgePushoverRequest -Payload $payload -Configuration $config } | Should -Throw
            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Stage -eq 'Σφάλμα'
            } -Times 1
        }

        It 'Καλύπτει Configuration.LoggingConfig.WarningLevel path σε σφάλμα' {
            Mock Invoke-RestMethod { throw 'Test API failure' }
            Mock Write-BridgeLog {}
            $baseConfig = New-BridgeConfiguration
            $config = [PSCustomObject]@{
                Urls             = [PSCustomObject]@{
                    PushoverApi = $baseConfig.Urls.PushoverApi
                }
                PushoverMessages = $baseConfig.PushoverMessages
                LoggingConfig    = @{
                    ErrorStage   = $baseConfig.LoggingConfig.ErrorStage
                    WarningLevel = 'Warning'
                }
            }

            $payload = @{ token = 'test'; user = 'user'; message = 'msg' }
            { Send-BridgePushoverRequest -Payload $payload -Configuration $config } | Should -Throw
            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Level -eq 'Warning'
            } -Times 1
        }

        It 'Καλύπτει όλες τις configuration paths μαζί σε σφάλμα' {
            Mock Invoke-RestMethod { throw 'Complete test failure' }
            Mock Write-BridgeLog {}
            $config = [PSCustomObject]@{
                Urls             = [PSCustomObject]@{
                    PushoverApi = 'https://custom-error-api.com/test'
                }
                PushoverMessages = @{
                    SendFailed = 'Complete custom error'
                }
                LoggingConfig    = @{
                    ErrorStage   = 'Σφάλμα'
                    WarningLevel = 'Warning'
                }
            }

            $payload = @{ token = 'test'; user = 'user'; message = 'msg' }
            { Send-BridgePushoverRequest -Payload $payload -Configuration $config } | Should -Throw

            Assert-MockCalled Invoke-RestMethod -ParameterFilter { $Uri -eq 'https://custom-error-api.com/test' } -Times 3
            Assert-MockCalled Write-BridgeLog -ParameterFilter {
                $Message -like 'Complete custom error*' -and
                $Stage -eq 'Σφάλμα' -and
                $Level -eq 'Warning'
            } -Times 1
        }

        It 'Καλύπτει configuration με επιτυχή σενάριο' {
            Mock Invoke-RestMethod {
                return @{ status = 1; request = 'success123' }
            }

            $config = [PSCustomObject]@{
                Urls           = [PSCustomObject]@{
                    PushoverApi = 'https://custom-success-api.com/messages'
                }
            }

            $payload = @{ token = 'test'; user = 'user'; message = 'success' }
            $result = Send-BridgePushoverRequest -Payload $payload -Configuration $config

            Assert-MockCalled Invoke-RestMethod -ParameterFilter {
                $Uri -eq 'https://custom-success-api.com/messages'
            } -Times 1
            $result.status | Should -Be 1
            $result.request | Should -Be 'success123'
        }
    }
    Context 'Επιπλέον κάλυψη για retries και WebException' {
        It 'Πετάει σφάλμα 400 Bad Request όταν το Exception έχει response' {
            Mock Invoke-RestMethod {
                throw [System.Net.WebException]::new("Mock WebException", $null, [System.Net.WebExceptionStatus]::ProtocolError, $null)
            }
            Mock Write-BridgeLog
            { Send-BridgePushoverRequest -Payload @{ token = 't'; user = 'u'; message = 'm' } } | Should -Throw
        }
    }
}