Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'Write-BridgeLog' -Fixture {
    BeforeAll -Scriptblock {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        $script:Config = New-BridgeConfiguration
    }

    BeforeEach -Scriptblock {
        Mock -CommandName Write-Verbose
        Mock -CommandName Write-Debug
        Mock -CommandName Write-Warning
        Mock -CommandName Add-Content
        Mock -CommandName New-Item
        Mock -CommandName Test-Path -MockWith { $false }
    }
    It -Name 'Γράφει log με Verbose level και δημιουργεί τον φάκελο' -Test {
        Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'δοκιμή' -Level 'Verbose'
        Should -Invoke -CommandName Write-Verbose -Times 1 -Exactly
        Should -Invoke -CommandName Add-Content -Times 1 -Exactly
        Should -Invoke -CommandName New-Item -Times 1 -Exactly
    }
    It -Name 'Γράφει log με Debug level' -Test {
        Write-BridgeLog -Configuration $script:Config -Stage 'Απόφαση' -Message 'λογική' -Level 'Debug'
        Should -Invoke -CommandName Write-Debug -Times 1 -Exactly
    }
    It -Name 'Γράφει log με Warning level' -Test {
        Write-BridgeLog -Configuration $script:Config -Stage 'Σφάλμα' -Message 'κάτι πήγε στραβά' -Level 'Warning'
        Should -Invoke -CommandName Write-Warning -Times 1 -Exactly
    }

    Context -Name 'Parameter Validation' -Fixture {
        It -Name 'Ρίχνει σφάλμα για άκυρο Stage' -Test {
            { Write-BridgeLog -Configuration $script:Config -Stage 'InvalidStage' -Message 'test' -Level 'Verbose' } | Should -Throw
        }

        It -Name 'Ρίχνει σφάλμα για άκυρο Level' -Test {
            { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'test' -Level 'InvalidLevel' } | Should -Throw
        }

        It -Name 'Ρίχνει σφάλμα για κενό Message' -Test {
            { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message '' -Level 'Verbose' } | Should -Throw
        }

        It -Name 'Δέχεται όλα τα έγκυρα Stages' -Test {
            $validStages = @('Ανάλυση', 'Απόφαση', 'Ειδοποίηση', 'Σφάλμα')
            foreach ($stage in $validStages) {
                { Write-BridgeLog -Configuration $script:Config -Stage $stage -Message 'test' -Level 'Verbose' } | Should -Not -Throw
            }
        }
        It -Name 'Δέχεται όλα τα έγκυρα Levels' -Test {
            $validLevels = @('Verbose', 'Debug', 'Warning')
            foreach ($level in $validLevels) {
                { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'test' -Level $level } | Should -Not -Throw
            }
        }
    }

    Context -Name 'Error Handling για File Operations' -Fixture {
        It -Name 'Γράφει Write-Warning όταν αποτυγχάνει το Add-Content' -Test {
            Mock -CommandName Add-Content -MockWith { throw [System.IO.IOException]::new('Access denied') }
            Mock -CommandName Write-Warning -MockWith {}

            { Write-BridgeLog -Configuration $script:Config -Stage 'Ανάλυση' -Message 'Test message' } | Should -Throw

            Should -Invoke -CommandName Write-Warning -Times 1 -Exactly -ParameterFilter {
                $Message -like '*Failed to write to log file*Access denied*'
            }
        }
    }

    Context -Name 'Legacy Encoding' -Fixture {
        It -Name 'Χρησιμοποιεί utf8 σε Legacy PowerShell' -Test {
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

Describe -Name 'Write-BridgeLog Retention Pruning' -Fixture {
    BeforeAll -Scriptblock {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
    }

    It -Name 'Διαγράφει BridgeWatcher-*.log αρχεία παλαιότερα από 7 ημέρες κατά τη δημιουργία νέου ημερήσιου log' -Test {
        $logDir = Join-Path -Path $TestDrive -ChildPath 'retention-new'
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null

        $expiredLog = Join-Path -Path $logDir -ChildPath 'BridgeWatcher-2020-01-01.log'
        $recentLog = Join-Path -Path $logDir -ChildPath 'BridgeWatcher-2020-01-02.log'
        $unrelatedFile = Join-Path -Path $logDir -ChildPath 'custom-audit.log'

        Set-Content -Path $expiredLog -Value 'expired log entry' -Encoding utf8
        (Get-Item -Path $expiredLog).LastWriteTime = (Get-Date).AddDays(-8)

        Set-Content -Path $recentLog -Value 'recent log entry' -Encoding utf8
        (Get-Item -Path $recentLog).LastWriteTime = (Get-Date).AddDays(-3)

        Set-Content -Path $unrelatedFile -Value 'unrelated file' -Encoding utf8
        (Get-Item -Path $unrelatedFile).LastWriteTime = (Get-Date).AddDays(-30)

        $cfg = New-BridgeConfiguration -LogDirectory $logDir
        Write-BridgeLog -Configuration $cfg -Stage 'Ανάλυση' -Message 'First daily log entry'

        $todayStr = (Get-Date).ToString('yyyy-MM-dd')
        $todayLog = Join-Path -Path $logDir -ChildPath "BridgeWatcher-$todayStr.log"

        $todayLog | Should -Exist
        $expiredLog | Should -Not -Exist
        $recentLog | Should -Exist
        $unrelatedFile | Should -Exist
    }

    It -Name 'Δεν εκτελεί εκκαθάριση όταν το ημερήσιο αρχείο καταγραφής υπάρχει ήδη' -Test {
        $logDir = Join-Path -Path $TestDrive -ChildPath 'retention-existing'
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null

        $todayStr = (Get-Date).ToString('yyyy-MM-dd')
        $todayLog = Join-Path -Path $logDir -ChildPath "BridgeWatcher-$todayStr.log"
        Set-Content -Path $todayLog -Value 'existing entry' -Encoding utf8

        $expiredLog = Join-Path -Path $logDir -ChildPath 'BridgeWatcher-2020-01-01.log'
        Set-Content -Path $expiredLog -Value 'expired log entry' -Encoding utf8
        (Get-Item -Path $expiredLog).LastWriteTime = (Get-Date).AddDays(-10)

        $cfg = New-BridgeConfiguration -LogDirectory $logDir
        Write-BridgeLog -Configuration $cfg -Stage 'Ανάλυση' -Message 'Second daily log entry'

        $expiredLog | Should -Exist
        (Get-Content -Path $todayLog -Raw) | Should -Match -RegularExpression 'Second daily log entry'
    }
}









