if (-not (Get-Module -Name 'BridgeWatcher')) {
    $ModulePath = "$PSScriptRoot/modules/BridgeWatcher/BridgeWatcher.psd1"
    if (-not (Test-Path -Path $ModulePath)) {
        $ModulePath = "$PSScriptRoot/BridgeWatcher/BridgeWatcher.psd1"
    }
    Import-Module -Name $ModulePath -Force -Verbose
}

$API_KEY = if ($Env:API_KEY) { $Env:API_KEY.Trim() } else { $null }
$POAPI_KEY = if ($Env:POAPI_KEY) { $Env:POAPI_KEY.Trim() } else { $null }
$POUSER_KEY = if ($Env:POUSER_KEY) { $Env:POUSER_KEY.Trim() } else { $null }

$SecretsDir = $Env:BRIDGEWATCHER_SECRETS_DIR
if ([string]::IsNullOrWhiteSpace($SecretsDir)) {
    $SecretsDir = '/run/secrets'
}

if ([string]::IsNullOrWhiteSpace($API_KEY)) {
    foreach ($secretName in @('api_key', 'API_KEY')) {
        $secretPath = Join-Path -Path $SecretsDir -ChildPath $secretName
        if (Test-Path -Path $secretPath) {
            $API_KEY = (Get-Content -Path $secretPath -Raw).Trim()
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($POAPI_KEY)) {
    foreach ($secretName in @('pushover_token', 'PUSHOVER_TOKEN')) {
        $secretPath = Join-Path -Path $SecretsDir -ChildPath $secretName
        if (Test-Path -Path $secretPath) {
            $POAPI_KEY = (Get-Content -Path $secretPath -Raw).Trim()
            break
        }
    }
}
if ([string]::IsNullOrWhiteSpace($POUSER_KEY)) {
    foreach ($secretName in @('pushover_user', 'PUSHOVER_USER')) {
        $secretPath = Join-Path -Path $SecretsDir -ChildPath $secretName
        if (Test-Path -Path $secretPath) {
            $POUSER_KEY = (Get-Content -Path $secretPath -Raw).Trim()
            break
        }
    }
}

if (-not $API_KEY -or -not $POAPI_KEY -or -not $POUSER_KEY) {
    throw 'One or more secrets are missing or empty'
}

$OutDir = $Env:BRIDGEWATCHER_OUT
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = '/app/logs'
}

if (-not (Test-Path -Path $OutDir)) {
    New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
}
$configurationSplat = @{
    LogDirectory = $OutDir
}
$ConfigurationPath = $Env:BRIDGEWATCHER_CONFIG_PATH
if (-not [string]::IsNullOrWhiteSpace($ConfigurationPath)) {
    $ConfigurationPath = $ConfigurationPath.Trim()
    if (-not (Test-Path -LiteralPath $ConfigurationPath -PathType Leaf)) {
        throw [System.IO.FileNotFoundException]::new("BRIDGEWATCHER_CONFIG_PATH does not point to a file: $ConfigurationPath", $ConfigurationPath)
    }
    $configurationSplat['ConfigurationPath'] = $ConfigurationPath
}
$Configuration = New-BridgeConfiguration @configurationSplat
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
    Write-Error -Message "Monitor failed: $_"
    try {
        Send-BridgePushover -Configuration $Configuration -PoUserKey $POUSER_KEY -PoApiKey $POAPI_KEY -Message "⚠️ BridgeWatcher monitor failed: $($_.Exception.Message)" -Title 'BridgeWatcher Alert' -Priority 1
    } catch {
        Write-Warning -Message "Failed to send failure alert: $($_.Exception.Message)"
    }
    exit 1
}

