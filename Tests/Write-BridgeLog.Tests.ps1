Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

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

        Context 'Parameter Validation' {
            It 'Ρίχνει σφάλμα για άκυρο Stage' {
                { Write-BridgeLog -Stage 'InvalidStage' -Message 'test' -Level 'Verbose' } | Should -Throw
            }

            It 'Ρίχνει σφάλμα για άκυρο Level' {
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'test' -Level 'InvalidLevel' } | Should -Throw
            }

            It 'Ρίχνει σφάλμα για κενό Message' {
                { Write-BridgeLog -Stage 'Ανάλυση' -Message '' -Level 'Verbose' } | Should -Throw
            }

            It 'Δέχεται όλα τα έγκυρα Stages' {
                $validStages = @('Ανάλυση', 'Απόφαση', 'Ειδοποίηση', 'Σφάλμα')
                foreach ($stage in $validStages) {
                    { Write-BridgeLog -Stage $stage -Message 'test' -Level 'Verbose' } | Should -Not -Throw
                }
            }

            It 'Δέχεται όλα τα έγκυρα Levels' {
                $validLevels = @('Verbose', 'Debug', 'Warning')
                foreach ($level in $validLevels) {
                    { Write-BridgeLog -Stage 'Ανάλυση' -Message 'test' -Level $level } | Should -Not -Throw
                }
            }
        }
    }
}
