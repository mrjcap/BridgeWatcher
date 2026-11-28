Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe -Name 'Resolve-BridgeStateForChange' -Fixture {

    BeforeAll -Scriptblock {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"
        $script:Config = New-BridgeConfiguration

    }

    Context -Name 'Όταν SideIndicator είναι =>' -Fixture {

        It -Name 'Επιστρέφει state από CurrentState για νέα κατάσταση' -Test {


            $mockPreviousState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T10:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-01-01T10:00:00' }

            )

            $mockCurrentState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-01-01T11:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T11:00:00' }

            )

            $mockChange = [PSCustomObject]@{

                GefyraName    = 'Ισθμία'

                GefyraStatus  = 'Κλειστή με πρόγραμμα'

                SideIndicator = '=>'

            }



            $result = Resolve-BridgeStateForChange -Change $mockChange -PreviousState $mockPreviousState -CurrentState $mockCurrentState



            $result.Count | Should -Be -ExpectedValue 1

            $result[0].GefyraName | Should -Be -ExpectedValue 'Ισθμία'

            $result[0].GefyraStatus | Should -Be -ExpectedValue 'Κλειστή με πρόγραμμα'

            $result[0].Timestamp | Should -Be -ExpectedValue '2025-01-01T11:00:00'

        }



        It -Name 'Επιστρέφει κενό array όταν δεν βρίσκει την γέφυρα στο CurrentState' -Test {


            $mockPreviousState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T10:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-01-01T10:00:00' }

            )

            $mockCurrentState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-01-01T11:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T11:00:00' }

            )

            $mockChange = [PSCustomObject]@{

                GefyraName    = 'ΆγνωστηΓέφυρα'

                GefyraStatus  = 'Ανοιχτή'

                SideIndicator = '=>'

            }

            $resolveBridgeStateForChangeSplat = @{

                Change        = $mockChange

                PreviousState = $mockPreviousState

                CurrentState  = $mockCurrentState

            }



            $result = Resolve-BridgeStateForChange @resolveBridgeStateForChangeSplat


            @($result).Count | Should -Be -ExpectedValue 0

        }

    }



    Context -Name 'Όταν SideIndicator είναι <=' -Fixture {

        It -Name 'Επιστρέφει state από CurrentState πρώτα για παλιά κατάσταση' -Test {


            $mockPreviousState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T10:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-01-01T10:00:00' }

            )

            $mockCurrentState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-01-01T11:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T11:00:00' }

            )

            $mockChange = [PSCustomObject]@{

                GefyraName    = 'Ποσειδωνία'

                GefyraStatus  = 'Κλειστή για συντήρηση'

                SideIndicator = '<='

            }



            $result = Resolve-BridgeStateForChange -Change $mockChange -PreviousState $mockPreviousState -CurrentState $mockCurrentState



            $result.Count | Should -Be -ExpectedValue 1

            $result[0].GefyraName | Should -Be -ExpectedValue 'Ποσειδωνία'

            $result[0].GefyraStatus | Should -Be -ExpectedValue 'Ανοιχτή'

            $result[0].Timestamp | Should -Be -ExpectedValue '2025-01-01T11:00:00'

        }



        It -Name 'Επιστρέφει state από PreviousState όταν δεν υπάρχει στο CurrentState (fallback)' -Test {


            $mockPreviousState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T10:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-01-01T10:00:00' }

            )


            $mockCurrentStateWithoutBridge = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-01-01T11:00:00' }

            )



            $mockChange = [PSCustomObject]@{

                GefyraName    = 'Ποσειδωνία'

                GefyraStatus  = 'Κλειστή για συντήρηση'

                SideIndicator = '<='

            }



            $result = Resolve-BridgeStateForChange -Change $mockChange -PreviousState $mockPreviousState -CurrentState $mockCurrentStateWithoutBridge



            $result.Count | Should -Be -ExpectedValue 1

            $result[0].GefyraName | Should -Be -ExpectedValue 'Ποσειδωνία'

            $result[0].GefyraStatus | Should -Be -ExpectedValue 'Κλειστή για συντήρηση'

            $result[0].Timestamp | Should -Be -ExpectedValue '2025-01-01T10:00:00'

        }

    }



    Context -Name 'Edge Cases' -Fixture {

        It -Name 'Επιστρέφει πάντα array ακόμα και για single result' -Test {


            $mockPreviousState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T10:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-01-01T10:00:00' }

            )

            $mockCurrentState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-01-01T11:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T11:00:00' }

            )

            $mockChange = [PSCustomObject]@{

                GefyraName    = 'Ισθμία'

                GefyraStatus  = 'Κλειστή με πρόγραμμα'

                SideIndicator = '=>'

            }



            $resolveBridgeStateForChangeSplat = @{

                Change        = $mockChange

                PreviousState = $mockPreviousState

                CurrentState  = $mockCurrentState

            }

            $result = Resolve-BridgeStateForChange @resolveBridgeStateForChangeSplat




            @($result).Count | Should -Be -ExpectedValue 1

            $result.GefyraName | Should -Be -ExpectedValue 'Ισθμία'

        }



        It -Name 'Χειρίζεται case-insensitive σύγκριση ονομάτων' -Test {


            $mockPreviousState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T10:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-01-01T10:00:00' }

            )

            $mockCurrentState = @(

                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-01-01T11:00:00' },

                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T11:00:00' }

            )

            $mockChange = [PSCustomObject]@{

                GefyraName    = 'ισθμία'

                GefyraStatus  = 'Ανοιχτή'

                SideIndicator = '=>'

            }



            $resolveBridgeStateForChangeSplat = @{

                Change        = $mockChange

                PreviousState = $mockPreviousState

                CurrentState  = $mockCurrentState

            }

            $result = Resolve-BridgeStateForChange @resolveBridgeStateForChangeSplat




            @($result).Count | Should -Be -ExpectedValue 1

            $result.GefyraName | Should -Be -ExpectedValue 'Ισθμία'

        }

    }

}

