# Comparison pipeline owns state backfill

Invoke-BridgeStatusComparison owns state enrichment and metadata backfill from previous bridge records during
comparison. Update-BridgeStatus avoids pre-comparison state mutation. This prevents masked state changes, preserves
detection of failed image downloads, and localizes enrichment logic to the comparison pipeline.
