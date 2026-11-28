Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force



Describe -Name 'Get-BridgeStatusFromHtml' -Fixture {

    BeforeAll -Scriptblock {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        $script:Config = New-BridgeConfiguration
    }




    Context -Name 'Όταν δεν βρίσκονται εικόνες' -Fixture {

        It -Name 'Πετάει σφάλμα BridgeImagesNotFound όταν δεν επιστρέφονται εικόνες' -Test {


            Mock -CommandName Get-BridgeImage -MockWith { $null }

            $html = '<html><body>no images</body></html>'

            $timestamp = '2025-04-18T08:00:00'

            $errs = @()
            Get-BridgeStatusFromHtml -Configuration $script:Config -Html $html -Timestamp $timestamp -ErrorVariable errs -ErrorAction SilentlyContinue
            $matchFound = [bool]($errs.FullyQualifiedErrorId -match 'BridgeImagesNotFound')
            $matchFound | Should -Be -ExpectedValue $true

        }

        It -Name 'Πετάει σφάλμα BridgeStatusPatternNotFound όταν οι εικόνες δεν ταιριάζουν σε κανένα πρότυπο' -Test {
            Mock -CommandName Get-BridgeImage -MockWith {
                return [System.Collections.ArrayList]@(
                    [pscustomobject]@{ src = 'unknown-banner.jpg' }
                )
            }
            Mock -CommandName Write-BridgeLog -MockWith { }

            $html = '<html><body>unrecognized images</body></html>'
            $timestamp = '2025-04-18T08:00:00'

            $errs = @()
            $result = Get-BridgeStatusFromHtml -Configuration $script:Config -Html $html -Timestamp $timestamp -ErrorVariable errs -ErrorAction SilentlyContinue
            $result | Should -BeNullOrEmpty
            $matchFound = [bool]($errs.FullyQualifiedErrorId -match 'BridgeStatusPatternNotFound')
            $matchFound | Should -Be -ExpectedValue $true
            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
                $Message -like '*Η γέφυρα θα θεωρηθεί Ανοιχτή*'
            } -Times 0 -Exactly -Scope It
        }

    }

    Context -Name 'Όταν υπάρχει Open image με ή χωρίς info εικόνα' -Fixture {

        It -Name 'Δεν καταγράφει προειδοποίηση info.php όταν υπάρχει εικόνα info.php?12345 στο HTML' -Test {
            Mock -CommandName Write-BridgeLog -MockWith { }

            $html = @'
<div class="panel panel-primary">
    <h4><b>ΠΟΣΕΙΔΩΝΊΑ</b></h4>
    <img src="image-bridge-open-no-schedule.php?12345">
    <img src="info.php?12345">
</div>
<div class="panel panel-primary">
    <h4><b>ΙΣΘΜΊΑ</b></h4>
    <img src="image-bridge-open-no-schedule.php?12345">
    <img src="info.php?12345">
</div>
'@
            $timestamp = '2025-04-18T08:00:00'

            $result = Get-BridgeStatusFromHtml -Html $html -Timestamp $timestamp -Configuration $script:Config

            $result.Count | Should -Be -ExpectedValue 2
            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
                $Message -like '*Λείπει η εικόνα info.php*'
            } -Times 0 -Exactly -Scope It
        }

        It -Name 'Δημιουργεί προειδοποίηση για Open κατάσταση χωρίς info εικόνα' -Test {
            $config = New-BridgeConfiguration

            Mock -CommandName Get-BridgeImage -MockWith {
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

            Mock -CommandName Write-BridgeLog -MockWith { }

            $html = '<html><body>dummy</body></html>'
            $timestamp = '2025-04-18T08:00:00'

            $result = Get-BridgeStatusFromHtml -Html $html -Timestamp $timestamp -Configuration $config

            $result.Count | Should -Be -ExpectedValue 2

            Should -Invoke -CommandName Write-BridgeLog -ParameterFilter {
                $Message -like '*Λείπει η εικόνα info.php*'
            } -Times 2 -Scope It
        }

    }

}

