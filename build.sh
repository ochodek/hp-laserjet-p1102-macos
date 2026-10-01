#!/bin/sh
set -eu
cd "$(dirname "$0")"
mkdir -p build
shasum -a 256 -c vendor/SHA256SUMS
for source in foo2zjs jbig jbig_ar; do
    xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -std=gnu99 \
        -Dmain=foo2zjs_cli_main -Ivendor/foo2zjs \
        -c "vendor/foo2zjs/$source.c" -o "build/$source.o"
done
xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -std=c11 \
    -Wall -Wextra -Werror src/rastertop1102.c \
    build/foo2zjs.o build/jbig.o build/jbig_ar.o -lcups -Wl,-dead_strip -o build/rastertop1102
codesign --force --sign - build/rastertop1102
cupstestppd -q -I filters ppd/HP-P1102-Native.ppd
file build/rastertop1102
otool -L build/rastertop1102
xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -std=c11 \
    -Wall -Wextra -Werror src/queue-check.c -lcups -o build/p1102-queue-check
codesign --force --sign - build/p1102-queue-check
xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -std=c11 \
    -Wall -Wextra -Werror -Wno-deprecated-declarations -c src/usb.c -o build/usb.o
for program in commandtop1102 device-cli; do
    output=$program
    if [ "$program" = device-cli ]; then output=p1102ctl; fi
    xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -fobjc-arc \
        -Wall -Wextra -Werror src/device.m "src/$program.m" build/usb.o \
        -framework Foundation -framework IOKit -o "build/$output"
    codesign --force --sign - "build/$output"
done
app_staging=$(mktemp -d "${TMPDIR:-/tmp}/p1102-app.XXXXXX")
trap '/bin/rm -rf "$app_staging"' EXIT HUP INT TERM
app="$app_staging/P1102 Utility.app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp -X LICENSE NOTICE "$app/Contents/Resources/"
cp -X installer/utility/Info.plist "$app/Contents/Info.plist"
xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -fobjc-arc \
    -Wall -Wextra -Werror tools/render-app-icon.m -framework Cocoa -o build/render-app-icon
build/render-app-icon "$app/Contents/Resources/P1102Utility.icns"
xcrun clang -arch arm64 -mmacosx-version-min=11.0 -O2 -fobjc-arc \
    -Wall -Wextra -Werror src/device.m src/pdf-tools.m src/utility.m build/usb.o \
    -framework Cocoa -framework PDFKit -framework IOKit -framework ApplicationServices -o "$app/Contents/MacOS/P1102Utility"
codesign --force --sign - "$app"
codesign --verify --strict "$app"
# Build/sign outside file-provider folders; package.sh also stages without xattrs.
/bin/rm -rf 'build/P1102 Utility.app'
ditto --norsrc --noextattr --noacl --noqtn "$app" 'build/P1102 Utility.app'
