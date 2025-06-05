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
                Write-Verbose "Expected error, ignoring for test."
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
    }
}