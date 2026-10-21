#!/usr/bin/env bash
# Install the official LazyVim Starter on Arch Linux.
set -Eeuo pipefail

if [[ ! -f /etc/arch-release ]] || [[ $EUID -eq 0 ]]; then
    printf 'Run this installer as a normal Arch Linux user.\n' >&2
    exit 1
fi

packages=(neovim git gcc tree-sitter-cli curl fzf ripgrep fd lazygit)
if ! pacman -Qq "${packages[@]}" >/dev/null 2>&1; then
    sudo pacman -Syu --needed --noconfirm "${packages[@]}"
fi

nvim_version="$(nvim --version | sed -n '1s/^NVIM v//p')"
if [[ -z "$nvim_version" ]] || (( $(vercmp "$nvim_version" 0.11.2) < 0 )); then
    printf 'LazyVim requires Neovim 0.11.2 or newer; found %s.\n' "$nvim_version" >&2
    exit 1
fi

config_dir="$HOME/.config/nvim"
if [[ -f "$config_dir/lua/config/lazy.lua" ]] && grep -Fq 'LazyVim/LazyVim' "$config_dir/lua/config/lazy.lua"; then
    printf 'LazyVim Starter is already configured in %s.\n' "$config_dir"
    exit 0
fi

paths=(
    "$config_dir"
    "$HOME/.local/share/nvim"
    "$HOME/.local/state/nvim"
    "$HOME/.cache/nvim"
)
for path in "${paths[@]}"; do
    if [[ ( -e "$path" || -L "$path" ) && ( -e "$path.bak" || -L "$path.bak" ) ]]; then
        printf 'Backup already exists: %s.bak. Move it before installing LazyVim.\n' "$path" >&2
        exit 1
    fi
done
for path in "${paths[@]}"; do
    if [[ -e "$path" || -L "$path" ]]; then
        mv -- "$path" "$path.bak"
        printf 'Backed up %s to %s.bak\n' "$path" "$path"
    fi
done

mkdir -p "$HOME/.config"
git clone https://github.com/LazyVim/starter "$config_dir"
rm -rf -- "$config_dir/.git"
printf 'LazyVim Starter installed in %s. Start nvim to download plugins.\n' "$config_dir"
