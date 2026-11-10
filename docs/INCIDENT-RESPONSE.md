# BridgeWatcher incident response runbook

> Last updated: 2026-06-26

## 1. Purpose and scope

This runbook defines incident response procedures for BridgeWatcher, a PowerShell-based monitoring tool that
tracks Corinth Canal bridge status using Google Vision API (OCR) and Pushover (notifications), deployed in Docker.

**In scope:**

- API credential compromise or exposure
- Service outages affecting bridge monitoring
- Container-level security incidents
- Monitoring gaps and false notifications

**Out of scope:**

- Infrastructure outside the BridgeWatcher stack
- Upstream Google or Pushover platform outages

---

## 2. Incident classification

| Severity | Category | Examples | Response SLA |
| --- | --- | --- | --- |
| SEV-1 | Critical | API key leak, credential exposure | Immediate |
| SEV-2 | High | Service outage, container compromise | < 1 hour |
| SEV-3 | Low | Monitoring gaps, false alerts | < 24 hours |

### Escalation triggers

- SEV-3 to SEV-2: Gap exceeds 4 hours or repeats 3 times.
- SEV-2 to SEV-1: Unauthorized access confirmed.

---

## 3. SEV-1: API key compromise playbook

### 3.1 Immediate revocation (< 5 min)

