#!/usr/bin/env python3
"""NeighborhoodSkout home server.

Serves index.html and keeps ONE shared copy of your map (plus photos) in a data
folder, so every device that opens the page sees the same map.
Python standard library only. Settings come from config.env (SKOUT_HOST, SKOUT_PORT, SKOUT_DATA, SKOUT_PASSWORD).
Reach it from your devices over Tailscale. Do NOT expose it to the public internet.
"""
import base64, hashlib, hmac, json, os, re, sys, tempfile, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

HERE = os.path.dirname(os.path.abspath(__file__))
DATA = os.path.abspath(os.path.expanduser(os.environ.get("SKOUT_DATA", "~/skout-data")))
HOST = os.environ.get("SKOUT_HOST", "127.0.0.1")
PORT = int(os.environ.get("SKOUT_PORT", "8095"))
PASSWORD = os.environ.get("SKOUT_PASSWORD", "")  # optional; empty = no login
INDEX = os.environ.get("SKOUT_INDEX", os.path.join(HERE, "index.html"))
STATE = os.path.join(DATA, "state.json")
PHOTOS = os.path.join(DATA, "photos")
SNAPS = os.path.join(DATA, "snapshots")
MAX_STATE = 20 * 1024 * 1024
MAX_PHOTO = 8 * 1024 * 1024
KEEP_SNAPSHOTS = 300
ID_RE = re.compile(r"^[A-Za-z0-9_-]{1,64}$")
LOCK = threading.Lock()


def rev_of(data):
    return hashlib.sha256(data).hexdigest()[:16]


def read_state():
    try:
        with open(STATE, "rb") as f:
            return f.read()
    except FileNotFoundError:
        return None


def atomic_write(path, data):
    d = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=d, prefix=".tmp-")
    try:
        with os.fdopen(fd, "wb") as f:
            f.write(data)
            f.flush()
            os.fsync(f.fileno())
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def counts(data):
    try:
        j = json.loads(data)
        houses = [b for b in j.get("blocks", []) if b.get("kind") == "house"]
        return len(houses), sum(len(b.get("residents", [])) for b in houses)
    except Exception:
        return 0, 0


def snapshot_if_needed(old, new):
    """Keep a copy of the previous map: at most every 5 minutes, and always before a big shrink."""
    if not old:
        return
    os.makedirs(SNAPS, exist_ok=True)
    names = sorted(os.listdir(SNAPS))
    last = os.path.getmtime(os.path.join(SNAPS, names[-1])) if names else 0
    shrink = len(new) < len(old) * 0.7
    if shrink or time.time() - last > 300:
        name = time.strftime("state-%Y%m%d-%H%M%S", time.localtime()) + ("-before-shrink" if shrink else "") + ".json"
        atomic_write(os.path.join(SNAPS, name), old)
        names = sorted(os.listdir(SNAPS))
        for n in names[:-KEEP_SNAPSHOTS]:
            try:
                os.unlink(os.path.join(SNAPS, n))
            except OSError:
                pass


