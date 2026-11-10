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

            $errs = @()
            Get-BridgeStatusFromHtml -Configuration $script:Config -Html $html -Timestamp $timestamp -ErrorVariable errs -ErrorAction SilentlyContinue
            $matchFound = [bool]($errs.FullyQualifiedErrorId -match 'BridgeImagesNotFound')
            $matchFound | Should -Be $true

        }

        It 'Πετάει σφάλμα BridgeStatusPatternNotFound όταν οι εικόνες δεν ταιριάζουν σε κανένα πρότυπο' {
            Mock Get-BridgeImage {
                return [System.Collections.ArrayList]@(
                    [pscustomobject]@{ src = 'unknown-banner.jpg' }
                )
            }
            Mock Write-BridgeLog { }

            $html = '<html><body>unrecognized images</body></html>'
            $timestamp = '2025-04-18T08:00:00'

            $errs = @()
            $result = Get-BridgeStatusFromHtml -Configuration $script:Config -Html $html -Timestamp $timestamp -ErrorVariable errs -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $matchFound = [bool]($errs.FullyQualifiedErrorId -match 'BridgeStatusPatternNotFound')
            $matchFound | Should -Be $true
        }

    }

    Context 'Όταν υπάρχει Open image αλλά δεν υπάρχει info εικόνα' {

        It 'Δημιουργεί προειδοποίηση για Open κατάσταση χωρίς info εικόνα' {
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

            # Should return 2 because both poseidonia and isthmia have an open image and we no longer skip them
            $result.Count | Should -Be 2

            # Verify the warning log message was written
            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
                $Message -like '*Λείπει η εικόνα info.php*'
            } -Times 2 -Scope It
        }

    }

}

