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

    Context 'Όταν κλείνει το LogStream και προκύπτει σφάλμα' {
        It 'Κάνει catch το σφάλμα και εκτυπώνει Verbose' {
            function Get-PSCallStack {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '')]
                param()
                return @()
            }
            $mockStream = New-Object PSObject
            $mockStream | Add-Member -MemberType ScriptMethod -Name Close -Value { throw "Close error" }
            $script:LogStream = $mockStream
            $script:LogStreamPath = "oldpath.log"
            $config = New-BridgeConfiguration
            $config.LogDirectory = "C:\TempLogs"
            Mock New-Object { $null } -ParameterFilter { $TypeName -eq 'System.IO.StreamWriter' }
            try {
                { Write-BridgeLog -Stage 'Ανάλυση' -Message "Test" -Configuration $config -Verbose } | Should -Not -Throw
            }
            finally {
                Remove-Item -Path function:Get-PSCallStack -ErrorAction SilentlyContinue
            }
        }
    }

    Context 'StreamWriter Logging (Else Block)' {
        BeforeEach {
            $script:LogStream = $null
            $script:LogStreamPath = $null
        }
        AfterEach {
            if ($script:LogStream) {
                try { $script:LogStream.Close() } catch { $null = $_ }
                $script:LogStream = $null
            }
        }
        It 'Γράφει σε αρχείο χρησιμοποιώντας StreamWriter' {
            function Get-PSCallStack {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '')]
                param()
                return @()
            }
            $mockWriter = New-Object PSObject
            $mockWriter | Add-Member -MemberType ScriptMethod -Name WriteLine -Value { param($line) [void]$line }
            $mockWriter | Add-Member -MemberType ScriptMethod -Name Flush -Value { }
            $mockWriter | Add-Member -MemberType ScriptMethod -Name Close -Value { }
            $mockWriter | Add-Member -MemberType NoteProperty -Name AutoFlush -Value $true
            Mock New-Object { $mockWriter } -ParameterFilter { $TypeName -eq 'System.IO.StreamWriter' }

            $config = New-BridgeConfiguration
            $config.LogDirectory = "C:\TempLogs"

            try {
                # First run: creates StreamWriter
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'StreamWriter Test' -Configuration $config } | Should -Not -Throw
                $script:LogStream | Should -Not -BeNullOrEmpty
                $script:LogStreamPath | Should -BeLike "C:\TempLogs\BridgeWatcher-*.log"

                # Second run: uses existing StreamWriter
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'StreamWriter Test 2' -Configuration $config } | Should -Not -Throw

                # Third run: changes log path
                $script:LogStreamPath = "C:\TempLogs\different.log"
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'StreamWriter Test 3' -Configuration $config } | Should -Not -Throw
            }
            finally {
                Remove-Item -Path function:Get-PSCallStack -ErrorAction SilentlyContinue
                if ($script:LogStream) {
                    try { $script:LogStream.Close() } catch { $null = $_ }
                    $script:LogStream = $null
                }
            }
        }
    }
}








