$ModulePath = "$PSScriptRoot/modules/BridgeWatcher/BridgeWatcher.psd1"
if (-not (Test-Path $ModulePath)) {
    $ModulePath = "$PSScriptRoot/BridgeWatcher/BridgeWatcher.psd1"
}
Import-Module $ModulePath -Force -Verbose

$API_KEY = if ($Env:API_KEY) { $Env:API_KEY.Trim() } else { $null }
$POAPI_KEY = if ($Env:POAPI_KEY) { $Env:POAPI_KEY.Trim() } else { $null }
$POUSER_KEY = if ($Env:POUSER_KEY) { $Env:POUSER_KEY.Trim() } else { $null }

if ([string]::IsNullOrWhiteSpace($API_KEY) -and (Test-Path '/run/secrets/API_KEY')) {
    $API_KEY = (Get-Content '/run/secrets/API_KEY' -Raw).Trim()
}
if ([string]::IsNullOrWhiteSpace($POAPI_KEY) -and (Test-Path '/run/secrets/PUSHOVER_TOKEN')) {
    $POAPI_KEY = (Get-Content '/run/secrets/PUSHOVER_TOKEN' -Raw).Trim()
}
if ([string]::IsNullOrWhiteSpace($POUSER_KEY) -and (Test-Path '/run/secrets/PUSHOVER_USER')) {
    $POUSER_KEY = (Get-Content '/run/secrets/PUSHOVER_USER' -Raw).Trim()
}

if (-not $API_KEY -or -not $POAPI_KEY -or -not $POUSER_KEY) {
    throw 'One or more secrets are missing or empty'
}

# Χρήση του home directory του user για output
$OutDir = $Env:BRIDGEWATCHER_OUT
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = '/app/logs'
}

# Ensure output directory exists
if (-not (Test-Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
# Wrap το Get-BridgeStatusMonitor
try {
    $startBridgeStatusMonitorSplat = @{
        IntervalSeconds = 300
        MaxIterations   = 0
        OutputFile      = "$OutDir/bridge_status.json"
        LogDirectory    = '/app/logs'
        ApiKey          = $API_KEY
        PoApiKey        = $POAPI_KEY
        PoUserKey       = $POUSER_KEY
        Verbose         = $true
    }
    Get-BridgeStatusMonitor @startBridgeStatusMonitorSplat
} catch {
    Write-Error "Monitor failed: $_"
    # F-10: Alert on monitoring failure via Pushover
    try {
        Send-BridgePushover -PoUserKey $POUSER_KEY -PoApiKey $POAPI_KEY -Message "⚠️ BridgeWatcher monitor failed: $($_.Exception.Message)" -Title 'BridgeWatcher Alert' -Priority 1
    } catch {
        Write-Warning "Failed to send failure alert: $($_.Exception.Message)"
    }
    exit 1  # Container θα κάνει restart αν έχεις --restart policy
}

