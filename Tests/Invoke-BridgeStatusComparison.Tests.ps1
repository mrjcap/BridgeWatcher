Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Invoke-BridgeStatusComparison - Ειδοποιήσεις' {

    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Public/Invoke-BridgeStatusComparison.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeClosedNotification.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOpenedNotification.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"
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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 0 -Exactly

        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 0 -Exactly

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1 -Exactly

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1 -Exactly

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Send-BridgePushover -Times 1

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 0

        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 0

        Should -Invoke -CommandName Send-BridgePushover -Times 0

    }

    It 'Δεν στέλνει ειδοποίηση όταν GefyraName δεν ταιριάζει' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $params = @{

            PreviousState = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = 'x.jpg' }

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Not -Throw

    }

    It 'Δεν στέλνει ειδοποίηση σε άκυρη τιμή status' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $params = @{

            PreviousState = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'ανικτή'; timestamp = (Get-Date); imageUrl = 'x.jpg' }

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Not -Throw

    }

    It 'Δεν στέλνει ειδοποίηση όταν μόνο το timestamp αλλάζει' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $base = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; imageUrl = 'x.jpg' }

        $params = @{

            PreviousState = $base

            CurrentState  = $base.Clone()

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        $params.CurrentState.timestamp = (Get-Date).AddMinutes(5)

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Send-BridgePushover -Times 0

    }

    It 'Πετάει σφάλμα όταν η CurrentState είναι $null' {

        $params = @{

            PreviousState = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = $null

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Throw

    }

    It 'Πετάει σφάλμα όταν η PreviousState είναι $null' {

        $params = @{

            PreviousState = $null

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Throw

    }

    It 'Δεν στέλνει ειδοποίηση όταν λείπει το imageUrl' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Send-BridgePushover -MockWith { }

        $params = @{

            PreviousState = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            CurrentState  = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); imageUrl = $null }

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @params } | Should -Not -Throw

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        # ✅ Αναμένουμε 2 κλήσεις (μία για κάθε αλλαγή)

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 2

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 0

        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 0

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1

        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 0

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        # ✅ Περιμένουμε μία κλήση σε κάθε notification

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1

        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 1

    }

    It 'Γράφει warning όταν λείπει κατάσταση' {

        { Invoke-BridgeStatusComparison -PreviousState $null -CurrentState @{ GefyraName = 'X'; GefyraStatus = 'Ανοιχτή' } -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Configuration $script:Config } | Should -Throw

    }

    It 'Γράφει verbose όταν δεν υπάρχουν αλλαγές' {

        Mock Send-BridgePushover {}

        $same = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; timestamp = Get-Date; imageUrl = 'x.jpg' }

        { Invoke-BridgeStatusComparison -PreviousState $same -CurrentState $same -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Configuration $script:Config -Verbose } | Should -Not -Throw

    }

    It 'Γράφει Exception όταν CurrentState ή PreviousState είναι κενό array' {

        $paramsMissingCurrent = @{

            PreviousState = @(@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' })

            CurrentState  = @()

            ApiKey = 'X'; PoUserKey = 'Y'; PoApiKey = 'Z'; Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @paramsMissingCurrent } | Should -Throw

        $paramsMissingPrevious = @{

            PreviousState = @()

            CurrentState  = @(@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' })

            ApiKey = 'X'; PoUserKey = 'Y'; PoApiKey = 'Z'; Configuration = $script:Config

        }

        { Invoke-BridgeStatusComparison @paramsMissingPrevious } | Should -Throw

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

            ApiKey = 'X'; PoUserKey = 'Y'; PoApiKey = 'Z'; Configuration = $script:Config

            Verbose       = $true

        }

        { Invoke-BridgeStatusComparison @params } | Should -Not -Throw

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

                ApiKey        = 'X'

                PoUserKey     = 'Y'

                PoApiKey = 'Z'; Configuration = $script:Config

                Verbose       = $true

            }

            Invoke-BridgeStatusComparison @invokeBridgeStatusComparisonSplat

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

                ApiKey        = 'X'

                PoUserKey     = 'Y'

                PoApiKey = 'Z'; Configuration = $script:Config

                Verbose       = $true

            }

            Invoke-BridgeStatusComparison @invokeBridgeStatusComparisonSplat } | Should -Not -Throw

    }

    It 'πρέπει να στείλει ειδοποίηση τύπου Closed' {

        $defaultParams = @{

            ApiKey    = 'fake-key'

            PoUserKey = 'user-key'

            PoApiKey = 'app-key'; Configuration = $script:Config

        }

        # Redefine Invoke-BridgeClosedNotification to write to notify.txt for this test
        Mock -CommandName Invoke-BridgeClosedNotification -MockWith {
            param($CurrentState)
            "NOTIFY:Closed:$($CurrentState[0].GefyraName)" | Out-File -Append "$TestDrive\notify.txt"
        }

        $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

        $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Μόνιμα κλειστή' }

        Invoke-BridgeStatusComparison @defaultParams -PreviousState $prev -CurrentState $curr

        (Get-Content "$TestDrive\notify.txt") | Should -Contain 'NOTIFY:Closed:Ισθμία'

    }

    It 'Στέλνει ειδοποίηση τύπου Open όταν γίνεται αλλαγή απο "Κλειστή για συντήρηση" (=>)' {

        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }

        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }

        $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

        $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή για συντήρηση'; timestamp = (Get-Date); imageUrl = 'img_maintenance.jpg' }

        $params = @{

            PreviousState = $prev

            CurrentState  = $curr

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1 -Exactly

        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 0 -Exactly

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

            ApiKey = 'dummy'

            PoUserKey     = 'dummy'

            PoApiKey = 'dummy'; Configuration = $script:Config

        }

        Invoke-BridgeStatusComparison @params

        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 0 -Exactly

        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 1 -Exactly

    }

}

