# Testing & CI Verification Guide

This guide covers BridgeWatcher's test architecture, local verification, CI timing reports, and test review policy.

## Verification Entry Points

### Full Local Pre-Commit Gate

Run the standard gate before every commit:

```powershell
pwsh -NoProfile -File ./gate.ps1
```

Confirm both exit code `0` and `GATE PASSED`.

### Explicit Integration Verification

The default `Tests/PesterConfiguration.psd1` excludes `Integration`-tagged tests (`Tests/Integration.Tests.ps1`).
Run the full suite including integration tests with:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -IntegrationOnly -SkipCoverage
```

Or run both unit and integration tests together:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -IncludeIntegration -ShardCount 2 -RunAllShardsInParallel
```

### Process-Isolated Sharding & Randomized Order

BridgeWatcher tests mutate process-wide environment variables (`$env:IsLegacyPowerShell`, `$env:API_KEY`,
`$env:POAPI_KEY`, `$env:POUSER_KEY`, `$env:BRIDGEWATCHER_OUT`) and global helpers. For parallel execution,
`scripts/Invoke-TestSuite.ps1` uses **process-isolated shards** matched to physical CPU cores:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -ShardCount 2 -RunAllShardsInParallel -Shuffle
```

Every CI run prints its deterministic shuffle seed and exact reproduction command:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -ShardCount 2 -RunAllShardsInParallel -Shuffle -Seed <seed>
```

Each shard runs in an isolated child `pwsh` process with dedicated `TMPDIR`/`TEMP`/`TMP` directories.
The merger checks that every shard reports the same command denominator across `BridgeWatcher/Public/*.ps1` and
`BridgeWatcher/Private/*.ps1`, then enforces 100% command coverage.

### Historical Per-File Timings

Successful `main` CI runs record per-file durations (`test-timings.json`) to balance shards using
longest-processing-time-first (LPT) scheduling. Unmeasured and new test files use a default weight (`0.5s`).
The shard inventory check ensures no tracked test is omitted or duplicated.

## CI Timing Reports

CI reports setup and execution times without failing jobs for exceeding a time budget. Tests, coverage, lint,
security scans, and Docker build and test checks still gate CI. For local runs, `scripts/Invoke-TestSuite.ps1`
accepts an optional `-MaxDurationSeconds` limit.

## Two-Week Test Value Observation Policy

Before proposing deletion or consolidation of a test, classify every test failure fixed over a
**two-week observation window** into one of three categories:

1. **Behavioral regression caught**: The failure prevented a real user-facing or contract defect from reaching `main`.
2. **Implementation-detail change detector**: The test failed after internal refactoring, but the behavior
   was unchanged and still verified elsewhere.
3. **Test, environment, or infrastructure defect**: The failure came from test isolation, an external service
   or network, or runner and tooling infrastructure.

### Deletion & Replacement Rules

- Never delete a test solely because it is slow or inconvenient.
- Never delete authorization, privacy, security, migration, or concurrency tests.
- Propose removal or replacement only after the two-week evidence log shows that the same behavior remains covered.
  Submit the proposed deletion for explicit maintainer review and approval.
- Record failure classifications during the observation period in PR descriptions or an issue tracker table with
  columns `Date | PR/Commit | Test File | Classification | Root Cause | Action Taken`.
