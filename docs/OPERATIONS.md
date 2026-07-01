# Operations Guide — BridgeWatcher

## 1. Recovery / Business Continuity (F-11)

BridgeWatcher is stateless. Recovery is a fresh
container deploy from the published image.

### Recovery Procedure

```bash
# 1. Pull the latest image
docker pull bridgewatcher:latest

# 2. Create secrets directory
mkdir -p /opt/bridgewatcher/secrets
echo "YOUR_API_KEY" > /opt/bridgewatcher/secrets/api_key
chmod 600 /opt/bridgewatcher/secrets/api_key

# 3. Deploy
docker run -d \
  --name bridgewatcher \
  --no-new-privileges \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid \
  --memory=256m \
  --cpus=0.5 \
  --restart=unless-stopped \
  -v /opt/bridgewatcher/secrets:/run/secrets:ro \
  -p 8080:8080 \
  bridgewatcher:latest
```

### Recovery Objectives

| Metric | Target | Notes |
|--------|--------|-------|
| **RPO** | Last JSON snapshot | Data is re-fetched on restart |
| **RTO** | ~5 minutes | Pull image + start container |

No database restore or state migration is required.

---

## 2. Recommended Docker Runtime Flags (F-12)

```bash
docker run \
  --no-new-privileges \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid \
  --memory=256m \
  --cpus=0.5 \
  --restart=unless-stopped \
  -v /path/to/secrets:/run/secrets:ro \
  bridgewatcher:latest
```

### Flag Explanations

| Flag | Purpose |
|------|---------|
| `--no-new-privileges` | Blocks `setuid`/`setgid` escalation |
| `--read-only` | Makes root filesystem immutable |
| `--tmpfs /tmp:rw,noexec,nosuid` | Writable `/tmp` without exec |
| `--memory=256m` | Caps memory to prevent DoS |
| `--cpus=0.5` | Limits CPU to half a core |
| `--restart=unless-stopped` | Auto-restart on crash |
| `-v ...:/run/secrets:ro` | Mount secrets read-only |

### Additional Hardening (Optional)

```bash
--security-opt=no-new-privileges:true
--cap-drop=ALL
--pids-limit=64
```

---

## 3. Log Management (F-13)

### Current Behaviour

BridgeWatcher writes daily rotating `.log` files
inside the container filesystem.

### Recommended: Syslog Forwarding

Use the Docker syslog driver to forward logs to a
central collector:

```bash
docker run \
  --log-driver=syslog \
  --log-opt syslog-address=tcp://loghost:514 \
  --log-opt tag=bridgewatcher \
  bridgewatcher:latest
```

### Alternative: Bind-Mount + Shipper

Mount the log directory and use Filebeat or Promtail:

```bash
docker run \
  -v /var/log/bridgewatcher:/app/logs \
  bridgewatcher:latest
```

Then configure a log shipper:

```yaml
# filebeat.yml snippet
filebeat.inputs:
  - type: log
    paths:
      - /var/log/bridgewatcher/*.log
    tags: ["bridgewatcher"]
```

### Retention

- **Local**: 7 days (default rotation)
- **Central**: 90 days recommended for audit trail

---
**Document History:** *created 2026-06-26*
