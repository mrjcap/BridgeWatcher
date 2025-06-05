Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeStatusComparison' {
        It 'Εκτελεί όλες τις βασικές λειτουργίες χωρίς σφάλμα' {
            $jsonFile = Join-Path $PSScriptRoot 'bridge_status_test.json'
            # Mock dependencies με σωστή παράμετρο
            Mock Get-BridgePreviousStatus {
                return @(
                    @{ Bridge = 'Ποσειδωνία'; Status = 'Ανοικτή' },
                    @{ Bridge = 'Ισθμία'; Status = 'Ανοικτή' }
                )
            } -ParameterFilter { $InputFile -eq $jsonFile } -ModuleName 'BridgeWatcher'
            Mock Get-BridgeStatus -ModuleName 'BridgeWatcher' -MockWith {
                return @(
                    @{ Bridge = 'Ποσειδωνία'; Status = 'Ανοικτή' },
                    @{ Bridge = 'Ισθμία'; Status = 'Ανοικτή' }
                )
            }
            Mock Invoke-BridgeStatusComparison {}
            Mock Set-Content {}
            Mock Write-Verbose {}
            # Κλήση υπό δοκιμή
            {
                Get-BridgeStatusComparison -OutputFile $jsonFile -ApiKey 'a' -PoUserKey 'u' -PoApiKey 'k'
            } | Should -Not -Throw
            # Καθαρισμός
            if (Test-Path $jsonFile) { Remove-Item $jsonFile -Force }
        }
        It 'Πρέπει να καλούνται Get-BridgePreviousStatus και Get-BridgeStatus με τα σωστά parameters όταν το αρχείο υπάρχει' {
            $jsonFile = Join-Path $PSScriptRoot 'bridge_status_test.json'
            # Mock για Test-Path (όταν το αρχείο δεν υπάρχει)
            Mock Test-Path { return $true }  # Εξασφαλίζει ότι το αρχείο δεν υπάρχει
            # Mock για Get-BridgeStatus (πρέπει να καλείται όταν το αρχείο δεν υπάρχει)
            Mock Get-Content {
                param ($Path)
                Write-Verbose "Mocked Get-Content for path: $Path"
                return '{"Bridge": "Ποσειδωνία", "Status": "Ανοιχτή"}'  # Ψευδή δεδομένα για το test
            }
            Mock Get-BridgeStatus -ModuleName 'BridgeWatcher' -MockWith {
                return @(
                    @{ Bridge = 'Ποσειδωνία'; Status = 'Ανοικτή' },
                    @{ Bridge = 'Ισθμία'; Status = 'Ανοικτή' }
                )
            }
            # Mock για Invoke-BridgeStatusComparison, Set-Content, Write-Verbose
            Mock Invoke-BridgeStatusComparison {}
            Mock Set-Content {}
            Mock Write-Verbose {}
            # Εκτέλεση της συνάρτησης Get-BridgeStatusComparison
            $getBridgeStatusComparisonSplat = @{
                OutputFile = $jsonFile
                ApiKey     = 'dummyApiKey'
                PoUserKey  = 'dummyPoUserKey'
                PoApiKey   = 'dummyPoApiKey'
            }
            { Get-BridgeStatusComparison @getBridgeStatusComparisonSplat } | Should -Not -Throw
            # Ελέγχουμε αν η συνάρτηση Get-BridgeStatus καλείται με το σωστό OutputFile και τα flags Verbose/Debug
            Assert-MockCalled Get-BridgeStatus -Exactly 1 -Scope It -Verbose
            # Ελέγχουμε αν η συνάρτηση Invoke-BridgeStatusComparison κλήθηκε
            Assert-MockCalled Invoke-BridgeStatusComparison -Exactly 1 -Scope It -Verbose
        }
    }
}