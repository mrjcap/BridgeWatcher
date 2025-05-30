Import-Module '/scripts/modules/BridgeWatcher/BridgeWatcher.psm1' -Force -Verbose

$API_KEY       = Get-Content '/run/secrets/API_KEY' -Raw
$POAPI_KEY     = Get-Content '/run/secrets/POAPI_KEY' -Raw
$POUSER_KEY    = Get-Content '/run/secrets/POUSER_KEY' -Raw

if (-not $API_KEY -or -not $POAPI_KEY -or -not $POUSER_KEY) {
    throw 'One or more secrets are missing or empty'
}

$OutDir    = $Env:BRIDGEWATCHER_OUT
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir    = '/tmp'
}
# Wrap το Start-BridgeStatusMonitor
try {
    $startBridgeStatusMonitorSplat = @{
        IntervalSeconds = 300
        MaxIterations   = 0
        OutputFile      = "$OutDir/bridge_status.json"
        ApiKey          = $API_KEY
        PoApiKey        = $POAPI_KEY
        PoUserKey       = $POUSER_KEY
        Verbose         = $true
    }
    Start-BridgeStatusMonitor @startBridgeStatusMonitorSplat
} catch {
    Write-Error "Monitor failed: $_"
    # Send alert?
    # Retry logic?
    exit 1  # Container θα κάνει restart αν έχεις --restart policy
}
