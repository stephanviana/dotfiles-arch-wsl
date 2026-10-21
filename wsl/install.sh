#!/usr/bin/env bash
# Incremental setup for Arch Linux under WSL 2.
set -Eeuo pipefail

tools_dir="$(cd "$(dirname "$0")/tools" && pwd)"
stage="${1:---all}"
trap 'printf "Falha na etapa %s do instalador Arch (linha %s).\n" "$stage" "$LINENO" >&2' ERR

if [[ ! -f /etc/arch-release ]] || ! grep -qi microsoft /proc/sys/kernel/osrelease; then
    printf 'Run this installer inside Arch Linux on WSL 2.\n' >&2
    exit 1
fi
if [[ $EUID -eq 0 ]]; then
    printf 'Run this installer as your normal Arch user.\n' >&2
    exit 1
fi

base() {
    sudo pacman -Syu --needed --noconfirm \
        git docker docker-compose docker-buildx nodejs-lts-krypton npm pnpm yarn rust \
        jdk17-openjdk jdk21-openjdk kotlin gradle android-tools unzip \
        python python-pip python-virtualenv ruby ruby-bundler ruby-stdlib \
        cmake ninja clang llvm ffmpeg gstreamer gst-plugins-base gst-plugins-good \
        gst-plugins-bad gst-plugins-ugly gst-libav gst-editing-services soundtouch \
        openssl readline zlib libyaml libffi gdbm ncurses bzip2 sqlite xz tk libxml2 libxslt \
        base-devel zsh starship curl wget ripgrep jq fzf zoxide github-cli mise usage
    # Arch supplies ELF binaries, headers and .so libraries through these packages.
    /usr/bin/python -c 'import ctypes; ctypes.CDLL("libclang.so")'
    pkg-config --exists gstreamer-1.0 gstreamer-gl-1.0 gst-editing-services-1.0
    for plugin in glshader pitch pulsesink; do
        gst-inspect-1.0 --exists "$plugin" || {
            printf 'Missing Linux GStreamer plugin: %s\n' "$plugin" >&2
            exit 1
        }
    done
    if [[ $(ps -p 1 -o comm=) != systemd ]]; then
        printf 'Enable systemd in /etc/wsl.conf and restart WSL before Docker.\n' >&2
        exit 1
    fi
    sudo systemctl enable --now docker.service
    if ! id -nG | grep -qw docker; then
        sudo usermod -aG docker "$USER"
        printf 'Open a new Arch session before using Docker without sudo.\n'
    fi
    mkdir -p "$HOME/dev" "$HOME/.local/bin"
    bash "$tools_dir/configure-shell.sh"
    . "$HOME/.config/dotfiles-wsl-arch/env.sh"
    bash "$tools_dir/mise.sh"
    bash "$tools_dir/interop.sh"
    bash "$tools_dir/vscode-wsl.sh"
    bash "$tools_dir/windows-validation.sh" --install
    printf 'Base toolchain and Docker installed.\n'
}

case "$stage" in
    --base) base ;;
    --mise)
        bash "$tools_dir/mise.sh"
        bash "$tools_dir/configure-shell.sh"
        ;;
    --android)
        bash "$tools_dir/android-sdk.sh"
        bash "$tools_dir/android.sh"
        ;;
    --supabase) bash "$tools_dir/supabase.sh" ;;
    --paru) bash "$tools_dir/paru.sh" ;;
    --lazyvim) bash "$tools_dir/lazyvim.sh" ;;
    --vscode) bash "$tools_dir/vscode-wsl.sh" ;;
    --windows-runner) bash "$tools_dir/windows-validation.sh" --install ;;
    --android-studio)
        bash "$tools_dir/android-sdk.sh"
        bash "$tools_dir/android-studio.sh"
        ;;
    --agentmemory) bash "$tools_dir/agentmemory.sh" ;;
    --agents) bash "$tools_dir/ai-agents.sh" ;;
    --all)
        base
        bash "$tools_dir/paru.sh"
        bash "$tools_dir/lazyvim.sh"
        bash "$tools_dir/android-sdk.sh"
        bash "$tools_dir/android.sh"
        bash "$tools_dir/android-studio.sh"
        bash "$tools_dir/supabase.sh"
        bash "$tools_dir/agentmemory.sh"
        bash "$tools_dir/ai-agents.sh"
        ;;
    *) printf 'Usage: %s [--base|--mise|--paru|--lazyvim|--vscode|--windows-runner|--android|--android-studio|--supabase|--agentmemory|--agents|--all]\n' "$0" >&2; exit 2 ;;
esac
