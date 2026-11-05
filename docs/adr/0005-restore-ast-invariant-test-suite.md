# Automated AST invariant test suite restoration

Tests under Tests/Review parse the PowerShell Abstract Syntax Tree across module and test files to enforce
architectural rules defined in AGENTS.md. Restoring these test files with portable paths prevents regressions on
blocking heuristics such as prohibition of object-oriented constructs, presence of retry jitter, and cleanup of
disposable objects.
