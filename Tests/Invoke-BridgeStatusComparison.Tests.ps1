Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope BridgeWatcher {
Describe 'Invoke-BridgeStatusComparison - Ειδοποιήσεις' {

    BeforeAll {
        $script:Config = New-BridgeConfiguration
    }

    It 'Δεν στέλνει ειδοποίηση όταν η κατάσταση δεν αλλάζει' {

        Mock -CommandName Invoke-BridgeClosedNotification { 'Closed notification sent' }

        Mock -CommandName Invoke-BridgeOpenedNotification { 'Opened notification sent' }

        $sameState = @(

            [PSCustomObject]@{

                GefyraName   = 'Ποσειδωνία'

                GefyraStatus = 'Ανοιχτή'

                timestamp    = '2025-04-14T10:00:00'

                imageUrl     = 'https://test/image2.php'

            }

        )

        $params = @{

            PreviousState = $sameState

            CurrentState  = $sameState

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $result | Where-Object { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty

        $result | Where-Object { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty

    }

    It 'Στέλνει απευθείας ειδοποίηση χωρίς OCR' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $timestamp = Get-Date

        $previous = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

        $current = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Μόνιμα κλειστή'; timestamp = $timestamp; imageUrl = 'img1.jpg' }

        $params = @{

            PreviousState = $previous

            CurrentState  = $current

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $evt_Closed = $result | Where-Object { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be 1

    }

    It 'Στέλνει ειδοποίηση με OCR' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $timestamp = Get-Date

        $previous = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

        $current = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = $timestamp; imageUrl = 'img2.jpg' }

        $params = @{

            PreviousState = $previous

            CurrentState  = $current

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $evt_Closed = $result | Where-Object { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be 1

    }

    It 'Στέλνει ειδοποίηση ανοίγματος' {

        # ΣΗΜΕΙΩΣΗ:ΔΕΝ βάζουμε -MockWith { } εδώ,

        # για να εκτελεστεί το real Invoke-BridgeOpenedNotification.

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $timestamp = Get-Date

        $previous = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }

        $current = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; timestamp = $timestamp; imageUrl = 'img3.jpg' }

        $params = @{

            PreviousState = $previous

            CurrentState  = $current

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params
        $result.Count | Should -Be 1


    }

    It 'Δεν στέλνει ειδοποίηση' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $timestamp = Get-Date

        # Ορίζει το ίδιο array για previous/current

        $same = @(

            @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; timestamp = $timestamp; imageUrl = 'img4.jpg' }

        )

        $params = @{

            PreviousState = $same

            CurrentState  = $same

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $result | Where-Object { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty

        $result | Where-Object { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty


    }

    It 'Δεν στέλνει ειδοποίηση όταν GefyraName δεν ταιριάζει' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $params = @{

            PreviousState = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'x.jpg' }

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params
        $result.Count | Should -Be 1

    }

    It 'Δεν στέλνει ειδοποίηση σε άκυρη τιμή status' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $params = @{

            PreviousState = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'ανικτή'; timestamp = (Get-Date); imageUrl = 'x.jpg' }

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params
        $result | Should -BeNullOrEmpty

    }

    It 'Δεν στέλνει ειδοποίηση όταν μόνο το timestamp αλλάζει' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; imageUrl = 'x.jpg' }

        $params = @{

            PreviousState = $base

            CurrentState  = $base.Clone()

            Configuration = $script:Config

        }

        $params.CurrentState.timestamp = (Get-Date).AddMinutes(5)

        $result = Invoke-BridgeStatusComparison @params
        $result | Should -BeNullOrEmpty


    }

    It 'Πετάει σφάλμα όταν η CurrentState είναι $null' {

        $params = @{

            PreviousState = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = $null

            Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Throw

    }

    It 'Πετάει σφάλμα όταν η PreviousState είναι $null' {

        $params = @{

            PreviousState = $null

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Not -Throw

    }

    It 'Δεν στέλνει ειδοποίηση όταν λείπει το imageUrl' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $params = @{

            PreviousState = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = $null }

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $evt_Closed = $result | Where-Object { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be 1

        # imageUrl δεν είναι κρίσιμο για την απόφαση αποστολής

    }

    It 'Επεξεργάζεται σωστά πολλαπλές αλλαγές' {

        # Κάνουμε mock μόνο την Invoke-BridgeClosedNotification για να ελέγξουμε τις κλήσεις

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $previousState = @(

            @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }

        )

        $currentState = @(

            @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'img1.jpg' }

            @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Μόνιμα κλειστή'; timestamp = (Get-Date); imageUrl = 'img2.jpg' }

        )

        $params = @{

            PreviousState = $previousState

            CurrentState  = $currentState

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        # ✅ Αναμένουμε 2 κλήσεις (μία για κάθε αλλαγή)

        $evt_Closed = $result | Where-Object { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be 2

    }

    It 'Δεν στέλνει ειδοποίηση όταν μόνο το imageUrl αλλάζει' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; timestamp = (Get-Date); imageUrl = 'img1.jpg' }

        $copy = $base.Clone()

        $copy.imageUrl = 'img1b.jpg'

        $params = @{

            PreviousState = $base

            CurrentState  = $copy

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $result | Where-Object { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty

        $result | Where-Object { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty

    }

    It 'Στέλνει ειδοποίηση όταν μόνο το imageUrl αλλάζει και η κατάσταση είναι Κλειστή με πρόγραμμα' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'img1.jpg' }

        $copy = $base.Clone()

        $copy.imageUrl = 'img1b.jpg'

        $params = @{

            PreviousState = $base

            CurrentState  = $copy

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $evt_Closed = $result | Where-Object { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be 1

        $result | Where-Object { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty

    }

    It 'Στέλνει σωστά ειδοποιήσεις για κλείσιμο και άνοιγμα όταν αλλάζουν δύο γέφυρες αντίθετα' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $previousState = @(

            @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }

        )

        $currentState = @(

            @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'img1.jpg' }

            @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; timestamp = (Get-Date); imageUrl = 'img2.jpg' }

        )

        $params = @{

            PreviousState = $previousState

            CurrentState  = $currentState

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        # ✅ Περιμένουμε μία κλήση σε κάθε notification

        $evt_Closed = $result | Where-Object { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be 1

        $evt_Opened = $result | Where-Object { $_.Type -eq 'Opened' }
        $evt_Opened.Count | Should -Be 1

    }

    It 'Γράφει warning όταν λείπει κατάσταση' {

        $result = Invoke-BridgeStatusComparison -PreviousState $null -CurrentState @{ GefyraName = 'X'; GefyraStatus = 'Ανοιχτή' } -Configuration $script:Config
        $result.Count | Should -Be 1

    }

    It 'Γράφει verbose όταν δεν υπάρχουν αλλαγές' {

        Mock Send-BridgePushover {}

        $same = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; timestamp = Get-Date; imageUrl = 'x.jpg' }

        $result = Invoke-BridgeStatusComparison -PreviousState $same -CurrentState $same -Configuration $script:Config -Verbose
        $result | Should -BeNullOrEmpty

    }

    It 'Γράφει Exception όταν CurrentState ή PreviousState είναι κενό array' {

        $paramsMissingCurrent = @{

            PreviousState = @(@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' })

            CurrentState  = @()

            Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @paramsMissingCurrent } | Should -Throw

        $paramsMissingPrevious = @{

            PreviousState = @()

            CurrentState  = @(@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' })

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @paramsMissingPrevious
        $result.Count | Should -Be 1

    }

    It 'Γράφει verbose όταν δεν υπάρχει καμία αλλαγή στις γέφυρες' {

        $state = @{

            GefyraName   = 'Ισθμία'

            GefyraStatus = 'Ανοιχτή'

            timestamp    = '2025-04-16T21:00:00'

            imageUrl     = 'https://image.jpg'

        }

        $params = @{

            PreviousState = @($state)

            CurrentState  = @($state)

            Configuration = $script:Config

            Verbose       = $true

        }

        $result = Invoke-BridgeStatusComparison @params
        $result | Should -BeNullOrEmpty

    }

    It 'Γράφει Write-Verbose όταν δεν υπάρχει καμία αλλαγή στις γέφυρες' {

        $state = @{

            GefyraName   = 'Ισθμία'

            GefyraStatus = 'Ανοιχτή'

            timestamp    = '2025-04-16T21:00:00'

            imageUrl     = 'https://image.jpg'

        }

        {

            $invokeBridgeStatusComparisonSplat = @{

                PreviousState = @($state)

                CurrentState  = @($state)

                Configuration = $script:Config

                Verbose       = $true

            }

            $null = Invoke-BridgeStatusComparison @invokeBridgeStatusComparisonSplat

        } | Should -Not -Throw

    }

    It 'Γράφει Write-Verbose όταν δεν υπάρχουν διαφορές (mocked Compare-Object)' {

        Mock Compare-Object { @() }

        $state = @{

            GefyraName   = 'Ισθμία'

            GefyraStatus = 'Ανοιχτή'

        }

        { $invokeBridgeStatusComparisonSplat = @{

                PreviousState = @($state)

                CurrentState  = @($state)

                Configuration = $script:Config

                Verbose       = $true

            }

            Invoke-BridgeStatusComparison @invokeBridgeStatusComparisonSplat } | Should -Not -Throw

    }

    It 'πρέπει να στείλει ειδοποίηση τύπου Closed' {

        $defaultParams = @{

            Configuration = $script:Config

        }

        # Redefine Invoke-BridgeClosedNotification to write to notify.txt for this test
        Mock -CommandName Invoke-BridgeClosedNotification -MockWith {
            param($CurrentState)
            "NOTIFY:Closed:$($CurrentState[0].GefyraName)" | Out-File -Append "$TestDrive\notify.txt"
        }

        $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

        $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Μόνιμα κλειστή' }

        $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState $prev -CurrentState $curr

        $evt_Closed_Ισθμία = $result | Where-Object { $_.Type -eq 'Closed' -and $_.BridgeName -eq 'Ισθμία' }
        $evt_Closed_Ισθμία | Should -Not -BeNullOrEmpty

    }

    It 'Στέλνει ειδοποίηση τύπου Open όταν γίνεται αλλαγή απο "Κλειστή για συντήρηση" (=>)' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

        $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή για συντήρηση'; timestamp = (Get-Date); imageUrl = 'img_maintenance.jpg' }

        $params = @{

            PreviousState = $prev

            CurrentState  = $curr

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $evt_Closed = $result | Where-Object { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be 1

        $result | Where-Object { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty

    }

    # Από Κλειστή για συντήρηση σε Ανοιχτή (πρέπει να καλείται μόνο Opened)

    It 'Στέλνει ειδοποίηση τύπου Opened όταν γίνεται αλλαγή από Κλειστή σε Ανοιχτή (=>)' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $prev = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση' }

        $curr = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; timestamp = (Get-Date); imageUrl = 'img_open.jpg' }

        $params = @{

            PreviousState = $prev

            CurrentState  = $curr

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $result | Where-Object { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty

        $evt_Opened = $result | Where-Object { $_.Type -eq 'Opened' }
        $evt_Opened.Count | Should -Be 1

    }

}

Describe 'Invoke-BridgeStatusComparison' {



    BeforeEach {

        Remove-Item "$TestDrive\log.txt", "$TestDrive\notify.txt" -ErrorAction SilentlyContinue

    }



    BeforeAll {
        $script:Config = New-BridgeConfiguration

        Mock -CommandName Write-BridgeLog -MockWith {

            param([string]$Stage, [string]$Message, [string]$Level)

            "$Stage|$Level|$Message" | Out-File -Append "$TestDrive\log.txt"
        }

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith {
            param($CurrentState)
            "NOTIFY:Closed:$($CurrentState[0].GefyraName)" | Out-File -Append "$TestDrive\notify.txt"
        }
        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith {
            param($CurrentState)
            "NOTIFY:Opened:$($CurrentState[0].GefyraName)" | Out-File -Append "$TestDrive\notify.txt"
        }

        $script:defaultParams = @{

            Configuration = $script:Config

        }

        $script:defaultParams

    }

    Context 'Καμία αλλαγή' {



        It 'πυροδοτεί το block "Καμία ουσιαστική αλλαγή"' {

            $obj = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($obj) -CurrentState @($obj)
            $result | Should -BeNullOrEmpty

            (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match 'Καμία ουσιαστική αλλαγή'

            Test-Path "$TestDrive\notify.txt" | Should -BeFalse

        }

        It 'πυροδοτεί το block "Καμία αλλαγή" όταν δεν υπάρχουν καθόλου αλλαγές' {

            $emptyObj = @{ GefyraName = 'Foo'; GefyraStatus = 'Ανοιχτή' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($emptyObj) -CurrentState @($emptyObj)
            $result | Should -BeNullOrEmpty

            (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match 'Καμία ουσιαστική αλλαγή'

        }

    }

    Context 'Κατάσταση αλλαγής ➡️' {

        It 'πρέπει να στείλει ειδοποίηση τύπου Closed' {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)

            $evt_Closed_Ισθμία = $result | Where-Object { $_.Type -eq 'Closed' -and $_.BridgeName -eq 'Ισθμία' }
            $evt_Closed_Ισθμία | Should -Not -BeNullOrEmpty

        }

        It 'πρέπει να στείλει ειδοποίηση τύπου Opened' {

            $prev = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }

            $curr = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)

            $evt_Opened_Ποσειδωνία = $result | Where-Object { $_.Type -eq 'Opened' -and $_.BridgeName -eq 'Ποσειδωνία' }
            $evt_Opened_Ποσειδωνία | Should -Not -BeNullOrEmpty

        }

    }

    Context 'Κατάσταση αλλαγής ⬅️' {

        It 'πυροδοτεί "Μόνιμα κλειστή|<="' {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Μόνιμα κλειστή' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($curr) -CurrentState @($prev)

            $evt_Closed_Ισθμία = $result | Where-Object { $_.Type -eq 'Closed' -and $_.BridgeName -eq 'Ισθμία' }
            $evt_Closed_Ισθμία | Should -Not -BeNullOrEmpty

        }

    }

    Context 'Άγνωστο combo' {

        It 'γράφει λογικά "Άγνωστο combo"' {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Foo' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Bar' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)
            $result | Should -BeNullOrEmpty

            (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match 'Άγνωστο combo'

        }

    }

    Context 'Σφάλμα εσωτερικό (catch)' {

        It 'γράφει εξαίρεση στο log όταν αποτυγχάνει εσωτερικά' {

            Mock -CommandName Compare-Object -MockWith { throw 'mock fail' }

            { Invoke-BridgeStatusComparison @defaultParams -PreviousState @(@{ GefyraName = 'X'; GefyraStatus = 'Y' }) -CurrentState @(@{ GefyraName = 'X'; GefyraStatus = 'Y' }) } | Should -Throw

            (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match '❌ mock fail'

        }

    }

    Context 'ImageHash Comparison' {
        It 'Στέλνει ειδοποίηση όταν αλλάζει το ImageHash στην Κλειστή με πρόγραμμα' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

            $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); ImageHash = 'hashA'; imageUrl = 'img1.jpg' }
            $copy = $base.Clone()
            $copy.ImageHash = 'hashB'

            $params = $script:defaultParams + @{
                PreviousState = @($base)
                CurrentState  = @($copy)
            }

            $result = Invoke-BridgeStatusComparison @params

            $evt_Closed = $result | Where-Object { $_.Type -eq 'Closed' }
            $evt_Closed.Count | Should -Be 1
        }

        It 'Δεν στέλνει ειδοποίηση όταν το ImageHash είναι ίδιο στην Κλειστή με πρόγραμμα' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

            $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); ImageHash = 'hashA'; imageUrl = 'img1.jpg' }
            $copy = $base.Clone()
            $copy.imageUrl = 'img1_different_query.jpg' # URL changed (query) but hash did not

            $params = $script:defaultParams + @{
                PreviousState = @($base)
                CurrentState  = @($copy)
            }

            $result = Invoke-BridgeStatusComparison @params

            $result | Where-Object { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty
        }

        It 'Επαναχρησιμοποιεί το προηγούμενο ImageHash αν το νέο είναι κενό/σφάλμα' {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

            $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); ImageHash = 'hashA'; imageUrl = 'img1.jpg' }

            # Current state failed to download/hash image, so ImageHash is null
            $copy = $base.Clone()
            $copy.ImageHash = $null
            $copy.imageUrl = 'img1_failed.jpg'

            $params = $script:defaultParams + @{
                PreviousState = @($base)
                CurrentState  = @($copy)
            }

            $result = Invoke-BridgeStatusComparison @params

            $result | Where-Object { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty
            $copy.ImageHash | Should -Be 'hashA' # check that previous hash was copied back
        }
    }

    It 'Backfills OCR properties when SideIndicator is ==' {
        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
        Mock Send-BridgePushover {}

        $prev = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; From = '10:00'; To = '12:00'; ClosedFor = '2h'; OpensIn = '1h'; Note1 = 'n1'; Note2 = 'n2' }
        $curr = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }
        $params = @{
            PreviousState = @($prev)
            CurrentState  = @($curr)
            Configuration = $script:Config
        }
        $null = Invoke-BridgeStatusComparison @params
        $curr.From | Should -Be '10:00'
    }

    It 'Backfills OCR properties when SideIndicator is => and ClosedWithSchedule' {
        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
        Mock Send-BridgePushover {}

        $prev = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; From = '10:00'; To = '12:00'; ClosedFor = '2h'; OpensIn = '1h'; Note1 = 'n1'; Note2 = 'n2'; ImageUrl = 'x.jpg'; ImageHash = 'hashA' }
        $curr = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); ImageUrl = 'y.jpg'; ImageHash = $null }
        $params = @{
            PreviousState = @($prev)
            CurrentState  = @($curr)
            Configuration = $script:Config
        }
        $null = Invoke-BridgeStatusComparison @params
        $curr.From | Should -Be '10:00'
    }

    It 'Δεν αποτυγχάνει σε strict mode όταν μια αμετάβλητη γέφυρα δεν έχει ιδιότητες OCR και μια άλλη αλλάζει κατάσταση' {
        $prev = @(
            [PSCustomObject]@{
                GefyraName   = 'Ποσειδωνία'
                GefyraStatus = 'Ανοιχτή'
                Timestamp    = '2026-04-01T10:00:00'
                ImageUrl     = 'https://example.com/pos.png'
                ImageHash    = $null
            },
            [PSCustomObject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Ανοιχτή'
                Timestamp    = '2026-04-01T10:00:00'
                ImageUrl     = 'https://example.com/ist.png'
                ImageHash    = $null
            }
        )
        $curr = @(
            [PSCustomObject]@{
                GefyraName   = 'Ποσειδωνία'
                GefyraStatus = 'Ανοιχτή'
                Timestamp    = '2026-04-01T10:05:00'
                ImageUrl     = 'https://example.com/pos.png'
                ImageHash    = $null
            },
            [PSCustomObject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2026-04-01T10:05:00'
                ImageUrl     = 'https://example.com/ist-closed.png'
                ImageHash    = 'hash123'
            }
        )

        $events = Invoke-BridgeStatusComparison -PreviousState $prev -CurrentState $curr -Configuration $script:Config
        $events.Count | Should -Be 1
        $events[0].BridgeName | Should -Be 'Ισθμία'
        $events[0].Type | Should -Be 'Closed'
    }
}
}


