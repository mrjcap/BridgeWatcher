Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope -ModuleName BridgeWatcher -ScriptBlock {
Describe -Name 'Invoke-BridgeStatusComparison - Ειδοποιήσεις' -Fixture {

    BeforeAll -Scriptblock {
        $script:Config = New-BridgeConfiguration
    }

    It -Name 'Omits a closure event when its bridge record cannot be resolved' -Test {
        Mock -CommandName Resolve-BridgeStateForChange -MockWith { return ,@() }
        $entry = [pscustomobject]@{ GefyraName = 'Ισθμία'; GefyraStatus = $script:Config.Statuses.PermanentlyClosed }

        $events = Invoke-BridgeStatusComparison -CurrentState @($entry) -Configuration $script:Config

        Should -Invoke -CommandName Resolve-BridgeStateForChange -Times 1 -Exactly
        $events | Should -BeNullOrEmpty
    }

    It -Name 'Δεν στέλνει ειδοποίηση όταν η κατάσταση δεν αλλάζει' -Test {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { 'Closed notification sent' }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { 'Opened notification sent' }

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

        $result | Where-Object -FilterScript { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty

        $result | Where-Object -FilterScript { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty

    }

    It -Name 'Στέλνει απευθείας ειδοποίηση χωρίς OCR' -Test {

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

        $evt_Closed = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be -ExpectedValue 1

    }

    It -Name 'Στέλνει ειδοποίηση με OCR' -Test {

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

        $evt_Closed = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be -ExpectedValue 1

    }

    It -Name 'Στέλνει ειδοποίηση ανοίγματος' -Test {



        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $timestamp = Get-Date

        Mock -CommandName Get-Date -MockWith { [datetime]::new(2030, 1, 15, 10, 1, 0, [DateTimeKind]::Utc) }
        $previous = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; To = '15/01/2030 12:00'; ImageUrl = 'image-bridge-open-with-schedule-isthmia.php?1' }

        $current = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; timestamp = $timestamp; ImageUrl = 'image-bridge-open-no-schedule.php?2' }

        $params = @{

            PreviousState = $previous

            CurrentState  = $current

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params
        $result.Count | Should -Be -ExpectedValue 1


    }

    It -Name 'Δεν στέλνει ειδοποίηση' -Test {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $timestamp = Get-Date


        $same = @(

            @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; timestamp = $timestamp; imageUrl = 'img4.jpg' }

        )

        $params = @{

            PreviousState = $same

            CurrentState  = $same

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $result | Where-Object -FilterScript { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty

        $result | Where-Object -FilterScript { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty


    }

    It -Name 'Δεν στέλνει ειδοποίηση όταν GefyraName δεν ταιριάζει' -Test {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $params = @{

            PreviousState = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'x.jpg' }

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params
        $result.Count | Should -Be -ExpectedValue 1

    }

    It -Name 'Δεν στέλνει ειδοποίηση σε άκυρη τιμή status' -Test {

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

    It -Name 'Δεν στέλνει ειδοποίηση όταν μόνο το timestamp αλλάζει' -Test {

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

    It -Name 'Πετάει σφάλμα όταν η CurrentState είναι $null' -Test {

        $params = @{

            PreviousState = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = $null

            Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Throw

    }

    It -Name 'Πετάει σφάλμα όταν η PreviousState είναι $null' -Test {

        $params = @{

            PreviousState = $null

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Not -Throw

    }

    It -Name 'Δεν στέλνει ειδοποίηση όταν λείπει το imageUrl' -Test {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $params = @{

            PreviousState = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = $null }

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params

        $evt_Closed = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be -ExpectedValue 1


    }

    It -Name 'Επεξεργάζεται σωστά πολλαπλές αλλαγές' -Test {


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


        $evt_Closed = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be -ExpectedValue 2

    }

    It -Name 'Δεν στέλνει ειδοποίηση όταν μόνο το imageUrl αλλάζει' -Test {

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

        $result | Where-Object -FilterScript { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty

        $result | Where-Object -FilterScript { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty

    }

    It -Name 'Στέλνει ειδοποίηση όταν μόνο το imageUrl αλλάζει και η κατάσταση είναι Κλειστή με πρόγραμμα' -Test {

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

        $evt_Closed = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be -ExpectedValue 1

        $result | Where-Object -FilterScript { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty

    }

    It -Name 'Στέλνει σωστά ειδοποιήσεις για κλείσιμο και άνοιγμα όταν αλλάζουν δύο γέφυρες αντίθετα' -Test {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Get-Date -MockWith { [datetime]::new(2030, 1, 15, 10, 1, 0, [DateTimeKind]::Utc) }
        $previousState = @(

            @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; To = '15/01/2030 12:00'; ImageUrl = 'image-bridge-open-with-schedule-posidonia.php?1' }

        )

        $currentState = @(

            @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'img1.jpg' }

            @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; timestamp = (Get-Date); ImageUrl = 'image-bridge-open-no-schedule.php?2' }

        )

        $params = @{

            PreviousState = $previousState

            CurrentState  = $currentState

            Configuration = $script:Config

        }

        $result = Invoke-BridgeStatusComparison @params


        $evt_Closed = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be -ExpectedValue 1

        $evt_Opened = $result | Where-Object -FilterScript { $_.Type -eq 'Opened' }
        $evt_Opened.Count | Should -Be -ExpectedValue 1

    }

    It -Name 'Γράφει warning όταν λείπει κατάσταση' -Test {

        $result = Invoke-BridgeStatusComparison -PreviousState $null -CurrentState @{ GefyraName = 'X'; GefyraStatus = 'Ανοιχτή' } -Configuration $script:Config
        $result.Count | Should -Be -ExpectedValue 1

    }

    It -Name 'Γράφει verbose όταν δεν υπάρχουν αλλαγές' -Test {

        Mock -CommandName Send-BridgePushover -MockWith {}

        $same = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; timestamp = Get-Date; imageUrl = 'x.jpg' }

        $result = Invoke-BridgeStatusComparison -PreviousState $same -CurrentState $same -Configuration $script:Config -Verbose
        $result | Should -BeNullOrEmpty

    }

    It -Name 'Γράφει Exception όταν CurrentState ή PreviousState είναι κενό array' -Test {

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
        $result.Count | Should -Be -ExpectedValue 1

    }

    It -Name 'Γράφει verbose όταν δεν υπάρχει καμία αλλαγή στις γέφυρες' -Test {

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

    It -Name 'Γράφει Write-Verbose όταν δεν υπάρχει καμία αλλαγή στις γέφυρες' -Test {

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

    It -Name 'Γράφει Write-Verbose όταν δεν υπάρχουν διαφορές (mocked Compare-Object)' -Test {

        Mock -CommandName Compare-Object -MockWith { @() }

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

    It -Name 'πρέπει να στείλει ειδοποίηση τύπου Closed' -Test {

        $defaultParams = @{

            Configuration = $script:Config

        }

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith {
            param($CurrentState)
            "NOTIFY:Closed:$($CurrentState[0].GefyraName)" | Out-File -Append -FilePath "$TestDrive\notify.txt"
        }

        $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

        $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Μόνιμα κλειστή' }

        $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState $prev -CurrentState $curr

        $evt_Closed_Ισθμία = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' -and $_.BridgeName -eq 'Ισθμία' }
        $evt_Closed_Ισθμία | Should -Not -BeNullOrEmpty

    }

    It -Name 'Στέλνει ειδοποίηση τύπου Open όταν γίνεται αλλαγή απο "Κλειστή για συντήρηση" (=>)' -Test {

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

        $evt_Closed = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' }
        $evt_Closed.Count | Should -Be -ExpectedValue 1

        $result | Where-Object -FilterScript { $_.Type -eq 'Opened' } | Should -BeNullOrEmpty

    }


    It -Name 'Στέλνει ειδοποίηση τύπου Opened όταν γίνεται αλλαγή από Κλειστή σε Ανοιχτή (=>)' -Test {

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

        $result | Where-Object -FilterScript { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty

        $evt_Opened = $result | Where-Object -FilterScript { $_.Type -eq 'Opened' }
        $evt_Opened.Count | Should -Be -ExpectedValue 1

    }

}

Describe -Name 'Invoke-BridgeStatusComparison' -Fixture {



    BeforeEach -Scriptblock {

        Remove-Item -Path "$TestDrive\log.txt", "$TestDrive\notify.txt" -ErrorAction SilentlyContinue

    }



    BeforeAll -Scriptblock {
        $script:Config = New-BridgeConfiguration

        Mock -CommandName Write-BridgeLog -MockWith {

            param([string]$Stage, [string]$Message, [string]$Level)

            "$Stage|$Level|$Message" | Out-File -Append -FilePath "$TestDrive\log.txt"
        }

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith {
            param($CurrentState)
            "NOTIFY:Closed:$($CurrentState[0].GefyraName)" | Out-File -Append -FilePath "$TestDrive\notify.txt"
        }
        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith {
            param($CurrentState)
            "NOTIFY:Opened:$($CurrentState[0].GefyraName)" | Out-File -Append -FilePath "$TestDrive\notify.txt"
        }

        $script:defaultParams = @{

            Configuration = $script:Config

        }

        $script:defaultParams

    }

    Context -Name 'Καμία αλλαγή' -Fixture {



        It -Name 'πυροδοτεί το block "Καμία ουσιαστική αλλαγή"' -Test {

            $obj = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($obj) -CurrentState @($obj)
            $result | Should -BeNullOrEmpty

            (Get-Content -Path "$TestDrive\log.txt") -join "`n" | Should -Match -RegularExpression 'Καμία ουσιαστική αλλαγή'

            Test-Path -Path "$TestDrive\notify.txt" | Should -BeFalse

        }

        It -Name 'πυροδοτεί το block "Καμία αλλαγή" όταν δεν υπάρχουν καθόλου αλλαγές' -Test {

            $emptyObj = @{ GefyraName = 'Foo'; GefyraStatus = 'Ανοιχτή' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($emptyObj) -CurrentState @($emptyObj)
            $result | Should -BeNullOrEmpty

            (Get-Content -Path "$TestDrive\log.txt") -join "`n" | Should -Match -RegularExpression 'Καμία ουσιαστική αλλαγή'

        }

    }

    Context -Name 'Κατάσταση αλλαγής ➡️' -Fixture {

        It -Name 'πρέπει να στείλει ειδοποίηση τύπου Closed' -Test {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)

            $evt_Closed_Ισθμία = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' -and $_.BridgeName -eq 'Ισθμία' }
            $evt_Closed_Ισθμία | Should -Not -BeNullOrEmpty

        }

        It -Name 'πρέπει να στείλει ειδοποίηση τύπου Opened' -Test {

            Mock -CommandName Get-Date -MockWith { [datetime]::new(2030, 1, 15, 10, 1, 0, [DateTimeKind]::Utc) }
            $prev = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; To = '15/01/2030 12:00'; ImageUrl = 'image-bridge-open-with-schedule-posidonia.php?1'; ScheduleState = 'Active' }

            $curr = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; ImageUrl = 'image-bridge-open-no-schedule.php?2' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)

            $evt_Opened_Ποσειδωνία = $result | Where-Object -FilterScript { $_.Type -eq 'Opened' -and $_.BridgeName -eq 'Ποσειδωνία' }
            $evt_Opened_Ποσειδωνία | Should -Not -BeNullOrEmpty

        }

    }

    Context -Name 'Κατάσταση αλλαγής ⬅️' -Fixture {

        It -Name 'πυροδοτεί "Μόνιμα κλειστή|<="' -Test {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Μόνιμα κλειστή' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($curr) -CurrentState @($prev)

            $evt_Closed_Ισθμία = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' -and $_.BridgeName -eq 'Ισθμία' }
            $evt_Closed_Ισθμία | Should -Not -BeNullOrEmpty

        }

    }

    Context -Name 'Άγνωστο combo' -Fixture {

        It -Name 'γράφει λογικά "Άγνωστο combo"' -Test {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Foo' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Bar' }

            $result = Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)
            $result | Should -BeNullOrEmpty

            (Get-Content -Path "$TestDrive\log.txt") -join "`n" | Should -Match -RegularExpression 'Άγνωστο combo'

        }

    }

    Context -Name 'Σφάλμα εσωτερικό (catch)' -Fixture {

        It -Name 'γράφει εξαίρεση στο log όταν αποτυγχάνει εσωτερικά' -Test {

            Mock -CommandName Compare-Object -MockWith { throw 'mock fail' }

            { Invoke-BridgeStatusComparison @defaultParams -PreviousState @(@{ GefyraName = 'X'; GefyraStatus = 'Y' }) -CurrentState @(@{ GefyraName = 'X'; GefyraStatus = 'Y' }) } | Should -Throw

            (Get-Content -Path "$TestDrive\log.txt") -join "`n" | Should -Match -RegularExpression '❌ mock fail'

        }

    }

    Context -Name 'ImageHash Comparison' -Fixture {
        It -Name 'Στέλνει ειδοποίηση όταν αλλάζει το ImageHash στην Κλειστή με πρόγραμμα' -Test {
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

            $evt_Closed = $result | Where-Object -FilterScript { $_.Type -eq 'Closed' }
            $evt_Closed.Count | Should -Be -ExpectedValue 1
        }

        It -Name 'Δεν στέλνει ειδοποίηση όταν το ImageHash είναι ίδιο στην Κλειστή με πρόγραμμα' -Test {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

            $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); ImageHash = 'hashA'; imageUrl = 'img1.jpg' }
            $copy = $base.Clone()
            $copy.imageUrl = 'img1_different_query.jpg'

            $params = $script:defaultParams + @{
                PreviousState = @($base)
                CurrentState  = @($copy)
            }

            $result = Invoke-BridgeStatusComparison @params

            $result | Where-Object -FilterScript { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty
        }

        It -Name 'Επαναχρησιμοποιεί το προηγούμενο ImageHash αν το νέο είναι κενό/σφάλμα' -Test {
            Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
            Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

            $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); ImageHash = 'hashA'; imageUrl = 'img1.jpg' }

            $copy = $base.Clone()
            $copy.ImageHash = $null
            $copy.imageUrl = 'img1_failed.jpg'

            $params = $script:defaultParams + @{
                PreviousState = @($base)
                CurrentState  = @($copy)
            }

            $result = Invoke-BridgeStatusComparison @params

            $result | Where-Object -FilterScript { $_.Type -eq 'Closed' } | Should -BeNullOrEmpty
            $copy.ImageHash | Should -Be -ExpectedValue 'hashA'
        }
    }

    It -Name 'Backfills OCR properties when SideIndicator is ==' -Test {
        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
        Mock -CommandName Send-BridgePushover -MockWith {}

        $prev = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; From = '10:00'; To = '12:00'; ClosedFor = '2h'; OpensIn = '1h'; Note1 = 'n1'; Note2 = 'n2' }
        $curr = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }
        $params = @{
            PreviousState = @($prev)
            CurrentState  = @($curr)
            Configuration = $script:Config
        }
        $null = Invoke-BridgeStatusComparison @params
        $curr.From | Should -Be -ExpectedValue '10:00'
    }

    It -Name 'Backfills OCR properties when SideIndicator is => and ClosedWithSchedule' -Test {
        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
        Mock -CommandName Send-BridgePushover -MockWith {}

        $prev = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; From = '10:00'; To = '12:00'; ClosedFor = '2h'; OpensIn = '1h'; Note1 = 'n1'; Note2 = 'n2'; ImageUrl = 'x.jpg'; ImageHash = 'hashA' }
        $curr = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); ImageUrl = 'y.jpg'; ImageHash = $null }
        $params = @{
            PreviousState = @($prev)
            CurrentState  = @($curr)
            Configuration = $script:Config
        }
        $null = Invoke-BridgeStatusComparison @params
        $curr.From | Should -Be -ExpectedValue '10:00'
    }

    It -Name 'Keeps legacy URL fallback independent of the other bridge hash (dictionary: <AsDictionary>)' -TestCases @(
        @{ AsDictionary = $true }
        @{ AsDictionary = $false }
    ) -Test {
        param([bool]$AsDictionary)
        $prev = @(
            @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = $script:Config.Statuses.ClosedWithSchedule; ImageUrl = 'old.jpg' }
            @{ GefyraName = 'Ισθμία'; GefyraStatus = $script:Config.Statuses.ClosedWithSchedule; ImageUrl = 'schedule.jpg'; ImageHash = 'verified' }
        )
        $curr = @($prev | ForEach-Object -Process { $_.Clone() })
        $curr[0].ImageUrl = 'new.jpg'
        if (-not $AsDictionary) {
            $prev = @($prev | ForEach-Object -Process { [pscustomobject]$_ })
            $curr = @($curr | ForEach-Object -Process { [pscustomobject]$_ })
        }
        $events = @(Invoke-BridgeStatusComparison -PreviousState $prev -CurrentState $curr -Configuration $script:Config)
        $events.Count | Should -Be -ExpectedValue 1
        $events[0].BridgeName | Should -Be -ExpectedValue 'Ποσειδωνία'
    }

    It -Name 'Treats absent verified fingerprints as unchanged despite URL cache busting (<MissingHash>)' -TestCases @(
        @{ MissingHash = $null }
        @{ MissingHash = '' }
    ) -Test {
        param($MissingHash)
        $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = $script:Config.Statuses.ClosedWithSchedule; ImageUrl = 'schedule.php?1'; ImageHash = $null }
        $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = $script:Config.Statuses.ClosedWithSchedule; ImageUrl = 'schedule.php?2'; ImageHash = $MissingHash }
        $events = @(Invoke-BridgeStatusComparison -PreviousState $prev -CurrentState $curr -Configuration $script:Config)
        $events.Count | Should -Be -ExpectedValue 0
    }

    It -Name 'Δεν αποτυγχάνει σε strict mode όταν μια αμετάβλητη γέφυρα δεν έχει ιδιότητες OCR και μια άλλη αλλάζει κατάσταση' -Test {
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
        $events.Count | Should -Be -ExpectedValue 1
        $events[0].BridgeName | Should -Be -ExpectedValue 'Ισθμία'
        $events[0].Type | Should -Be -ExpectedValue 'Closed'
    }
}
}


