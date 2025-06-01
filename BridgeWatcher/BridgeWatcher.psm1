# BridgeWatcher.psm1

# region Public Functions
. "$PSScriptRoot\Public\Get-BridgeStatus.ps1"
. "$PSScriptRoot\Public\Get-BridgePreviousStatus.ps1"
. "$PSScriptRoot\Public\Get-BridgeStatusComparison.ps1"
. "$PSScriptRoot\Public\Invoke-BridgeStatusComparison.ps1"
. "$PSScriptRoot\Public\Send-BridgePushover.ps1"
. "$PSScriptRoot\Public\Get-BridgeStatusMonitor.ps1"

# region Private Functions
. "$PSScriptRoot\Private\ConvertFrom-BridgeOCRResult.ps1"
. "$PSScriptRoot\Private\ConvertTo-BridgeTimeRange.ps1"
. "$PSScriptRoot\Private\Export-BridgeStatusJson.ps1"
. "$PSScriptRoot\Private\ConvertTo-BridgeClosedDuration.ps1"
. "$PSScriptRoot\Private\Get-BridgeImage.ps1"
. "$PSScriptRoot\Private\Get-BridgeNameFromUri.ps1"
. "$PSScriptRoot\Private\Get-BridgeStatusAdvice.ps1"
. "$PSScriptRoot\Private\Get-BridgeStatusFromHtml.ps1"
. "$PSScriptRoot\Private\Get-BridgeHtml.ps1"
. "$PSScriptRoot\Private\Invoke-BridgeClosedNotification.ps1"
. "$PSScriptRoot\Private\Invoke-BridgeOpenedNotification.ps1"
. "$PSScriptRoot\Private\Invoke-BridgeOCRGoogleCloud.ps1"
. "$PSScriptRoot\Private\Invoke-BridgeOCRRequest.ps1"
. "$PSScriptRoot\Private\Get-BridgeStatusObject.ps1"
. "$PSScriptRoot\Private\Get-BridgeOCRRequestBody.ps1"
. "$PSScriptRoot\Private\Get-BridgePushoverPayload.ps1"
. "$PSScriptRoot\Private\Resolve-BridgeStatus.ps1"
. "$PSScriptRoot\Private\Send-BridgePushoverRequest.ps1"
. "$PSScriptRoot\Private\Send-BridgeNotification.ps1"
. "$PSScriptRoot\Private\Write-BridgeStage.ps1"
. "$PSScriptRoot\Private\Write-BridgeLog.ps1"

# Export only public functions
Export-ModuleMember -Function Get-BridgeStatus,Get-BridgePreviousStatus,Get-BridgeStatusComparison,Invoke-BridgeStatusComparison,Send-BridgePushover,Get-BridgeStatusMonitor