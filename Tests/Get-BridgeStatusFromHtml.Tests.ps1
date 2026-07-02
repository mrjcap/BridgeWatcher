Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Get-BridgeStatusFromHtml' {

    BeforeAll {

        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"

    }




    Context 'Όταν δεν βρίσκονται εικόνες' {

        It 'Πετάει σφάλμα BridgeImagesNotFound όταν δεν επιστρέφονται εικόνες' {

            # Mock το Get-BridgeImage να επιστρέφει $null

            Mock Get-BridgeImage { $null }

            $html = '<html><body>no images</body></html>'

            $timestamp = '2025-04-18T08:00:00'

            { Get-BridgeStatusFromHtml -Html $html -Timestamp $timestamp } | Should -Throw -ErrorId '*BridgeImagesNotFound*'

        }

    }

}

