# BridgeWatcher

## about_BridgeWatcher

## SHORT DESCRIPTION

BridgeWatcher monitors the submersible bridges at the Corinth Canal, parses schedule updates, and dispatches alerts.

## LONG DESCRIPTION

BridgeWatcher periodically scrapes the public status page for the Poseidonia and Isthmia submersible bridges.
When a bridge closes on a published schedule, the module retrieves the schedule notice image, calls the Google
Vision API for text detection (OCR), parses the closure timeframe, and delivers push notifications via Pushover.

State changes are tracked across polling iterations and persisted to an atomic JSON snapshot file.

## EXAMPLES

Start continuous monitoring:

```powershell
Get-BridgeStatusMonitor -OutputFile './BridgeStatusSnapshot.json' `
    -ApiKey $env:GOOGLE_VISION_API_KEY `
    -PoUserKey $env:PUSHOVER_USER_KEY `
    -PoApiKey $env:PUSHOVER_API_KEY
```

Fetch current status once:

```powershell
Get-BridgeStatus -Configuration (New-BridgeConfiguration)
```

## NOTE

BridgeWatcher requires an active internet connection to query topvision.gr and Google Cloud Vision APIs.

## SEE ALSO

- Get-BridgeStatus
- Get-BridgeStatusMonitor
- Update-BridgeStatus
- Invoke-BridgeStatusComparison
- Send-BridgePushover

## KEYWORDS

- BridgeWatcher
- Corinth
- Canal
- Bridge
