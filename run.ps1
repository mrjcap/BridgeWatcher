Import-Module 'C:\code\BridgeWatcher\BridgeWatcher\BridgeWatcher.psm1' -Force -Verbose

$API_KEY = Get-Secret -Name GoogleVisionAPI -AsPlainText
$POAPI_KEY = Get-Secret -Name POAPIKEY -AsPlainText
$POUSER_KEY = Get-Secret -Name POUSERKEY -AsPlainText

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
    # Send alert?
    # Retry logic?
    exit 1  # Container θα κάνει restart αν έχεις --restart policy
}
