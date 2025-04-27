Import-Module "$PSScriptRoot\..\src\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Δοκιμές της συνάρτησης ConvertTo-BridgeClosedDuration' {
        It "θα επιστρέψει 'ημέρα' για διάρκεια 1 ημέρας" {
            $duration = [timespan]::FromDays(1)
            $result = ConvertTo-BridgeClosedDuration -Duration $duration
            # Ελέγχουμε αν περιέχει τη λέξη "ημέρα"
            $result | Should -Contain '1 ημέρα'
        }
        It "θα επιστρέψει 'ημέρες' για διάρκεια περισσότερων από 1 ημέρα" {
            $duration = [timespan]::FromDays(2)
            $result = ConvertTo-BridgeClosedDuration -Duration $duration
            # Ελέγχουμε αν περιέχει τη λέξη "ημέρες"
            $result | Should -Contain '2 ημέρες'
        }
        It "θα επιστρέψει 'ώρα' για διάρκεια 1 ώρας" {
            $duration = [timespan]::FromHours(1)
            $result = ConvertTo-BridgeClosedDuration -Duration $duration
            # Ελέγχουμε αν περιέχει τη λέξη "ώρα"
            $result | Should -Contain '1 ώρα'
        }
        It "θα επιστρέψει 'ώρες' για διάρκεια περισσότερων από 1 ώρα" {
            $duration = [timespan]::FromHours(2)
            $result = ConvertTo-BridgeClosedDuration -Duration $duration
            # Ελέγχουμε αν περιέχει τη λέξη "ώρες"
            $result | Should -Contain '2 ώρες'
        }
        It "θα επιστρέψει 'λεπτό' για διάρκεια 1 λεπτού" {
            $duration = [timespan]::FromMinutes(1)
            $result = ConvertTo-BridgeClosedDuration -Duration $duration
            # Ελέγχουμε αν περιέχει τη λέξη "λεπτό"
            $result | Should -Contain '1 λεπτό'
        }
        It "θα επιστρέψει 'λεπτά' για διάρκεια περισσότερων από 1 λεπτό" {
            $duration = [timespan]::FromMinutes(2)
            $result = ConvertTo-BridgeClosedDuration -Duration $duration
            # Ελέγχουμε αν περιέχει τη λέξη "λεπτά"
            $result | Should -Contain '2 λεπτά'
        }
        It "θα επιστρέψει 'ημέρα, ώρα' για διάρκεια 1 ημέρας και 1 ώρας" {
            $duration = [timespan]::FromDays(1).Add([timespan]::FromHours(1))
            $result = ConvertTo-BridgeClosedDuration -Duration $duration
            # Ελέγχουμε αν περιέχει τις λέξεις "ημέρα" και "ώρα"
            $result | Should -Contain '1 ημέρα, 1 ώρα'
        }
        It "θα επιστρέψει 'ημέρες, ώρες, λεπτά' για διάρκεια περισσότερων από 1 ημέρα, ώρα και λεπτό" {
            $duration = [timespan]::FromDays(2).Add([timespan]::FromHours(3)).Add([timespan]::FromMinutes(5))
            $result = ConvertTo-BridgeClosedDuration -Duration $duration
            # Ελέγχουμε αν περιέχει τις λέξεις "ημέρες", "ώρες", και "λεπτά"
            $result | Should -Contain '2 ημέρες, 3 ώρες, 5 λεπτά'
        }
    }
    Context 'Όταν το Duration είναι null' {
        It 'Πετάει σφάλμα όταν το Duration είναι null' {
            { ConvertTo-BridgeClosedDuration -Duration $null } | Should -Throw -ErrorId 'ParameterArgumentTransformationError,ConvertTo-BridgeClosedDuration'
        }
        It 'Πετάει σφάλμα όταν δεν δοθεί καθόλου το Duration' {
            { ConvertTo-BridgeClosedDuration -Duration $null } | Should -Throw -ErrorId 'ParameterArgumentTransformationError,ConvertTo-BridgeClosedDuration'
        }
    }
    Describe 'ConvertTo-BridgeClosedDuration' {
        Context 'Όταν παρέχεται αρνητικό TimeSpan' {
            It 'Πρέπει να ρίξει σφάλμα όταν η διάρκεια είναι αρνητική' {
                {
                    ConvertTo-BridgeClosedDuration -Duration ([timespan]::FromMinutes(-5))
                } | Should -Throw -ErrorId 'NegativeDurationNotAllowed,ConvertTo-BridgeClosedDuration'
            }
        }
    }
}