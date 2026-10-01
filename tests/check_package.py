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
expected = {
    'Library/Printers/P1102Native/rastertop1102': root/'build/rastertop1102',
    'Library/Printers/P1102Native/commandtop1102': root/'build/commandtop1102',
    'Library/Printers/P1102Native/p1102ctl': root/'build/p1102ctl',
    'Library/Printers/P1102Native/LICENSE': root/'LICENSE',
    'Library/Printers/P1102Native/NOTICE': root/'NOTICE',
    'Library/Printers/P1102Native/Source.tar.gz': root/'build/Source.tar.gz',
    'Library/Printers/PPDs/Contents/Resources/HP-P1102-Native.ppd': root/'ppd/HP-P1102-Native.ppd',
}
app = root/'build/P1102 Utility.app'
for p in app.rglob('*'):
    if p.is_file(): expected['Applications/P1102 Utility.app/'+str(p.relative_to(app))] = p
with tempfile.TemporaryDirectory() as tmp:
    expanded = Path(tmp)/'expanded'
    subprocess.run(['pkgutil','--expand-full',str(package),str(expanded)],check=True)
    component=expanded/'P1102-component.pkg';payload=component/'Payload'
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
    assert distribution.find("pkg-ref[@version]").attrib['version']==info.attrib['version']=='1.7'
    assert len(info.find('relocate'))==0
    assert (component/'Scripts/postinstall').read_bytes()==(root/'scripts/postinstall').read_bytes()
    with tarfile.open(payload/'Library/Printers/P1102Native/Source.tar.gz') as archive:
        for item in archive.getmembers():
            path=Path(item.name)
            assert not path.is_absolute() and '..' not in path.parts and not item.issym() and not item.islnk()
            assert path.parts[0] not in ['build','dist','diagnostics','.git']
            if item.isfile():
                assert (root/path).is_file() and archive.extractfile(item).read()==(root/path).read_bytes(), str(path)
        public_files={str(p.relative_to(root)) for folder in ['src','tests','vendor','ppd','installer','scripts'] for p in (root/folder).rglob('*') if p.is_file()}
        public_files.update(p.name for p in root.iterdir() if p.is_file() and (p.suffix in ['.md','.sh'] or p.name in ['LICENSE','NOTICE','.gitignore','.gitattributes']))
        assert public_files <= set(archive.getnames()), public_files-set(archive.getnames())
print('Package contracts passed: exact payload/source, ARM64, signatures, safe modes and fixed destination.')
