Import-Module -Name "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe -Name 'Get-BridgeImage' -Fixture {
    BeforeAll -Scriptblock {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"
        $script:Config = New-BridgeConfiguration
    }

    Context -Name 'Ισθμία' -Fixture {
        It -Name 'Επιστρέφει εικόνες από valid HTML block' -Test {
            $html = @'
<div class="panel panel-primary">
<div class="panel-heading">
    <h4><b>ΙΣΘΜΊΑ</b></h4>
</div>
<div class="panel-body">
<div class="form-group">
<center>
        <img src="image-bridge-open-no-schedule.php?123456">
        <img src="image-bridge-open-no-schedule-info.php?123456">
      </center>
    </div>
  </div>
</div>
'@
            $result = Get-BridgeImage -Configuration $script:Config -HtmlContent $html -Location 'isthmia'
            $result.Count | Should -Be -ExpectedValue 2
            $result[0].src | Should -Match -RegularExpression 'no-schedule'
        }
        It -Name 'Επιστρέφει Exception αν δεν βρεθεί matching block' -Test {
            $html = '<div>Κάτι άλλο</div>'
            { Get-BridgeImage -Configuration $script:Config -HtmlContent $html -Location 'isthmia' } | Should -Throw -ExpectedMessage "Δεν βρέθηκε block για τη θέση isthmia."
        }


        It -Name 'Επιστρέφει εικόνες όταν η HTML χρησιμοποιεί μονά εισαγωγικά, επιπλέον classes, ή lowercase tags' -Test {
            $html = @'
<DIV class='panel panel-primary flex-row'>
<div class="panel-heading">
    <h4><b>ισθμία</b></h4>
</div>
<div class="panel-body">
    <img class="img-fluid" src='image-bridge-open-no-schedule.php?123456' />
</div>
</DIV>
'@
            $result = Get-BridgeImage -Configuration $script:Config -HtmlContent $html -Location 'isthmia'
            $result.Count | Should -Be -ExpectedValue 1
            $result[0].src | Should -Be -ExpectedValue 'image-bridge-open-no-schedule.php?123456'
        }

        It -Name 'Διατηρεί την εικόνα info.php?12345 από πραγματικό HTML ανοιχτής γέφυρας' -Test {
            $html = @'
<div class="panel panel-primary">
<div class="panel-heading">
    <h4><b>ΙΣΘΜΊΑ</b></h4>
</div>
<div class="panel-body">
    <img src="image-bridge-open-no-schedule.php?12345">
    <img src="info.php?12345">
    <img src="logo.png">
</div>
</div>
'@
            $result = Get-BridgeImage -Configuration $script:Config -HtmlContent $html -Location 'isthmia'
            $result.Count | Should -Be -ExpectedValue 2
            $result[0].src | Should -Be -ExpectedValue 'image-bridge-open-no-schedule.php?12345'
            $result[1].src | Should -Be -ExpectedValue 'info.php?12345'
        }
    }
}
