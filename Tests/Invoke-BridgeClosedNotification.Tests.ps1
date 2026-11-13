Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope BridgeWatcher {
Describe 'Invoke-BridgeClosedNotification' {

    BeforeAll {
        $script:Config = New-BridgeConfiguration
    }



    Context 'Όταν η γέφυρα είναι κλειστή' {

        It 'Καλεί OCR και στέλνει Pushover' {

            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
                return [pscustomobject]@{
                    From = '10:00'
                    To = '11:00'
                    ClosedFor = '1 ώρα'
                    OpensIn = '30 λεπτά'
                    Note1 = 'Test Note'
                }
            }

            Mock -CommandName Send-BridgePushover -MockWith { }

            $params = @{

                CurrentState = @(

                    @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; imageUrl = 'https://example.com/img.jpg'; timestamp = (Get-Date) }

                )

                ApiKey       = 'dummy'
                PoUserKey    = 'dummy'
                PoApiKey     = 'dummy'
                Configuration = $script:Config

            }

            Invoke-BridgeClosedNotification @params -Configuration $script:Config

            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 1 -Exactly

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly

        }

        It 'Στέλνει debug log και Pushover notification χωρίς OCR' {

            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Κλειστή για συντήρηση'

                timestamp    = (Get-Date)

                imageUrl     = 'https://example.com/image.jpg'

            }

            Mock Send-BridgePushover -MockWith { }

            Mock Write-BridgeLog -MockWith { }

            Mock Invoke-BridgeOCRGoogleCloud { throw 'Δεν πρέπει να κληθεί OCR!' }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose -Debug

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly

            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -ParameterFilter { $Message -like '*κλειστή για συντήρηση*' }

            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 0 -Exactly

        }

        It 'Γράφει debug για μόνιμα κλειστή γέφυρα' {

            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Μόνιμα κλειστή'

            }

            Mock -CommandName Send-BridgePushover

            Mock -CommandName Write-Debug

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose

            Should -Invoke -CommandName Write-Debug -Times 1 -Exactly -Scope It

        }

        It 'Propagates delivery failures without sending an OCR-failure fallback' {
            Mock Write-BridgeLog { }
            Mock Invoke-BridgeOCRGoogleCloud {
                [pscustomobject]@{
                    ScheduleState = 'Future'
                    From          = '25/12/2099 10:00'
                    To            = '25/12/2099 11:00'
                    ClosedFor     = '1 ώρα'
                }
            }
            $attempts = [System.Collections.Generic.List[string]]::new()
            Mock Send-BridgePushover {
                $attempts.Add($Title)
                if ($attempts.Count -eq 1) { throw 'Notification transport failed' }
            }
            $entry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = $script:Config.Statuses.ClosedWithSchedule
                ImageUrl     = 'https://example.com/schedule.png'
            }
            $parameters = @{
                Configuration = $script:Config
                CurrentState  = @($entry)
                ApiKey        = 'dummy'
                PoUserKey     = 'dummy'
                PoApiKey      = 'dummy'
            }

            { Invoke-BridgeClosedNotification @parameters } | Should -Throw '*Notification transport failed*'
            $attempts.Count | Should -Be 1
            $attempts[0] | Should -Match 'θα κλείσει'
            $entry.ScheduleState | Should -Be 'Future'
            Should -Invoke Invoke-BridgeOCRGoogleCloud -Times 1 -Exactly
        }

        It 'Γράφει warning όταν αποτυγχάνει η OCR' {

            Mock Invoke-BridgeOCRGoogleCloud { throw 'Fake OCR failure' }
            Mock Send-BridgePushover -MockWith { }

            $entry = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = Get-Date; imageUrl = 'https://example.com/x.jpg' }

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose } | Should -Not -Throw

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly
        }

        It 'Στέλνει fallback ειδοποίηση όταν το OCR επιστρέφει $null' {

            Mock Invoke-BridgeOCRGoogleCloud { $null }
            Mock Send-BridgePushover -MockWith { }

            $entry = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = Get-Date; imageUrl = 'https://example.com/x.jpg' }

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose } | Should -Not -Throw

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly
        }


        It 'Γράφει debug και δεν καλεί Send-BridgePushover για άγνωστη κατάσταση' {

            # Arrange

            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Μπερδεμένη'

                timestamp    = (Get-Date)

                imageUrl     = 'https://example.com/image.jpg'

            }

            Mock Send-BridgePushover { throw 'Δεν έπρεπε να εκτελεστεί!' }

            # Act

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose -Debug } | Should -Not -Throw

        }

        It 'Αγνοεί κενές εγγραφές (null) στο CurrentState χωρίς σφάλμα' {
        $state = @( $null, [PSCustomObject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = $script:Config.Statuses.ClosedForMaintenance
                timestamp    = '2023-10-27 10:00'
                imageUrl     = 'https://example.com/nulltest.jpg'
            } )

        $providerMock = {
            param($Title, $Message, $Type)
            $script:ProviderCalled = $true
            $script:ProviderArgs = @{ Title = $Title; Message = $Message; Type = $Type }
        }

        Invoke-BridgeClosedNotification -CurrentState $state -ApiKey 'fakekey' -Configuration $script:Config -NotificationProvider $providerMock

        $script:ProviderCalled | Should -BeTrue
    }

    It 'Χρησιμοποιεί NotificationProvider αντί Pushover όταν παρέχεται' {

            $script:providerCalled = $false
            $script:providerTitle = ''
            $script:providerMessage = ''

            $provider = {
                param([string]$Title, [string]$Message, [string]$Type)
                $null = $Type
                $script:providerCalled = $true
                $script:providerTitle = $Title
                $script:providerMessage = $Message
            }

            $entry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή για συντήρηση'
                timestamp    = (Get-Date)
                imageUrl     = 'https://example.com/image.jpg'
            }

            Mock Send-BridgePushover { throw 'Δεν έπρεπε να κληθεί Pushover!' }
            Mock Write-BridgeLog { }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -NotificationProvider $provider

            $script:providerCalled | Should -BeTrue
            $script:providerTitle | Should -BeLike '*κλειστή για συντήρηση*'
        }

        It 'Ξεχωρίζει μελλοντικό πρόγραμμα κλεισίματος χωρίς να δηλώνει ότι η γέφυρα έκλεισε ήδη' {
            Mock Invoke-BridgeOCRGoogleCloud {
                return [pscustomobject]@{
                    ScheduleState = 'Future'
                    From          = '25/04/2025 10:00'
                    To            = '25/04/2025 11:00'
                    ClosedFor     = '1 ώρα'
                    OpensIn       = ''
                    Note1         = ''
                    Note2         = 'Η γέφυρα θα κλείσει στις 10:00 για 1 ώρα.'
                }
            }
            Mock Write-BridgeLog { }

            $script:futureTitle = ''
            $script:futureMessage = ''
            $provider = {
                param([string]$Title, [string]$Message, [string]$Type)
                $null = $Type
                $script:futureTitle = $Title
                $script:futureMessage = $Message
            }

            $entry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T09:00:00'
                ImageUrl     = 'https://example.com/future.jpg'
            }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -NotificationProvider $provider

            $script:futureTitle | Should -Match 'θα κλείσει'
            $script:futureTitle | Should -Not -Match 'έκλεισε$'
            $script:futureMessage | Should -Match 'Η γέφυρα θα κλείσει στις 10:00'
            $script:futureMessage | Should -Not -Match 'Ανοίγει σε:'
        }

        It 'Συμπεριλαμβάνει το Note2 και το Ανοίγει σε για ενεργό κλείσιμο' {
            Mock Invoke-BridgeOCRGoogleCloud {
                return [pscustomobject]@{
                    ScheduleState = 'Active'
                    From          = '25/04/2025 10:00'
                    To            = '25/04/2025 11:00'
                    ClosedFor     = '1 ώρα'
                    OpensIn       = '45 λεπτά'
                    Note1         = 'Είναι προτιμότερο να μην περιμένεις'
                    Note2         = 'Η γέφυρα είναι ήδη κλειστή από τις 10:00.'
                }
            }
            Mock Write-BridgeLog { }

            $script:activeTitle = ''
            $script:activeMessage = ''
            $provider = {
                param([string]$Title, [string]$Message, [string]$Type)
                $null = $Type
                $script:activeTitle = $Title
                $script:activeMessage = $Message
            }

            $entry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T10:15:00'
                ImageUrl     = 'https://example.com/active.jpg'
            }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -NotificationProvider $provider

            $script:activeTitle | Should -Be '🚧 Η γέφυρα Ισθμία έκλεισε'
            $script:activeMessage | Should -Match 'Ανοίγει σε: 45 λεπτά'
            $script:activeMessage | Should -Match 'Σημείωση: Είναι προτιμότερο να μην περιμένεις'
            $script:activeMessage | Should -Match 'Η γέφυρα είναι ήδη κλειστή από τις 10:00\.'
        }

        It 'Ξεχωρίζει ληγμένο πρόγραμμα κλεισίματος χωρίς να δηλώνει ότι η γέφυρα έκλεισε' {
            Mock Invoke-BridgeOCRGoogleCloud {
                return [pscustomobject]@{
                    ScheduleState = 'Expired'
                    From          = '25/04/2025 10:00'
                    To            = '25/04/2025 11:00'
                    ClosedFor     = 'Ολοκληρώθηκε'
                    OpensIn       = 'Τώρα'
                    Note1         = 'Η γέφυρα έχει ανοίξει ή το χρονικό διάστημα έχει παρέλθει.'
                    Note2         = 'Η γέφυρα είναι ανοιχτή.'
                }
            }
            Mock Write-BridgeLog { }

            $script:expiredTitle = ''
            $script:expiredMessage = ''
            $provider = {
                param([string]$Title, [string]$Message, [string]$Type)
                $null = $Type
                $script:expiredTitle = $Title
                $script:expiredMessage = $Message
            }

            $entry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T11:15:00'
                ImageUrl     = 'https://example.com/expired.jpg'
            }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -NotificationProvider $provider

            $script:expiredTitle | Should -Match 'ολοκληρώθηκε'
            $script:expiredTitle | Should -Not -Match 'έκλεισε$'
            $script:expiredMessage | Should -Match 'Η γέφυρα είναι ανοιχτή\.'
        }

        It 'Εμπλουτίζει επιτόπου εγγραφή PSCustomObject με όλα τα πεδία OCR' {
            Mock Invoke-BridgeOCRGoogleCloud {
                return [pscustomobject]@{
                    Bridge        = 'Ισθμία'
                    ScheduleState = 'Active'
                    From          = '25/04/2025 10:00'
                    To            = '25/04/2025 11:00'
                    ClosedFor     = '1 ώρα'
                    OpensIn       = '45 λεπτά'
                    Note1         = 'Σημείωση 1'
                    Note2         = 'Σημείωση 2'
                }
            }
            Mock Send-BridgePushover { }
            Mock Write-BridgeLog { }

            $entry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T10:15:00'
                ImageUrl     = 'https://example.com/active.jpg'
            }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'u' -PoApiKey 'p'

            $entry.ScheduleState | Should -Be 'Active'
            $entry.From | Should -Be '25/04/2025 10:00'
            $entry.To | Should -Be '25/04/2025 11:00'
            $entry.ClosedFor | Should -Be '1 ώρα'
            $entry.OpensIn | Should -Be '45 λεπτά'
            $entry.Note1 | Should -Be 'Σημείωση 1'
            $entry.Note2 | Should -Be 'Σημείωση 2'
        }

        It 'Εμπλουτίζει επιτόπου εγγραφή hashtable με όλα τα πεδία OCR' {
            Mock Invoke-BridgeOCRGoogleCloud {
                return [pscustomobject]@{
                    Bridge        = 'Ποσειδωνία'
                    ScheduleState = 'Future'
                    From          = '25/04/2025 12:00'
                    To            = '25/04/2025 13:00'
                    ClosedFor     = '1 ώρα'
                    OpensIn       = ''
                    Note1         = ''
                    Note2         = 'Η γέφυρα θα κλείσει στις 12:00 για 1 ώρα.'
                }
            }
            Mock Send-BridgePushover { }
            Mock Write-BridgeLog { }

            $entry = @{
                GefyraName   = 'Ποσειδωνία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T11:30:00'
                ImageUrl     = 'https://example.com/future.jpg'
            }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'u' -PoApiKey 'p'

            $entry['ScheduleState'] | Should -Be 'Future'
            $entry['From'] | Should -Be '25/04/2025 12:00'
            $entry['To'] | Should -Be '25/04/2025 13:00'
            $entry['ClosedFor'] | Should -Be '1 ώρα'
            $entry['OpensIn'] | Should -Be ''
            $entry['Note1'] | Should -Be ''
            $entry['Note2'] | Should -Be 'Η γέφυρα θα κλείσει στις 12:00 για 1 ώρα.'
        }

        It 'Δεν τροποποιεί την εγγραφή όταν το OCR επιστρέφει $null' {
            Mock Invoke-BridgeOCRGoogleCloud { return $null }
            Mock Send-BridgePushover { }
            Mock Write-BridgeLog { }

            $psEntry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T10:15:00'
                ImageUrl     = 'https://example.com/null.jpg'
            }
            $htEntry = @{
                GefyraName   = 'Ποσειδωνία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T10:15:00'
                ImageUrl     = 'https://example.com/null2.jpg'
            }

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($psEntry, $htEntry) -ApiKey 'x' -PoUserKey 'u' -PoApiKey 'p' } | Should -Not -Throw

            $psEntry.PSObject.Properties['ScheduleState'] | Should -BeNullOrEmpty
            $psEntry.PSObject.Properties['From'] | Should -BeNullOrEmpty
            $htEntry.ContainsKey('ScheduleState') | Should -BeFalse
            $htEntry.ContainsKey('From') | Should -BeFalse
        }

    }

}
}

