"""Protect active jobs, unrelated queues and files during explicit removal."""
import json
import os
from pathlib import Path
import plistlib
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
MOCK = r'''#!/usr/bin/python3
import os, sys, json
from pathlib import Path
name = Path(sys.argv[0]).name
with open(os.environ["CALL_LOG"], "a") as f:
    f.write(json.dumps([name, *sys.argv[1:]]) + "\n")
if name == "id":
    print(os.environ["ROOT_UID"])
if name == "p1102-queue-check":
    state = os.environ["QUEUE_STATE"]
    if state in ("foreign", "busy", "error"):
        print("Queue verification failed: " + state, file=sys.stderr)
        sys.exit(1)
    print(state)
'''


class UninstallTests(unittest.TestCase):
    def remove(self, state="present", redirect=False, guard_missing=False, root=True):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            log = folder / "calls"
            script = (ROOT / "uninstall.sh").read_text()
            for command, absolute in [
                ("id", "/usr/bin/id"), ("lpadmin", "/usr/sbin/lpadmin"),
                ("rm", "/bin/rm"), ("rmdir", "/bin/rmdir"), ("pkgutil", "/usr/sbin/pkgutil"),
                ("p1102-queue-check", "/Library/Printers/P1102Native/p1102-queue-check")
            ]:
                mock = folder / command
                if command != "p1102-queue-check" or not guard_missing:
                    mock.write_text(MOCK)
                    mock.chmod(0o755)
                script = script.replace(absolute, str(mock))
            target, app = folder / "driver", folder / "app"
            target.mkdir()
            (app / "Contents/Resources").mkdir(parents=True)
            (app / "Contents/Info.plist").write_bytes(
                plistlib.dumps({"CFBundleIdentifier": "cz.marek.p1102-native.utility"}))
            if redirect:
                (target / "LICENSE").symlink_to(folder / "unrelated")
            script = script.replace("/Library/Printers/P1102Native", str(target))
            script = script.replace("/Applications/P1102 Utility.app", str(app))
            fixture = folder / "uninstall.sh"
            fixture.write_text(script)
            result = subprocess.run(
                ["/bin/sh", str(fixture)], capture_output=True, text=True,
                env={**os.environ, "CALL_LOG": str(log), "QUEUE_STATE": state,
                     "ROOT_UID": "0" if root else "501"})
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            mutations = [call for call in calls if call[0] in ("lpadmin", "rm", "rmdir", "pkgutil")]
            return result, mutations

    def test_pending_jobs_conflicts_and_scheduler_errors_never_remove_anything(self):
        for state in ["busy", "foreign", "error"]:
            with self.subTest(state=state):
                result, changes = self.remove(state=state)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(changes, [])

    def test_missing_or_unexpected_guard_results_never_remove_anything(self):
        for options in [{"guard_missing": True}, {"state": ""}, {"state": "present\nabsent"}]:
            with self.subTest(options=options):
                result, changes = self.remove(**options)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual(changes, [])

    def test_symlinks_cannot_redirect_privileged_removal(self):
        result, changes = self.remove(redirect=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(changes, [])

    def test_admin_permission_is_required_before_verification_or_removal(self):
        result, changes = self.remove(root=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(changes, [])

    def test_explicit_removal_uses_only_named_files_and_its_own_queue(self):
        result, changes = self.remove()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual([call for call in changes if call[0] == "lpadmin"], [
            ["lpadmin", "-h", "/private/var/run/cupsd", "-x", "HP_LaserJet_P1102_Native"]
        ])
        self.assertFalse(any("-r" in arg or "-R" in arg for call in changes
                             if call[0] == "rm" for arg in call[1:]))
        for suffix in ["/Contents/Resources/P1102Utility.icns", "/p1102-queue-check"]:
            self.assertTrue(any(arg.endswith(suffix) for call in changes
                                if call[0] == "rm" for arg in call[1:]))
        self.assertEqual(changes[-1], ["pkgutil", "--forget", "cz.marek.p1102-native"])

    def test_absent_queue_allows_only_the_owned_files_to_be_removed(self):
        result, changes = self.remove(state="absent")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(any(call[0] == "lpadmin" for call in changes))
        self.assertEqual(changes[-1], ["pkgutil", "--forget", "cz.marek.p1102-native"])

    def test_dismissing_the_launcher_does_not_request_privileges(self):
        with tempfile.TemporaryDirectory() as directory:
            script = (ROOT / "installer/Uninstall.command").read_text().replace(
                "/usr/bin/sudo", "/usr/bin/false")
            fixture = Path(directory) / "Uninstall.command"
            fixture.write_text(script)
            result = subprocess.run(["/bin/sh", str(fixture)], input="cancel\n",
                                    capture_output=True, text=True)
            self.assertEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main(verbosity=2)
