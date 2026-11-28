Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe -Name 'Δοκιμές της συνάρτησης ConvertTo-BridgeClosedDuration' -Fixture {

    BeforeAll -Scriptblock {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeClosedDuration.ps1"
        $script:Config = New-BridgeConfiguration

    }

    It -Name "θα επιστρέψει 'ημέρα' για διάρκεια 1 ημέρας" -Test {

        $duration = [timespan]::FromDays(1)

        $result = ConvertTo-BridgeClosedDuration -Duration $duration


        $result | Should -Contain -ExpectedValue '1 ημέρα'

    }

    It -Name "θα επιστρέψει 'ημέρες' για διάρκεια περισσότερων από 1 ημέρα" -Test {

        $duration = [timespan]::FromDays(2)

        $result = ConvertTo-BridgeClosedDuration -Duration $duration


        $result | Should -Contain -ExpectedValue '2 ημέρες'

    }

    It -Name "θα επιστρέψει 'ώρα' για διάρκεια 1 ώρας" -Test {

        $duration = [timespan]::FromHours(1)

        $result = ConvertTo-BridgeClosedDuration -Duration $duration


        $result | Should -Contain -ExpectedValue '1 ώρα'

    }

    It -Name "θα επιστρέψει 'ώρες' για διάρκεια περισσότερων από 1 ώρα" -Test {

        $duration = [timespan]::FromHours(2)

        $result = ConvertTo-BridgeClosedDuration -Duration $duration


        $result | Should -Contain -ExpectedValue '2 ώρες'

    }

    It -Name "θα επιστρέψει 'λεπτό' για διάρκεια 1 λεπτού" -Test {

        $duration = [timespan]::FromMinutes(1)

        $result = ConvertTo-BridgeClosedDuration -Duration $duration


        $result | Should -Contain -ExpectedValue '1 λεπτό'

    }

    It -Name "θα επιστρέψει 'λεπτά' για διάρκεια περισσότερων από 1 λεπτό" -Test {

        $duration = [timespan]::FromMinutes(2)

        $result = ConvertTo-BridgeClosedDuration -Duration $duration


        $result | Should -Contain -ExpectedValue '2 λεπτά'

    }

    It -Name "θα επιστρέψει 'ημέρα, ώρα' για διάρκεια 1 ημέρας και 1 ώρας" -Test {

        $duration = [timespan]::FromDays(1).Add([timespan]::FromHours(1))

        $result = ConvertTo-BridgeClosedDuration -Duration $duration


        $result | Should -Contain -ExpectedValue '1 ημέρα, 1 ώρα'

    }

    It -Name "θα επιστρέψει 'ημέρες, ώρες, λεπτά' για διάρκεια περισσότερων από 1 ημέρα, ώρα και λεπτό" -Test {

        $duration = [timespan]::FromDays(2).Add([timespan]::FromHours(3)).Add([timespan]::FromMinutes(5))

        $result = ConvertTo-BridgeClosedDuration -Duration $duration


        $result | Should -Contain -ExpectedValue '2 ημέρες, 3 ώρες, 5 λεπτά'

    }

    Context -Name 'Όταν το Duration είναι null' -Fixture {

        It -Name 'Πετάει σφάλμα όταν το Duration είναι null' -Test {

            { ConvertTo-BridgeClosedDuration -Duration $null } | Should -Throw -ErrorId 'ParameterArgumentTransformationError,ConvertTo-BridgeClosedDuration'

        }

        It -Name 'Πετάει σφάλμα όταν δεν δοθεί καθόλου το Duration' -Test {

            { ConvertTo-BridgeClosedDuration -Duration $null } | Should -Throw -ErrorId 'ParameterArgumentTransformationError,ConvertTo-BridgeClosedDuration'

        }

    }

}

Describe -Name 'ConvertTo-BridgeClosedDuration' -Fixture {

    BeforeAll -Scriptblock {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertTo-BridgeClosedDuration.ps1"

    }

    Context -Name 'Όταν παρέχεται αρνητικό TimeSpan' -Fixture {

        It -Name "Πρέπει να επιστρέφει 'λιγότερο από 1 λεπτό' όταν η διάρκεια είναι μικρότερη από 1 λεπτό" -Test {
            $result = ConvertTo-BridgeClosedDuration -Duration ([timespan]::FromSeconds(30))
            $result | Should -Be -ExpectedValue 'λιγότερο από 1 λεπτό'
        }

        It -Name 'Πρέπει να επιστρέψει "άγνωστη διάρκεια" όταν η διάρκεια είναι αρνητική' -Test {
            $res = ConvertTo-BridgeClosedDuration -Duration ([timespan]::FromMinutes(-5))
            $res | Should -Be -ExpectedValue 'άγνωστη διάρκεια'
        }

    }

}

