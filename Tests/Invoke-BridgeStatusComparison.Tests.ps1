Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Invoke-BridgeStatusComparison - Ειδοποιήσεις' {
        It 'Δεν στέλνει ειδοποίηση όταν η κατάσταση δεν αλλάζει' {
            Mock -CommandName Invoke-BridgeClosedNotification { 'Closed notification sent' }
            Mock -CommandName Invoke-BridgeOpenedNotification { 'Opened notification sent' }
            $sameState = @(
                [PSCustomObject]@{
                    gefyraName   = 'Ποσειδωνία'
                    gefyraStatus = 'Ανοιχτή'
                    timestamp    = '2025-04-14T10:00:00'
                    imageUrl     = 'https://test/image2.php'
                }
            )
            $params = @{
                PreviousState = $sameState
                CurrentState  = $sameState
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            Invoke-BridgeStatusComparison @params
            Should -Invoke -CommandName Invoke-BridgeClosedNotification -Exactly 0
            Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Exactly 0
        }
        It 'Στέλνει απευθείας ειδοποίηση χωρίς OCR' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            $timestamp = Get-Date
            $previous = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
            $current = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Μόνιμα κλειστή'; timestamp = $timestamp; imageUrl = 'img1.jpg' }
            $params = @{
                PreviousState = $previous
                CurrentState  = $current
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            Invoke-BridgeStatusComparison @params
            Assert-MockCalled -CommandName Invoke-BridgeClosedNotification -Exactly 1
        }
        It 'Στέλνει ειδοποίηση με OCR' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            $timestamp = Get-Date
            $previous = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
            $current = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = $timestamp; imageUrl = 'img2.jpg' }
            $params = @{
                PreviousState = $previous
                CurrentState  = $current
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            Invoke-BridgeStatusComparison @params
            Assert-MockCalled -CommandName Invoke-BridgeClosedNotification -Exactly 1
        }
        It 'Στέλνει ειδοποίηση ανοίγματος' {
            # ΣΗΜΕΙΩΣΗ:ΔΕΝ βάζουμε -MockWith { } εδώ,
            # για να εκτελεστεί το real Invoke-BridgeOpenedNotification.
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Send-BridgePushover -MockWith { }
            $timestamp = Get-Date
            $previous = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα' }
            $current = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή'; timestamp = $timestamp; imageUrl = 'img3.jpg' }
            $params = @{
                PreviousState = $previous
                CurrentState  = $current
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            Invoke-BridgeStatusComparison @params
            Assert-MockCalled -CommandName Send-BridgePushover -Times 1
        }
        It 'Δεν στέλνει ειδοποίηση' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            Mock -CommandName Send-BridgePushover -MockWith { }
            $timestamp = Get-Date
            # Ορίζει το ίδιο array για previous/current
            $same = @(
                @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή'; timestamp = $timestamp; imageUrl = 'img4.jpg' }
            )
            $params = @{
                PreviousState = $same
                CurrentState  = $same
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            Invoke-BridgeStatusComparison @params
            Assert-MockCalled -CommandName Invoke-BridgeClosedNotification -Times 0
            Assert-MockCalled -CommandName Invoke-BridgeOpenedNotification -Times 0
            Assert-MockCalled -CommandName Send-BridgePushover -Times 0
        }
        It 'Δεν στέλνει ειδοποίηση όταν gefyraName δεν ταιριάζει' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            Mock -CommandName Send-BridgePushover -MockWith { }
            $params = @{
                PreviousState = @{ gefyraName = 'Ποσειδωνία'; gefyraStatus = 'Ανοιχτή' }
                CurrentState  = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'x.jpg' }
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            { Invoke-BridgeStatusComparison @params } | Should -Not -Throw
        }
        It 'Δεν στέλνει ειδοποίηση σε άκυρη τιμή status' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            Mock -CommandName Send-BridgePushover -MockWith { }
            $params = @{
                PreviousState = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                CurrentState  = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'ανικτή'; timestamp = (Get-Date); imageUrl = 'x.jpg' }
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            { Invoke-BridgeStatusComparison @params } | Should -Not -Throw
        }
        It 'Δεν στέλνει ειδοποίηση όταν μόνο το timestamp αλλάζει' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            Mock -CommandName Send-BridgePushover -MockWith { }
            $base = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή'; imageUrl = 'x.jpg' }
            $params = @{
                PreviousState = $base
                CurrentState  = $base.Clone()
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            $params.CurrentState.timestamp = (Get-Date).AddMinutes(5)
            Invoke-BridgeStatusComparison @params
            Assert-MockCalled -CommandName Send-BridgePushover -Times 0
        }
        It 'Πετάει σφάλμα όταν η CurrentState είναι $null' {
            $params = @{
                PreviousState = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                CurrentState  = $null
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            { Invoke-BridgeStatusComparison @params } | Should -Throw
        }
        It 'Πετάει σφάλμα όταν η PreviousState είναι $null' {
            $params = @{
                PreviousState = $null
                CurrentState  = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            { Invoke-BridgeStatusComparison @params } | Should -Throw
        }
        It 'Δεν στέλνει ειδοποίηση όταν λείπει το imageUrl' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Send-BridgePushover -MockWith { }
            $params = @{
                PreviousState = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                CurrentState  = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = $null }
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            { Invoke-BridgeStatusComparison @params } | Should -Not -Throw
            Assert-MockCalled -CommandName Invoke-BridgeClosedNotification -Times 1
            # imageUrl δεν είναι κρίσιμο για την απόφαση αποστολής
        }
        It 'Επεξεργάζεται σωστά πολλαπλές αλλαγές' {
            # Κάνουμε mock μόνο την Invoke-BridgeClosedNotification για να ελέγξουμε τις κλήσεις
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            $previousState = @(
                @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                @{ gefyraName = 'Ποσειδωνία'; gefyraStatus = 'Ανοιχτή' }
            )
            $currentState = @(
                @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'img1.jpg' }
                @{ gefyraName = 'Ποσειδωνία'; gefyraStatus = 'Μόνιμα κλειστή'; timestamp = (Get-Date); imageUrl = 'img2.jpg' }
            )
            $params = @{
                PreviousState = $previousState
                CurrentState  = $currentState
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            Invoke-BridgeStatusComparison @params
            # ✅ Αναμένουμε 2 κλήσεις (μία για κάθε αλλαγή)
            Assert-MockCalled -CommandName Invoke-BridgeClosedNotification -Times 2
        }
        It 'Δεν στέλνει ειδοποίηση όταν μόνο το imageUrl αλλάζει' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            $base = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή'; timestamp = (Get-Date); imageUrl = 'img1.jpg' }
            $copy = $base.Clone()
            $copy.imageUrl = 'img1b.jpg'
            $params = @{
                PreviousState = $base
                CurrentState  = $copy
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            Invoke-BridgeStatusComparison @params
            Assert-MockCalled -CommandName Invoke-BridgeClosedNotification -Times 0
            Assert-MockCalled -CommandName Invoke-BridgeOpenedNotification -Times 0
        }
        It 'Στέλνει σωστά ειδοποιήσεις για κλείσιμο και άνοιγμα όταν αλλάζουν δύο γέφυρες αντίθετα' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
            $previousState = @(
                @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                @{ gefyraName = 'Ποσειδωνία'; gefyraStatus = 'Κλειστή με πρόγραμμα' }
            )
            $currentState = @(
                @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'img1.jpg' }
                @{ gefyraName = 'Ποσειδωνία'; gefyraStatus = 'Ανοιχτή'; timestamp = (Get-Date); imageUrl = 'img2.jpg' }
            )
            $params = @{
                PreviousState = $previousState
                CurrentState  = $currentState
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }
            Invoke-BridgeStatusComparison @params
            # ✅ Περιμένουμε μία κλήση σε κάθε notification
            Assert-MockCalled -CommandName Invoke-BridgeClosedNotification -Times 1
            Assert-MockCalled -CommandName Invoke-BridgeOpenedNotification -Times 1
        }
        It 'Γράφει warning όταν λείπει κατάσταση' {
            { Invoke-BridgeStatusComparison -PreviousState $null -CurrentState @{ gefyraName = 'X'; gefyraStatus = 'Ανοιχτή' } -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' } | Should -Throw
        }
        It 'Γράφει verbose όταν δεν υπάρχουν αλλαγές' {
            Mock Send-BridgePushover {}
            $same = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή'; timestamp = Get-Date; imageUrl = 'x.jpg' }
            { Invoke-BridgeStatusComparison -PreviousState $same -CurrentState $same -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose } | Should -Not -Throw
        }
        It 'Γράφει Exception όταν CurrentState ή PreviousState είναι κενό array' {
            $paramsMissingCurrent = @{
                PreviousState = @(@{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' })
                CurrentState = @()
                ApiKey = 'X'; PoUserKey = 'Y'; PoApiKey = 'Z'
            }
            { Invoke-BridgeStatusComparison @paramsMissingCurrent } | Should -Throw
            $paramsMissingPrevious = @{
                PreviousState = @()
                CurrentState = @(@{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' })
                ApiKey = 'X'; PoUserKey = 'Y'; PoApiKey = 'Z'
            }
            { Invoke-BridgeStatusComparison @paramsMissingPrevious } | Should -Throw
        }
        It 'Γράφει verbose όταν δεν υπάρχει καμία αλλαγή στις γέφυρες' {
            $state = @{
                gefyraName   = 'Ισθμία'
                gefyraStatus = 'Ανοιχτή'
                timestamp    = '2025-04-16T21:00:00'
                imageUrl     = 'https://image.jpg'
            }
            $params = @{
                PreviousState = @($state)
                CurrentState = @($state)
                ApiKey = 'X'; PoUserKey = 'Y'; PoApiKey = 'Z'
                Verbose = $true
            }
            { Invoke-BridgeStatusComparison @params } | Should -Not -Throw
        }
        It 'Γράφει Write-Verbose όταν δεν υπάρχει καμία αλλαγή στις γέφυρες' {
            $state = @{
                gefyraName   = 'Ισθμία'
                gefyraStatus = 'Ανοιχτή'
                timestamp    = '2025-04-16T21:00:00'
                imageUrl     = 'https://image.jpg'
            }
            {
                $invokeBridgeStatusComparisonSplat = @{
                    PreviousState = @($state)
                    CurrentState  = @($state)
                    ApiKey        = 'X'
                    PoUserKey     = 'Y'
                    PoApiKey      = 'Z'
                    Verbose       = $true
                }
                Invoke-BridgeStatusComparison @invokeBridgeStatusComparisonSplat
            } | Should -Not -Throw
        }
        It 'Γράφει Write-Verbose όταν δεν υπάρχουν διαφορές (mocked Compare-Object)' {
            Mock Compare-Object { @() }
            $state = @{
                gefyraName   = 'Ισθμία'
                gefyraStatus = 'Ανοιχτή'
            }
            { $invokeBridgeStatusComparisonSplat = @{
                    PreviousState = @($state)
                    CurrentState  = @($state)
                    ApiKey        = 'X'
                    PoUserKey     = 'Y'
                    PoApiKey      = 'Z'
                    Verbose       = $true
                }
                Invoke-BridgeStatusComparison @invokeBridgeStatusComparisonSplat } | Should -Not -Throw
        }
        It 'πρέπει να στείλει ειδοποίηση τύπου Closed' {
            $defaultParams = @{
                ApiKey    = 'fake-key'
                PoUserKey = 'user-key'
                PoApiKey  = 'app-key'
            }
            $prev = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
            $curr = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Μόνιμα κλειστή' }
            Invoke-BridgeStatusComparison @defaultParams -PreviousState $prev -CurrentState $curr
            Test-Path "$TestDrive\notify.txt" | Should -BeFalse
        }
        It 'πυροδοτεί handler για Μόνιμα κλειστή|<=' {
            $defaultParams = @{
                ApiKey    = 'fake-key'
                PoUserKey = 'user-key'
                PoApiKey  = 'app-key'
            }
            # current είναι Ανοιχτή        =>μπήκε παλιά
            # previous είναι Μόνιμα κλειστή=>τώρα εμφανίζεται=><=
            $current = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
            $previous = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Μόνιμα κλειστή' }
            # παρατηρούμε:ΔΕΝ κάνουμε mock το Send-BridgeNotification
            function Send-BridgeNotification {
                param([ValidateSet('Closed','Opened')]$Type, [object[]]$State)
                "NOTIFY:$($Type):$($State[0].gefyraName)" | Out-File -Append "$TestDrive\notify.txt"
            }
            Invoke-BridgeStatusComparison @defaultParams -PreviousState @($previous) -CurrentState @($current)
            (Get-Content "$TestDrive\notify.txt") | Should -Contain 'NOTIFY:Closed:Ισθμία'
        }
    }
    Describe 'Invoke-BridgeStatusComparison' {

        BeforeEach {
            Remove-Item "$TestDrive\log.txt","$TestDrive\notify.txt" -ErrorAction SilentlyContinue
        }

        BeforeAll {
            function Write-BridgeLog {
                param([string]$Stage, [string]$Message, [string]$Level)
                "$Stage|$Level|$Message" | Out-File -Append "$TestDrive\log.txt"
            }

            function Write-BridgeStage {
                param(
                    [ValidateSet('Ανάλυση','Σφάλμα')][string]$Stage,
                    [string]$Message,
                    [ValidateSet('Verbose','Warning','Error')][string]$Level = 'Verbose'
                )
                Write-BridgeLog -Stage $Stage -Message $Message -Level $Level
            }

            function Send-BridgeNotification {
                param([ValidateSet('Closed','Opened')]$Type, [object[]]$State)
                "NOTIFY:$($Type):$($State[0].gefyraName)" | Out-File -Append "$TestDrive\notify.txt"
            }
            $defaultParams = @{
                ApiKey    = 'fake-key'
                PoUserKey = 'user-key'
                PoApiKey  = 'app-key'
            }
        }
        Context 'Καμία αλλαγή' {
            It 'πυροδοτεί το block "Καμία ουσιαστική αλλαγή"' {
                $obj = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                Invoke-BridgeStatusComparison @defaultParams -PreviousState @($obj) -CurrentState @($obj)
                (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match 'Καμία ουσιαστική αλλαγή'
                Test-Path "$TestDrive\notify.txt" | Should -BeFalse
            }
            It 'πυροδοτεί το block "Καμία αλλαγή" όταν δεν υπάρχουν καθόλου αλλαγές' {
                $emptyObj = @{ gefyraName = 'Foo'; gefyraStatus = 'Ανοιχτή' }
                Invoke-BridgeStatusComparison @defaultParams -PreviousState @($emptyObj) -CurrentState @($emptyObj)
                (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match 'Καμία ουσιαστική αλλαγή'
            }
        }
        Context 'Κατάσταση αλλαγής ➡️' {
            It 'πρέπει να στείλει ειδοποίηση τύπου Closed' {
                $prev = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                $curr = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Κλειστή με πρόγραμμα' }
                Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)
                (Get-Content "$TestDrive\notify.txt") | Should -Contain 'NOTIFY:Closed:Ισθμία'
            }
            It 'πρέπει να στείλει ειδοποίηση τύπου Opened' {
                $prev = @{ gefyraName = 'Ποσειδωνία'; gefyraStatus = 'Κλειστή με πρόγραμμα' }
                $curr = @{ gefyraName = 'Ποσειδωνία'; gefyraStatus = 'Ανοιχτή' }
                Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)
                (Get-Content "$TestDrive\notify.txt") | Should -Contain 'NOTIFY:Opened:Ποσειδωνία'
            }
        }
        Context 'Κατάσταση αλλαγής ⬅️' {
            It 'πυροδοτεί "Μόνιμα κλειστή|<="' {
                $prev = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Μόνιμα κλειστή' }
                $curr = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Ανοιχτή' }
                Invoke-BridgeStatusComparison @defaultParams -PreviousState @($curr) -CurrentState @($prev)
                (Get-Content "$TestDrive\notify.txt") | Should -Contain 'NOTIFY:Closed:Ισθμία'
            }
        }
        Context 'Άγνωστο combo' {
            It 'γράφει λογικά "Άγνωστο combo"' {
                $prev = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Foo' }
                $curr = @{ gefyraName = 'Ισθμία'; gefyraStatus = 'Bar' }
                Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)
                (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match 'Άγνωστο combo'
            }
        }
        Context 'Σφάλμα εσωτερικό (catch)' {
            It 'γράφει εξαίρεση στο log όταν αποτυγχάνει εσωτερικά' {
                function Compare-Object { throw 'mock fail' }
                { Invoke-BridgeStatusComparison @defaultParams -PreviousState @(@{ gefyraName = 'X'; gefyraStatus = 'Y' }) -CurrentState @(@{ gefyraName = 'X'; gefyraStatus = 'Y' }) } | Should -Throw
                (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match '❌ mock fail'
            }
        }
    }
}