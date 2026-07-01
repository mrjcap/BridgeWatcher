$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Parent $here) + "\BridgeWatcher\BridgeWatcher.psm1"
Import-Module $sut -Force

Describe "Integration - Live Bridge HTML Parsing" -Tag 'Integration' {
    It "Should successfully fetch and parse the live HTML from topvision.gr" {
        InModuleScope 'BridgeWatcher' {
            $config = New-BridgeConfiguration

            $getBridgeHtmlSplat = @{
                Uri           = $config.SourceUrl
                Configuration = $config
            }
            $htmlResult = Get-BridgeHtml @getBridgeHtmlSplat

            $htmlResult.Success | Should -Be $true
            $htmlResult.Data | Should -Not -BeNullOrEmpty

            $getBridgeStatusFromHtmlSplat = @{
                Html          = $htmlResult.Data
                Timestamp     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')
                Configuration = $config
            }
            $statusResults = Get-BridgeStatusFromHtml @getBridgeStatusFromHtmlSplat

            $statusResults | Should -Not -BeNullOrEmpty
            $statusResults.Count | Should -BeGreaterThan 0

            foreach ($status in $statusResults) {
                $status.GefyraName | Should -Match '^(Ποσειδωνια|Ισθμια)$'
                $status.GefyraStatus | Should -Not -BeNullOrEmpty
            }
        }
    }
}
