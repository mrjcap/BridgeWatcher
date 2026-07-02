# BridgeWatcher.psm1
Set-StrictMode -Version Latest

#region Public Functions
. "$PSScriptRoot\Public\Get-BridgeStatus.ps1"
. "$PSScriptRoot\Public\Get-BridgePreviousStatus.ps1"
. "$PSScriptRoot\Public\Update-BridgeStatus.ps1"
. "$PSScriptRoot\Public\Invoke-BridgeStatusComparison.ps1"
. "$PSScriptRoot\Public\Send-BridgePushover.ps1"
. "$PSScriptRoot\Public\Get-BridgeStatusMonitor.ps1"
#endregion Public Functions

#region Private Functions
. "$PSScriptRoot\Private\New-BridgeConfiguration.ps1"
. "$PSScriptRoot\Private\ConvertFrom-BridgeOCRResult.ps1"
. "$PSScriptRoot\Private\ConvertTo-BridgeTimeRange.ps1"
. "$PSScriptRoot\Private\Export-BridgeStatusJson.ps1"
. "$PSScriptRoot\Private\ConvertTo-BridgeClosedDuration.ps1"
. "$PSScriptRoot\Private\Get-BridgeImage.ps1"
. "$PSScriptRoot\Private\Get-BridgeNameFromUri.ps1"
. "$PSScriptRoot\Private\Get-BridgeStatusAdvice.ps1"
. "$PSScriptRoot\Private\Get-BridgeStatusFromHtml.ps1"
. "$PSScriptRoot\Private\Invoke-BridgeClosedNotification.ps1"
. "$PSScriptRoot\Private\Invoke-BridgeOpenedNotification.ps1"
. "$PSScriptRoot\Private\Invoke-BridgeOCRGoogleCloud.ps1"
. "$PSScriptRoot\Private\Invoke-BridgeOCRRequest.ps1"
. "$PSScriptRoot\Private\Get-BridgeStatusObject.ps1"
. "$PSScriptRoot\Private\Send-BridgePushoverRequest.ps1"
. "$PSScriptRoot\Private\Write-BridgeLog.ps1"
. "$PSScriptRoot\Private\Resolve-BridgeStateForChange.ps1"
#endregion Private Functions

# Export only public functions
Export-ModuleMember -Function Get-BridgeStatus, Get-BridgePreviousStatus, Update-BridgeStatus, Invoke-BridgeStatusComparison, Send-BridgePushover, Get-BridgeStatusMonitor
