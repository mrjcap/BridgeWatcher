# Application Security Requirements

This document defines the security requirements for
BridgeWatcher, aligned with ISO 27001:2022 Annex A
control A.8.26 (Application Security Requirements).

## 1. Input Validation

| Requirement | Implementation | Enforcement |
| --- | --- | --- |
| All function parameters must declare types | `[string]`, `[int]`, `[PSCustomObject]` | PSScriptAnalyzer |
| Mandatory params use `[Parameter(Mandatory)]` | Applied to all required params | Pester tests |
| String params use `[ValidateNotNullOrEmpty()]` | Applied to credential and content params | PSScriptAnalyzer |
| URL params must validate format | `[ValidateScript({ $_ -match '^https?://' })]` | Runtime validation |
| File paths must be validated before use | `Test-Path` checks before file operations | Code review |

## 2. Error Handling

| Requirement | Implementation |
| --- | --- |
| All API calls must use `try/catch` blocks | Implemented in all HTTP-calling functions |
| Errors must use structured `ErrorRecord` objects | `New-BridgeResult` pattern with error codes |
| API failures must not expose credentials | URLs in error records contain no API keys |
| Errors must be logged with severity level | `Write-BridgeLog` with Warning/Error levels |

## 3. Credential Handling

| Requirement | Implementation |
| --- | --- |
| API keys must not appear in URLs | `X-Goog-Api-Key` HTTP header |
| Credentials from Docker secrets or env vars | `/run/secrets/` mount pattern |
| Credential params have suppression justification | `SuppressMessageAttribute` on all key params |
| Credentials must never be logged | Logging excludes credential values |

## 4. Transport Security

| Requirement | Implementation |
| --- | --- |
| All external API calls must use HTTPS | Hardcoded `https://` URLs |
| TLS version must be 1.2 or higher | `[Net.ServicePointManager]::SecurityProtocol` |
| Certificate validation must not be disabled | Default .NET validation preserved |

## 5. Data Integrity

| Requirement | Implementation |
| --- | --- |
| JSON output must use atomic writes | Temp file + `Move-Item` rename pattern |
| Status files must be validated on read | `Test-Path` and JSON parse validation |
| Previous status must survive process restart | Persisted to `bridge_status.json` |

## 6. Container Security

| Requirement | Implementation |
| --- | --- |
| Container must run as non-root | `USER appuser` (UID 99) |
| Image must strip setuid/setgid binaries | `chmod a-s` in Dockerfile |
| Unnecessary ports must not be exposed | No EXPOSE directives active |
| Health check must validate output freshness | HEALTHCHECK with 10-minute threshold |

---

*Last reviewed: 2026-06-26*
*Review frequency: Annually or when architecture changes*
