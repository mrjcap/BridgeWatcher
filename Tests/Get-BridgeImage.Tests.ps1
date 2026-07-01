Import-Module "$PSScriptRoot/../BridgeWatcher/BridgeWatcher.psd1" -Force

Describe 'Get-BridgeImage' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"
    }

    Context 'Ισθμία' {
        It 'Επιστρέφει εικόνες από valid HTML block' {
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
            $result = Get-BridgeImage -HtmlContent $html -Location 'isthmia'
            $result.Count | Should -Be 2
            $result[0].src | Should -Match 'no-schedule'
        }
        It 'Επιστρέφει Exception αν δεν βρεθεί matching block' {
            $html = '<div>Κάτι άλλο</div>'
            { Get-BridgeImage -HtmlContent $html -Location 'isthmia' } | Should -Throw "Δεν βρέθηκε block για τη θέση isthmia."
        }


        It 'Επιστρέφει εικόνες όταν η HTML χρησιμοποιεί μονά εισαγωγικά, επιπλέον classes, ή lowercase tags' {
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
            $result = Get-BridgeImage -HtmlContent $html -Location 'isthmia'
            $result.Count | Should -Be 1
            $result[0].src | Should -Be 'image-bridge-open-no-schedule.php?123456'
        }
    }
}

