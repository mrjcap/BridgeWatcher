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
        Should -Invoke -CommandName Write-Verbose -Times 1 -Exactly
        Should -Invoke -CommandName Add-Content -Times 1 -Exactly
        Should -Invoke -CommandName New-Item -Times 1 -Exactly
    }
    It 'Γράφει log με Debug level' {
        Write-BridgeLog -Configuration $script:Config -Stage 'Απόφαση' -Message 'λογική' -Level 'Debug'
        Should -Invoke -CommandName Write-Debug -Times 1 -Exactly
    }
    It 'Γράφει log με Warning level' {
        Write-BridgeLog -Configuration $script:Config -Stage 'Σφάλμα' -Message 'κάτι πήγε στραβά' -Level 'Warning'
        Should -Invoke -CommandName Write-Warning -Times 1 -Exactly
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
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like '*Failed to write to log file*Access denied*'
            }
        }
    }

    Context 'Legacy Encoding' {
        It 'Χρησιμοποιεί utf8 σε Legacy PowerShell' {
            $env:IsLegacyPowerShell = 'true'
            try {
                { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'Legacy encoding test' } | Should -Not -Throw
            }
            finally {
                Remove-Item -Path env:IsLegacyPowerShell -ErrorAction SilentlyContinue
            }
        }
    }
}

Describe 'Write-BridgeLog Retention Pruning' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
    }

    It 'Διαγράφει BridgeWatcher-*.log αρχεία παλαιότερα από 7 ημέρες κατά τη δημιουργία νέου ημερήσιου log' {
        $logDir = Join-Path $TestDrive 'retention-new'
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null

        $expiredLog = Join-Path $logDir 'BridgeWatcher-2020-01-01.log'
        $recentLog = Join-Path $logDir 'BridgeWatcher-2020-01-02.log'
        $unrelatedFile = Join-Path $logDir 'custom-audit.log'

        Set-Content -Path $expiredLog -Value 'expired log entry' -Encoding utf8
        (Get-Item -Path $expiredLog).LastWriteTime = (Get-Date).AddDays(-8)

        Set-Content -Path $recentLog -Value 'recent log entry' -Encoding utf8
        (Get-Item -Path $recentLog).LastWriteTime = (Get-Date).AddDays(-3)

        Set-Content -Path $unrelatedFile -Value 'unrelated file' -Encoding utf8
        (Get-Item -Path $unrelatedFile).LastWriteTime = (Get-Date).AddDays(-30)

        $cfg = New-BridgeConfiguration -LogDirectory $logDir
        Write-BridgeLog -Configuration $cfg -Stage 'Ανάλυση' -Message 'First daily log entry'

        $todayStr = (Get-Date).ToString('yyyy-MM-dd')
        $todayLog = Join-Path $logDir "BridgeWatcher-$todayStr.log"

        $todayLog | Should -Exist
        $expiredLog | Should -Not -Exist
        $recentLog | Should -Exist
        $unrelatedFile | Should -Exist
    }

    It 'Δεν εκτελεί εκκαθάριση όταν το ημερήσιο αρχείο καταγραφής υπάρχει ήδη' {
        $logDir = Join-Path $TestDrive 'retention-existing'
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null

        $todayStr = (Get-Date).ToString('yyyy-MM-dd')
        $todayLog = Join-Path $logDir "BridgeWatcher-$todayStr.log"
        Set-Content -Path $todayLog -Value 'existing entry' -Encoding utf8

        $expiredLog = Join-Path $logDir 'BridgeWatcher-2020-01-01.log'
        Set-Content -Path $expiredLog -Value 'expired log entry' -Encoding utf8
        (Get-Item -Path $expiredLog).LastWriteTime = (Get-Date).AddDays(-10)

        $cfg = New-BridgeConfiguration -LogDirectory $logDir
        Write-BridgeLog -Configuration $cfg -Stage 'Ανάλυση' -Message 'Second daily log entry'

        $expiredLog | Should -Exist
        (Get-Content -Path $todayLog -Raw) | Should -Match 'Second daily log entry'
    }
}









