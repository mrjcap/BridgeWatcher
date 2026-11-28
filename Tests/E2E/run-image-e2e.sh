#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-}"
case "$MODE" in
  happy) PUSHOVER_MODE=accept ;;
  pushover-reject) PUSHOVER_MODE=reject ;;
  *) echo "usage: run-image-e2e.sh happy|pushover-reject" >&2; exit 2 ;;
esac

: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${E2E_FIXTURE_IMAGE:?E2E_FIXTURE_IMAGE is required}"
DEADLINE_SECONDS="${E2E_POLL_DEADLINE_SECONDS:-90}"

ROOT="$(pwd)"
FIX="$ROOT/Tests/E2E/fixtures"
SERVER="$ROOT/Tests/E2E/fixture_server.py"
SECRETS="$ROOT/test-secrets"
LOGS="$ROOT/test-logs/$MODE"
WORK="$ROOT/test-e2e/$MODE"
EVIDENCE="$ROOT/e2e-evidence/$MODE"
REC="$WORK/records/requests.jsonl"
HOST="fixture.bridgewatcher.test"
BASE="https://$HOST:8443/dioriga"
NET="bridgewatcher-e2e-$MODE"
APP="bridgewatcher-test-$MODE"
SRV="bridgewatcher-e2e-fixture-$MODE"
CLEANUP_SECONDS="${E2E_CLEANUP_TIMEOUT_SECONDS:-60}"
COLLECT_SECONDS="${E2E_COLLECT_TIMEOUT_SECONDS:-15}"
MARK_DONE="Finished comparison and saved snapshot."
MARK_START="Starting comparison..."
MARK_MONITOR_ERROR="Σφάλμα κατά την ανάκτηση της κατάστασης της γέφυρας"
MARK_OCR_FAILURE="Απέτυχε η OCR"
EXPECT_FROM="09/07/2026 00:01"
EXPECT_TO="09/07/2026 00:40"
EXPECT_TITLE="ℹ️ Το πρόγραμμα κλεισίματος της γέφυρας Ποσειδωνία ολοκληρώθηκε"
EXPECT_IMAGE_HASH="CD918AA95F316456C5D42A80D4DC7D75"

[[ -d "$ROOT/test-logs" ]] || { echo "::error::test-logs must be prepared by the workflow step" >&2; exit 2; }
[[ -d "$SECRETS" ]] || { echo "::error::test-secrets must be prepared by the workflow step" >&2; exit 2; }

applog() {
  sudo find "$LOGS" -maxdepth 1 -type f -name 'BridgeWatcher-*.log' -exec cat {} + 2>/dev/null || true
}
appsnap() {
  sudo find "$LOGS" -maxdepth 1 -type f -name 'bridge_status.json' -exec cat {} + 2>/dev/null || true
}
secret() {
  local name="$1"
  sudo cat "$SECRETS/$name" 2>/dev/null | tr -d '\r\n'
}
fail() { echo "::error::e2e[$MODE]: $*" >&2; exit 1; }
teardown() {
  local status=0
  timeout "$CLEANUP_SECONDS" docker rm -f "$APP" "$SRV" >/dev/null 2>&1 || status=$?
  [[ "$status" -ne 124 ]] || echo "::warning::e2e[$MODE]: container removal did not finish within ${CLEANUP_SECONDS}s" >&2
  timeout "$CLEANUP_SECONDS" docker network rm "$NET" >/dev/null 2>&1 || true
}

