import base64
import hashlib
import json
import os
import ssl
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qsl, urlsplit

FIXTURES = os.environ.get("E2E_FIXTURES", "/fixtures")
RECORDS = os.environ.get("E2E_RECORDS", "/records")
TLS_DIR = os.environ.get("E2E_TLS", "/tls")
HOST = os.environ.get("E2E_HOST", "fixture.bridgewatcher.test")
BIND = os.environ.get("E2E_BIND", "")
PORT = int(os.environ.get("E2E_PORT", "8443"))
PUSHOVER_MODE = os.environ.get("E2E_PUSHOVER_MODE", "accept")

PROBE_PATH = "/__probe"
PAGE_PATH = "/dioriga/"
IMAGE_PATH = "/dioriga/image-bridge-open-with-schedule-posidonia.php"
IMAGE_QUERY = "1720472460"
VISION_PATH = "/v1/images:annotate"
PUSHOVER_PATH = "/1/messages.json"

JSON_CONTENT_TYPE = "application/json; charset=utf-8"
TEXT_CONTENT_TYPE = "text/plain; charset=utf-8"
PUSHOVER_RESPONSES = {
    "reject": (
        400,
        b'{"status":0,"errors":["user identifier is invalid"],"request":"e2e"}',
    ),
    "accept": (200, b'{"status":1,"request":"e2e"}'),
}


def read_bytes(name):
    with open(os.path.join(FIXTURES, name), "rb") as handle:
        return handle.read()


PAGE = read_bytes("dioriga.html")
IMAGE = read_bytes("poseidonia-schedule.png")
VISION = read_bytes("vision-response.json")
IMAGE_SHA256 = hashlib.sha256(IMAGE).hexdigest()
LOCK = threading.Lock()

GET_ROUTES = {
    (PROBE_PATH, ""): ("probe", b"ok", TEXT_CONTENT_TYPE, {}),
    (PAGE_PATH, ""): ("page", PAGE, "text/html; charset=utf-8", {}),
    (IMAGE_PATH, IMAGE_QUERY): (
        "image",
        IMAGE,
        "image/png",
        {"served_sha256": IMAGE_SHA256},
    ),
}


def sha256_text(value):
    return hashlib.sha256(value.encode("utf-8")).hexdigest()


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "BridgeWatcherFixture"
    sys_version = ""

    def record(self, route, status, **extra):
        parts = urlsplit(self.path)
        entry = {
            "route": route,
            "method": self.command,
            "path": parts.path,
            "query": parts.query,
            "host": self.headers.get("Host", ""),
            "tls": self.connection.version(),
            "status": status,
        }
        entry.update(extra)
        line = json.dumps(
            entry,
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        records_path = os.path.join(RECORDS, "requests.jsonl")
        with LOCK, open(records_path, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")

    def reply(self, status, body, content_type):
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Connection", "close")
        self.end_headers()
        self.wfile.write(body)

    def read_body(self):
        raw_length = self.headers.get("Content-Length", "0")
        return self.rfile.read(int(raw_length))

    def handle_vision(self, raw):
        try:
            body = json.loads(raw.decode("utf-8"))
            requests = body["requests"]
            first = requests[0]
            image = first["image"]
            decoded = base64.b64decode(image["content"], validate=True)
            features = [
                feature.get("type") for feature in first.get("features", [])
            ]
        except (ValueError, KeyError, IndexError, TypeError) as error:
            self.record("vision", 400, error=type(error).__name__)
            return self.reply(400, b'{"error":{"code":400}}', JSON_CONTENT_TYPE)
        self.record(
            "vision",
            200,
            api_key_sha256=sha256_text(self.headers.get("X-Goog-Api-Key", "")),
            content_type=self.headers.get("Content-Type", ""),
            request_count=len(requests),
            image_keys=sorted(image.keys()),
            features=features,
            image_sha256=hashlib.sha256(decoded).hexdigest(),
        )
        return self.reply(200, VISION, JSON_CONTENT_TYPE)

    def handle_pushover(self, raw):
        form = dict(parse_qsl(raw.decode("utf-8"), keep_blank_values=True))
        status, body = PUSHOVER_RESPONSES.get(
            PUSHOVER_MODE,
            PUSHOVER_RESPONSES["accept"],
        )
        self.record(
            "pushover",
            status,
            content_type=self.headers.get("Content-Type", ""),
            token_sha256=sha256_text(form.get("token", "")),
            user_sha256=sha256_text(form.get("user", "")),
            title=form.get("title", ""),
            message=form.get("message", ""),
            fields=sorted(form.keys()),
        )
        return self.reply(status, body, JSON_CONTENT_TYPE)

    def do_GET(self):
        parts = urlsplit(self.path)
        match = GET_ROUTES.get((parts.path, parts.query))
        if match is None:
            self.record("unexpected", 404)
            return self.reply(404, b"not found", TEXT_CONTENT_TYPE)
        route, body, content_type, extra = match
        self.record(route, 200, **extra)
        return self.reply(200, body, content_type)

    def do_POST(self):
        parts = urlsplit(self.path)
        raw = self.read_body()
        handlers = {
            (VISION_PATH, ""): self.handle_vision,
            (PUSHOVER_PATH, ""): self.handle_pushover,
        }
        handler = handlers.get((parts.path, parts.query))
        if handler is None:
            self.record("unexpected", 404)
            return self.reply(404, b"not found", TEXT_CONTENT_TYPE)
        return handler(raw)


def main():
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    context.load_cert_chain(
        os.path.join(TLS_DIR, "server.pem"),
        os.path.join(TLS_DIR, "server.key"),
    )
    server = ThreadingHTTPServer((BIND, PORT), Handler)
    server.daemon_threads = True
    server.socket = context.wrap_socket(server.socket, server_side=True)
    with open(os.path.join(RECORDS, "ready"), "w", encoding="utf-8") as handle:
        handle.write(HOST + "\n")
    server.serve_forever()


if __name__ == "__main__":
    main()
