#!/bin/sh
set -eu
if [ "$(id -u)" != 0 ]; then
    printf '%s\n' 'Run with sudo. Removes only the P1102 Native queue and driver.' >&2
    exit 1
fi
if lpstat -v HP_LaserJet_P1102_Native >/dev/null 2>&1; then
    lpadmin -x HP_LaserJet_P1102_Native
fi
rm -f /Library/Printers/P1102Native/rastertop1102 /Library/Printers/P1102Native/LICENSE
rm -f /Library/Printers/P1102Native/Source.tar.gz
rm -f /Library/Printers/P1102Native/NOTICE
rm -f /Library/Printers/P1102Native/commandtop1102 /Library/Printers/P1102Native/p1102ctl
app="/Applications/P1102 Utility.app"
if [ -f "$app/Contents/Info.plist" ] && [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = cz.marek.p1102-native.utility ]; then
    rm -f "$app/Contents/MacOS/P1102Utility" "$app/Contents/Info.plist" "$app/Contents/_CodeSignature/CodeResources"
    if [ -d "$app/Contents/Resources" ]; then
        rm -f "$app/Contents/Resources/LICENSE" "$app/Contents/Resources/NOTICE"
        rmdir "$app/Contents/Resources"
    fi
    rmdir "$app/Contents/MacOS" "$app/Contents/_CodeSignature" "$app/Contents" "$app"
fi
rmdir /Library/Printers/P1102Native
rm -f /Library/Printers/PPDs/Contents/Resources/HP-P1102-Native.ppd
pkgutil --forget cz.marek.p1102-native
