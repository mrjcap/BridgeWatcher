$here = Split-Path -Parent -Path $MyInvocation.MyCommand.Path

$sut = Join-Path -Path (Split-Path -Parent -Path $here) -ChildPath 'BridgeWatcher/BridgeWatcher.psd1'

Import-Module -Name $sut -Force



Describe -Name "Integration - Live Bridge HTML Parsing" -Tag 'Integration' -Fixture {

    BeforeAll -Scriptblock {
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



    It -Name "Should successfully fetch and parse the live HTML from topvision.gr" -Test {

        $config = New-BridgeConfiguration



        $response = Invoke-WebRequest -Uri $config.Urls.Source -UseBasicParsing -SkipHttpErrorCheck -ErrorAction 'Stop'
        $htmlResultData = $response.Content

        $blocked = $response.StatusCode -in 403, 429, 503, 508 -or
            ($htmlResultData -notmatch 'panel-primary' -and $htmlResultData -match '<title>\s*One moment, please')
        if ($blocked) {
            Set-ItResult -Skipped -Because "topvision.gr did not serve the bridge status (HTTP $($response.StatusCode), browser verification)"
            return
        }

        $response.StatusCode | Should -BeLessThan -ExpectedValue 400
        $htmlResultData | Should -Not -BeNullOrEmpty



        $getBridgeStatusFromHtmlSplat = @{

            Html          = $htmlResultData

            Timestamp     = (Get-Date).ToString('yyyy-MM-dd HH:mm:ss')

            Configuration = $config

        }

        $statusResults = Get-BridgeStatusFromHtml @getBridgeStatusFromHtmlSplat



        $statusResults | Should -Not -BeNullOrEmpty

        $statusResults.Count | Should -BeGreaterThan -ExpectedValue 0



        foreach ($status in $statusResults) {

            $status.GefyraName | Should -Match -RegularExpression '^(Ποσειδων[ιί]α|Ισθμ[ιί]α)$'

            $status.GefyraStatus | Should -Not -BeNullOrEmpty

        }

    }

}

