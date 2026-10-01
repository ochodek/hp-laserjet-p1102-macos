#!/bin/sh
set -eu
cd "$(dirname "$0")"
./test.sh
root=$(mktemp -d build/package-root.XXXXXX)
resources=$(mktemp -d build/package-resources.XXXXXX)
trap '/bin/rm -rf "$root" "$resources"' EXIT HUP INT TERM
mkdir -p "$root/Library/Printers/P1102Native" \
    "$root/Library/Printers/PPDs/Contents/Resources" dist
install -m 755 build/rastertop1102 build/commandtop1102 build/p1102ctl "$root/Library/Printers/P1102Native/"
mkdir -p "$root/Applications"
ditto --noextattr --noqtn "build/P1102 Utility.app" "$root/Applications/P1102 Utility.app"
install -m 644 LICENSE NOTICE "$root/Library/Printers/P1102Native/"
install -m 755 uninstall.sh installer/Uninstall.command "$root/Library/Printers/P1102Native/"
tools/archive-source.sh build/Source.tar.gz
install -m 644 build/Source.tar.gz "$root/Library/Printers/P1102Native/Source.tar.gz"
install -m 644 ppd/HP-P1102-Native.ppd "$root/Library/Printers/PPDs/Contents/Resources/"
# Staged files belong to the builder; pkgbuild assigns root ownership on install.
codesign --verify --strict "$root/Library/Printers/P1102Native/rastertop1102"
pkgbuild --root "$root" --identifier cz.marek.p1102-native \
    --component-plist installer/components.plist --version 1.7.1 --ownership recommended --install-location / \
    --scripts scripts build/P1102-component.pkg
ditto --noextattr --noqtn installer/resources "$resources"
cp LICENSE "$resources/License.txt"
productbuild --distribution installer/Distribution.xml --package-path build \
    --resources "$resources" dist/HP-P1102-Native-1.7.1.pkg
cp build/Source.tar.gz dist/HP-P1102-Native-1.7.1-source.tar.gz
(cd dist && shasum -a 256 HP-P1102-Native-1.7.1.pkg HP-P1102-Native-1.7.1-source.tar.gz > SHA256SUMS)

python3 tests/check_package.py dist/HP-P1102-Native-1.7.1.pkg
