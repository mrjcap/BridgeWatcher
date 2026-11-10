---
name: Annual Compliance & Risk Review
about: Version-controlled annual review of security controls, risk register, and compliance status.
title: 'chore(compliance): Annual Risk & Security Review - YYYY'
labels: ['compliance', 'security', 'governance']
assignees: ['mrjcap']
---

## Annual compliance and risk review

This issue tracks the annual security review for BridgeWatcher, aligned with NIST CSF 2.0 (GV.RM)
and ISO 27001:2022 (A.5.36).

## Review checklist

### 1. Risk register audit (NIST SP 800-30)

- [ ] Review [RISK-ASSESSMENT.md](../docs/RISK-ASSESSMENT.md) for completeness.
- [ ] Re-assess likelihood and impact of all existing threats (R-1 through R-5).
- [ ] Identify any new threat events (upstream site changes, dependency updates, integration changes).
- [ ] Log any closed or accepted risks.

### 2. Dependency and vulnerability review

- [ ] Review dependency pins in [Dockerfile](../Docker/Dockerfile) and GitHub Actions.
- [ ] Run a manual Trivy vulnerability scan against the container image.
- [ ] Verify Gitleaks scan history in CI/CD logs to ensure no secret exposure has occurred.
- [ ] Confirm latest CycloneDX Software Bill of Materials (SBOM) has been successfully generated and archived.

### 3. Incident response and operations drill

- [ ] Review [INCIDENT-RESPONSE.md](../docs/INCIDENT-RESPONSE.md) playbooks.
- [ ] Verify escalation contacts and communication channels are current.
- [ ] Conduct a simulated incident response drill (such as simulated Google Vision API key rotation).
- [ ] Review log management and forwarding status (Filebeat / syslog).

### 4. Document review and attestation

- [ ] Review and update [SECURITY.md](../SECURITY.md) and [SECURITY-REQUIREMENTS.md](../docs/SECURITY-REQUIREMENTS.md).
- [ ] Attest compliance and close this issue.

---

Assessor: @mrjcap  
Date completed: YYYY-MM-DD  
Compliance re-certification: Approved / Rejected
