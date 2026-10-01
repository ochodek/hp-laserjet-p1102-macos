"""Exercise the real libcups client against an isolated Unix-socket IPP server."""
from contextlib import contextmanager
from http.server import BaseHTTPRequestHandler
import os
from pathlib import Path
import socketserver
import struct
import subprocess
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
QUEUE = "HP_LaserJet_P1102_Native"
URI = "usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?serial=TEST"


def attribute(tag, name, value):
    name = name.encode()
    value = value if isinstance(value, bytes) else value.encode()
    return bytes([tag]) + struct.pack(">H", len(name)) + name + struct.pack(">H", len(value)) + value


def decode_request(data):
    operation = struct.unpack(">H", data[2:4])[0]
    values = {}
    position = 8
    name = None
    while position < len(data):
        tag = data[position]
        position += 1
        if tag == 3:
            break
        if tag < 16:
            continue
        size = struct.unpack_from(">H", data, position)[0]
        position += 2
        if size:
            name = data[position:position + size].decode()
        position += size
        size = struct.unpack_from(">H", data, position)[0]
        position += 2
        value = data[position:position + size]
        position += size
        values.setdefault(name, []).append(value)
    return operation, values


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def log_message(self, *args):
        pass

    def do_POST(self):
        request = self.rfile.read(int(self.headers["Content-Length"]))
        operation, attributes = decode_request(request)
        self.server.calls.append((operation, attributes))
        mode = self.server.mode
        if mode == "http-unauthorized":
            self.send_response(401)
            self.send_header("WWW-Authenticate", 'Basic realm="local-test"')
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        if mode == "http-error":
            self.send_response(500)
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        status = 0
        body = bytes([1]) + attribute(0x47, "attributes-charset", "utf-8")
        body += attribute(0x48, "attributes-natural-language", self.server.language)
        if mode == "unauthorized":
            status = 0x0401
        elif mode == "absent" and operation == 0x000B:
            status = 0x0406
        elif mode == "jobs-error" and operation == 0x000A:
            status = 0x0502
        elif mode == "substituted":
            status = 0x0001
        elif operation == 0x000B:
            uri = "ipp://example.invalid/unrelated" if mode == "foreign" else URI
            body += bytes([4]) + attribute(0x42, "printer-name", QUEUE)
            if mode != "missing-uri":
                body += attribute(0x45, "device-uri", uri)
            body += attribute(0x23, "printer-type", struct.pack(">I", 1 if mode == "class" else 0))
        elif operation == 0x000A and mode == "busy":
            body += bytes([2]) + attribute(0x21, "job-id", struct.pack(">I", 243))
        elif operation == 0x000A and mode == "jobs-wrong-group":
            body += bytes([4]) + attribute(0x21, "job-id", struct.pack(">I", 243))
        elif operation == 0x000A and mode == "jobs-operation-group":
            body += attribute(0x21, "job-id", struct.pack(">I", 243))
        reply = request[:2] + struct.pack(">H", status) + request[4:8] + body + bytes([3])
        if mode == "malformed":
            reply = b"invalid IPP"
        self.send_response(200)
        self.send_header("Content-Type", "application/ipp")
        self.send_header("Content-Length", str(len(reply)))
        self.end_headers()
        if mode == "timeout":
            time.sleep(6)
        try:
            self.wfile.write(reply)
        except BrokenPipeError:
            pass


class QueueTransportTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.directory = tempfile.TemporaryDirectory(prefix="p1102-ipp-", dir="/private/tmp")
        cls.folder = Path(cls.directory.name)
        cls.socket_path = cls.folder / "cups.sock"
        cls.executable = cls.folder / "guard"
        subprocess.run([
            "xcrun", "clang", "-arch", "arm64", "-mmacosx-version-min=11.0",
            "-std=c11", "-Wall", "-Wextra", "-Werror",
            f'-DP1102_CUPS_SOCKET="{cls.socket_path}"',
            str(ROOT / "src/queue-check.c"), "-lcups", "-o", str(cls.executable)
        ], check=True)

    @classmethod
    def tearDownClass(cls):
        cls.directory.cleanup()

    @contextmanager
    def server(self, mode="ready", language="cs"):
        server = socketserver.UnixStreamServer(str(self.socket_path), Handler)
        server.mode, server.language, server.calls = mode, language, []
        worker = threading.Thread(target=server.serve_forever, daemon=True)
        worker.start()
        try:
            yield server
        finally:
            server.shutdown()
            server.server_close()
            self.socket_path.unlink(missing_ok=True)
            worker.join()

    def run_guard(self, **environment):
        return subprocess.run([str(self.executable)], capture_output=True, text=True,
                              timeout=15, env={**os.environ, **environment})

    def test_czech_english_german_and_japanese_do_not_change_queue_identity(self):
        for language in ["cs", "en", "de", "ja"]:
            with self.subTest(language=language), self.server(language=language) as server:
                result = self.run_guard(LC_ALL="C", LANG="C")
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, "present\n")
                self.assertEqual([call[0] for call in server.calls], [0x000B, 0x000A])

    def test_a_real_not_found_response_is_the_only_successful_absence(self):
        with self.server("absent") as server:
            result = self.run_guard()
            self.assertEqual((result.returncode, result.stdout), (0, "absent\n"))
            self.assertEqual(len(server.calls), 1)

    def test_errors_conflicts_missing_attributes_classes_and_jobs_stop_the_guard(self):
        for mode in ["unauthorized", "jobs-error", "substituted", "foreign",
                     "missing-uri", "class", "busy", "malformed",
                     "http-unauthorized", "http-error", "jobs-wrong-group",
                     "jobs-operation-group"]:
            with self.subTest(mode=mode), self.server(mode):
                result = self.run_guard()
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(result.stdout, "")
                self.assertTrue(result.stderr)
                self.assertNotIn(URI, result.stderr)
                self.assertNotIn("serial=TEST", result.stderr)

    def test_a_stopped_scheduler_is_not_treated_as_a_missing_queue(self):
        result = self.run_guard()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(result.stdout, "")

    def test_an_unresponsive_scheduler_times_out_without_changing_state(self):
        with self.server("timeout"):
            started = time.monotonic()
            result = self.run_guard()
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(result.stdout, "")
            self.assertLess(time.monotonic() - started, 12)

    def test_inherited_cups_settings_cannot_redirect_the_guard(self):
        with self.server() as server:
            result = self.run_guard(CUPS_SERVER="example.invalid:9", IPP_PORT="9",
                                    CUPS_USER="another-user")
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(server.calls), 2)
            for operation, attributes in server.calls:
                self.assertEqual(attributes["printer-uri"],
                                 [f"ipp://localhost:631/printers/{QUEUE}".encode()])
                self.assertNotEqual(attributes["requesting-user-name"], [b"another-user"])
                if operation == 0x000A:
                    self.assertEqual(attributes["which-jobs"], [b"not-completed"])
                    self.assertEqual(attributes["my-jobs"], [b"\0"])
                    self.assertEqual(attributes["limit"], [struct.pack(">I", 1)])
                    self.assertEqual(attributes["requested-attributes"], [b"job-id"])
                else:
                    self.assertEqual(attributes["requested-attributes"],
                                     [b"printer-name", b"device-uri", b"printer-type"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
