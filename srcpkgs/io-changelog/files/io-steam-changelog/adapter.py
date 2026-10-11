#!/usr/bin/python3
"""Io's opt-in CEF patch-notes adapter. Uses only localhost CEF CDP."""
import base64
import hashlib
import json
import os
import pwd
import re
import socket
import struct
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime
from pathlib import Path

PORT = 8080
DEBUG_FLAG = Path.home() / ".steam/steam/.cef-enable-remote-debugging"
CREATED_FLAG = Path.home() / ".local/state/io-steam-changelog/created-debug-flag"
SPEC = Path("/usr/share/io/changelog/steam.json")
SUMMARY = Path("/run/io-update-changelog.json")
MATCH_PATH = "/events/ajaxgetadjacentpartnerevents/"
APP_ID = "1675200"
WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"


def log(message):
    logfile = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "io-steam-changelog.log"
    try:
        logfile.parent.mkdir(parents=True, exist_ok=True)
        with logfile.open("a", encoding="utf-8") as out:
            out.write(f"{datetime.now().isoformat(timespec='seconds')} {message}\n")
    except OSError:
        pass


def prepare_debug_flag():
    if not DEBUG_FLAG.exists():
        DEBUG_FLAG.parent.mkdir(parents=True, exist_ok=True)
        DEBUG_FLAG.touch(mode=0o600)
        CREATED_FLAG.parent.mkdir(parents=True, exist_ok=True)
        CREATED_FLAG.write_text("created by io-steam-changelog\n", encoding="utf-8")
        log("enabled CEF remote debugging for the current user")


def cleanup_debug_flag():
    if CREATED_FLAG.exists():
        DEBUG_FLAG.unlink(missing_ok=True)
        CREATED_FLAG.unlink(missing_ok=True)
        log("removed CEF remote debugging flag created by this package")
    else:
        log("left pre-existing CEF remote debugging flag untouched")
    return 0


def stop_legacy_monitor():
    """Stop the pre-runit background observer when upgrading this package."""
    try:
        legacy_pidfile = Path(f"/run/user/{pwd.getpwnam('deck').pw_uid}/io-steam-changelog.pid")
    except KeyError:
        return 0
    try:
        pid = int(legacy_pidfile.read_text(encoding="ascii").strip())
        command = Path(f"/proc/{pid}/cmdline").read_bytes().replace(b"\0", b" ").decode(errors="ignore")
        if "io-steam-changelog" in command and "monitor" in command:
            os.kill(pid, 15)
    except (OSError, ValueError, KeyError):
        pass
    legacy_pidfile.unlink(missing_ok=True)
    return 0


def service():
    prepare_debug_flag()
    log("CEF observer service started")
    monitor()


def matching_url(url):
    try:
        p = urllib.parse.urlsplit(url)
        return MATCH_PATH in p.path.lower() and APP_ID in urllib.parse.parse_qs(p.query).get("appid", [])
    except Exception:
        return False


