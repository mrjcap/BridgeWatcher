# Pure comparison pipeline returning domain diff events

Invoke-BridgeStatusComparison acts as a pure transformation function that produces bridge diff events instead of
directly dispatching notifications. Update-BridgeStatus owns notification dispatch. This decouples state diffing
from Pushover delivery side effects and simplifies unit testing.
