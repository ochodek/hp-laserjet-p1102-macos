#!/bin/sh
set -eu
cd "$(dirname "$0")"
./test.sh
root=build/package-root-1.7
mkdir -p "$root/Library/Printers/P1102Native" \
    "$root/Library/Printers/PPDs/Contents/Resources" dist
install -m 755 build/rastertop1102 build/commandtop1102 build/p1102ctl "$root/Library/Printers/P1102Native/"
mkdir -p "$root/Applications"
ditto --noextattr --noqtn "build/P1102 Utility.app" "$root/Applications/P1102 Utility.app"
install -m 644 LICENSE NOTICE "$root/Library/Printers/P1102Native/"
COPYFILE_DISABLE=1 tar --no-xattrs --uid 0 --gid 0 --uname root --gname wheel \
    -czf build/Source.tar.gz \
    src tests vendor ppd installer scripts build.sh test.sh package.sh uninstall.sh \
    README.md README.cs.md SECURITY.md SECURITY.cs.md CHANGELOG.md FEATURES.md FEATURES.cs.md REVIEW.md NOTICE LICENSE \
    .gitignore .gitattributes
install -m 644 build/Source.tar.gz "$root/Library/Printers/P1102Native/Source.tar.gz"
install -m 644 ppd/HP-P1102-Native.ppd "$root/Library/Printers/PPDs/Contents/Resources/"
# Staged files belong to the builder; pkgbuild assigns root ownership on install.
codesign --verify --strict "$root/Library/Printers/P1102Native/rastertop1102"
pkgbuild --root "$root" --identifier cz.marek.p1102-native \
    --component-plist installer/components.plist --version 1.7 --ownership recommended --install-location / \
    --scripts scripts build/P1102-component.pkg
productbuild --distribution installer/Distribution.xml --package-path build \
    --resources installer/resources dist/HP-P1102-Native-1.7.pkg
cp build/Source.tar.gz dist/HP-P1102-Native-1.7-source.tar.gz
(cd dist && shasum -a 256 HP-P1102-Native-1.7.pkg HP-P1102-Native-1.7-source.tar.gz > SHA256SUMS)

python3 tests/check_package.py dist/HP-P1102-Native-1.7.pkg
