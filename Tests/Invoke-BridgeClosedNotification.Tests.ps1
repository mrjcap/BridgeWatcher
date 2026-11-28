Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

InModuleScope -ModuleName BridgeWatcher -ScriptBlock {
Describe -Name 'Invoke-BridgeClosedNotification' -Fixture {

    BeforeAll -Scriptblock {
        $script:Config = New-BridgeConfiguration
    }



    Context -Name 'Όταν η γέφυρα είναι κλειστή' -Fixture {

        It -Name 'Καλεί OCR και στέλνει Pushover' -Test {

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

        It -Name 'Στέλνει debug log και Pushover notification χωρίς OCR' -Test {

            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Κλειστή για συντήρηση'

                timestamp    = (Get-Date)

                imageUrl     = 'https://example.com/image.jpg'

            }

            Mock -CommandName Send-BridgePushover -MockWith { }

            Mock -CommandName Write-BridgeLog -MockWith { }

            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith { throw 'Δεν πρέπει να κληθεί OCR!' }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose -Debug

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly

            Should -Invoke -CommandName Write-BridgeLog -Times 1 -Exactly -ParameterFilter { $Message -like '*κλειστή για συντήρηση*' }

            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 0 -Exactly

        }

        It -Name 'Γράφει debug για μόνιμα κλειστή γέφυρα' -Test {

            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Μόνιμα κλειστή'

            }

            Mock -CommandName Send-BridgePushover

            Mock -CommandName Write-Debug

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose

            Should -Invoke -CommandName Write-Debug -Times 1 -Exactly -Scope It

        }

        It -Name 'Propagates delivery failures without sending an OCR-failure fallback' -Test {
            Mock -CommandName Write-BridgeLog -MockWith { }
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
                [pscustomobject]@{
                    ScheduleState = 'Future'
                    From          = '25/12/2099 10:00'
                    To            = '25/12/2099 11:00'
                    ClosedFor     = '1 ώρα'
                }
            }
            $attempts = [System.Collections.Generic.List[string]]::new()
            Mock -CommandName Send-BridgePushover -MockWith {
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

            { Invoke-BridgeClosedNotification @parameters } | Should -Throw -ExpectedMessage '*Notification transport failed*'
            $attempts.Count | Should -Be -ExpectedValue 1
            $attempts[0] | Should -Match -RegularExpression 'θα κλείσει'
            $entry.ScheduleState | Should -Be -ExpectedValue 'Future'
            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 1 -Exactly
        }

        It -Name 'Γράφει warning όταν αποτυγχάνει η OCR' -Test {

            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith { throw 'Fake OCR failure' }
            Mock -CommandName Send-BridgePushover -MockWith { }

            $entry = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = Get-Date; imageUrl = 'https://example.com/x.jpg'; ImageHash = 'first' }

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose } | Should -Not -Throw

            $entry.ImageHash | Should -BeNullOrEmpty
            $entry.FallbackNotifiedImageHash | Should -Be -ExpectedValue 'first'
            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly
        }

        It -Name 'Keeps an empty OCR result retryable and sends only one fallback for the same image' -Test {
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith { $null }
            Mock -CommandName Send-BridgePushover -MockWith {}
            $entry = @{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                ImageUrl     = 'https://example.com/schedule.jpg'
                ImageHash    = 'unchanged'
            }
            $fixtureKey = 'dummy-key'
            $call = @{
                Configuration = $script:Config
                CurrentState  = @($entry)
                ApiKey        = $fixtureKey
                PoUserKey     = $fixtureKey
                PoApiKey      = $fixtureKey
            }

            Invoke-BridgeClosedNotification @call
            $entry.ImageHash | Should -BeNullOrEmpty
            $entry.FallbackNotifiedImageHash | Should -BeExactly -ExpectedValue 'unchanged'

            $entry.ImageHash = 'unchanged'
            Invoke-BridgeClosedNotification @call
            Should -Invoke -CommandName Invoke-BridgeOCRGoogleCloud -Times 2 -Exactly
            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly
        }

        It -Name 'Στέλνει fallback ειδοποίηση όταν το OCR επιστρέφει $null' -Test {

            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith { $null }
            Mock -CommandName Send-BridgePushover -MockWith { }

            $entry = @{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; timestamp = Get-Date; imageUrl = 'https://example.com/x.jpg' }

            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose } | Should -Not -Throw

            Should -Invoke -CommandName Send-BridgePushover -Times 1 -Exactly
        }


        It -Name 'Γράφει debug και δεν καλεί Send-BridgePushover για άγνωστη κατάσταση' -Test {


            $entry = [pscustomobject]@{

                GefyraName   = 'Ισθμία'

                GefyraStatus = 'Μπερδεμένη'

                timestamp    = (Get-Date)

                imageUrl     = 'https://example.com/image.jpg'

            }

            Mock -CommandName Send-BridgePushover -MockWith { throw 'Δεν έπρεπε να εκτελεστεί!' }


            { Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'x' -PoApiKey 'x' -Verbose -Debug } | Should -Not -Throw

        }

        It -Name 'Αγνοεί κενές εγγραφές (null) στο CurrentState χωρίς σφάλμα' -Test {
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

    It -Name 'Χρησιμοποιεί NotificationProvider αντί Pushover όταν παρέχεται' -Test {

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

            Mock -CommandName Send-BridgePushover -MockWith { throw 'Δεν έπρεπε να κληθεί Pushover!' }
            Mock -CommandName Write-BridgeLog -MockWith { }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -NotificationProvider $provider

            $script:providerCalled | Should -BeTrue
            $script:providerTitle | Should -BeLike -ExpectedValue '*κλειστή για συντήρηση*'
        }

        It -Name 'Ξεχωρίζει μελλοντικό πρόγραμμα κλεισίματος χωρίς να δηλώνει ότι η γέφυρα έκλεισε ήδη' -Test {
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
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
            Mock -CommandName Write-BridgeLog -MockWith { }

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

            $script:futureTitle | Should -Match -RegularExpression 'θα κλείσει'
            $script:futureTitle | Should -Not -Match -RegularExpression 'έκλεισε$'
            $script:futureMessage | Should -Match -RegularExpression 'Η γέφυρα θα κλείσει στις 10:00'
            $script:futureMessage | Should -Not -Match -RegularExpression 'Ανοίγει σε:'
        }

        It -Name 'Συμπεριλαμβάνει το Note2 και το Ανοίγει σε για ενεργό κλείσιμο' -Test {
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
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
            Mock -CommandName Write-BridgeLog -MockWith { }

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

            $script:activeTitle | Should -Be -ExpectedValue '🚧 Η γέφυρα Ισθμία έκλεισε'
            $script:activeMessage | Should -Match -RegularExpression 'Ανοίγει σε: 45 λεπτά'
            $script:activeMessage | Should -Match -RegularExpression 'Σημείωση: Είναι προτιμότερο να μην περιμένεις'
            $script:activeMessage | Should -Match -RegularExpression 'Η γέφυρα είναι ήδη κλειστή από τις 10:00\.'
        }

        It -Name 'Ξεχωρίζει ληγμένο πρόγραμμα κλεισίματος χωρίς να δηλώνει ότι η γέφυρα έκλεισε' -Test {
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
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
            Mock -CommandName Write-BridgeLog -MockWith { }

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

            $script:expiredTitle | Should -Match -RegularExpression 'ολοκληρώθηκε'
            $script:expiredTitle | Should -Not -Match -RegularExpression 'έκλεισε$'
            $script:expiredMessage | Should -Match -RegularExpression 'Η γέφυρα είναι ανοιχτή\.'
        }

        It -Name 'Εμπλουτίζει επιτόπου εγγραφή PSCustomObject με όλα τα πεδία OCR' -Test {
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
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
            Mock -CommandName Send-BridgePushover -MockWith { }
            Mock -CommandName Write-BridgeLog -MockWith { }

            $entry = [pscustomobject]@{
                GefyraName   = 'Ισθμία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T10:15:00'
                ImageUrl     = 'https://example.com/active.jpg'
            }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'u' -PoApiKey 'p'

            $entry.ScheduleState | Should -Be -ExpectedValue 'Active'
            $entry.From | Should -Be -ExpectedValue '25/04/2025 10:00'
            $entry.To | Should -Be -ExpectedValue '25/04/2025 11:00'
            $entry.ClosedFor | Should -Be -ExpectedValue '1 ώρα'
            $entry.OpensIn | Should -Be -ExpectedValue '45 λεπτά'
            $entry.Note1 | Should -Be -ExpectedValue 'Σημείωση 1'
            $entry.Note2 | Should -Be -ExpectedValue 'Σημείωση 2'
        }

        It -Name 'Εμπλουτίζει επιτόπου εγγραφή hashtable με όλα τα πεδία OCR' -Test {
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith {
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
            Mock -CommandName Send-BridgePushover -MockWith { }
            Mock -CommandName Write-BridgeLog -MockWith { }

            $entry = @{
                GefyraName   = 'Ποσειδωνία'
                GefyraStatus = 'Κλειστή με πρόγραμμα'
                Timestamp    = '2025-04-25T11:30:00'
                ImageUrl     = 'https://example.com/future.jpg'
            }

            Invoke-BridgeClosedNotification -Configuration $script:Config -CurrentState @($entry) -ApiKey 'x' -PoUserKey 'u' -PoApiKey 'p'

            $entry['ScheduleState'] | Should -Be -ExpectedValue 'Future'
            $entry['From'] | Should -Be -ExpectedValue '25/04/2025 12:00'
            $entry['To'] | Should -Be -ExpectedValue '25/04/2025 13:00'
            $entry['ClosedFor'] | Should -Be -ExpectedValue '1 ώρα'
            $entry['OpensIn'] | Should -Be -ExpectedValue ''
            $entry['Note1'] | Should -Be -ExpectedValue ''
            $entry['Note2'] | Should -Be -ExpectedValue 'Η γέφυρα θα κλείσει στις 12:00 για 1 ώρα.'
        }

        It -Name 'Δεν τροποποιεί την εγγραφή όταν το OCR επιστρέφει $null' -Test {
            Mock -CommandName Invoke-BridgeOCRGoogleCloud -MockWith { return $null }
            Mock -CommandName Send-BridgePushover -MockWith { }
            Mock -CommandName Write-BridgeLog -MockWith { }

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

