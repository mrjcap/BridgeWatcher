# In-memory configuration defaults with optional JSON override

New-BridgeConfiguration constructs a self-contained PSCustomObject in memory with default URLs, status mappings,
and operational limits. Loading settings from an external JSON file via -ConfigurationPath is optional. This eliminates
runtime dependencies on untracked configuration files, ensures fresh repository checkouts work in CI pipelines, and
removes disk I/O from configuration initialization.
