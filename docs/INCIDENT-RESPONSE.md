# BridgeWatcher Incident Response Runbook

> Last updated: 2026-06-26

## 1. Purpose & Scope

This runbook defines incident response procedures for
**BridgeWatcher** — a PowerShell-based monitoring tool that
tracks Corinth Canal bridge status using Google Vision API
(OCR) and Pushover (notifications), deployed in Docker.

**In scope:**
- API credential compromise or exposure
- Service outages affecting bridge monitoring
- Container-level security incidents
- Monitoring gaps and false notifications

**Out of scope:**
- Infrastructure outside the BridgeWatcher stack
- Upstream Google/Pushover platform outages

---

## 2. Incident Classification

| Severity | Category | Examples | Response SLA |
|----------|----------|----------|--------------|
| **SEV-1** | Critical | API key leak, credential exposure | Immediate |
| **SEV-2** | High | Service outage, container compromise | < 1 hour |
| **SEV-3** | Low | Monitoring gaps, false alerts | < 24 hours |

### Escalation Triggers

- SEV-3 → SEV-2: Gap exceeds 4 hours or repeats 3×
- SEV-2 → SEV-1: Unauthorized access confirmed

---

## 3. SEV-1: API Key Compromise Playbook

> **Priority: This is the most critical scenario.**
> A leaked API key can incur costs, enable abuse,
> or expose the notification pipeline.

### 3.1 Immediate — Revoke (< 5 min)

