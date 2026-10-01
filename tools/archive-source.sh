#!/bin/sh
set -eu

manifest=SOURCE_MANIFEST
output=${1:?usage: archive-source.sh OUTPUT}

LC_ALL=C sort -c "$manifest"
if [ "$(LC_ALL=C sort -u "$manifest" | wc -l | tr -d ' ')" != "$(wc -l < "$manifest" | tr -d ' ')" ]; then
    printf '%s\n' 'Source manifest contains duplicate paths.' >&2
    exit 1
fi
while IFS= read -r path || [ -n "$path" ]; do
    case "$path" in
        ''|-*|/*|*'..'*|*'//'*) printf '%s\n' "Invalid source manifest path: $path" >&2; exit 1 ;;
    esac
    [ -f "$path" ] || { printf '%s\n' "Missing source manifest path: $path" >&2; exit 1; }
done < "$manifest"

COPYFILE_DISABLE=1 tar --no-xattrs --uid 0 --gid 0 --uname root --gname wheel \
    --files-from="$manifest" -czf "$output"
