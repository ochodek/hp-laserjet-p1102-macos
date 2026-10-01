"""Exercise privileged-hook decisions with isolated commands and no real writes."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
URI = "usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?serial=TEST"
SOCKET = "/private/var/run/cupsd"
MOCK = r'''#!/usr/bin/python3
import json, os, sys
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["CALL_LOG"], "a") as f:
    f.write(json.dumps([name, *sys.argv[1:]]) + "\n")
if name == "p1102-queue-check":
    state = os.environ["QUEUE_STATE"]
    if os.environ["NEXT_STATE"]:
        count = sum(json.loads(line)[0] == name
                    for line in Path(os.environ["CALL_LOG"]).read_text().splitlines())
        if count > 1:
            state = os.environ["NEXT_STATE"]
    if state in ("foreign", "busy", "error"):
        print("Queue verification failed: " + state, file=sys.stderr)
        sys.exit(1)
    print(state)
if name == "sysctl":
    print(os.environ["ARM64"])
if name == "lpinfo":
    print(os.environ["DEVICES"])
    sys.exit(int(os.environ["DISCOVERY_ERROR"]))
'''


class InstallerTests(unittest.TestCase):
    def install(self, state="absent", devices="", discovery_error=False,
                phase="postinstall", arm64=True, symlink=False, app_id=None,
                path=None, guard_missing=False, next_state=None):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            scripts = {p.name: p.read_text() for p in (ROOT / "scripts").iterdir()}
            for command, absolute in [
                ("lpinfo", "/usr/sbin/lpinfo"), ("lpadmin", "/usr/sbin/lpadmin"),
                ("sysctl", "/usr/sbin/sysctl")
            ]:
                mock = folder / command
                mock.write_text(MOCK)
                mock.chmod(0o755)
                self.assertTrue(any(absolute in script for script in scripts.values()))
                scripts = {name: script.replace(absolute, str(mock))
                           for name, script in scripts.items()}
            if not guard_missing:
                guard = folder / "p1102-queue-check"
                guard.write_text(MOCK)
                guard.chmod(0o755)
            target, app = folder / "driver-destination", folder / "app-destination"
            if app_id is not None:
                (app / "Contents").mkdir(parents=True)
                (app / "Contents/Info.plist").write_bytes(
                    plistlib.dumps({"CFBundleIdentifier": app_id}))
            if symlink:
                target.symlink_to(folder / "unrelated-target")
            for name, script in scripts.items():
                (folder / name).write_text(
                    script.replace("/Library/Printers/P1102Native", str(target))
                          .replace("/Applications/P1102 Utility.app", str(app)))
            log = folder / "calls.jsonl"
            result = subprocess.run(
                ["/bin/sh", str(folder / phase)], capture_output=True, text=True,
                env={**os.environ, "QUEUE_STATE": state, "DEVICES": devices,
                     "NEXT_STATE": next_state or "",
                     "DISCOVERY_ERROR": str(int(discovery_error)),
                     "ARM64": str(int(arm64)), "CALL_LOG": str(log),
                     **({"PATH": path} if path is not None else {})})
            calls = [json.loads(line) for line in log.read_text().splitlines()] if log.exists() else []
            return result, calls

    def test_a_unique_p1102_is_added_without_changing_the_default_printer(self):
        result, calls = self.install(devices="direct " + URI)
        self.assertEqual(result.returncode, 0, result.stderr)
        changes = [call for call in calls if call[0] == "lpadmin"]
        self.assertEqual(len(changes), 1)
        self.assertIn(URI, changes[0])
        self.assertIn("printer-is-shared=false", changes[0])
        self.assertNotIn("-d", changes[0])
        self.assertEqual(changes[0][1:3], ["-h", SOCKET])

    def test_multiple_p1102_devices_require_an_explicit_user_selection(self):
        result, calls = self.install(devices="direct " + URI + "\ndirect " + URI + "2")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(call[0] == "lpadmin" for call in calls))

    def test_an_existing_idle_p1102_queue_is_updated_without_recreating_it(self):
        result, calls = self.install(state="present")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[0] for call in calls], ["p1102-queue-check", "lpadmin"])
        self.assertEqual(calls[-1][1:5], ["-h", SOCKET, "-p", "HP_LaserJet_P1102_Native"])
        for argument in ["-v", "-o", "-d", "-x", "-E"]:
            self.assertNotIn(argument, calls[-1])

    def test_conflicts_busy_jobs_and_scheduler_errors_never_reconfigure_a_queue(self):
        for phase in ["preinstall", "postinstall"]:
            for state in ["foreign", "busy", "error"]:
                with self.subTest(phase=phase, state=state):
                    result, calls = self.install(phase=phase, state=state)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(any(call[0] in ("lpadmin", "lpinfo") for call in calls))

    def test_a_queue_changed_during_usb_discovery_is_rechecked_before_mutations(self):
        for state in ["foreign", "busy", "error", "unexpected"]:
            with self.subTest(state=state):
                result, calls = self.install(devices="direct " + URI, next_state=state)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual([call[0] for call in calls],
                                 ["p1102-queue-check", "lpinfo", "p1102-queue-check"])

    def test_an_owned_queue_created_during_discovery_is_updated_without_rebinding_it(self):
        result, calls = self.install(devices="direct " + URI, next_state="present")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call[0] for call in calls],
                         ["p1102-queue-check", "lpinfo", "p1102-queue-check", "lpadmin"])
        for argument in ["-v", "-o", "-d", "-x", "-E"]:
            self.assertNotIn(argument, calls[-1])

    def test_missing_or_unexpected_guard_results_stop_before_mutations(self):
        for phase in ["preinstall", "postinstall"]:
            for options in [{"guard_missing": True}, {"state": ""}, {"state": "present\nabsent"}]:
                with self.subTest(phase=phase, options=options):
                    result, calls = self.install(phase=phase, **options)
                    self.assertNotEqual(result.returncode, 0)
                    self.assertFalse(any(call[0] in ("lpadmin", "lpinfo") for call in calls))

    def test_discovery_failure_is_reported_and_no_device_is_not_an_error(self):
        result, calls = self.install(discovery_error=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse(any(call[0] == "lpadmin" for call in calls))
        result, calls = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(call[0] == "lpadmin" for call in calls))
        self.assertEqual(calls[-1][1:3], ["-h", SOCKET])

    def test_preflight_blocks_an_unsupported_mac_before_installing_files(self):
        result, calls = self.install(phase="preinstall", arm64=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Apple Silicon", result.stderr)
        self.assertFalse(any(call[0] == "p1102-queue-check" for call in calls))

    def test_preflight_blocks_a_redirected_driver_destination(self):
        result, calls = self.install(phase="preinstall", symlink=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("symbolic link", result.stderr)
        self.assertFalse(any(call[0] == "p1102-queue-check" for call in calls))

    def test_preflight_uses_the_system_path_resolver_before_privileged_work(self):
        with tempfile.TemporaryDirectory() as directory:
            attacker = Path(directory)
            (attacker / "dirname").write_text(
                '#!/bin/sh\nprintf \'%s\\n\' "' + str(attacker) + '"\n')
            (attacker / "dirname").chmod(0o755)
            for name in ["check-queue", "p1102-queue-check"]:
                (attacker / name).write_text("#!/bin/sh\nprintf 'absent\\n'\n")
                (attacker / name).chmod(0o755)
            result, calls = self.install(phase="preinstall", state="foreign", path=str(attacker))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("foreign", result.stderr)
        self.assertFalse(any(call[0] == "lpadmin" for call in calls))

    def test_preflight_preserves_an_unrelated_application_with_the_same_name(self):
        result, calls = self.install(phase="preinstall", app_id="org.example.unrelated")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Another application", result.stderr)
        self.assertFalse(any(call[0] == "p1102-queue-check" for call in calls))
        for app_id in ["cz.marek.p1102-native.utility", None]:
            result, calls = self.install(phase="preinstall", app_id=app_id)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertFalse(any(call[0] == "lpadmin" for call in calls))


if __name__ == "__main__":
    unittest.main(verbosity=2)
