#!/bin/sh
set -eu
LC_ALL=C
export LC_ALL
if [ "$(/usr/bin/id -u)" != 0 ]; then
    printf '%s\n' 'Run with sudo. Removes only the P1102 Native queue and driver.' >&2
    exit 1
fi
for path in /Library/Printers/P1102Native '/Applications/P1102 Utility.app'; do
    if [ -L "$path" ] || { [ -d "$path" ] && [ -n "$(/usr/bin/find "$path" -type l -print)" ]; }; then
        printf '%s\n' 'Refusing to remove a driver destination containing symbolic links.' >&2
        exit 1
    fi
done
if current=$(/usr/bin/lpstat -v HP_LaserJet_P1102_Native 2>/dev/null); then
    case "$current" in
        'device for HP_LaserJet_P1102_Native: usb://Hewlett-Packard/HP%20LaserJet%20Professional%20P1102?'*) ;;
        *) printf '%s\n' 'The native queue name belongs to another printer. Nothing was removed.' >&2; exit 1 ;;
    esac
    pending=$(/usr/bin/lpstat -W not-completed -o HP_LaserJet_P1102_Native)
    if [ -n "$pending" ]; then
        printf '%s\n' 'Finish or cancel pending native print jobs before uninstalling.' >&2
        exit 1
    fi
    /usr/sbin/lpadmin -x HP_LaserJet_P1102_Native
fi
/bin/rm -f /Library/Printers/P1102Native/rastertop1102 /Library/Printers/P1102Native/LICENSE
/bin/rm -f /Library/Printers/P1102Native/Source.tar.gz
/bin/rm -f /Library/Printers/P1102Native/NOTICE
/bin/rm -f /Library/Printers/P1102Native/commandtop1102 /Library/Printers/P1102Native/p1102ctl
app="/Applications/P1102 Utility.app"
if [ -f "$app/Contents/Info.plist" ] && [ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$app/Contents/Info.plist")" = cz.marek.p1102-native.utility ]; then
    /bin/rm -f "$app/Contents/MacOS/P1102Utility" "$app/Contents/Info.plist" "$app/Contents/_CodeSignature/CodeResources"
    if [ -d "$app/Contents/Resources" ]; then
        /bin/rm -f "$app/Contents/Resources/LICENSE" "$app/Contents/Resources/NOTICE" "$app/Contents/Resources/P1102Utility.icns"
        /bin/rmdir "$app/Contents/Resources"
    fi
    /bin/rmdir "$app/Contents/MacOS" "$app/Contents/_CodeSignature" "$app/Contents" "$app"
fi
/bin/rm -f /Library/Printers/P1102Native/uninstall.sh /Library/Printers/P1102Native/Uninstall.command
/bin/rmdir /Library/Printers/P1102Native
/bin/rm -f /Library/Printers/PPDs/Contents/Resources/HP-P1102-Native.ppd
/usr/sbin/pkgutil --forget cz.marek.p1102-native
