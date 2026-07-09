Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe 'Get-BridgeStatusFromHtml' {

    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        $script:Config = New-BridgeConfiguration
    }




    Context 'Όταν δεν βρίσκονται εικόνες' {

        It 'Πετάει σφάλμα BridgeImagesNotFound όταν δεν επιστρέφονται εικόνες' {

            # Mock το Get-BridgeImage να επιστρέφει $null

            Mock Get-BridgeImage { $null }

            $html = '<html><body>no images</body></html>'

            $timestamp = '2025-04-18T08:00:00'

            { Get-BridgeStatusFromHtml -Configuration $script:Config -Html $html -Timestamp $timestamp } | Should -Throw -ErrorId '*BridgeImagesNotFound*'

        }

    }

    Context 'Όταν υπάρχει Open image αλλά δεν υπάρχει info εικόνα' {

        It 'Παραλείπει Open κατάσταση χωρίς info εικόνα' {
            $config = New-BridgeConfiguration

            # Mock Get-BridgeImage to return images with Open pattern but no info.php
            Mock Get-BridgeImage {
                param($HtmlContent, $Location)
                $null = $HtmlContent
                if ($Location -eq 'poseidonia') {
                    return [System.Collections.ArrayList]@(
                        [pscustomobject]@{ src = 'image-bridge-open-no-schedule.php?123' }
                    )
                }
                return [System.Collections.ArrayList]@(
                    [pscustomobject]@{ src = 'image-bridge-open-no-schedule.php?456' }
                )
            }

            Mock Write-BridgeLog { }

            $html = '<html><body>dummy</body></html>'
            $timestamp = '2025-04-18T08:00:00'

            $result = Get-BridgeStatusFromHtml -Html $html -Timestamp $timestamp -Configuration $config

            # Should return empty because Open status was skipped (no info image)
            $result.Count | Should -Be 0

            # Verify the skip log message was written
            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
                $Message -like '*Παραλείπεται*' -and $Message -like '*info*'
            } -Times 1 -Scope It
        }

    }

}

