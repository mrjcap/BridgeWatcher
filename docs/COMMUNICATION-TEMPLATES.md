# Incident & Recovery Communication Templates

This document contains standard pre-formatted communication templates for BridgeWatcher incident handling, aligned with ISO 27001:2022 A.5.29 and A.5.30 (Information Security during Disruption).

These templates ensure fast, accurate, and consistent communications during outages or security events.

---

## Template 1: Initial Incident Alert (SEV-1 / SEV-2)

*Use when a significant service disruption or credential compromise is detected.*

**Subject:** ALERT: BridgeWatcher Service Outage / Potential Disruption

```text
Dear Stakeholders,

We have detected a service disruption affecting the BridgeWatcher monitoring system. 

Details:
- Incident ID: INC-[YYYY]-[NNN]
- Severity: [SEV-1 (Critical) / SEV-2 (High)]
- Status: Under Investigation
- Impact: Submersible bridge status updates are currently delayed or unavailable.

The primary responder is currently executing the diagnostic and containment playbooks. Further updates will be provided as we isolate the root cause.

Sincerely,
BridgeWatcher Operations
```

---

## Template 2: Outage Status / Mitigation Update

*Use during prolonged incident resolution cycles to provide progress updates.*

**Subject:** UPDATE: INC-[YYYY]-[NNN] — BridgeWatcher Incident Resolution Progress

```text
Dear Stakeholders,

This is an update regarding the ongoing incident INC-[YYYY]-[NNN] affecting BridgeWatcher.

Current Status:
- Root cause has been identified as [API Quota Limits / Upstream Scraping Failure / Credential Rotation].
- Mitigation actions are underway: [e.g., Rotating API key, rebuilding container].
- Expected Time to Recovery (ETR): [Estimated Time, e.g., 30 minutes]

We will send a follow-up notification once the system is fully operational and status monitoring has resumed.

Sincerely,
BridgeWatcher Operations
```

---

## Template 3: Service Restored / Recovery Attestation

*Use once the incident has been resolved and verified.*

**Subject:** RESOLVED: INC-[YYYY]-[NNN] — BridgeWatcher Fully Operational

```text
Dear Stakeholders,

We are pleased to report that the incident INC-[YYYY]-[NNN] has been successfully resolved.

Details:
- Recovery Action: [e.g., Deployed new container with rotated Vision API credentials].
- Verification: Completed test cycle; bridge status updates are flowing successfully.
- Incident Resolution Time: [Total Duration, e.g., 45 minutes]

A formal Post-Incident Review (PIR) will be conducted within 48 hours to document lessons learned and implement permanent hardening.

Sincerely,
BridgeWatcher Operations
```

---

## Template 4: External Credential Exposure Disclosure

*Use in the event of an API key exposure to cloud vendors or public forums.*

**Subject:** SECURITY NOTICE: BridgeWatcher Google Cloud API Key Rotation

```text
Dear Security Operations,

A BridgeWatcher integration key (Google Cloud Vision API key) was briefly exposed in a public repository commit/log at [Timestamp].

Actions taken:
1. Compromised key was immediately revoked in the Google Cloud Console.
2. A new restricted API key has been generated and redeployed.
3. System logs and API metrics have been audited; we found [no / minimal] unauthorized API usage prior to revocation.

No personal user data or payment data was exposed. 

Sincerely,
BridgeWatcher Security Lead
```
