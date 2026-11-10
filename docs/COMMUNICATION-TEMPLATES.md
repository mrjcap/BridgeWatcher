# Incident and recovery communication templates

Standard communication templates for BridgeWatcher incident handling, aligned with ISO 27001:2022 A.5.29 and A.5.30
(Information Security during Disruption).

---

## Template 1: initial incident alert (SEV-1 / SEV-2)

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

The primary responder is executing diagnostic and containment playbooks. Further updates will follow once the root
cause is isolated.

Sincerely,
BridgeWatcher Operations
```

---

## Template 2: outage status and mitigation update

*Use during prolonged incident resolution cycles to provide progress updates.*

**Subject:** UPDATE: INC-[YYYY]-[NNN]: BridgeWatcher Incident Resolution Progress

```text
Dear Stakeholders,

This is an update regarding incident INC-[YYYY]-[NNN] affecting BridgeWatcher.

Current Status:
- Root cause: [API Quota Limits / Upstream Scraping Failure / Credential Rotation].
- Mitigation actions: [Rotating API key, rebuilding container].
- Expected Time to Recovery (ETR): [Estimated Time, e.g., 30 minutes]

A follow-up notification will follow once status monitoring resumes.

Sincerely,
BridgeWatcher Operations
```

---

## Template 3: service restored and recovery attestation

*Use once the incident has been resolved and verified.*

**Subject:** RESOLVED: INC-[YYYY]-[NNN]: BridgeWatcher Fully Operational

```text
Dear Stakeholders,

Incident INC-[YYYY]-[NNN] has been resolved and verified.

Details:
- Recovery Action: [e.g., Deployed new container with rotated Vision API credentials].
- Verification: Completed test cycle; bridge status updates are flowing successfully.
- Incident Resolution Time: [Total Duration, e.g., 45 minutes]

A formal Post-Incident Review (PIR) will follow within 48 hours to document findings and permanent controls.

Sincerely,
BridgeWatcher Operations
```

---

## Template 4: external credential exposure disclosure

*Use if an API key is exposed to cloud vendors or public repositories.*

**Subject:** SECURITY NOTICE: BridgeWatcher Google Cloud API Key Rotation

```text
Dear Security Operations,

A BridgeWatcher integration key (Google Cloud Vision API key) was exposed in a public repository commit or log
at [Timestamp].

Actions taken:
1. Revoked the compromised key in Google Cloud Console.
2. Generated and redeployed a new restricted API key.
3. Audited API metrics and system logs; confirmed [no / minimal] unauthorized API calls prior to revocation.

No personal user data or payment data was exposed. 

Sincerely,
BridgeWatcher Security Lead
```
