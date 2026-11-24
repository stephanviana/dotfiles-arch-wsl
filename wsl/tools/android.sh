#!/usr/bin/env bash
# Keep the Linux adb command as a client of the Windows ADB server.
set -euo pipefail

tools_dir="$(cd "$(dirname "$0")" && pwd)"
client='/usr/local/bin/adb'

# Update only the exact legacy wrapper or an installed version with our marker
# whose hash is recorded by this installer; preserve custom wrappers.
runtime_dir="$HOME/.local/lib/dotfiles-wsl-arch"
legacy_client=$'#!/bin/sh\n# Always use the Windows ADB server in WSL mirrored mode.\nexec /usr/bin/adb -H 127.0.0.1 -P 5037 "$@"'
managed=false
if [[ -f "$client" ]]; then
    if cmp -s "$tools_dir/adb-client" "$client" || \
       [[ $(cat "$client") == "$legacy_client" ]]; then
        managed=true
    elif [[ -f "$runtime_dir/adb-client.sha256" ]] && \
         [[ $(sha256sum "$client" | cut -d ' ' -f 1) == "$(cat "$runtime_dir/adb-client.sha256")" ]]; then
        managed=true
    fi
fi
if [[ -e "$client" || -L "$client" ]] && [[ $managed != true ]]; then
    printf 'Existing %s differs; preserving it.\n' "$client" >&2
    exit 1
fi
mkdir -p "$HOME/.local/bin" "$runtime_dir"
install -m 0755 "$tools_dir/adb-bridge" "$HOME/.local/bin/adb-bridge"
install -m 0644 "$tools_dir/../../windows/ensure-adb-server.ps1" "$runtime_dir/ensure-adb-server.ps1"
sudo install -m 0755 "$tools_dir/adb-client" "$client"
sha256sum "$tools_dir/adb-client" | cut -d ' ' -f 1 > "$runtime_dir/adb-client.sha256"

export ADB_SERVER_SOCKET='tcp:127.0.0.1:5037'
"$client" version | head -n 2
"$client" devices -l
