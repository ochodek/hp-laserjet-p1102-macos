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
rmdir /Library/Printers/P1102Native
rm -f /Library/Printers/PPDs/Contents/Resources/HP-P1102-Native.ppd
pkgutil --forget cz.marek.p1102-native
