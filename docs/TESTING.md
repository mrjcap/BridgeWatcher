# Testing & CI Verification Guide

This guide documents BridgeWatcher's testing architecture, local verification entry points, CI performance budgets, and test-value review policy.

## Verification Entry Points

### Full Local Pre-Commit Gate

Run the standard gate before every commit:

```powershell
pwsh -NoProfile -File ./gate.ps1
```

Confirm both exit code `0` and `GATE PASSED`.

### Explicit Integration Verification

The default `Tests/PesterConfiguration.psd1` excludes `Integration`-tagged tests (`Tests/Integration.Tests.ps1`). Run the full suite including integration tests with:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -IntegrationOnly -SkipCoverage
```

Or run both unit and integration tests together:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -IncludeIntegration -ShardCount 2 -RunAllShardsInParallel
```

### Process-Isolated Sharding & Randomized Order

BridgeWatcher tests mutate process-wide environment variables (`$env:IsLegacyPowerShell`, `$env:API_KEY`, `$env:POAPI_KEY`, `$env:POUSER_KEY`, `$env:BRIDGEWATCHER_OUT`) and global helpers, so parallel execution uses **process-isolated shards** matched to physical CPU cores via `scripts/Invoke-TestSuite.ps1`:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -ShardCount 2 -RunAllShardsInParallel -Shuffle
```

Every CI run prints its deterministic shuffle seed and exact reproduction command:

```powershell
pwsh -NoProfile -File ./scripts/Invoke-TestSuite.ps1 -ShardCount 2 -RunAllShardsInParallel -Shuffle -Seed <seed>
```

Each shard runs in an isolated child `pwsh` process with dedicated `TMPDIR`/`TEMP`/`TMP` directories. Command-level code coverage is merged across all shards while asserting identical command denominators across the full module scope (`BridgeWatcher/Public/*.ps1`, `BridgeWatcher/Private/*.ps1`) and enforcing the 100% coverage requirement.

### Historical Per-File Timings

Successful `main` CI runs record per-file durations (`test-timings.json`) to balance shards using longest-processing-time-first (LPT) scheduling. Unmeasured or newly added test files automatically fall back to a default weight (`0.5s`) and are verified by the shard inventory completeness check so no tracked test can be omitted or duplicated.

## CI Performance Budgets

| Scope | Enforced Budget | Notes |
|---|---:|---|
| Runner waiting | < 5s (target) | Monitored via workflow telemetry |
| Job setup | <= 15s | Enforced per job |
| PowerShell AST parse & module manifest validation | <= 5s | Enforced in `static-checks` |
| Pester sharded test execution | <= 30s | Enforced via `-MaxDurationSeconds 30` |
| Slowest required PR job | <= 35s | Enforced per PR job after correctness checks complete |
| End-to-end PR feedback | < 60s p50, < 120s p95 | Measured from triggering event to all required checks |

Correctness results are always preserved and printed before a job fails on a performance budget overrun.

## Two-Week Test Value Observation Policy

Before proposing deletion or consolidation of any existing test, contributors must observe and classify every test failure fixed over a **two-week observation window** into one of three categories:

1. **Behavioral regression caught**: The failure prevented a real user-facing or contract defect from reaching `main`.
2. **Implementation-detail change detector**: The failure broke solely due to internal refactoring while meaningful behavior was unchanged and still verified elsewhere.
3. **Test, environment, or infrastructure defect**: The failure was caused by test isolation bugs, external network/service issues, or runner/tooling infrastructure.

### Deletion & Replacement Rules

- Never delete a test solely because it is slow or inconvenient.
- Never delete authorization, privacy, security, migration, or concurrency tests.
- Propose test removal or replacement only after the two-week evidence log demonstrates that the same meaningful behavior remains covered, and submit the proposed deletion for explicit maintainer review and approval.
- Record failure classifications during the observation period in PR descriptions or an issue tracker table with columns: `Date | PR/Commit | Test File | Classification | Root Cause | Action Taken`.
