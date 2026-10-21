#!/usr/bin/env bash
# Install mise-managed Linux runtimes and Python tooling.
set -Eeuo pipefail

if [[ ! -f /etc/arch-release ]] || [[ $EUID -eq 0 ]]; then
    printf 'Run this installer as a normal Arch Linux user.\n' >&2
    exit 1
fi

tools_dir="$(cd "$(dirname "$0")" && pwd)"
if ! pacman -Qq mise usage >/dev/null 2>&1; then
    sudo pacman -Syu --needed --noconfirm mise usage
fi

config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/mise"
config="$config_dir/config.toml"
mkdir -p "$config_dir"
if [[ -f "$config" ]] && ! cmp -s "$tools_dir/mise.toml" "$config" && [[ ! -e "$config.bak" ]]; then
    cp -- "$config" "$config.bak"
fi
install -m 0644 "$tools_dir/mise.toml" "$config"

# A clean directory prevents a project's version file from affecting bootstrap.
temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT
export MAKE_OPTS="${MAKE_OPTS:--j2}"
mise -C "$temp_dir" install --yes
mise -C "$temp_dir" exec -- python -m ensurepip --upgrade
mise -C "$temp_dir" exec -- python -m pip install --upgrade pip
mise reshim

mise -C "$temp_dir" exec -- node --version
mise -C "$temp_dir" exec -- ruby --version
mise -C "$temp_dir" exec -- kotlin -version
mise -C "$temp_dir" exec -- python --version
mise -C "$temp_dir" exec -- python -m pip --version
mise -C "$temp_dir" exec -- uv --version
printf 'mise configured: %s. Open a new Arch terminal.\n' "$config"
