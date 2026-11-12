$here = Split-Path -Parent $MyInvocation.MyCommand.Path

$sut = (Split-Path -Parent $here) + "\BridgeWatcher\BridgeWatcher.psd1"

Import-Module $sut -Force



Describe "Integration - Live Bridge HTML Parsing" -Tag 'Integration' {

    BeforeAll {
        . "$PSScriptRoot/../BridgeWatcher/Private/New-BridgeConfiguration.ps1"



        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusFromHtml.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeImage.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Resolve-BridgeStateForChange.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeStatusObject.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Write-BridgeLog.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/Get-BridgeHttpExceptionInfo.ps1"
        . "$PSScriptRoot/../BridgeWatcher/Private/Invoke-BridgeOCRRequest.ps1"

        . "$PSScriptRoot/../BridgeWatcher/Private/ConvertFrom-BridgeOCRResult.ps1"
        $script:Config = New-BridgeConfiguration

    }



    It "Should successfully fetch and parse the live HTML from topvision.gr" {

        $config = New-BridgeConfiguration



        $response = Invoke-WebRequest -Uri $config.Urls.Source -UseBasicParsing -ErrorAction 'Stop'
        $htmlResultData = $response.Content

        $htmlResultData | Should -Not -BeNullOrEmpty



        $getBridgeStatusFromHtmlSplat = @{

            Html          = $htmlResultData

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

