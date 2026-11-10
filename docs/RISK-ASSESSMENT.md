# Risk assessment: BridgeWatcher

> Baseline risk assessment per NIST SP 800-30 Rev. 1
> *Guidelines for Conducting Risk Assessments*

## Scope

This document covers the BridgeWatcher application, a containerized bridge-status monitor that polls an
upstream website and publishes results via JSON snapshots and Pushover alerts.

## Risk register

| ID | Threat | Likelihood | Impact | Risk | Treatment |
| --- | --- | --- | --- | --- | --- |
| R-1 | API key exposure via logs | Low (mitigated) | High | MEDIUM | Mitigated: moved to HTTP header |
| R-2 | Upstream website serves unexpected content | Low | Medium | LOW | Accepted |
| R-3 | Supply chain compromise | Low | High | MEDIUM | Mitigated: SHA-pinned dependencies |
| R-4 | Container escape | Very Low | High | LOW | Mitigated: non-root, setuid removed |
| R-5 | API quota exhaustion | Low | Medium | LOW | Accepted: natural polling throttle |

### Risk scoring method

- Likelihood: Very Low / Low / Medium / High
- Impact: Low / Medium / High / Critical
- Risk: Likelihood x Impact (qualitative, per NIST SP 800-30 Table H-3)

### Treatment key

- Mitigated: control implemented to reduce risk
- Accepted: residual risk acknowledged by owner

## Maintenance schedule

- Review annually or after any security incident.
- Re-assess when adding new dependencies or modifying core architecture.

## Approval

| Role | Name | Date |
| --- | --- | --- |
| Project Owner | Jay Cap | 2026-06-26 |
| Security Lead | Jay Cap | 2026-06-26 |

---

Document history: created 2026-06-26
