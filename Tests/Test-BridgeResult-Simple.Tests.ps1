Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Test-BridgeResult Simple Mock Test' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
    }

    BeforeEach {
        Mock Write-BridgeLog
    }

    It 'Mocks Write-BridgeLog correctly' {
        $errorResult = New-BridgeResult -Success $false -ErrorMessage 'test error'

        Test-BridgeResult -Result $errorResult | Should -Be $false

        Assert-MockCalled Write-BridgeLog -Times 1
    }
}


