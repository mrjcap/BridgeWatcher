Import-Module "$PSScriptRoot\..\BridgeWatcher\BridgeWatcher.psm1" -Force

InModuleScope 'BridgeWatcher' {
    Describe 'Get-BridgeImage' {
        Context 'Ισθμία' {
            It 'Επιστρέφει εικόνες από valid HTML block' {
                $html = @'
<div class="panel panel-primary">
<div class="panel-heading">
    <h4><b>ΙΣΘΜΙΑ</b></h4>
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
                $result    = Get-BridgeImage -HtmlContent $html -Location 'isthmia'
                $result.Count | Should -Be 2
                $result[0].src | Should -Match 'no-schedule'
            }
            It 'Επιστρέφει Exception αν δεν βρεθεί matching block' {
                $html      = '<div>Κάτι άλλο</div>'
                {Get-BridgeImage -HtmlContent $html -Location 'isthmia' } | Should -Throw "Δεν βρέθηκε block για τη θέση isthmia."

            }
        }
    }
}