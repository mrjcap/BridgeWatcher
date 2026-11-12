Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Update-BridgeStatus' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/TestHelper.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeOptionalProperty.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Send-BridgeNotification.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeClosedNotification.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOpenedNotification.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatus.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgePreviousStatus.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Invoke-BridgeStatusComparison.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Update-BridgeStatus.ps1"
        $script:Config = New-BridgeConfiguration

        function script:Initialize-TwoBridgeDiffMock {
            <#
            .SYNOPSIS
            Initializes mocks for two-bridge partial alert tests.
            #>
            param(
                [object[]]$PreviousEntries = @(),
                [object[]]$ExtraCurrentEntries = @()
            )
            $b1 = [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Κλειστή για συντήρηση'; Timestamp = '2025-04-25T10:00:00' }
            $b2 = [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T10:00:00' }
            $hasPrevious = $PreviousEntries.Count -gt 0
            Mock Test-Path { return $hasPrevious }.GetNewClosure()
            if ($hasPrevious) {
                Mock Get-BridgePreviousStatus { return $PreviousEntries }.GetNewClosure()
            }
            $allCurrent = @($ExtraCurrentEntries) + @($b1, $b2)
            Mock Get-BridgeStatus { return $allCurrent }.GetNewClosure()
            Mock Invoke-BridgeStatusComparison {
                return @(
                    [PSCustomObject]@{ BridgeName = 'Ποσειδωνία'; Type = 'Closed'; StateInfo = @($b1) },
                    [PSCustomObject]@{ BridgeName = 'Ισθμία'; Type = 'Opened'; StateInfo = @($b2) }
                )
            }.GetNewClosure()
            $script:capturedExports = @()
            Mock Export-BridgeStatusJson {
                $script:capturedExports += , @($Data)
                return New-BridgeResult -Success $true
            }
            Mock Write-BridgeLog { }
        }
    }

    It 'Εκτελεί όλες τις βασικές λειτουργίες χωρίς σφάλμα' {
        $jsonFile = "TestDrive:\bridge_status_test.json"
        # Mock dependencies με σωστή παράμετρο
        Mock Get-BridgePreviousStatus {
            return @(
                @{ Bridge = 'Ποσειδωνία'; Status = 'Ανοικτή' },
                @{ Bridge = 'Ισθμία'; Status = 'Ανοικτή' }
            )
        } -ParameterFilter { $InputFile -eq $jsonFile }
        Mock Get-BridgeStatus -MockWith {
            return @(
                @{ Bridge = 'Ποσειδωνία'; Status = 'Ανοικτή' },
                @{ Bridge = 'Ισθμία'; Status = 'Ανοικτή' }
            )
        }
        Mock Invoke-BridgeStatusComparison {}
        Mock Export-BridgeStatusJson {
            New-BridgeResult -Success $true
        }
        Mock Write-Verbose {}

        # Κλήση υπό δοκιμή
        {
            Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
        } | Should -Not -Throw
    }

    It 'Πρέπει να καλούνται Get-BridgePreviousStatus και Get-BridgeStatus με τα σωστά parameters όταν το αρχείο υπάρχει' {
        $jsonFile = "TestDrive:\bridge_status_test_exists.json"

        # We ensure Test-Path returns true to simulate file existence
        Mock Test-Path { return $true }

        Mock Get-BridgePreviousStatus {
            return @(
                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοικτή'; From = '00:00'; ImageHash = 'abc' }
            )
        }
        Mock Get-BridgeStatus -MockWith {
            return @(
                [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοικτή' }
            )
        }
        Mock Invoke-BridgeStatusComparison {
            return @(
                [PSCustomObject]@{ Type = 'Closed'; StateInfo = @{ GefyraName = 'Ποσειδωνία' } },
                [PSCustomObject]@{ Type = 'Opened'; StateInfo = @{ GefyraName = 'Ισθμία' } }
            )
        }
        Mock Export-BridgeStatusJson {
            New-BridgeResult -Success $true
        }
        Mock Write-Verbose {}
        Mock Invoke-BridgeClosedNotification {}
        Mock Invoke-BridgeOpenedNotification {}

        $updateBridgeStatusSplat = @{
            OutputFile    = $jsonFile
            ApiKey        = 'dummyApiKey'
            PoUserKey     = 'dummyPoUserKey'
            PoApiKey      = 'dummyPoApiKey'
            Configuration = $script:Config
        }
        { Update-BridgeStatus @updateBridgeStatusSplat } | Should -Not -Throw

        # Ελέγχουμε αν η συνάρτηση Get-BridgeStatus καλείται
        Should -Invoke -CommandName Get-BridgeStatus -Times 1 -Exactly -Scope It
        # Ελέγχουμε αν η συνάρτηση Invoke-BridgeStatusComparison κλήθηκε
        Should -Invoke -CommandName Invoke-BridgeStatusComparison -Times 1 -Exactly -Scope It
        Should -Invoke -CommandName Invoke-BridgeClosedNotification -Times 1 -Exactly -Scope It
        Should -Invoke -CommandName Invoke-BridgeOpenedNotification -Times 1 -Exactly -Scope It
    }

    It 'Εκτελείται σωστά με -WhatIf και δεν καλεί Invoke/Export' {
        $jsonFile = "TestDrive:\bridge_status_whatif.json"

        Mock Test-Path { return $true }
        Mock Get-BridgePreviousStatus { return @() }
        Mock Get-BridgeStatus { return @() }
        Mock Invoke-BridgeStatusComparison {}
        Mock Export-BridgeStatusJson {}
        Mock Write-BridgeLog {}

        Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k' -WhatIf

        Should -Not -Invoke -CommandName Invoke-BridgeStatusComparison -Scope It
        Should -Not -Invoke -CommandName Export-BridgeStatusJson -Scope It
        Should -Invoke -CommandName Write-BridgeLog -ParameterFilter { $Message -eq 'Finished comparison and saved snapshot.' } -Times 1 -Scope It
    }

    It 'Ρίχνει terminating error όταν η Export-BridgeStatusJson επιστρέφει Success = $false' {
        $jsonFile = "TestDrive:\bridge_status_export_fail.json"

        Mock Test-Path { return $false }
        Mock Get-BridgeStatus { return @([PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοικτή' }) }
        Mock Invoke-BridgeStatusComparison { return @() }
        Mock Export-BridgeStatusJson {
            return New-BridgeResult -Success $false -ErrorMessage 'Disk full' -ErrorCode 'JSON_EXPORT_FAILURE'
        }
        Mock Write-BridgeLog {}

        {
            Update-BridgeStatus -Configuration $script:Config -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
        } | Should -Throw -ExpectedMessage '*Disk full*'
    }

    It 'Αποθηκεύει μόνο την επιτυχημένη γέφυρα σε cold start όταν αποτυγχάνει η δεύτερη ειδοποίηση και επαναρίχνει το σφάλμα' {
        Initialize-TwoBridgeDiffMock
        Mock Invoke-BridgeClosedNotification { }
        Mock Invoke-BridgeOpenedNotification { throw 'Bridge 2 Pushover timeout' }

        {
            Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_cold_partial.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
        } | Should -Throw -ExpectedMessage '*Bridge 2 Pushover timeout*'

        Should -Invoke -CommandName Export-BridgeStatusJson -Times 1 -Exactly -Scope It
        $saved = @($script:capturedExports[0])
        $saved.Count | Should -Be 1
        $saved[0].GefyraName | Should -Be 'Ποσειδωνία'
        $saved[0].GefyraStatus | Should -Be 'Κλειστή για συντήρηση'
    }

    It 'Αποθηκεύει τη νέα κατάσταση της πρώτης γέφυρας, τις αμετάβλητες και την προηγούμενη της αποτυχημένης όταν υπάρχει ιστορικό' {
        $prevEntries = @(
            [PSCustomObject]@{ GefyraName = 'Κόρινθος'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T09:55:00' },
            [PSCustomObject]@{ GefyraName = 'Ποσειδωνία'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T09:55:00' },
            [PSCustomObject]@{ GefyraName = 'Ισθμία'; GefyraStatus = 'Κλειστή με πρόγραμμα'; Timestamp = '2025-04-25T09:55:00'; From = '10:00' }
        )
        $unchangedCurrent = @([PSCustomObject]@{ GefyraName = 'Κόρινθος'; GefyraStatus = 'Ανοιχτή'; Timestamp = '2025-04-25T10:00:00' })
        Initialize-TwoBridgeDiffMock -PreviousEntries $prevEntries -ExtraCurrentEntries $unchangedCurrent
        Mock Invoke-BridgeClosedNotification { }
        Mock Invoke-BridgeOpenedNotification { throw 'Bridge 2 Pushover HTTP 503' }

        {
            Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_warm_partial.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
        } | Should -Throw -ExpectedMessage '*Bridge 2 Pushover HTTP 503*'

        Should -Invoke -CommandName Export-BridgeStatusJson -Times 1 -Exactly -Scope It
        $saved = @($script:capturedExports[0])
        $saved.Count | Should -Be 3
        ($saved | Where-Object { $_.GefyraName -eq 'Κόρινθος' }).Timestamp | Should -Be '2025-04-25T10:00:00'
        ($saved | Where-Object { $_.GefyraName -eq 'Ποσειδωνία' }).GefyraStatus | Should -Be 'Κλειστή για συντήρηση'
        $isthmiaSaved = $saved | Where-Object { $_.GefyraName -eq 'Ισθμία' }
        $isthmiaSaved.GefyraStatus | Should -Be 'Κλειστή με πρόγραμμα'
        $isthmiaSaved.From | Should -Be '10:00'
    }

    It 'Δεν καλεί Export-BridgeStatusJson όταν αποτύχουν όλες οι ειδοποιήσεις αλλαγών' {
        Initialize-TwoBridgeDiffMock
        Mock Invoke-BridgeClosedNotification { throw 'First bridge notification failed' }
        Mock Invoke-BridgeOpenedNotification { throw 'Second bridge notification failed' }

        {
            Update-BridgeStatus -Configuration $script:Config -OutputFile 'TestDrive:\bridge_status_first_fail.json' -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
        } | Should -Throw -ExpectedMessage '*First bridge notification failed*'

        Should -Not -Invoke -CommandName Export-BridgeStatusJson -Scope It
    }
}
