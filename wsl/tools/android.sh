#!/usr/bin/env bash
# Keep the Linux adb command as a client of the Windows ADB server.
set -euo pipefail

tools_dir="$(cd "$(dirname "$0")" && pwd)"
client='/usr/local/bin/adb'

if [[ -e "$client" ]] && ! cmp -s "$tools_dir/adb-client" "$client"; then
    printf 'Existing %s differs; preserving it.\n' "$client" >&2
    exit 1
fi
if [[ ! -e "$client" ]]; then
    sudo install -m 0755 "$tools_dir/adb-client" "$client"
fi

export ADB_SERVER_SOCKET='tcp:127.0.0.1:5037'
"$client" version | head -n 2
"$client" devices -l
