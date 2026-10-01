"""Protect active jobs, unrelated queues and files during explicit removal."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT=Path(__file__).resolve().parents[1]
URI='device for HP_LaserJet_P1102_Native: usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?serial=TEST'

class UninstallTests(unittest.TestCase):
    def remove(self,current=URI,pending='',redirect=False):
        with tempfile.TemporaryDirectory() as directory:
            folder=Path(directory); log=folder/'calls'
            script=(ROOT/'uninstall.sh').read_text()
            for command,path in [('id','/usr/bin/id'),('lpstat','/usr/bin/lpstat'),('lpadmin','/usr/sbin/lpadmin'),('rm','/bin/rm'),('rmdir','/bin/rmdir'),('pkgutil','/usr/sbin/pkgutil')]:
                mock=folder/command
                mock.write_text('#!/usr/bin/python3\nimport os,sys,json\nfrom pathlib import Path\nn=Path(sys.argv[0]).name\nwith open(os.environ["CALL_LOG"],"a") as f:f.write(json.dumps([n,*sys.argv[1:]])+"\\n")\nif n=="id":print(0)\nif n=="lpstat":\n value=os.environ["PENDING"] if "-o" in sys.argv else os.environ["QUEUE"]\n print(value);sys.exit(0 if "-o" in sys.argv or value else 1)\n')
                mock.chmod(0o755);script=script.replace(path,str(mock))
            target=folder/'driver';app=folder/'app'
            target.mkdir()
            if redirect:(target/'LICENSE').symlink_to(folder/'unrelated')
            script=script.replace('/Library/Printers/P1102Native',str(target)).replace('/Applications/P1102 Utility.app',str(app))
            fixture=folder/'uninstall.sh';fixture.write_text(script)
            result=subprocess.run(['/bin/sh',str(fixture)],capture_output=True,text=True,env={**os.environ,'CALL_LOG':str(log),'PENDING':pending,'QUEUE':current})
            calls=[json.loads(line) for line in log.read_text().splitlines()]
            return result,[call for call in calls if call[0] in ('lpadmin','rm','rmdir','pkgutil')]

    def test_pending_jobs_are_never_cancelled_by_uninstall(self):
        result,changes=self.remove(pending='HP_LaserJet_P1102_Native-1')
        self.assertNotEqual(result.returncode,0);self.assertEqual(changes,[])

    def test_a_reassigned_queue_is_never_deleted(self):
        result,changes=self.remove(current='device for HP_LaserJet_P1102_Native: ipp://example.invalid/other')
        self.assertNotEqual(result.returncode,0);self.assertEqual(changes,[])

    def test_symlinks_cannot_redirect_privileged_removal(self):
        result,changes=self.remove(redirect=True)
        self.assertNotEqual(result.returncode,0);self.assertEqual(changes,[])

    def test_explicit_removal_uses_only_named_files_and_its_own_queue(self):
        result,changes=self.remove()
        self.assertEqual(result.returncode,0,result.stderr)
        self.assertEqual([c for c in changes if c[0]=='lpadmin'],[['lpadmin','-x','HP_LaserJet_P1102_Native']])
        self.assertFalse(any('-r' in arg or '-R' in arg for c in changes if c[0]=='rm' for arg in c[1:]))
        self.assertEqual(changes[-1],['pkgutil','--forget','cz.marek.p1102-native'])

    def test_dismissing_the_launcher_does_not_request_privileges(self):
        with tempfile.TemporaryDirectory() as directory:
            script=(ROOT/'installer/Uninstall.command').read_text().replace('/usr/bin/sudo','/usr/bin/false')
            fixture=Path(directory)/'Uninstall.command';fixture.write_text(script)
            result=subprocess.run(['/bin/sh',str(fixture)],input='cancel\n',capture_output=True,text=True)
            self.assertEqual(result.returncode,0)

if __name__=='__main__':unittest.main(verbosity=2)