| Step | Action | Owner |
| --- | --- | --- |
| 1 | Google Vision API key: disable or delete key in [Google Cloud Console](https://console.cloud.google.com/apis/credentials) | Operator |
| 2 | Pushover API/User key: reset application token in [Pushover Dashboard](https://pushover.net/) | Operator |
| 3 | Stop BridgeWatcher container to halt outbound requests | Operator |

```powershell
# Stop the container immediately
docker stop bridgewatcher
```

### 3.2 Key rotation (< 15 min)

1. Create a new API key in Google Cloud Console with IP or referrer restrictions.
2. Generate a new application token in Pushover.
3. Update Docker secrets or environment variables:

```powershell
# If using docker run with env vars:
docker run -d --name bridgewatcher \
  -e GOOGLE_API_KEY="<new-key>" \
  -e PUSHOVER_TOKEN="<new-token>" \
  -e PUSHOVER_USER="<user-key>" \
  bridgewatcher:latest

# If using Docker secrets:
echo "<new-key>" | docker secret create google_api_key -
echo "<new-token>" | docker secret create pushover_token -
```

1. Verify the new keys work before going live:

```powershell
# Quick API health check
docker logs bridgewatcher --tail 20
```

### 3.3 Usage audit (< 1 hour)

| Check | How |
| --- | --- |
| Google API usage | Check Cloud Console metrics for unexpected spikes or unknown IPs. |
| Pushover usage | Review Pushover message history for unauthorized notifications. |
| Source of leak | Search git history via `git log -S "key"` or CI logs. |
| Container logs | Export logs with `docker logs bridgewatcher > incident.log`. |

### 3.4 Stakeholder notification

- Inform project maintainers of the compromise.
- Follow disclosure obligations if third-party data was exposed.
- Log the incident in the issue tracker.

### 3.5 Post-incident hardening

- [ ] Ensure keys are not committed to source control.
- [ ] Add secrets files to `.gitignore`.
- [ ] Enable Google API key restrictions.
- [ ] Set Pushover monthly message limits.
- [ ] Run `gitleaks detect` locally.
- [ ] Use Docker secrets instead of plain environment variables.

---

## 4. SEV-2: service outage playbook

Bridge monitoring is offline and status updates are interrupted.

### 4.1 Diagnosis (< 10 min)

```powershell
# Check container status
docker ps -a --filter name=bridgewatcher

# View recent logs
docker logs bridgewatcher --tail 50 --timestamps

# Check container health
docker inspect bridgewatcher --format='{{.State.Health}}'

# Test API connectivity from host
Invoke-RestMethod -Uri "https://vision.googleapis.com/v1/images:annotate?key=$env:GOOGLE_API_KEY" `
  -Method POST -Body '{}' -ContentType 'application/json'
```

| Symptom | Likely cause | Fix |
| --- | --- | --- |
| Container `Exited` | Crash or OOM kill | Check logs, restart |
| Container running, no output | Script hang or sleep loop | Restart container |
| API 403/401 errors | Key invalid or quota exceeded | Rotate key or check quota |
| Network timeout | DNS or connectivity issue | Check Docker network |
| Pushover errors | Token invalid or rate limit | Check Pushover dashboard |

### 4.2 Recovery

```powershell
# Restart existing container
docker restart bridgewatcher

# Or redeploy from image
docker rm -f bridgewatcher
docker run -d --name bridgewatcher \
  --restart unless-stopped \
  --env-file .env \
  bridgewatcher:latest
```

### 4.3 Verification

- [ ] Container shows `Up` in `docker ps`.
- [ ] Logs show successful OCR processing.
- [ ] Test notification arrives via Pushover.
- [ ] Monitoring cycle resumes at configured interval.

---

## 5. SEV-2: container compromise playbook

Suspected unauthorized access or unexpected execution in the container.

### 5.1 Isolation

```powershell
# Disconnect from network first to preserve state
docker network disconnect bridge bridgewatcher

# Stop the container (do not remove yet)
docker stop bridgewatcher

# Export container filesystem for investigation
docker export bridgewatcher > bridgewatcher-forensic.tar
```

### 5.2 Investigation

| Action | Command / location |
| --- | --- |
| Preserve container logs | `docker logs bridgewatcher > compromise.log 2>&1` |
| Check for unexpected processes | Review forensic tar for added binaries |
| Review Trivy scan results | Run `trivy image bridgewatcher:latest` |
| Check image integrity | Compare `docker image inspect` hash against known-good build |
| Review Docker daemon logs | Check systemd journal or Docker Desktop logs |

### 5.3 Rebuild

```powershell
# Remove compromised container
docker rm -f bridgewatcher

# Pull or rebuild a clean image
docker build --no-cache -t bridgewatcher:latest .

# Scan the new image
docker run --rm aquasec/trivy image bridgewatcher:latest
```

### 5.4 Credential rotation

Assume all secrets mounted in the container are compromised:

- [ ] Rotate Google Vision API key.
- [ ] Rotate Pushover application token.
- [ ] Rotate any additional secrets mounted in container.
- [ ] Update Docker secrets or environment variables.
- [ ] Redeploy container.

---

## 6. Contact and escalation

| Role | Name | Contact | Escalation path |
| --- | --- | --- | --- |
| Primary Operator | Jay Cap (@mrjcap) | GitHub Issues / <mrjcap@users.noreply.github.com> | First responder |
| Project Owner | Jay Cap (@mrjcap) | GitHub Issues / <mrjcap@users.noreply.github.com> | SEV-1 escalation |
| Security Lead | Jay Cap (@mrjcap) | GitHub Issues / <mrjcap@users.noreply.github.com> | Compromise events |
| Google Cloud Admin | Jay Cap (@mrjcap) | Google Cloud Console / Console Admin | API key rotation |

External resources:

- [Google Cloud Support](https://cloud.google.com/support)
- [Pushover Support](https://pushover.net/support)
- [Docker Security](https://docs.docker.com/engine/security/)

---

## 7. Post-incident review template

Complete within 48 hours of incident resolution.

### Incident summary

| Field | Value |
| --- | --- |
| Incident ID | *INC-YYYY-NNN* |
| Severity | SEV-1 / SEV-2 / SEV-3 |
| Date detected | *YYYY-MM-DD HH:MM UTC* |
| Date resolved | *YYYY-MM-DD HH:MM UTC* |
| Duration | *X hours Y minutes* |
| Responder(s) | *Names* |
| Root cause | *Brief description* |

### Review checklist

- [ ] Document timeline of events.
- [ ] Confirm root cause.
- [ ] Verify applied remediations.
- [ ] Rotate all exposed credentials.
- [ ] Archive logs for audit records.
- [ ] Identify detection and alerting gaps.
- [ ] Document preventive controls.
- [ ] Update runbook with findings.
- [ ] Open GitHub issues for follow-up engineering work.
- [ ] Notify stakeholders of resolution.

### Lessons learned

| Question | Answer |
| --- | --- |
| What worked well? | *...* |
| What failed? | *...* |
| What surprised us? | *...* |
| What concrete change will we make? | *...* |

---

Update this runbook after each incident and review quarterly.
