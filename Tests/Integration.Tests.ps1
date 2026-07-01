$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Parent $here) + "\BridgeWatcher\BridgeWatcher.psm1"
Import-Module $sut -Force

Describe "Integration - Live Bridge HTML Parsing" -Tag 'Integration' {
    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Test-BridgeResult.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStatus.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeHtml.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRRequest.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeOCRRequestBody.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1"
    }

    It "Should successfully fetch and parse the live HTML from topvision.gr" {
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
            $status.GefyraName | Should -Match '^(Ποσειδων[ιί]α|Ισθμ[ιί]α)$'
            $status.GefyraStatus | Should -Not -BeNullOrEmpty
        }
    }
}
