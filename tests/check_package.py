"""Reject unplanned payload files and verify the installer carries this build."""
from pathlib import Path
import plistlib
import stat
import subprocess
import sys
import tarfile
import tempfile
import xml.etree.ElementTree as ET

root = Path(__file__).resolve().parents[1]
package = Path(sys.argv[1]).resolve()
source_files = set((root/'SOURCE_MANIFEST').read_text().splitlines())
expected = {
    'Library/Printers/P1102Native/rastertop1102': root/'build/rastertop1102',
    'Library/Printers/P1102Native/commandtop1102': root/'build/commandtop1102',
    'Library/Printers/P1102Native/p1102ctl': root/'build/p1102ctl',
    'Library/Printers/P1102Native/LICENSE': root/'LICENSE',
    'Library/Printers/P1102Native/NOTICE': root/'NOTICE',
    'Library/Printers/P1102Native/uninstall.sh': root/'uninstall.sh',
    'Library/Printers/P1102Native/Uninstall.command': root/'installer/Uninstall.command',
    'Library/Printers/P1102Native/Source.tar.gz': root/'build/Source.tar.gz',
    'Library/Printers/PPDs/Contents/Resources/HP-P1102-Native.ppd': root/'ppd/HP-P1102-Native.ppd',
}
app = root/'build/P1102 Utility.app'
for name in ['Contents/Info.plist','Contents/MacOS/P1102Utility','Contents/_CodeSignature/CodeResources','Contents/Resources/LICENSE','Contents/Resources/NOTICE','Contents/Resources/P1102Utility.icns']:
    expected['Applications/P1102 Utility.app/'+name] = app/name
with tempfile.TemporaryDirectory() as tmp:
    expanded = Path(tmp)/'expanded'
    subprocess.run(['pkgutil','--expand-full',str(package),str(expanded)],check=True)
    component=expanded/'P1102-component.pkg';payload=component/'Payload'
    for p in payload.rglob('*'):
        assert not p.is_symlink(), str(p)
    actual={str(p.relative_to(payload)) for p in payload.rglob('*') if p.is_file()}
    assert actual==set(expected), (actual-set(expected),set(expected)-actual)
    for name, source in expected.items():
        p=payload/name
        assert not p.is_symlink() and p.read_bytes()==source.read_bytes(), name
        assert not p.stat().st_mode & (stat.S_ISUID|stat.S_ISGID|stat.S_IWOTH), name
        if name.endswith(('rastertop1102','commandtop1102','p1102ctl','P1102Utility')):
            assert subprocess.check_output(['lipo','-archs',str(p)],text=True).strip()=='arm64'
            subprocess.run(['codesign','--verify','--strict',str(p)],check=True)
    info=ET.parse(component/'PackageInfo').getroot()
    assert info.attrib['relocatable']=='false' and info.attrib['install-location']=='/'
    distribution=ET.parse(expanded/'Distribution').getroot()
    assert distribution.find("pkg-ref[@version]").attrib['version']==info.attrib['version']=='1.7.1'
    assert len(info.find('relocate'))==0
    with (payload/'Applications/P1102 Utility.app/Contents/Info.plist').open('rb') as plist_file:
        assert plistlib.load(plist_file)['CFBundleIconFile']=='P1102Utility.icns'
    assert {p.name for p in (component/'Scripts').iterdir()}=={p.name for p in (root/'scripts').iterdir()}
    for p in (root/'scripts').iterdir(): assert (component/'Scripts'/p.name).read_bytes()==p.read_bytes()
    assert distribution.find('domains').attrib=={'enable_anywhere':'false','enable_currentUserHome':'false','enable_localSystem':'true'}
    assert distribution.find('pkg-ref/must-close/app').attrib['id']=='cz.marek.p1102-native.utility'
    for tag in ['welcome','readme','conclusion']:
        name=distribution.find(tag).attrib['file']
        for locale in ['en.lproj','cs.lproj']:
            assert (expanded/'Resources'/locale/name).read_bytes()==(root/'installer/resources'/locale/name).read_bytes()
    assert (expanded/'Resources'/distribution.find('license').attrib['file']).read_bytes()==(root/'LICENSE').read_bytes()
    with tarfile.open(payload/'Library/Printers/P1102Native/Source.tar.gz') as archive:
        archive_files = {item.name for item in archive.getmembers() if item.isfile()}
        assert archive_files == source_files, (archive_files-source_files, source_files-archive_files)
        for item in archive.getmembers():
            path=Path(item.name)
            assert not path.is_absolute() and '..' not in path.parts and not item.issym() and not item.islnk()
            assert path.parts[0] not in ['build','dist','diagnostics','.git']
            if item.isfile():
                assert (root/path).is_file() and archive.extractfile(item).read()==(root/path).read_bytes(), str(path)
print('Package contracts passed: exact payload/source, ARM64, signatures, safe modes and fixed destination.')