| Step | Action | Owner |
|------|--------|-------|
| 1 | **Google Vision API key**: Go to [Google Cloud Console](https://console.cloud.google.com/apis/credentials) → Delete or disable the compromised key | Operator |
| 2 | **Pushover API/User key**: Go to [Pushover Dashboard](https://pushover.net/) → Reset application token | Operator |
| 3 | Stop the BridgeWatcher container to prevent further API calls with the compromised key | Operator |

```powershell
# Stop the container immediately
docker stop bridgewatcher
```

### 3.2 Rotate — Generate New Credentials (< 15 min)

1. **Google Cloud Console**: Create a new API key with
   restrictions (HTTP referrer or IP-based).
2. **Pushover**: Generate a new application token.
3. **Update Docker secrets / environment variables**:

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

4. Verify the new keys work before going live:

```powershell
# Quick API health check
docker logs bridgewatcher --tail 20
```

### 3.3 Investigate — Audit Usage (< 1 hour)

| Check | How |
|-------|-----|
| Google API usage | Cloud Console → APIs & Services → Vision API → Metrics. Look for unexpected spikes or calls from unknown IPs. |
| Pushover usage | Pushover dashboard → Message history. Check for unauthorized notifications sent. |
| Source of leak | Search git history: `git log --all -p -- '*.ps1' '*.env' '*.yml'` for hardcoded keys. Check CI/CD logs. |
| Container logs | `docker logs bridgewatcher 2>&1 > incident.log` — preserve before removal. |

### 3.4 Notify Stakeholders

- Inform project maintainers of the compromise.
- If third-party data was exposed, follow disclosure
  obligations.
- Log the incident in the project issue tracker.

### 3.5 Post-Incident Hardening

- [ ] Ensure keys are **never** committed to source control
- [ ] Add `.env` and secrets files to `.gitignore`
- [ ] Enable Google API key restrictions (IP/referrer)
- [ ] Set Pushover monthly message limits
- [ ] Run `git secrets --scan` or `gitleaks detect`
- [ ] Consider Docker secrets instead of env vars

---

## 4. SEV-2: Service Outage Playbook

Bridge monitoring is offline — status updates are not
being sent.

### 4.1 Diagnose (< 10 min)

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

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Container `Exited` | Crash or OOM kill | Check logs, restart |
| Container running, no output | Script hang or sleep loop | Restart container |
| API 403/401 errors | Key invalid or quota exceeded | Rotate key / check quota |
| Network timeout | DNS or connectivity issue | Check Docker network |
| Pushover errors | Token invalid or rate limit | Check Pushover dashboard |

### 4.2 Recover

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

### 4.3 Verify

- [ ] Container shows `Up` in `docker ps`
- [ ] Logs show successful OCR processing
- [ ] Test notification is received via Pushover
- [ ] Confirm monitoring cycle resumes at expected interval

---

## 5. SEV-2: Container Compromise Playbook

Suspected unauthorized access or malicious activity
in the BridgeWatcher container.

### 5.1 Isolate (Immediate)

```powershell
# Disconnect from network first to preserve state
docker network disconnect bridge bridgewatcher

# Stop the container (do NOT remove yet)
docker stop bridgewatcher

# Export container filesystem for investigation
docker export bridgewatcher > bridgewatcher-forensic.tar
```

### 5.2 Investigate

| Action | Command / Location |
|--------|--------------------|
| Preserve container logs | `docker logs bridgewatcher > compromise.log 2>&1` |
| Check for unexpected processes | Review forensic tar for added binaries |
| Review Trivy scan results | `docker run --rm -v /var/run/docker.sock:/var/run/docker.sock aquasec/trivy image bridgewatcher:latest` |
| Check image integrity | Compare `docker image inspect` hash against known-good |
| Review Docker daemon logs | `journalctl -u docker` (Linux) or Docker Desktop logs |

### 5.3 Rebuild

```powershell
# Remove compromised container
docker rm -f bridgewatcher

# Pull or rebuild a clean image
docker build --no-cache -t bridgewatcher:latest .

# Scan the new image
docker run --rm aquasec/trivy image bridgewatcher:latest
```

### 5.4 Rotate All Credentials

> **Assume all secrets in the container are compromised.**

- [ ] Rotate Google Vision API key (see §3.2)
- [ ] Rotate Pushover application token (see §3.2)
- [ ] Rotate any other credentials mounted in the container
- [ ] Update Docker secrets or env files
- [ ] Redeploy with new credentials

---

## 6. Contact & Escalation

| Role | Name | Contact | Escalation Path |
|------|------|---------|-----------------|
| Primary Operator | Jay Cap (@mrjcap) | GitHub Issues / mrjcap@users.noreply.github.com | First responder |
| Project Owner | Jay Cap (@mrjcap) | GitHub Issues / mrjcap@users.noreply.github.com | SEV-1 escalation |
| Security Lead | Jay Cap (@mrjcap) | GitHub Issues / mrjcap@users.noreply.github.com | Compromise events |
| Google Cloud Admin | Jay Cap (@mrjcap) | Google Cloud Console / Console Admin | API key rotation |

**External Resources:**
- [Google Cloud Support](https://cloud.google.com/support)
- [Pushover Support](https://pushover.net/support)
- [Docker Security](https://docs.docker.com/engine/security/)

---

## 7. Post-Incident Review Template

Complete within **48 hours** of incident resolution.

### Incident Summary

| Field | Value |
|-------|-------|
| Incident ID | *INC-YYYY-NNN* |
| Severity | SEV-1 / SEV-2 / SEV-3 |
| Date detected | *YYYY-MM-DD HH:MM UTC* |
| Date resolved | *YYYY-MM-DD HH:MM UTC* |
| Duration | *X hours Y minutes* |
| Responder(s) | *Names* |
| Root cause | *Brief description* |

### Review Checklist

- [ ] Timeline of events documented
- [ ] Root cause identified and confirmed
- [ ] Immediate fix applied and verified
- [ ] All compromised credentials rotated
- [ ] Logs preserved for reference
- [ ] Detection gap identified (how could we
      have caught this sooner?)
- [ ] Preventive measures defined
- [ ] Runbook updated with lessons learned
- [ ] Issue/ticket filed for follow-up actions
- [ ] Stakeholders notified of resolution

### Lessons Learned

| Question | Answer |
|----------|--------|
| What went well? | *...* |
| What went wrong? | *...* |
| What was lucky? | *...* |
| What will we change? | *...* |

---

*This runbook is a living document. Update it after
every incident and review quarterly.*
