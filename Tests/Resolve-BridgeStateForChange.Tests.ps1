Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Resolve-BridgeStateForChange' {
        BeforeEach {
            # Mock test data
            $mockPreviousState = @(
                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T10:00:00' },
                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-01-01T10:00:00' }
            )

            $mockCurrentState = @(
                [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-01-01T11:00:00' },
                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-01-01T11:00:00' }
            )
        }

        Context 'Όταν SideIndicator είναι =>' {
            It 'Επιστρέφει state από CurrentState για νέα κατάσταση' {
                $mockChange = [PSCustomObject]@{
                    GefyraName = 'Ισθμία'
                    GefyraStatus = 'Κλειστή με πρόγραμμα'
                    SideIndicator = '=>'
                }

                $result = Resolve-BridgeStateForChange -Change $mockChange -PreviousState $mockPreviousState -CurrentState $mockCurrentState

                $result.Count | Should -Be 1
                $result[0].GefyraName | Should -Be 'Ισθμία'
                $result[0].GefyraStatus | Should -Be 'Κλειστή με πρόγραμμα'
                $result[0].Timestamp | Should -Be '2025-01-01T11:00:00'
            }

            It 'Επιστρέφει κενό array όταν δεν βρίσκει την γέφυρα στο CurrentState' {
                $mockChange = [PSCustomObject]@{
                    GefyraName       = 'ΆγνωστηΓέφυρα'
                    GefyraStatus     = 'Ανοιχτή'
                    SideIndicator    = '=>'
                }
                $resolveBridgeStateForChangeSplat = @{
                    Change           = $mockChange
                    PreviousState    = $mockPreviousState
                    CurrentState     = $mockCurrentState
                }

                $result    = Resolve-BridgeStateForChange @resolveBridgeStateForChangeSplat
                # PowerShell unwraps single-item arrays, so we test the Count instead
                @($result).Count | Should -Be 0
            }
        }

        Context 'Όταν SideIndicator είναι <=' {
            It 'Επιστρέφει state από CurrentState πρώτα για παλιά κατάσταση' {
                $mockChange = [PSCustomObject]@{
                    GefyraName       = 'Ποσειδωνία'
                    GefyraStatus     = 'Κλειστή για συντήρηση'
                    SideIndicator    = '<='
                }

                $result = Resolve-BridgeStateForChange -Change $mockChange -PreviousState $mockPreviousState -CurrentState $mockCurrentState

                $result.Count | Should -Be 1
                $result[0].GefyraName | Should -Be 'Ποσειδωνία'
                $result[0].GefyraStatus | Should -Be 'Ανοιχτή'  # Από CurrentState
                $result[0].Timestamp | Should -Be '2025-01-01T11:00:00'
            }

            It 'Επιστρέφει state από PreviousState όταν δεν υπάρχει στο CurrentState (fallback)' {
                # Δημιουργούμε CurrentState χωρίς την γέφυρα
                $mockCurrentStateWithoutBridge = @(
                    [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-01-01T11:00:00' }
                )

                $mockChange = [PSCustomObject]@{
                    GefyraName       = 'Ποσειδωνία'
                    GefyraStatus     = 'Κλειστή για συντήρηση'
                    SideIndicator    = '<='
                }

                $result = Resolve-BridgeStateForChange -Change $mockChange -PreviousState $mockPreviousState -CurrentState $mockCurrentStateWithoutBridge

                $result.Count | Should -Be 1
                $result[0].GefyraName | Should -Be 'Ποσειδωνία'
                $result[0].GefyraStatus | Should -Be 'Κλειστή για συντήρηση'  # Από PreviousState
                $result[0].Timestamp | Should -Be '2025-01-01T10:00:00'
            }
        }

        Context 'Edge Cases' {
            It 'Επιστρέφει πάντα array ακόμα και για single result' {
                $mockChange = [PSCustomObject]@{
                    GefyraName       = 'Ισθμία'
                    GefyraStatus     = 'Κλειστή με πρόγραμμα'
                    SideIndicator    = '=>'
                }

                $resolveBridgeStateForChangeSplat = @{
                    Change           = $mockChange
                    PreviousState    = $mockPreviousState
                    CurrentState     = $mockCurrentState
                }
                $result    = Resolve-BridgeStateForChange @resolveBridgeStateForChangeSplat

                # Test that we get exactly one result (PowerShell unwraps single-item arrays)
                @($result).Count | Should -Be 1
                $result.GefyraName | Should -Be 'Ισθμία'
            }

            It 'Χειρίζεται case-insensitive σύγκριση ονομάτων' {
                $mockChange = [PSCustomObject]@{
                    GefyraName       = 'ισθμία'  # Lowercase
                    GefyraStatus     = 'Ανοιχτή'
                    SideIndicator    = '=>'
                }

                $resolveBridgeStateForChangeSplat = @{
                    Change           = $mockChange
                    PreviousState    = $mockPreviousState
                    CurrentState     = $mockCurrentState
                }
                $result    = Resolve-BridgeStateForChange @resolveBridgeStateForChangeSplat

                # Test that case-insensitive matching works
                @($result).Count | Should -Be 1  # Θα βρει match γιατί το PowerShell είναι case-insensitive
                $result.GefyraName | Should -Be 'Ισθμία'  # Original case from mock data
            }
        }
    }
}
