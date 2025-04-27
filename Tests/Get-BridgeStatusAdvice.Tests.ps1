Import-Module "$PSScriptRoot\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeStatusAdvice Tests' {
        It 'should return "Είναι προτιμότερο να μην περιμένεις" when more than 12 minutes until open' {
            # Καλέστε τη συνάρτηση με τιμή πάνω από 12 λεπτά
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 15
            $result | Should -Be 'Είναι προτιμότερο να μην περιμένεις'
        }
        It 'should return "Είναι προτιμότερο να περιμένεις" when 12 minutes or less until open' {
            # Καλέστε τη συνάρτηση με τιμή 12 ή λιγότερο
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 12
            $result | Should -Be 'Είναι προτιμότερο να περιμένεις'
            # Επιπλέον έλεγχος για τιμή 5 λεπτών
            $result = Get-BridgeStatusAdvice -MinutesUntilOpen 5
            $result | Should -Be 'Είναι προτιμότερο να περιμένεις'
        }
    }
}