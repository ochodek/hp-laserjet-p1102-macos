"""Exercise queue ownership decisions without administrator access or printing."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
URI = 'usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?serial=TEST'


class InstallerTests(unittest.TestCase):
    def install(self, current=None, devices='', discovery_error=False, phase='postinstall', arm64=True, symlink=False, app_id=None):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            scripts = {p.name:p.read_text() for p in (ROOT/'scripts').iterdir() if p.is_file()}
            for command, path in [('lpstat', '/usr/bin/lpstat'), ('lpinfo', '/usr/sbin/lpinfo'), ('lpadmin', '/usr/sbin/lpadmin'), ('sysctl','/usr/sbin/sysctl')]:
                mock = folder/command
                mock.write_text('#!/usr/bin/python3\n' +
                    'import json,os,sys\nfrom pathlib import Path\n' +
                    'name=Path(sys.argv[0]).name\n' +
                    'with open(os.environ["CALL_LOG"],"a") as f:f.write(json.dumps([name,*sys.argv[1:]])+"\\n")\n' +
                    'if name=="lpstat":\n print(os.environ["CURRENT_QUEUE"]);sys.exit(0 if os.environ["CURRENT_QUEUE"] else 1)\n' +
                    'if name=="sysctl":\n print(os.environ["ARM64"]);sys.exit(0)\n' +
                    'if name=="lpinfo":\n print(os.environ["DEVICES"]);sys.exit(int(os.environ["DISCOVERY_ERROR"]))\n')
                mock.chmod(0o755)
                assert any(path in script for script in scripts.values())
                scripts = {name:script.replace(path,str(mock)) for name,script in scripts.items()}
            target=folder/'driver-destination'
            app=folder/'app-destination'
            if app_id is not None:
                import plistlib
                (app/'Contents').mkdir(parents=True)
                (app/'Contents/Info.plist').write_bytes(plistlib.dumps({'CFBundleIdentifier':app_id}))
            if symlink: target.symlink_to(folder/'unrelated-target')
            for name,script in scripts.items():
                (folder/name).write_text(script.replace('/Library/Printers/P1102Native',str(target)).replace('/Applications/P1102 Utility.app',str(app)))
            fixture = folder/phase
            log = folder/'calls.jsonl'
            result = subprocess.run(['/bin/sh', str(fixture)], capture_output=True, text=True,
                env={**os.environ, 'CURRENT_QUEUE': current or '', 'DEVICES': devices,
                     'DISCOVERY_ERROR': str(int(discovery_error)), 'ARM64':str(int(arm64)), 'CALL_LOG': str(log)})
            changes = [json.loads(line) for line in log.read_text().splitlines() if json.loads(line)[0]=='lpadmin']
            return result, changes

    def test_a_unique_p1102_is_added_without_changing_the_default_printer(self):
        result, changes = self.install(devices='direct '+URI)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(changes), 1)
        self.assertIn(URI, changes[0])
        self.assertIn('printer-is-shared=false', changes[0])
        self.assertNotIn('-d', changes[0])

    def test_multiple_p1102_devices_require_an_explicit_user_selection(self):
        result, changes = self.install(devices='direct '+URI+'\ndirect '+URI+'2')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(changes, [])

    def test_an_existing_p1102_queue_is_updated(self):
        result, changes = self.install(current='device for HP_LaserJet_P1102_Native: '+URI)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(changes), 1)
        self.assertNotIn('-v', changes[0])
        self.assertNotIn('-o', changes[0])  # An update must preserve the user's quality choice.

    def test_a_name_collision_never_reconfigures_an_unrelated_printer(self):
        result, changes = self.install(current='device for HP_LaserJet_P1102_Native: ipp://example.invalid/printer')
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(changes, [])

    def test_discovery_failure_is_reported_and_no_device_is_not_an_error(self):
        result, changes = self.install(discovery_error=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(changes, [])
        result, changes = self.install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(changes, [])

    def test_preflight_blocks_an_unsupported_mac_before_installing_files(self):
        result, changes = self.install(phase='preinstall',arm64=False)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Apple Silicon',result.stderr)
        self.assertEqual(changes,[])

    def test_preflight_blocks_a_redirected_driver_destination(self):
        result, changes = self.install(phase='preinstall',symlink=True)
        self.assertNotEqual(result.returncode,0)
        self.assertIn('symbolic link',result.stderr)
        self.assertEqual(changes,[])

    def test_preflight_rejects_a_queue_conflict_without_mutations(self):
        result, changes = self.install(phase='preinstall',current='device for HP_LaserJet_P1102_Native: ipp://example.invalid/other')
        self.assertNotEqual(result.returncode,0)
        self.assertEqual(changes,[])

    def test_preflight_preserves_an_unrelated_application_with_the_same_name(self):
        result,changes=self.install(phase='preinstall',app_id='org.example.unrelated')
        self.assertNotEqual(result.returncode,0)
        self.assertIn('Another application',result.stderr)
        self.assertEqual(changes,[])
        result,changes=self.install(phase='preinstall',app_id='cz.marek.p1102-native.utility')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(changes,[])
        result, changes = self.install(phase='preinstall')
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual(changes,[])


if __name__ == '__main__':
    unittest.main(verbosity=2)
