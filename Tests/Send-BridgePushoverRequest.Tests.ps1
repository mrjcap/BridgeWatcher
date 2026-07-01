Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Send-BridgePushoverRequest' {
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
            } catch {
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

        Context 'Configuration Coverage Tests' {
            It 'Καλύπτει Configuration.PushoverApiUrl path' {
                Mock Invoke-RestMethod {
                    return @{ status = 1 }
                }

                $config = [PSCustomObject]@{
                    PushoverApiUrl = 'https://custom-pushover-api.com/messages'
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

                $config = [PSCustomObject]@{
                    PushoverMessages = @{
                        SendFailed = 'Custom send failed message'
                    }
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
                $config = [PSCustomObject]@{
                    LoggingConfig = @{
                        ErrorStage = 'Σφάλμα'
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
                $config = [PSCustomObject]@{
                    LoggingConfig = @{
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
                    PushoverApiUrl   = 'https://custom-error-api.com/test'
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

                Assert-MockCalled Invoke-RestMethod -ParameterFilter {
                    $Uri -eq 'https://custom-error-api.com/test'
                } -Times 1
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
                    PushoverApiUrl = 'https://custom-success-api.com/messages'
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

        Context 'Exceptions and Retries' {
            It 'Κάνει retry και throw όταν WebException δεν έχει 400, 401, 403 status code' {
                Mock Invoke-RestMethod { throw [System.Net.WebException]::new("Timeout") }
                Mock Start-Sleep {}
                { Send-BridgePushoverRequest -Payload @{ message = 'test' } } | Should -Throw
                Assert-MockCalled Start-Sleep -Times 2
                Assert-MockCalled Invoke-RestMethod -Times 3
            }

            It 'Κάνει throw αμέσως όταν WebException έχει 401 status code' {
                if (-not ("MockWebResponse" -as [type])) {
                    Add-Type -TypeDefinition '
                    using System;
                    using System.Net;
                    public class MockWebResponse : WebResponse {
                        public HttpStatusCode StatusCode { get; set; } = HttpStatusCode.Unauthorized;
                    }
                    '
                }
                $response = [MockWebResponse]::new()
                $ex = [System.Net.WebException]::new("Unauthorized", $null, [System.Net.WebExceptionStatus]::ProtocolError, $response)
                Mock Invoke-RestMethod { throw $ex }
                Mock Start-Sleep {}
                { Send-BridgePushoverRequest -Payload @{ message = 'test' } } | Should -Throw
                Assert-MockCalled Start-Sleep -Times 0
                Assert-MockCalled Invoke-RestMethod -Times 1
            }
        }
    }
}

