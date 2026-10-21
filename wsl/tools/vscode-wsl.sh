#!/usr/bin/env bash
# Expose the official Windows VS Code WSL launcher without importing Windows PATH.
set -Eeuo pipefail

launcher="$HOME/.local/bin/code"
mkdir -p "$(dirname "$launcher")"

if [[ -e "$launcher" || -L "$launcher" ]]; then
    if [[ ! -f "$launcher" ]]; then
        printf 'Existing VS Code launcher is unusable: %s\n' "$launcher" >&2
        exit 1
    fi
    printf 'Preserving existing VS Code launcher: %s\n' "$launcher"
    exit 0
fi

cmd_exe='/mnt/c/Windows/System32/cmd.exe'
if [[ ! -x "$cmd_exe" ]]; then
    printf 'Windows interop is unavailable; cannot locate VS Code.\n' >&2
    exit 1
fi

code_script=''
while IFS= read -r windows_path; do
    windows_path="${windows_path%$'\r'}"
    [[ ${windows_path##*\\} == code ]] || continue
    candidate="$(wslpath -u "$windows_path")"
    if [[ -f "$candidate" ]]; then
        code_script="$candidate"
        break
    fi
done < <("$cmd_exe" /C where code)

if [[ -z "$code_script" ]]; then
    printf 'Install VS Code on Windows, add it to Windows PATH and install the WSL extension.\n' >&2
    exit 1
fi

ln -s "$code_script" "$launcher"
printf 'VS Code WSL launcher: %s -> %s\n' "$launcher" "$code_script"
