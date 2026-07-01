Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Write-BridgeLog' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
    }

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

    Context 'Error Handling για File Operations' {
        It 'Γράφει Write-Warning όταν αποτυγχάνει το Add-Content' {
            # Mock το Add-Content για να προκαλέσουμε σφάλμα
            Mock Add-Content { throw [System.IO.IOException]::new('Access denied') }
            Mock Write-Warning {}

            # Εκτέλεση - δεν πρέπει να ρίξει exception αλλά να καλέσει Write-Warning
            { Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message' } | Should -Not -Throw

            # Επιβεβαίωση ότι καλέστηκε το Write-Warning με το σωστό μήνυμα
            Should -Invoke Write-Warning -Exactly 1 -ParameterFilter {
                $Message -like '*Failed to write to log file*Access denied*'
            }
        }
    }

    Context 'Log Stream Logic (non-Pester path)' {
        BeforeAll {
            . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
            $script:tempLogDir = Join-Path ([System.IO.Path]::GetTempPath()) "BridgeWatcherLogTest_$([guid]::NewGuid())"
            New-Item -Path $script:tempLogDir -ItemType Directory -Force | Out-Null
        }
        AfterAll {
            if ($script:LogStream) {
                try { $script:LogStream.Close() } catch { }
                $script:LogStream = $null
            }
            Remove-Item $script:tempLogDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Δημιουργεί νέο LogStream όταν δεν υπάρχει' {
            Mock Get-PSCallStack { @() }
            $config = New-BridgeConfiguration
            $config.LogDirectory = $script:tempLogDir
            
            Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message 1' -Configuration $config
            
            $script:LogStream | Should -Not -BeNullOrEmpty
            $script:LogStream.BaseStream.CanWrite | Should -Be $true
            
            # Δοκιμή ότι γράφει στο ίδιο stream
            Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message 2' -Configuration $config
            
            # Καθαρισμός για να κλείσει το αρχείο και να διαβαστεί
            $script:LogStream.Close()
            $script:LogStream = $null
            
            $files = Get-ChildItem $script:tempLogDir
            $content = Get-Content $files[0].FullName
            $content.Count | Should -Be 2
            $content[0] | Should -Match 'Test message 1'
            $content[1] | Should -Match 'Test message 2'
        }

        It 'Κλείνει το παλιό stream αν αλλάξει το log path (π.χ. νέα μέρα)' {
            Mock Get-PSCallStack { @() }
            $config = New-BridgeConfiguration
            $config.LogDirectory = $script:tempLogDir
            
            # Αρχικό
            Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message A' -Configuration $config
            
            $oldStream = $script:LogStream
            
            # Αλλάζουμε τεχνητά το LogStreamPath για να προσομοιώσουμε αλλαγή μέρας
            $script:LogStreamPath = "dummy.log"
            
            Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message B' -Configuration $config
            
            $oldStream.BaseStream.CanWrite | Should -Be $false
            $script:LogStream.BaseStream.CanWrite | Should -Be $true
            
            $script:LogStream.Close()
            $script:LogStream = $null
        }

        It 'Πιάνει σφάλματα κατά το γράψιμο στο stream και κάνει Write-Warning' {
            Mock Get-PSCallStack { @() }
            $config = New-BridgeConfiguration
            $config.LogDirectory = $script:tempLogDir
            
            Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message' -Configuration $config
            
            # Κλείνουμε το stream, το επόμενο γράψιμο θα πετάξει exception
            $script:LogStream.Close()
            
            Mock Write-Warning { }
            Write-BridgeLog -Stage 'Ανάλυση' -Message 'Test message error' -Configuration $config
            Assert-MockCalled Write-Warning -Times 1 -Exactly
            
            $script:LogStream = $null
        }
    }
}