class Handler(BaseHTTPRequestHandler):
    server_version = "SkoutServer/1"

    def log_message(self, fmt, *args):
        if os.environ.get("SKOUT_LOG"):
            sys.stderr.write("%s - %s\n" % (self.address_string(), fmt % args))

    # ---- helpers ----
    def send(self, code, body=b"", ctype="application/json", extra=None):
        if isinstance(body, (dict, list)):
            body = json.dumps(body).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Robots-Tag", "noindex, nofollow")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        for k, v in (extra or {}).items():
            self.send_header(k, v)
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def body(self, limit):
        n = int(self.headers.get("Content-Length") or 0)
        if n > limit:
            self.send(413, {"error": "too large"})
            return None
        return self.rfile.read(n)

    def authed(self):
        if not PASSWORD:
            return True
        h = self.headers.get("Authorization", "")
        if h.startswith("Basic "):
            try:
                _, _, pw = base64.b64decode(h[6:]).decode().partition(":")
                if hmac.compare_digest(pw.encode(), PASSWORD.encode()):
                    return True
            except Exception:
                pass
        self.send(401, b"Login required", "text/plain", {"WWW-Authenticate": 'Basic realm="NeighborhoodSkout"'})
        return False

    def guard(self):
        # blocks simple cross-site requests: browsers can't add this header to forms/images
        if self.headers.get("X-Skout") != "1":
            self.send(403, {"error": "missing header"})
            return False
        return True

    # ---- routes ----
    def do_HEAD(self):
        self.do_GET()

    def do_GET(self):
        if not self.authed():
            return
        p = urlparse(self.path).path
        if p in ("/", "/index.html"):
            try:
                with open(INDEX, "rb") as f:
                    return self.send(200, f.read(), "text/html; charset=utf-8")
            except FileNotFoundError:
                return self.send(500, b"index.html not found next to server.py", "text/plain")
        if p == "/robots.txt":
            return self.send(200, b"User-agent: *\nDisallow: /\n", "text/plain")
        if not p.startswith("/api/"):
            return self.send(404, {"error": "not found"})
        if not self.guard():
            return
        if p == "/api/ping":
            data = read_state()
            h, pe = counts(data) if data else (0, 0)
            return self.send(200, {"app": "NeighborhoodSkout-server", "rev": rev_of(data) if data else "0", "houses": h, "people": pe})
        if p == "/api/state":
            data = read_state()
            if data is None:
                return self.send(404, {"error": "no state yet"}, extra={"X-Rev": "0"})
            return self.send(200, data, extra={"X-Rev": rev_of(data)})
        if p == "/api/photos":
            os.makedirs(PHOTOS, exist_ok=True)
            out = []
            for n in os.listdir(PHOTOS):
                if n.endswith(".jpg") and ID_RE.match(n[:-4]):
                    out.append({"id": n[:-4], "size": os.path.getsize(os.path.join(PHOTOS, n))})
            return self.send(200, out)
        m = re.match(r"^/api/photo/([^/]+)$", p)
        if m and ID_RE.match(m.group(1)):
            try:
                with open(os.path.join(PHOTOS, m.group(1) + ".jpg"), "rb") as f:
                    return self.send(200, f.read(), "image/jpeg")
            except FileNotFoundError:
                return self.send(404, {"error": "no photo"})
        return self.send(404, {"error": "not found"})

    def do_PUT(self):
        if not self.authed():
            return
        p = urlparse(self.path).path
        if not self.guard():
            return
        if p == "/api/state":
            data = self.body(MAX_STATE)
            if data is None:
                return
            try:
                j = json.loads(data)
                assert isinstance(j, dict) and isinstance(j.get("blocks"), list)
            except Exception:
                return self.send(400, {"error": "not a NeighborhoodSkout map"})
            want = self.headers.get("If-Match")
            if want is None:
                return self.send(428, {"error": "If-Match required"})
            with LOCK:
                os.makedirs(DATA, exist_ok=True)
                old = read_state()
                cur = rev_of(old) if old else "0"
                if want != cur:
                    return self.send(412, {"error": "changed elsewhere", "rev": cur})
                snapshot_if_needed(old, data)
                atomic_write(STATE, data)
            return self.send(200, {"rev": rev_of(data)})
        m = re.match(r"^/api/photo/([^/]+)$", p)
        if m and ID_RE.match(m.group(1)):
            data = self.body(MAX_PHOTO)
            if data is None:
                return
            if data[:3] != b"\xff\xd8\xff":
                return self.send(400, {"error": "not a JPEG"})
            with LOCK:
                os.makedirs(PHOTOS, exist_ok=True)
                atomic_write(os.path.join(PHOTOS, m.group(1) + ".jpg"), data)
            return self.send(200, {"ok": True})
        return self.send(404, {"error": "not found"})

    def do_DELETE(self):
        if not self.authed():
            return
        p = urlparse(self.path).path
        if not self.guard():
            return
        m = re.match(r"^/api/photo/([^/]+)$", p)
        if m and ID_RE.match(m.group(1)):
            with LOCK:
                try:
                    os.unlink(os.path.join(PHOTOS, m.group(1) + ".jpg"))
                except FileNotFoundError:
                    pass
            return self.send(200, {"ok": True})
        return self.send(404, {"error": "not found"})


def main():
    os.makedirs(DATA, exist_ok=True)
    srv = ThreadingHTTPServer((HOST, PORT), Handler)
    print(f"NeighborhoodSkout server on http://{HOST}:{PORT}  data: {DATA}", flush=True)
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
