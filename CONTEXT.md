# BridgeWatcher Domain Context

## Glossary

| Term | Definition |
| --- | --- |
| **Bridge Image / Schedule Image** | A graphic image (not a live camera feed) posted by the bridge operator to announce scheduled closures. It does not contain camera noise or glare. |
| **Empty OCR Result** | A scenario where the Google Cloud Vision API successfully processes a Bridge Image but finds no text. This causes an intentional error that is caught by the notification system to send a specialized "OCR Failed, see image" message instead of failing the daemon loop. |
| **Outage Tolerance** | The time window (e.g., 60 minutes) during which the daemon gracefully handles upstream failures (like the topvision website being offline) without completely aborting. If this threshold is exceeded, a terminating error is triggered. |
| **Missing Schedule Image** | A state where the HTML indicates a scheduled closure but the referenced image file returns a 404 Not Found (e.g., operator forgot to upload it). This is treated as a graceful warning (`ImageHash` remains `$null`) rather than a fatal system failure. |
| **Strict Date Format Rule** | The system enforces strict matching of a `dd/MM/yyyy HH:mm` pattern for OCR schedule extraction. Misformatted or missing dates are intentionally rejected. |
| **Expired Schedule Persistence** | If a bridge schedule expires but the image hash remains unchanged, the system intentionally maintains the original binary "Do Not Wait" advice. It relies entirely on detecting a new image hash to trigger a fresh OCR pass. |
| **Boot-Up Broadcast** | Upon a fresh boot where the local state JSON is missing, the daemon intentionally treats all bridges as "new" and sends a notification broadcast for their current state. This serves to verify that the service started successfully. |