collect() {
  mkdir -p "$EVIDENCE"
  timeout "$COLLECT_SECONDS" docker logs "$APP" >"$EVIDENCE/app-stdout.log" 2>&1 || true
  timeout "$COLLECT_SECONDS" docker logs "$SRV" >"$EVIDENCE/fixture-stdout.log" 2>&1 || true
  timeout "$COLLECT_SECONDS" docker inspect -f '{{json .State}}' "$APP" >"$EVIDENCE/app-state.json" 2>/dev/null || true
  if [[ -f "$REC" ]]; then cp "$REC" "$EVIDENCE/requests.jsonl" || true; fi
  applog >"$EVIDENCE/bridgewatcher.log" || true
  appsnap >"$EVIDENCE/bridge_status.json" || true
  for name in api_key pushover_token pushover_user; do
    value="$(secret "$name" || true)"
    [[ -n "$value" ]] || continue
    escaped="$(printf '%s' "$value" | sed 's/[][\/.^$*&]/\\&/g')"
    sed -i "s/$escaped/[REDACTED:$name]/g" "$EVIDENCE"/*.log "$EVIDENCE"/*.json 2>/dev/null || true
  done
}

cleanup() {
  rc=$?
  collect || true
  teardown
  rm -rf "$WORK"
  if [[ "$rc" -eq 0 ]]; then echo "e2e[$MODE]: PASS"; else echo "e2e[$MODE]: FAIL (evidence in e2e-evidence/$MODE)"; fi
  exit "$rc"
}
trap cleanup EXIT

teardown
rm -rf "$WORK" "$EVIDENCE"
mkdir -p "$WORK/tls" "$WORK/ca" "$WORK/ca-empty" "$WORK/records" "$EVIDENCE"
chmod 755 "$WORK" "$WORK/ca" "$WORK/ca-empty" "$WORK/records"
chmod 700 "$WORK/tls"

openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -days 1 \
  -subj "/CN=BridgeWatcher E2E Test CA" \
  -addext "basicConstraints=critical,CA:TRUE" -addext "keyUsage=critical,keyCertSign,cRLSign" \
  -keyout "$WORK/tls/ca.key" -out "$WORK/ca/ca.pem" 2>/dev/null
openssl req -new -newkey ec -pkeyopt ec_paramgen_curve:P-256 -nodes -subj "/CN=$HOST" \
  -keyout "$WORK/tls/server.key" -out "$WORK/tls/server.csr" 2>/dev/null
printf 'subjectAltName=DNS:%s\nextendedKeyUsage=serverAuth\nbasicConstraints=critical,CA:FALSE\nkeyUsage=critical,digitalSignature\n' "$HOST" >"$WORK/tls/server.ext"
openssl x509 -req -in "$WORK/tls/server.csr" -CA "$WORK/ca/ca.pem" -CAkey "$WORK/tls/ca.key" \
  -set_serial "0x$(openssl rand -hex 8)" -days 1 -extfile "$WORK/tls/server.ext" -out "$WORK/tls/server.pem" 2>/dev/null
rm -f "$WORK/tls/ca.key" "$WORK/tls/server.csr" "$WORK/tls/server.ext"
chmod 644 "$WORK/ca/ca.pem"
[[ "$(ls -A "$WORK/ca")" == "ca.pem" ]] || fail "CA directory must contain only ca.pem"
[[ -z "$(ls -A "$WORK/ca-empty")" ]] || fail "SSL_CERT_DIR must be empty"

for name in api_key pushover_token pushover_user; do
  sudo test -s "$SECRETS/$name" || fail "test-secrets/$name must be prepared by the workflow step"
done
key_sha="$(secret api_key | sha256sum | cut -d' ' -f1)"
tok_sha="$(secret pushover_token | sha256sum | cut -d' ' -f1)"
usr_sha="$(secret pushover_user | sha256sum | cut -d' ' -f1)"
img_sha="$(sha256sum "$FIX/poseidonia-schedule.png" | cut -d' ' -f1)"
seed_sha="$(sha256sum "$FIX/seed-bridge_status.json" | cut -d' ' -f1)"

sudo install -d -o 99 -g 100 -m 750 "$LOGS"
sudo install -o 99 -g 100 -m 640 "$FIX/seed-bridge_status.json" "$LOGS/bridge_status.json"

docker image inspect "$E2E_FIXTURE_IMAGE" >/dev/null 2>&1 || docker pull --quiet --platform linux/amd64 "$E2E_FIXTURE_IMAGE" >/dev/null
docker network create --internal "$NET" >/dev/null

docker run -d --name "$SRV" --network "$NET" --network-alias "$HOST" \
  --pull=never --user "$(id -u):$(id -g)" --read-only --cap-drop ALL --security-opt no-new-privileges \
  -e PYTHONDONTWRITEBYTECODE=1 -e E2E_PUSHOVER_MODE="$PUSHOVER_MODE" -e E2E_HOST="$HOST" \
  -v "$SERVER:/srv/fixture_server.py:ro" -v "$FIX:/fixtures:ro" \
  -v "$WORK/tls:/tls:ro" -v "$WORK/records:/records" \
  "$E2E_FIXTURE_IMAGE" python /srv/fixture_server.py >/dev/null

for _ in $(seq 1 60); do
  [[ -f "$WORK/records/ready" ]] && break
  [[ "$(docker inspect -f '{{.State.Running}}' "$SRV")" == "true" ]] || fail "fixture server exited during startup"
  sleep 0.25
done
[[ -f "$WORK/records/ready" ]] || fail "fixture server not ready within 15s"

docker run --rm --pull=never --network "$NET" --read-only --cap-drop ALL --security-opt no-new-privileges \
  -v "$WORK/ca/ca.pem:/e2e/ca/ca.pem:ro" --entrypoint curl "$IMAGE_TAG" \
  --silent --show-error --fail --max-time 10 --cacert /e2e/ca/ca.pem -o /dev/null "https://$HOST:8443/__probe" \
  || fail "in-network TLS probe to $HOST failed"

docker create --pull=never --name "$APP" --network "$NET" \
  --read-only --tmpfs /tmp:rw,noexec,nosuid --cap-drop ALL --security-opt no-new-privileges \
  --health-interval=30s --health-timeout=10s --health-retries=3 \
  -e BRIDGEWATCHER_CONFIG_PATH=/e2e/bridgewatcher.e2e.json \
  -e SSL_CERT_FILE=/e2e/ca/ca.pem -e SSL_CERT_DIR=/e2e/ca-empty \
  -v "$FIX/bridgewatcher.e2e.json:/e2e/bridgewatcher.e2e.json:ro" \
  -v "$WORK/ca/ca.pem:/e2e/ca/ca.pem:ro" -v "$WORK/ca-empty:/e2e/ca-empty:ro" \
  -v "$SECRETS:/run/secrets:ro" -v "$LOGS:/app/logs" \
  "$IMAGE_TAG" >/dev/null

start="$(date +%s)"
docker start "$APP" >/dev/null
outcome=""
while :; do
  [[ "$(docker inspect -f '{{.State.Running}}' "$APP")" == "true" ]] || fail "application container exited"
  [[ "$(docker inspect -f '{{.State.Running}}' "$SRV")" == "true" ]] || fail "fixture server exited"
  if [[ -f "$REC" ]] && grep -q '"route":"unexpected"' "$REC"; then fail "application made an unexpected request"; fi
  log="$(applog)"
  if printf '%s' "$log" | grep -qF "$MARK_DONE"; then outcome="done"; break; fi
  if printf '%s' "$log" | grep -qF "$MARK_MONITOR_ERROR"; then outcome="monitor-error"; break; fi
  [[ $(( $(date +%s) - start )) -lt "$DEADLINE_SECONDS" ]] || fail "no poll outcome within ${DEADLINE_SECONDS}s"
  sleep 0.5
done
elapsed=$(( $(date +%s) - start ))
echo "e2e[$MODE]: first poll outcome '$outcome' after ${elapsed}s"
sleep 1
[[ "$(docker inspect -f '{{.State.Running}}' "$APP")" == "true" ]] || fail "application container exited after the poll"

failed=0
note() {
  local status="$1" name="$2"
  if [[ "$status" -eq 0 ]]; then echo "  ok   $name"; else echo "  FAIL $name"; failed=1; fi
}
textcheck() {
  local name="$1" result="$2"
  if [[ "$result" == "true" ]]; then echo "  ok   $name"; else echo "  FAIL $name"; failed=1; fi
}

log="$(applog)"
starts="$(printf '%s\n' "$log" | grep -cF "$MARK_START" || true)"
dones="$(printf '%s\n' "$log" | grep -cF "$MARK_DONE" || true)"
errors="$(printf '%s\n' "$log" | grep -cF "$MARK_MONITOR_ERROR" || true)"
ocrfails="$(printf '%s\n' "$log" | grep -cF "$MARK_OCR_FAILURE" || true)"

rc=0
jq -e -s '[.[] | select(.route != "probe") | .route] == ["page","image","vision","pushover"]' "$REC" >/dev/null 2>&1 || rc=$?
note "$rc" "app requests are page,image,vision,pushover in order"

rc=0
jq -e -s --arg h "$HOST:8443" \
  'all(.[]; .host == $h and (.tls == "TLSv1.2" or .tls == "TLSv1.3"))' "$REC" >/dev/null 2>&1 || rc=$?
note "$rc" "every request used Host $HOST:8443 over TLS 1.2+"

rc=0
jq -e -s --arg img "$img_sha" \
  '[.[] | select(.route == "image")] | length == 1 and .[0].query == "1720472460" and .[0].served_sha256 == $img' "$REC" >/dev/null 2>&1 || rc=$?
note "$rc" "image request carried the page query and got the fixture PNG"

rc=0
jq -e -s --arg key "$key_sha" --arg img "$img_sha" \
  '[.[] | select(.route == "vision")] | length == 1 and .[0].status == 200 and .[0].query == "" and .[0].api_key_sha256 == $key and .[0].request_count == 1 and .[0].image_keys == ["content"] and .[0].features == ["DOCUMENT_TEXT_DETECTION"] and .[0].image_sha256 == $img' "$REC" >/dev/null 2>&1 || rc=$?
note "$rc" "vision request: dummy key, 1 request, inline content only, DOCUMENT_TEXT_DETECTION, exact PNG bytes"

rc=0
jq -e -s --arg tok "$tok_sha" --arg usr "$usr_sha" \
  '[.[] | select(.route == "pushover")] | length == 1 and .[0].token_sha256 == $tok and .[0].user_sha256 == $usr and (.[0].content_type | startswith("application/x-www-form-urlencoded"))' "$REC" >/dev/null 2>&1 || rc=$?
note "$rc" "pushover request: dummy token/user, form-encoded, exactly one attempt"

rc=0
jq -e -s --arg title "$EXPECT_TITLE" --arg first "Από: $EXPECT_FROM Έως: $EXPECT_TO" \
  '[.[] | select(.route == "pushover")][0] | .title == $title and (.message | split("\n")[0]) == $first' "$REC" >/dev/null 2>&1 || rc=$?
note "$rc" "pushover title and first message line match the 9 July window"

textcheck "exactly one poll started" "$([[ "$starts" -eq 1 ]] && echo true || echo false)"
textcheck "no OCR failure logged" "$([[ "$ocrfails" -eq 0 ]] && echo true || echo false)"

snap="$WORK/snapshot.json"
appsnap >"$snap"
[[ -s "$snap" ]] || fail "snapshot file missing or not a regular file"

if [[ "$MODE" == "happy" ]]; then
  rc=0
  jq -e -s '[.[] | select(.route != "probe") | .status] | all(. == 200)' "$REC" >/dev/null 2>&1 || rc=$?
  note "$rc" "fixture answered 200 to every app request"

  textcheck "completion marker logged exactly once" "$([[ "$dones" -eq 1 ]] && echo true || echo false)"
  textcheck "no monitor error logged" "$([[ "$errors" -eq 0 ]] && echo true || echo false)"

  rc=0
  jq -e '[.[].GefyraName] | sort == ["Ισθμία","Ποσειδωνία"]' "$snap" >/dev/null 2>&1 || rc=$?
  note "$rc" "snapshot holds exactly Ποσειδωνία and Ισθμία"

  rc=0
  jq -e --arg url "$BASE/image-bridge-open-with-schedule-posidonia.php?1720472460" --arg md5 "$EXPECT_IMAGE_HASH" \
    --arg from "$EXPECT_FROM" --arg to "$EXPECT_TO" \
    '[.[] | select(.GefyraName == "Ποσειδωνία")] | length == 1 and .[0].GefyraStatus == "Κλειστή με πρόγραμμα" and .[0].ImageUrl == $url and .[0].ImageHash == $md5 and .[0].From == $from and .[0].To == $to and .[0].ScheduleState == "Expired"' "$snap" >/dev/null 2>&1 || rc=$?
  note "$rc" "Ποσειδωνία: Κλειστή με πρόγραμμα, page ImageUrl, uppercase MD5, 9 July From/To, ScheduleState Expired"

  rc=0
  jq -e --arg url "$BASE/image-bridge-open-no-schedule.php?1720472400" \
    '[.[] | select(.GefyraName == "Ισθμία")] | length == 1 and .[0].GefyraStatus == "Ανοιχτή" and .[0].ImageUrl == $url and .[0].ImageHash == null and (.[0] | has("From") | not) and (.[0] | has("To") | not)' "$snap" >/dev/null 2>&1 || rc=$?
  note "$rc" "Ισθμία: Ανοιχτή, unchanged ImageUrl, no hash, no schedule fields"
else
  rc=0
  jq -e -s '[.[] | select(.route == "pushover") | .status] == [400]' "$REC" >/dev/null 2>&1 || rc=$?
  note "$rc" "fixture rejected the single pushover attempt with 400"

  textcheck "completion marker never logged" "$([[ "$dones" -eq 0 ]] && echo true || echo false)"
  textcheck "monitor error logged once" "$([[ "$errors" -eq 1 ]] && echo true || echo false)"
  textcheck "snapshot is byte-identical to the seed" "$([[ "$(sha256sum "$snap" | cut -d' ' -f1)" == "$seed_sha" ]] && echo true || echo false)"
fi

[[ "$failed" -eq 0 ]] || fail "assertions failed"