def load_changelog():
    try:
        spec = json.loads(SPEC.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        spec = {"headline": "Io system update", "intro": "Io package update details.",
                "release_url": "https://github.com/Lolzen/io-packages/wiki/Changelog", "notes": []}
    try:
        summary = json.loads(SUMMARY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        summary = {}
    return spec, summary


def bb(text):
    return str(text).replace("[", "&#91;").replace("]", "&#93;")


def render_body(spec, summary):
    lines = []
    intro = spec.get("intro", "Io system update")
    if intro:
        lines.append(f"[p]{bb(intro)}[/p]")
    build = summary.get("build_id")
    packages = summary.get("packages", [])
    if build:
        count = summary.get("package_count", len(packages))
        size = int(summary.get("download_bytes", 0))
        lines.append(f"[p]Build {bb(build)}: {count} package update(s), {size / 1048576:.1f} MiB download.[/p]")
    if packages:
        lines.append("[list]")
        for item in packages:
            name = bb(item.get("name", "package"))
            old = item.get("from")
            new = bb(item.get("to", ""))
            change = f"{bb(old)} → {new}" if old else f"→ {new} (new)"
            lines.append(f"[*][p]{name}: {change}[/p][/*]")
        lines.append("[/list]")
    for note in spec.get("notes", []):
        lines.append(f"[p]{bb(note)}[/p]")
    url = spec.get("release_url", "")
    if url:
        lines.append(f'[p][url="{url}"]Io release notes[/url][/p]')
    return "".join(lines)


def replace_steam_event(payload):
    spec, summary = load_changelog()
    events = payload.get("events")
    if not isinstance(events, list):
        return payload, False
    title = str(spec.get("headline", "Io system update"))
    body = render_body(spec, summary)
    replaced = False
    for event in events:
        if not isinstance(event, dict):
            continue
        announcement = event.get("announcement_body")
        fallback_name = announcement.get("headline", "") if isinstance(announcement, dict) else ""
        name = str(event.get("event_name") or fallback_name).strip()
        # App 1675200 also carries Steam client announcements. Replace only
        # the OS update event; retain adjacent client notes unchanged.
        if not name.lower().startswith("steamos"):
            continue
        event["event_name"] = title
        event["event_notes"] = "see announcement body"
        announcement = event.get("announcement_body")
        if not isinstance(announcement, dict):
            announcement = {}
            event["announcement_body"] = announcement
        announcement["headline"] = title
        announcement["body"] = body
        replaced = True
    return payload, replaced


def targets():
    with urllib.request.urlopen(f"http://127.0.0.1:{PORT}/json", timeout=4) as r:
        return json.load(r)


class WebSocket:
    def __init__(self, url):
        parts = urllib.parse.urlsplit(url)
        if parts.scheme != "ws" or parts.hostname not in ("127.0.0.1", "localhost", "::1"):
            raise RuntimeError("DevTools-WebSocket is not local")
        self.sock = socket.create_connection((parts.hostname, parts.port or PORT), timeout=5)
        self.sock.settimeout(None)
        self.buf = b""
        self.next_id = 0
        key = base64.b64encode(os.urandom(16)).decode("ascii")
        path = parts.path or "/"
        if parts.query:
            path += "?" + parts.query
        request = (f"GET {path} HTTP/1.1\r\nHost: {parts.hostname}:{parts.port or PORT}\r\n"
                   f"Upgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Key: {key}\r\n"
                   "Sec-WebSocket-Version: 13\r\n\r\n").encode("ascii")
        self.sock.sendall(request)
        headers = self._until(b"\r\n\r\n", 65536).decode("latin1")
        lines = headers.split("\r\n")
        parsed = {k.strip().lower(): v.strip() for line in lines[1:] if ":" in line
                  for k, v in [line.split(":", 1)]}
        accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
        if " 101 " not in f" {lines[0]} " or parsed.get("sec-websocket-accept") != accept:
            self.close()
            raise RuntimeError("DevTools-WebSocket handshake failed")
        self.events = []

    def _until(self, marker, limit):
        data = b""
        while marker not in data:
            chunk = self.sock.recv(4096)
            if not chunk:
                raise RuntimeError("WebSocket closed during handshake")
            data += chunk
            if len(data) > limit:
                raise RuntimeError("oversized WebSocket handshake")
        head, self.buf = data.split(marker, 1)
        return head + marker

    def _exact(self, n, deadline=None):
        if deadline is not None and time.monotonic() >= deadline:
            raise socket.timeout("DevTools command timed out")
        while len(self.buf) < n:
            if deadline is not None:
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise socket.timeout("DevTools command timed out")
                self.sock.settimeout(remaining)
            chunk = self.sock.recv(max(4096, n - len(self.buf)))
            if not chunk:
                raise RuntimeError("DevTools-WebSocket closed")
            self.buf += chunk
        if deadline is not None and time.monotonic() >= deadline:
            raise socket.timeout("DevTools command timed out")
        value, self.buf = self.buf[:n], self.buf[n:]
        return value

    def send(self, obj):
        payload = json.dumps(obj, separators=(",", ":")).encode()
        n = len(payload)
        if n < 126:
            head = bytes((0x81, 0x80 | n))
        elif n < 65536:
            head = bytes((0x81, 0x80 | 126)) + struct.pack("!H", n)
        else:
            head = bytes((0x81, 0x80 | 127)) + struct.pack("!Q", n)
        mask = os.urandom(4)
        self.sock.sendall(head + mask + bytes(b ^ mask[i % 4] for i, b in enumerate(payload)))

    def recv(self, deadline=None):
        parts = bytearray()
        started = False
        while True:
            a, b = self._exact(2, deadline)
            fin, opcode = bool(a & 0x80), a & 15
            masked, n = bool(b & 0x80), b & 127
            if n == 126:
                n = struct.unpack("!H", self._exact(2, deadline))[0]
            elif n == 127:
                n = struct.unpack("!Q", self._exact(8, deadline))[0]
            if n > 16 * 1024 * 1024:
                raise RuntimeError("oversized DevTools message")
            mask = self._exact(4, deadline) if masked else None
            data = self._exact(n, deadline)
            if mask:
                data = bytes(x ^ mask[i % 4] for i, x in enumerate(data))
            if opcode == 8:
                raise RuntimeError("DevTools-WebSocket closed")
            if opcode == 9:
                self.sock.sendall(bytes((0x8A, 0x80 | len(data))) + (m := os.urandom(4)) + bytes(x ^ m[i % 4] for i, x in enumerate(data)))
                continue
            if opcode == 10:
                continue
            if opcode == 1:
                parts = bytearray(data); started = True
            elif opcode == 0 and started:
                parts.extend(data)
            else:
                continue
            if fin:
                return json.loads(parts.decode("utf-8"))

    def call(self, method, params=None, timeout=5):
        self.next_id += 1
        ident = self.next_id
        command = {"id": ident, "method": method}
        if params is not None:
            command["params"] = params
        deadline = time.monotonic() + timeout
        try:
            self.sock.settimeout(timeout)
            self.send(command)
            while True:
                # The event loop intentionally waits indefinitely, but a CDP
                # command issued while Fetch has paused a response must not
                # leave that request blocked forever if CEF stops answering.
                msg = self.recv(deadline)
                if time.monotonic() >= deadline:
                    raise socket.timeout("DevTools command timed out")
                if msg.get("id") == ident:
                    if "error" in msg:
                        raise RuntimeError(msg["error"].get("message", method))
                    return msg.get("result", {})
                if msg.get("method"):
                    self.events.append(msg)
        except socket.timeout:
            # A timeout can occur halfway through a WebSocket frame. Discard
            # this connection instead of trying to parse an incomplete frame
            # or issuing more CDP commands on a desynchronized stream.
            self.close()
            raise
        finally:
            try:
                self.sock.settimeout(None)
            except OSError:
                pass

    def send_without_waiting(self, method, params=None):
        """Send a recovery command without waiting on a possibly stuck CEF."""
        self.next_id += 1
        command = {"id": self.next_id, "method": method}
        if params is not None:
            command["params"] = params
        self.send(command)

    def event(self):
        while True:
            if self.events:
                return self.events.pop(0)
            msg = self.recv()
            if msg.get("method"):
                return msg

    def close(self):
        try:
            self.sock.close()
        except Exception:
            pass


def continue_paused(ws, request_id):
    try:
        ws.call("Fetch.continueResponse", {"requestId": request_id}, timeout=2)
        return
    except Exception:
        pass
    try:
        # Recovery must itself be non-blocking: this is used after a timed
        # out body/fulfill command, when the response may still be paused.
        ws.send_without_waiting("Fetch.continueRequest", {"requestId": request_id})
    except Exception:
        pass


def fulfill(ws, request_id, status, headers, body):
    kept = []
    for h in headers or []:
        if h.get("name", "").lower() not in ("content-length", "content-encoding", "transfer-encoding"):
            kept.append(h)
    ws.call("Fetch.fulfillRequest", {"requestId": request_id,
             "responseCode": int(status or 200), "responseHeaders": kept,
             "body": base64.b64encode(body).decode("ascii")}, timeout=3)


def handle_paused(ws, params):
    rid = params.get("requestId")
    url = params.get("request", {}).get("url", "")
    if not rid:
        return
    if not matching_url(url):
        continue_paused(ws, rid)
        return
    raw = None
    status = params.get("responseStatusCode", 200)
    headers = params.get("responseHeaders", [])
    try:
        result = ws.call("Fetch.getResponseBody", {"requestId": rid}, timeout=3)
        original = result.get("body", "")
        raw = base64.b64decode(original) if result.get("base64Encoded") else original.encode("utf-8")
        payload = json.loads(raw.decode("utf-8"))
        payload, changed = replace_steam_event(payload)
        out = json.dumps(payload, ensure_ascii=False, separators=(",", ":")).encode("utf-8") if changed else raw
        fulfill(ws, rid, status, headers, out)
        if changed:
            log("replaced SteamOS patch-notes response with Io changelog")
    except Exception as exc:
        log(f"response replacement skipped ({type(exc).__name__}: {exc})")
        if raw is not None:
            try:
                fulfill(ws, rid, status, headers, raw)
                return
            except Exception:
                pass
        continue_paused(ws, rid)


def monitor():
    log("monitor started")
    retry_delay = 2
    while True:
        ws = None
        try:
            available = targets()
            target = next((t for t in available
                           if "sharedjscontext" in " ".join(str(t.get(k, "")) for k in ("title", "url", "type")).lower()
                           and t.get("webSocketDebuggerUrl")), None)
            if target is None:
                time.sleep(retry_delay)
                retry_delay = min(retry_delay * 2, 30)
                continue
            ws = WebSocket(target["webSocketDebuggerUrl"])
            patterns = [
                "*/events/ajaxgetadjacentpartnerevents/*?appid=1675200*",
                "*/events/ajaxgetadjacentpartnerevents/*&appid=1675200*",
            ]
            ws.call("Fetch.enable", {"patterns": [{"urlPattern": pattern,
                                                     "requestStage": "Response"}
                                                    for pattern in patterns]})
            log(f"watching {target.get('title')} [{target.get('id')}]")
            while True:
                event = ws.event()
                retry_delay = 2
                if event.get("method") == "Fetch.requestPaused":
                    handle_paused(ws, event.get("params", {}))
        except Exception as exc:
            log(f"CEF observer reconnecting ({type(exc).__name__}: {exc})")
            time.sleep(retry_delay)
            retry_delay = min(retry_delay * 2, 30)
        finally:
            if ws:
                ws.close()


def main(argv):
    command = argv[1] if len(argv) > 1 else ""
    if command == "service":
        service()
    if command == "cleanup":
        return cleanup_debug_flag()
    if command == "legacy-stop":
        return stop_legacy_monitor()
    print("usage: io-steam-changelog [service|cleanup|legacy-stop]", file=sys.stderr)
    return 2


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
