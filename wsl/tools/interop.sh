#!/usr/bin/env bash
# Prevent WSL shells from silently selecting Windows build tools.
set -euo pipefail

config='/etc/wsl.conf'
if grep -Eq '^\[interop\][[:space:]]*$' "$config"; then
    if grep -Eq '^appendWindowsPath[[:space:]]*=[[:space:]]*false[[:space:]]*$' "$config"; then
        printf 'Windows PATH inheritance is already disabled.\n'
    else
        printf 'Existing [interop] section found; review %s manually.\n' "$config" >&2
        exit 1
    fi
else
    printf '\n[interop]\nappendWindowsPath=false\n' | sudo tee -a "$config" >/dev/null
    printf 'Windows PATH inheritance disabled; run wsl --shutdown to apply.\n'
fi
