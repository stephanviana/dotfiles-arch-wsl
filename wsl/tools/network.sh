#!/usr/bin/env bash
# Read-only checks for WSL networking and DNS.
set -euo pipefail

printf 'PID 1: %s\n' "$(ps -p 1 -o comm=)"
printf 'resolv.conf: %s\n' "$(readlink -f /etc/resolv.conf)"
ip -br address
if getent hosts archlinux.org >/dev/null; then
    printf 'DNS works.\n'
else
    printf 'DNS lookup failed; inspect .wslconfig and /etc/wsl.conf.\n' >&2
    exit 1
fi
