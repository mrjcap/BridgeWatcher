# BridgeWatcher Domain Context

Context for monitoring Isthmia and Poseidonia bridge statuses, parsing schedule notices, and sending alerts.

## Language

**Bridge Image / Schedule Image**:
A graphic notice posted by the bridge operator to announce scheduled closures. It contains no live camera stream.
_Avoid_: Camera feed, live stream

**Empty OCR Result**:
A scenario where vision analysis completes successfully but extracts zero text tokens, yielding $null. Callers
distinguish unreadable text from upstream service outages without throwing exceptions.
_Avoid_: OCR error, parse failure

**Outage Tolerance**:
The maximum time window during which the daemon tolerates upstream bridge website outages before terminating.
_Avoid_: Downtime limit, retry budget

**Missing Schedule Image**:
A state where status indicates scheduled closure but the referenced graphic file returns 404 Not Found.
_Avoid_: Image broken, missing asset

**Strict Date Format Rule**:
The requirement enforcing explicit dd/MM/yyyy HH:mm timestamps for schedule validity.
_Avoid_: Date pattern, loose parsing

**Expired Schedule Persistence**:
Maintaining original advice when a schedule expires if the underlying image hash remains unchanged.
_Avoid_: Cached schedule, stale notice

**State Backfill**:
Enriching current bridge records with schedule metadata and image hashes from prior state when notices do not change.
_Avoid_: State sync, property copy

**Bridge Diff Event**:
A structured event emitted by status comparison that captures a verified state transition for a bridge.
_Avoid_: State delta, notification object

**Boot-Up Broadcast**:
Initial notification broadcast sent for all detected bridges upon cold start when no prior state file exists.
_Avoid_: Startup ping, initial sync

**Bridge State Snapshot**:
The persisted JSON file holding the most recent known state of each monitored bridge for comparison on the next polling
cycle.
_Avoid_: Snapshot history, audit log, historical database

**Schedule Image Hash**:
The MD5 digest of a schedule image's raw bytes, computed during status retrieval to detect updated closure schedules
without invoking OCR on unchanged notices.
_Avoid_: Image etag, cache key, file checksum