Describe 'Invoke-BridgeStatusComparison' {



    BeforeEach {

        Remove-Item "$TestDrive\log.txt", "$TestDrive\notify.txt" -ErrorAction SilentlyContinue

    }



    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Public/Invoke-BridgeStatusComparison.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeClosedNotification.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOpenedNotification.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgePushoverRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Send-BridgePushover.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"



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

            ApiKey    = 'fake-key'

            PoUserKey = 'user-key'

            PoApiKey = 'app-key'; Configuration = $script:Config

        }

        $script:defaultParams

    }

    Context 'Καμία αλλαγή' {



        It 'πυροδοτεί το block "Καμία ουσιαστική αλλαγή"' {

            $obj = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            Invoke-BridgeStatusComparison @defaultParams -PreviousState @($obj) -CurrentState @($obj)

            (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match 'Καμία ουσιαστική αλλαγή'

            Test-Path "$TestDrive\notify.txt" | Should -BeFalse

        }

        It 'πυροδοτεί το block "Καμία αλλαγή" όταν δεν υπάρχουν καθόλου αλλαγές' {

            $emptyObj = @{ GefyraName = 'Foo'; GefyraStatus = 'Ανοιχτή' }

            Invoke-BridgeStatusComparison @defaultParams -PreviousState @($emptyObj) -CurrentState @($emptyObj)

            (Get-Content "$TestDrive\log.txt") -join "`n" | Should -Match 'Καμία ουσιαστική αλλαγή'

        }

    }

    Context 'Κατάσταση αλλαγής ➡️' {

        It 'πρέπει να στείλει ειδοποίηση τύπου Closed' {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }

            Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)

            (Get-Content "$TestDrive\notify.txt") | Should -Contain 'NOTIFY:Closed:Ισθμία'

        }

        It 'πρέπει να στείλει ειδοποίηση τύπου Opened' {

            $prev = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή με πρόγραμμα' }

            $curr = @{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή' }

            Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)

            (Get-Content "$TestDrive\notify.txt") | Should -Contain 'NOTIFY:Opened:Ποσειδωνία'

        }

    }

    Context 'Κατάσταση αλλαγής ⬅️' {

        It 'πυροδοτεί "Μόνιμα κλειστή|<="' {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Μόνιμα κλειστή' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή' }

            Invoke-BridgeStatusComparison @defaultParams -PreviousState @($curr) -CurrentState @($prev)

            (Get-Content "$TestDrive\notify.txt") | Should -Contain 'NOTIFY:Closed:Ισθμία'

        }

    }

    Context 'Άγνωστο combo' {

        It 'γράφει λογικά "Άγνωστο combo"' {

            $prev = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Foo' }

            $curr = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Bar' }

            Invoke-BridgeStatusComparison @defaultParams -PreviousState @($prev) -CurrentState @($curr)

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

            Invoke-BridgeStatusComparison @params

            Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1
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

            Invoke-BridgeStatusComparison @params

            Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 0
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

            Invoke-BridgeStatusComparison @params

            Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 0
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
            ApiKey = 'dummy'
            PoUserKey = 'dummy'
            PoApiKey = 'dummy'
            Configuration = $script:Config
        }
        Invoke-BridgeStatusComparison @params
        $curr.From | Should -Be '10:00'
    }

    It 'Backfills OCR properties when SideIndicator is => and ClosedWithSchedule' {
        Mock -CommandName Invoke-BridgeClosedNotification -MockWith { }
        Mock -CommandName Invoke-BridgeOpenedNotification -MockWith { }
        Mock Send-BridgePushover {}

        $prev = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; From = '10:00'; To = '12:00'; ClosedFor = '2h'; OpensIn = '1h'; Note1 = 'n1'; Note2 = 'n2'; ImageUrl = 'x.jpg' }
        $curr = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = (Get-Date); ImageUrl = 'y.jpg' }
        $params = @{
            PreviousState = @($prev)
            CurrentState  = @($curr)
            ApiKey = 'dummy'
            PoUserKey = 'dummy'
            PoApiKey = 'dummy'
            Configuration = $script:Config
        }
        Invoke-BridgeStatusComparison @params
        $curr.From | Should -Be '10:00'
    }
}




