# Operations guide: BridgeWatcher

## 1. Recovery and business continuity (F-11)

BridgeWatcher is stateless. Recovery is a fresh container deploy from the published image.

### Recovery procedure

```bash
# 1. Pull the latest image
docker pull mrjcap/bridgewatcher:latest

# 2. Create secrets directory
mkdir -p /opt/bridgewatcher/secrets
echo "YOUR_API_KEY" > /opt/bridgewatcher/secrets/api_key
echo "YOUR_PUSHOVER_TOKEN" > /opt/bridgewatcher/secrets/pushover_token
echo "YOUR_PUSHOVER_USER" > /opt/bridgewatcher/secrets/pushover_user
chmod 600 /opt/bridgewatcher/secrets/api_key \
  /opt/bridgewatcher/secrets/pushover_token \
  /opt/bridgewatcher/secrets/pushover_user

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
  -v log-data:/app/logs \
  mrjcap/bridgewatcher:latest
```

### Recovery objectives

| Metric | Target | Notes |
| --- | --- | --- |
| RPO | Last JSON snapshot | Data is re-fetched on restart |
| RTO | ~5 minutes | Pull image and start container |

No database restore or state migration is required.

---

## 2. Recommended Docker runtime flags (F-12)

```bash
docker run \
  --no-new-privileges \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid \
  --memory=256m \
  --cpus=0.5 \
  --restart=unless-stopped \
  -v /path/to/secrets:/run/secrets:ro \
  -v log-data:/app/logs \
  mrjcap/bridgewatcher:latest
```

### Flag explanations

| Flag | Purpose |
| --- | --- |
| `--no-new-privileges` | Blocks `setuid`/`setgid` escalation |
| `--read-only` | Makes root filesystem immutable |
| `--tmpfs /tmp:rw,noexec,nosuid` | Writable `/tmp` without exec |
| `--memory=256m` | Caps memory to prevent DoS |
| `--cpus=0.5` | Limits CPU to half a core |
| `--restart=unless-stopped` | Auto-restart on crash |
| `-v ...:/run/secrets:ro` | Mount secrets read-only |
| `-v log-data:/app/logs` | Writable volume for logs and state snapshots |

### Additional hardening (optional)

```bash
--security-opt=no-new-privileges:true
--cap-drop=ALL
--pids-limit=64
```

---

## 3. Log management (F-13)

### Current behavior

BridgeWatcher writes daily rotating `.log` files inside the container filesystem.

### Recommended: syslog forwarding

Layer the syslog override file on top of the base compose file. No tracked file needs editing:

```bash
SYSLOG_ADDRESS=tcp://loghost:514 \
  docker compose -f docker-compose.yml -f docker-compose.syslog.yml up -d
```

Compose refuses to start the override without `SYSLOG_ADDRESS`.

### Alternative: Filebeat sidecar

The `siem` profile runs Filebeat against the shared log volume. Settings come from environment variables
(or an `.env` file), not from edits to the repository.

Logstash output (default `Docker/filebeat.yml`):

```bash
LOGSTASH_HOST=siem.example.com LOGSTASH_PORT=5044 \
  docker compose --profile siem up -d
```

Elasticsearch output (select `Docker/filebeat.elasticsearch.yml`):

```bash
FILEBEAT_CONFIG=./Docker/filebeat.elasticsearch.yml \
ELASTICSEARCH_HOST=es.example.com ELASTICSEARCH_USERNAME=filebeat ELASTICSEARCH_PASSWORD=... \
  docker compose --profile siem up -d
```

`LOGSTASH_PORT` defaults to 5044, `ELASTICSEARCH_PORT` to 9200 and `ELASTICSEARCH_PROTOCOL` to https. Filebeat
exits with a missing-field error when a required variable is unset, so a placeholder host is never contacted.

Without Compose, bind-mount the log directory and point any shipper at it:

```bash
docker run \
  -v /var/log/bridgewatcher:/app/logs \
  mrjcap/bridgewatcher:latest
```

### Retention

- Local: 7 days (default rotation)
- Central: 90 days recommended for audit trail

---

Document history: created 2026-06-26
