#!/bin/sh
set -eu
printf '%s\n' 'P1102 Native: uninstall / odinstalace' \
    'Quit P1102 Utility and finish pending print jobs.' \
    'Ukončete P1102 Utility a dokončete čekající tiskové úlohy.' \
    'Removes only this driver, its utility and native queue. Original HP software remains.' \
    'Odebere pouze tento ovladač, jeho aplikaci a nativní frontu. Původní software HP zůstane.'
printf '%s' 'Type REMOVE to continue / Pro pokračování napište REMOVE: '
IFS= read -r answer
if [ "$answer" != REMOVE ]; then exit 0; fi
/usr/bin/sudo /bin/sh /Library/Printers/P1102Native/uninstall.sh
