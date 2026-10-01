"""Ensure corresponding source archives rebuild outside a Git checkout."""
import shutil
import struct
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class SourceArchiveTests(unittest.TestCase):
    def test_application_icon_contains_correct_pixel_sizes_on_any_display(self):
        with tempfile.TemporaryDirectory() as directory:
            iconset=Path(directory)/'app.iconset'
            subprocess.run(['/usr/bin/iconutil','-c','iconset',str(ROOT/'build/P1102 Utility.app/Contents/Resources/P1102Utility.icns'),'-o',str(iconset)],check=True)
            for size in [16,32,128,256,512]:
                for scale,suffix in [(1,''),(2,'@2x')]:
                    png=(iconset/f'icon_{size}x{size}{suffix}.png').read_bytes()
                    self.assertEqual(struct.unpack('>II',png[16:24]),(size*scale,size*scale))

    def test_manifest_covers_tracked_files_when_git_is_available(self):
        if not (ROOT/'.git').exists():
            self.skipTest('Git metadata is absent from an exported source tree.')
        manifest = set((ROOT/'SOURCE_MANIFEST').read_text().splitlines())
        tracked = set(subprocess.check_output(['git', '-C', str(ROOT), 'ls-files'], text=True).splitlines())
        self.assertEqual(tracked-manifest, set())

    def test_manifested_source_archives_without_git_or_untracked_files(self):
        manifest = (ROOT/'SOURCE_MANIFEST').read_text().splitlines()
        with tempfile.TemporaryDirectory() as directory:
            copied = Path(directory)/'source'
            copied.mkdir()
            for name in manifest:
                destination = copied/name
                destination.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(ROOT/name, destination)
            junk = copied/'tests/__pycache__'
            junk.mkdir()
            (junk/'local.cpython-313.pyc').write_bytes(b'local path disclosure')
            archive = copied/'Source.tar.gz'
            subprocess.run(['sh', 'tools/archive-source.sh', str(archive)], cwd=copied, check=True)
            with tarfile.open(archive) as source:
                self.assertEqual({item.name for item in source.getmembers() if item.isfile()}, set(manifest))
                self.assertNotIn('tests/__pycache__/local.cpython-313.pyc', source.getnames())


if __name__ == '__main__':
    unittest.main(verbosity=2)
