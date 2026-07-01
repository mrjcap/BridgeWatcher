# Risk Assessment — BridgeWatcher

> Baseline risk assessment per NIST SP 800-30 Rev. 1
> *Guidelines for Conducting Risk Assessments*

## Scope

This document covers the BridgeWatcher application:
a containerised bridge-status monitor that polls an
upstream website and exposes results via a REST API.

For the full security audit, see
[SECURITY-AUDIT.md](SECURITY-AUDIT.md).

## Risk Register

| ID | Threat | Likelihood | Impact | Risk | Treatment |
|----|--------|-----------|--------|------|-----------|
| R-1 | API key exposure via logs | Low (mitigated) | High | **MEDIUM** | Mitigated: moved to HTTP header |
| R-2 | Upstream website serves malicious content | Low | Medium | **LOW** | Accepted |
| R-3 | Supply chain compromise | Low | High | **MEDIUM** | Mitigated: SHA-pinned deps |
| R-4 | Container escape | Very Low | High | **LOW** | Mitigated: non-root, setuid removed |
| R-5 | API quota exhaustion | Low | Medium | **LOW** | Accepted: natural polling throttle |

### Risk Scoring Method

- **Likelihood**: Very Low / Low / Medium / High
- **Impact**: Low / Medium / High / Critical
- **Risk** = Likelihood × Impact
  (qualitative, per NIST SP 800-30 Table H-3)

### Treatment Key

- **Mitigated** — control implemented to reduce risk
- **Accepted** — residual risk acknowledged by owner

## Maintenance Schedule

- Review **annually** or after any security incident.
- Re-assess when new dependencies are added or the
  architecture changes significantly.

## Approval

| Role | Name | Date |
|------|------|------|
| Project Owner | ________________ | ____-**-__ |
| Security Lead | ________________ | ____-**-__ |

---
*Document created: 2026-06-26*
