---
name: Annual Compliance & Risk Review
about: Version-controlled annual review of security controls, risk register, and compliance status.
title: 'chore(compliance): Annual Risk & Security Review - YYYY'
labels: ['compliance', 'security', 'governance']
assignees: ['mrjcap']
---

## Annual Compliance & Risk Review

This issue tracks the annual security review for **BridgeWatcher**, aligned with NIST CSF 2.0 (GV.RM) and ISO 27001:2022 (A.5.36).

## Review Checklist

### 1. Risk Register Audit (NIST SP 800-30)

- [ ] Review [RISK-ASSESSMENT.md](../docs/RISK-ASSESSMENT.md) for completeness.
- [ ] Re-assess likelihood and impact of all existing threats (R-1 through R-7).
- [ ] Identify any new threat events (e.g., changes to upstream scraping structure, new module dependencies, integration modifications).
- [ ] Log any closed or accepted risks.

### 2. Dependency & Vulnerability Review

- [ ] Review dependency pins in [Dockerfile](../Docker/Dockerfile) and GitHub Actions.
- [ ] Run a manual Trivy vulnerability scan against the container image.
- [ ] Verify Gitleaks scan history in CI/CD logs to ensure no secret exposure has occurred.
- [ ] Confirm latest CycloneDX Software Bill of Materials (SBOM) has been successfully generated and archived.

### 3. Incident Response & Operations Drill

- [ ] Review [INCIDENT-RESPONSE.md](../docs/INCIDENT-RESPONSE.md) playbooks.
- [ ] Verify escalation contacts and phone/email information are current.
- [ ] Conduct a simulated incident response tabletop or credential rotation drill (e.g., simulated Google API key rotation).
- [ ] Review log management and SIEM forwarding status (Filebeat/syslog).

### 4. Document Review & Attestation

- [ ] Review and update [SECURITY.md](../SECURITY.md) and [SECURITY-REQUIREMENTS.md](../docs/SECURITY-REQUIREMENTS.md).
- [ ] Attest compliance and close this issue.

---
**Assessor:** @mrjcap  
**Date Completed:** YYYY-MM-DD  
**Compliance Re-Certification:** Approved / Rejected
