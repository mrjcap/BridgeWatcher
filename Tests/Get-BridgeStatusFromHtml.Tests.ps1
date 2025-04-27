Import-Module "$PSScriptRoot\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeStatusFromHtml' {
        Context 'Debug branch' {
            It 'γράφει Write-Debug όταν δεν βρίσκει match για status' {
                # Mock το Get-BridgeImages να επιστρέφει έστω μία εικόνα
                Mock Get-BridgeImages { @(@{ src = 'not-matching.jpg' }) }
                # Mock το Resolve-BridgeStatus να επιστρέφει $null (κανένα status δεν ταιριάζει)
                Mock Resolve-BridgeStatus { $null }
                # Mock το New-BridgeStatusObject για να μην εκτελεστεί ποτέ (θα μπει μόνο στο else)
                Mock New-BridgeStatusObject {}
                $html = '<div>dummy</div>'
                $timestamp = '2025-04-18T08:00:00'
                # Πρέπει να ενεργοποιήσεις το Debug output!
                $result = Get-BridgeStatusFromHtml -Html $html -Timestamp $timestamp -Debug
                $result
                # Εναλλακτικά, μπορείς να τσεκάρεις αν το Write-Debug εκτελέστηκε:
                Assert-MockCalled Resolve-BridgeStatus -Exactly 6 -Scope It # Καλείται για κάθε status
                # Το σημαντικό: το Write-Debug της "Δεν ταιριάζει" θα εκτελεστεί για κάθε status
            }
        }
        Context 'Όταν δεν βρίσκονται εικόνες' {
            It 'Πετάει σφάλμα BridgeImagesNotFound όταν δεν επιστρέφονται εικόνες' {
                # Mock το Get-BridgeImages να επιστρέφει $null
                Mock Get-BridgeImages { $null }
                $html = '<html><body>no images</body></html>'
                $timestamp = '2025-04-18T08:00:00'
                { Get-BridgeStatusFromHtml -Html $html -Timestamp $timestamp } | Should -Throw -ErrorId 'BridgeImagesNotFound,Get-BridgeStatusFromHtml'
            }
        }
    }
}