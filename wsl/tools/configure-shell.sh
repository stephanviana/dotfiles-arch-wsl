#!/usr/bin/env bash
# Add shared environment without replacing existing shell or Git settings.
set -euo pipefail

tools_dir="$(cd "$(dirname "$0")" && pwd)"
mkdir -p "$HOME/.config/dotfiles-wsl-arch"
install -m 0644 "$tools_dir/env.sh" "$HOME/.config/dotfiles-wsl-arch/env.sh"

source_line='[ -f "$HOME/.config/dotfiles-wsl-arch/env.sh" ] && . "$HOME/.config/dotfiles-wsl-arch/env.sh"'
for rc in "$HOME/.bash_profile" "$HOME/.zshenv"; do
    if [[ ! -f "$rc" ]] || ! grep -Fq 'dotfiles-wsl-arch/env.sh' "$rc"; then
        printf '\n%s\n' "$source_line" >> "$rc"
    fi
done

if [[ ! -e "$HOME/.gitconfig" ]]; then
    install -m 0644 "$tools_dir/../.gitconfig" "$HOME/.gitconfig"
fi

if [[ ! -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    install -m 0644 "$tools_dir/../.zshrc" "$HOME/.zshrc"
fi

if ! grep -Fq 'mise activate zsh' "$HOME/.zshrc"; then
    cat >> "$HOME/.zshrc" <<'EOF'

# mise-en-place (dotfiles-wsl-arch)
if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
fi
EOF
fi

# Keep a UTF-8 locale available for prompt symbols and interactive tools.
if ! locale -a 2>/dev/null | grep -Eiq '^en_US\.utf-?8$'; then
    sudo sed -i '/^#en_US\.UTF-8 UTF-8/s/^#//' /etc/locale.gen
    sudo locale-gen
    if ! locale -a 2>/dev/null | grep -Eiq '^en_US\.utf-?8$'; then
        printf 'Failed to generate en_US.UTF-8 for the shell environment.\n' >&2
        exit 1
    fi
fi

if [[ ! -f "$HOME/.oh-my-zsh/oh-my-zsh.sh" ]]; then
    if [[ -e "$HOME/.oh-my-zsh" ]]; then
        printf 'Incomplete Oh My Zsh installation at %s; inspect it before retrying.\n' "$HOME/.oh-my-zsh" >&2
        exit 1
    fi
    installer="$(mktemp)"
    trap 'rm -f -- "$installer"' EXIT
    curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh -o "$installer"
    sh "$installer" --unattended --keep-zshrc
    rm -f -- "$installer"
    trap - EXIT
fi

custom_plugins="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    plugin_dir="$custom_plugins/$plugin"
    if [[ ! -f "$plugin_dir/$plugin.plugin.zsh" ]]; then
        if [[ -e "$plugin_dir" ]]; then
            printf 'Incomplete Zsh plugin installation at %s; inspect it before retrying.\n' "$plugin_dir" >&2
            exit 1
        fi
        git clone "https://github.com/zsh-users/$plugin.git" "$plugin_dir"
    fi
done

if ! command -v starship >/dev/null 2>&1; then
    printf 'Starship was not found; install the Arch package starship before configuring Zsh.\n' >&2
    exit 1
fi

if command -v zsh >/dev/null 2>&1; then
    zsh_bin="$(readlink -f "$(command -v zsh)")"
    current_shell="$(getent passwd "$(id -un)" | cut -d: -f7)"
    if [[ "$(readlink -f "$current_shell")" != "$zsh_bin" ]]; then
        sudo usermod -s "$zsh_bin" "$(id -un)"
    fi
fi

printf 'Shell environment installed; open a new login shell to apply it.\n'
