Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Resolve-BridgeStateForChange' {

    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"
        $script:Config = New-BridgeConfiguration

    }

    Context 'Όταν SideIndicator είναι =>' {

        It 'Επιστρέφει state από CurrentState για νέα κατάσταση' {


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



            $result.Count | Should -Be 1

            $result[0].GefyraName | Should -Be 'Ισθμία'

            $result[0].GefyraStatus | Should -Be 'Κλειστή με πρόγραμμα'

            $result[0].Timestamp | Should -Be '2025-01-01T11:00:00'

        }



        It 'Επιστρέφει κενό array όταν δεν βρίσκει την γέφυρα στο CurrentState' {


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


            @($result).Count | Should -Be 0

        }

    }



    Context 'Όταν SideIndicator είναι <=' {

        It 'Επιστρέφει state από CurrentState πρώτα για παλιά κατάσταση' {


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



            $result.Count | Should -Be 1

            $result[0].GefyraName | Should -Be 'Ποσειδωνία'

            $result[0].GefyraStatus | Should -Be 'Ανοιχτή'

            $result[0].Timestamp | Should -Be '2025-01-01T11:00:00'

        }



        It 'Επιστρέφει state από PreviousState όταν δεν υπάρχει στο CurrentState (fallback)' {


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



            $result.Count | Should -Be 1

            $result[0].GefyraName | Should -Be 'Ποσειδωνία'

            $result[0].GefyraStatus | Should -Be 'Κλειστή για συντήρηση'

            $result[0].Timestamp | Should -Be '2025-01-01T10:00:00'

        }

    }



    Context 'Edge Cases' {

        It 'Επιστρέφει πάντα array ακόμα και για single result' {


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




            @($result).Count | Should -Be 1

            $result.GefyraName | Should -Be 'Ισθμία'

        }



        It 'Χειρίζεται case-insensitive σύγκριση ονομάτων' {


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




            @($result).Count | Should -Be 1

            $result.GefyraName | Should -Be 'Ισθμία'

        }

    }

}

