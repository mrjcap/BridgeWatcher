# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |
| < 1.0   | :x:                |

## Reporting a Vulnerability

**Do not open public issues for security vulnerabilities.**

Please report vulnerabilities through
[GitHub Security Advisories](../../security/advisories/new) (private).

### What to Include

- Description of the vulnerability and its potential impact
- Steps to reproduce or a proof-of-concept
- Affected versions and components
- Any suggested remediation (optional)

### Response SLA

| Stage               | Timeframe  |
| ------------------- | ---------- |
| Acknowledgement     | 48 hours   |
| Initial assessment  | 7 days     |
| Fix or advisory     | Determined after assessment |

We will coordinate disclosure with you and credit reporters unless
anonymity is requested.

## Security Controls

BridgeWatcher implements the following security controls:

- **Container isolation** — All services run as non-root users
  inside Docker containers.
- **Secrets management** — Credentials are injected via Docker
  secrets; never baked into images.
- **Static analysis (SAST)** — Semgrep, Codacy, and
  PSScriptAnalyzer run in CI on every pull request.
- **Container scanning** — Trivy scans images for known CVEs
  before deployment.
- **Dependency pinning** — All dependencies use pinned versions
  to prevent supply-chain drift.
- **Transport encryption** — All external communication requires
  TLS 1.2 or higher.

## Credential Handling

Credentials **must never** be committed to source control or
written to application logs.

### Approved Methods

| Method                       | Use Case                    |
| ---------------------------- | --------------------------- |
| Docker secrets               | Production containers       |
| Environment variables        | Local development / CI      |
| `SecretManagement` module    | PowerShell script contexts  |

### Guidelines

- Rotate secrets on a regular schedule and after any suspected
  compromise.
- Use read-only secret mounts where possible.
- Sanitize or redact credentials before logging any API request
  or response payloads.

## Cloud Services

BridgeWatcher uses the following external cloud services:

| Service | Provider | Data Sent | Purpose |
| ------- | -------- | --------- | ------- |
| Cloud Vision API | Google Cloud | Bridge status images (public) | OCR text extraction |
| Pushover API | Pushover | Notification text (non-sensitive) | Push notifications |

### Cloud Security Requirements

- API keys are passed via HTTP headers, never in URL query strings.
- All API communication uses TLS 1.2 or higher.
- API keys must be restricted by IP or referrer in the Google Cloud
  Console where possible.
- No personal data is transmitted to any cloud service.
- Cloud service credentials are managed per the Credential Handling
  section above.

## Compliance

BridgeWatcher's credential and access controls align with
**NIST SP 800-53 IA-5** (Authenticator Management), covering:

- Protection of authenticators at rest and in transit
- Minimum complexity and rotation requirements
- Restriction of authenticator embedding in code or logs

### Compliance Review Process

| Activity | Frequency | Method |
| -------- | --------- | ------ |
| SAST and container scanning | Every PR | Automated via CI (Semgrep, Trivy) |
| PSScriptAnalyzer security rules | Every PR | Automated via CI |
| Risk assessment review | Annual | Manual review per `docs/RISK-ASSESSMENT.md` |
| Credential rotation audit | Annual | Manual check of API key age and access logs |
| IR runbook review | After each incident or annually | Manual review per `docs/INCIDENT-RESPONSE.md` |
