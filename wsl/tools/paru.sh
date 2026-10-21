#!/usr/bin/env bash
# Install the current stable Paru package from the AUR for Arch Linux.
set -Eeuo pipefail

tools_dir="$(cd "$(dirname "$0")" && pwd)"
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/paru"

if [[ ! -f /etc/arch-release ]] || [[ $EUID -eq 0 ]]; then
    printf 'Run this installer as a normal Arch Linux user.\n' >&2
    exit 1
fi

if ! command -v paru >/dev/null 2>&1; then
    sudo pacman -Syu --needed --noconfirm base-devel git
    build_dir="$(mktemp -d "${TMPDIR:-/tmp}/paru-build.XXXXXXXX")"
    trap 'rm -rf -- "$build_dir"' EXIT
    git clone --depth=1 https://aur.archlinux.org/paru.git "$build_dir/paru"
    (
        cd "$build_dir/paru"
        makepkg -si --noconfirm
    )
fi

mkdir -p "$config_dir"
if [[ ! -e "$config_dir/paru.conf" && ! -L "$config_dir/paru.conf" ]]; then
    install -m 0644 "$tools_dir/paru.conf" "$config_dir/paru.conf"
fi

paru --version
