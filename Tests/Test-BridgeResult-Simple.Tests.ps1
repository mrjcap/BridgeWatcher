Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Test-BridgeResult Simple Mock Test' {
        BeforeEach {
            Mock Write-BridgeLog
        }

        It 'Mocks Write-BridgeLog correctly' {
            $errorResult = New-BridgeResult -Success $false -ErrorMessage 'test error'

            Test-BridgeResult -Result $errorResult | Should -Be $false

            Assert-MockCalled Write-BridgeLog -Times 1
        }
    }
}


