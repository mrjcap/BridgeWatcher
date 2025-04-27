Import-Module "$PSScriptRoot/../BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Resolve-BridgeStatus' {
        It 'Βρίσκει matching εικόνα με βάση pattern' {
            $mockImages = @(
                [pscustomobject]@{ src = 'image-bridge-open-with-schedule-posidonia.php?456' },
                [pscustomobject]@{ src = 'image-bridge-open-no-schedule-info.php?123' }
            )
            $pattern = 'image-bridge-open-with-schedule-posidonia\.php(\?\d+)?'
            $result = Resolve-BridgeStatus -Location 'poseidonia' -Status 'Κλειστή με πρόγραμμα' `
                -Pattern $pattern -BridgeImages $mockImages -RequireInfoImage:$false
            $result.src | Should -Match 'with-schedule-posidonia'
        }
        It 'Επιστρέφει $null όταν λείπει info εικόνα για Ανοιχτή' {
            $images = @([pscustomobject]@{ src = 'image-bridge-open-no-schedule.php?999' })
            $result = Resolve-BridgeStatus -Location 'poseidonia' -Status 'Ανοιχτή' `
                -Pattern 'image-bridge-open-no-schedule\.php\?\d+' `
                -BridgeImages $images -RequireInfoImage:$true
            $result | Should -BeNullOrEmpty
        }
        It 'Επιστρέφει εικόνα όταν υπάρχει και info για Ανοιχτή' {
            $images = @(
                [pscustomobject]@{ src = 'image-bridge-open-no-schedule.php?100' },
                [pscustomobject]@{ src = 'image-bridge-open-no-schedule-info.php?100' }
            )
            $result = Resolve-BridgeStatus -Location 'isthmia' -Status 'Ανοιχτή' `
                -Pattern 'image-bridge-open-no-schedule\.php\?\d+' `
                -BridgeImages $images -RequireInfoImage:$true
            $result.src | Should -Match 'no-schedule\.php'
        }
    }
}