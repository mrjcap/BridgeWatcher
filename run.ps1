[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSAvoidUsingConvertToSecureStringWithPlainText', '',
    Justification = 'Secrets are read from Docker secret files at runtime (/run/secrets/*). ConvertTo-SecureString is used only to satisfy cmdlet parameter types; the source is never a hardcoded or user-supplied plaintext value.'
)]
param()

[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
Import-Module './modules/BridgeWatcher/BridgeWatcher.psm1' -Force -Verbose

$API_KEY = ConvertTo-SecureString (Get-Content '/run/secrets/API_KEY' -Raw) -AsPlainText -Force
$POAPI_KEY = ConvertTo-SecureString (Get-Content '/run/secrets/POAPI_KEY' -Raw) -AsPlainText -Force
$POUSER_KEY = ConvertTo-SecureString (Get-Content '/run/secrets/POUSER_KEY' -Raw) -AsPlainText -Force

if (-not $API_KEY -or -not $POAPI_KEY -or -not $POUSER_KEY) {
    throw 'One or more secrets are missing or empty'
}

# Χρήση του home directory του user για output
$OutDir = $Env:BRIDGEWATCHER_OUT
if ([string]::IsNullOrWhiteSpace($OutDir)) {
    $OutDir = '/home/appuser/output'
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

