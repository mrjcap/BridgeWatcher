$files = @(
    'Tests\Invoke-BridgeStatusComparison.Tests.ps1',
    'BridgeWatcher\Private\ConvertFrom-BridgeOCRResult.ps1',
    'BridgeWatcher\Private\Invoke-BridgeClosedNotification.ps1',
    'BridgeWatcher\Private\Write-BridgeLog.ps1',
    'BridgeWatcher\BridgeWatcher.psm1',
    'BridgeWatcher\Private\Send-BridgePushoverRequest.ps1',
    'BridgeWatcher\Private\Invoke-BridgeOCRRequest.ps1',
    'BridgeWatcher\Private\ConvertTo-BridgeTimeRange.ps1',
    'BridgeWatcher\Public\Send-BridgePushover.ps1',
    'BridgeWatcher\Private\New-BridgeConfiguration.ps1',
    'Tests\New-BridgeConfiguration.Tests.ps1',
    'Tests\Review\PesterScope.Tests.ps1',
    'Tests\Review\SilentFailure.Tests.ps1',
    'Tests\Review\LoopFailureContract.Tests.ps1'
)
$utf8BOM = New-Object System.Text.UTF8Encoding $true
foreach ($f in $files) {
    $path = Join-Path $PSScriptRoot $f
    $content = [System.IO.File]::ReadAllText($path)
    [System.IO.File]::WriteAllText($path, $content, $utf8BOM)
    Write-Output "BOM restored: $f"
}
Write-Output 'BOM sweep complete.'
