Import-Module "$PSScriptRoot\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Write-BridgeLog' {
        BeforeEach {
            Mock Write-Verbose
            Mock Write-Debug
            Mock Write-Warning
            Mock Add-Content
            Mock New-Item
            Mock Test-Path { $false }  # simulate missing log dir
        }
        It 'Γράφει log με Verbose level και δημιουργεί τον φάκελο' {
            Write-BridgeLog -Stage 'Ανάλυση' -Message 'δοκιμή' -Level 'Verbose'
            Assert-MockCalled Write-Verbose -Exactly 1
            Assert-MockCalled Add-Content -Exactly 1
            Assert-MockCalled New-Item -Exactly 1
        }
        It 'Γράφει log με Debug level' {
            Write-BridgeLog -Stage 'Απόφαση' -Message 'λογική' -Level 'Debug'
            Assert-MockCalled Write-Debug -Exactly 1
        }
        It 'Γράφει log με Warning level' {
            Write-BridgeLog -Stage 'Σφάλμα' -Message 'κάτι πήγε στραβά' -Level 'Warning'
            Assert-MockCalled Write-Warning -Exactly 1
        }
    }
}