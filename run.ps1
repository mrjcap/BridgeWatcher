$ModulePath = "$PSScriptRoot/modules/BridgeWatcher/BridgeWatcher.psd1"
if (-not (Test-Path $ModulePath)) {
    $ModulePath = "$PSScriptRoot/BridgeWatcher/BridgeWatcher.psd1"
}
Import-Module $ModulePath -Force -Verbose

$API_KEY = if ($Env:API_KEY) { $Env:API_KEY.Trim() } else { $null }
$POAPI_KEY = if ($Env:POAPI_KEY) { $Env:POAPI_KEY.Trim() } else { $null }
$POUSER_KEY = if ($Env:POUSER_KEY) { $Env:POUSER_KEY.Trim() } else { $null }

if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    foreach ($secretPath in @('/run/secrets/api_key', '/run/secrets/API_KEY')) {
        if (Test-Path $secretPath) {
            $API_KEY = (Get-Content $secretPath -Raw).Trim()
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($POAPI_KEY)) {
    foreach ($secretPath in @('/run/secrets/pushover_token', '/run/secrets/PUSHOVER_TOKEN')) {
        if (Test-Path $secretPath) {
            $POAPI_KEY = (Get-Content $secretPath -Raw).Trim()
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($POUSER_KEY)) {
    foreach ($secretPath in @('/run/secrets/pushover_user', '/run/secrets/PUSHOVER_USER')) {
        if (Test-Path $secretPath) {
            $POUSER_KEY = (Get-Content $secretPath -Raw).Trim()
            break
        }
    }
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
$Configuration = New-BridgeConfiguration -LogDirectory $OutDir
# Wrap το Get-BridgeStatusMonitor
try {
    $startBridgeStatusMonitorSplat = @{
        Configuration   = $Configuration
        IntervalSeconds = 300
        MaxIterations   = 0
        OutputFile      = "$OutDir/bridge_status.json"
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
        Send-BridgePushover -Configuration $Configuration -PoUserKey $POUSER_KEY -PoApiKey $POAPI_KEY -Message "⚠️ BridgeWatcher monitor failed: $($_.Exception.Message)" -Title 'BridgeWatcher Alert' -Priority 1
    } catch {
        Write-Warning "Failed to send failure alert: $($_.Exception.Message)"
    }
    exit 1  # Container θα κάνει restart αν έχεις --restart policy
}

