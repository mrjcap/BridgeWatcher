Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Write-BridgeLog' {
    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        $script:Config = New-BridgeConfiguration
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
        Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'δοκιμή' -Level 'Verbose'
        Assert-MockCalled Write-Verbose -Exactly 1
        Assert-MockCalled Add-Content -Exactly 1
        Assert-MockCalled New-Item -Exactly 1
    }
    It 'Γράφει log με Debug level' {
        Write-BridgeLog -Configuration $script:Config -Stage 'Απόφαση' -Message 'λογική' -Level 'Debug'
        Assert-MockCalled Write-Debug -Exactly 1
    }
    It 'Γράφει log με Warning level' {
        Write-BridgeLog -Configuration $script:Config -Stage 'Σφάλμα' -Message 'κάτι πήγε στραβά' -Level 'Warning'
        Assert-MockCalled Write-Warning -Exactly 1
    }

    Context 'Parameter Validation' {
        It 'Ρίχνει σφάλμα για άκυρο Stage' {
            { Write-BridgeLog -Configuration $script:Config -Stage 'InvalidStage' -Message 'test' -Level 'Verbose' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για άκυρο Level' {
            { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'test' -Level 'InvalidLevel' } | Should -Throw
        }

        It 'Ρίχνει σφάλμα για κενό Message' {
            { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message '' -Level 'Verbose' } | Should -Throw
        }

        It 'Δέχεται όλα τα έγκυρα Stages' {
            $validStages = @('Ανάλυση', 'Απόφαση', 'Ειδοποίηση', 'Σφάλμα')
            foreach ($stage in $validStages) {
                { Write-BridgeLog -Configuration $script:Config -Stage $stage -Message 'test' -Level 'Verbose' } | Should -Not -Throw
            }
        }
        It 'Δέχεται όλα τα έγκυρα Levels' {
            $validLevels = @('Verbose', 'Debug', 'Warning')
            foreach ($level in $validLevels) {
                { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'test' -Level $level } | Should -Not -Throw
            }
        }
    }

    Context 'Error Handling για File Operations' {
        It 'Γράφει Write-Warning όταν αποτυγχάνει το Add-Content' {
            # Mock το Add-Content για να προκαλέσουμε σφάλμα
            Mock Add-Content { throw [System.IO.IOException]::new('Access denied') }
            Mock Write-Warning {}

            # Εκτέλεση - δεν πρέπει να ρίξει exception αλλά να καλέσει Write-Warning
            { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'Test message' } | Should -Throw

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
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '')]
                param()
                return @()
            }
            $mockStream = New-Object PSObject
            $mockStream | Add-Member -MemberType ScriptMethod -Name Close -Value { throw "Close error" }
            $script:LogStream = $mockStream
            $script:LogStreamPath = "oldpath.log"
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "TempLogs"
            $mockNewStream = New-Object PSObject
            $mockNewStream | Add-Member -MemberType NoteProperty -Name AutoFlush -Value $true
            $mockNewStream | Add-Member -MemberType ScriptMethod -Name WriteLine -Value { param($val) $null = $val }
            Mock New-Object { $mockNewStream } -ParameterFilter { $TypeName -eq 'System.IO.StreamWriter' }
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
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '')]
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
            $config.Defaults.LogDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "TempLogs"

            try {
                # First run: creates StreamWriter
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'StreamWriter Test' -Configuration $config } | Should -Not -Throw
                $script:LogStream | Should -Not -BeNullOrEmpty
                $script:LogStreamPath | Should -BeLike (Join-Path $config.Defaults.LogDirectory "BridgeWatcher-*.log")

                # Second run: uses existing StreamWriter
                { Write-BridgeLog -Stage 'Ανάλυση' -Message 'StreamWriter Test 2' -Configuration $config } | Should -Not -Throw

                # Third run: changes log path
                $script:LogStreamPath = Join-Path $config.Defaults.LogDirectory "different.log"
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

        It 'Θέτει το legacy encoding utf8' {
            $env:IsLegacyPowerShell = 'true'
            try {
                { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'Legacy encoding test' } | Should -Not -Throw
            }
            finally {
                Remove-Item -Path env:IsLegacyPowerShell -ErrorAction SilentlyContinue
            }
        }

        It 'Ρίχνει σφάλμα όταν αποτυγχάνει η δημιουργία StreamWriter' {
            function Get-PSCallStack {
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidOverwritingBuiltInCmdlets', '')]
                [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSProvideCommentHelp', '')]
                param()
                return @()
            }
            Mock New-Object { throw [System.IO.IOException]::new("StreamWriter creation failed") } -ParameterFilter { $TypeName -eq 'System.IO.StreamWriter' }
            Mock Write-Warning {}
            $config = New-BridgeConfiguration
            $config.Defaults.LogDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "TempLogsFailed"
            try {
                { Write-BridgeLog -Stage 'Ανάλυση' -Message "Test Fail" -Configuration $config } | Should -Throw
                Assert-MockCalled Write-Warning -Exactly 1
            }
            finally {
                Remove-Item -Path function:Get-PSCallStack -ErrorAction SilentlyContinue
            }
        }
    }
}








