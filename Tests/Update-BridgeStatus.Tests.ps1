Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Update-BridgeStatus' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/TestHelper.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Export-BridgeStatusJson.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgeStatus.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Get-BridgePreviousStatus.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Invoke-BridgeStatusComparison.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Public/Update-BridgeStatus.ps1"
        $script:Config = New-BridgeConfiguration
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
                @{ Bridge = 'Ποσειδωνία'; Status = 'Ανοικτή' }
            )
        }
        Mock Get-BridgeStatus -MockWith {
            return @(
                @{ Bridge = 'Ποσειδωνία'; Status = 'Ανοικτή' }
            )
        }
        Mock Invoke-BridgeStatusComparison {}
        Mock Export-BridgeStatusJson {
            New-BridgeResult -Success $true
        }
        Mock Write-Verbose {}

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
}
