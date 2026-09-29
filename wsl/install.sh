#!/bin/bash
# =============================================================================
# Dotfiles — Instalador WSL 2 (Arch Linux)
# Orquestra a instalação de todas as ferramentas e configurações
# =============================================================================
set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS_DIR="$DOTFILES_DIR/wsl/tools"
TOTAL_STEPS=9
STEP=0

# ── Helpers ──────────────────────────────────────────────────────────────────
step() {
    STEP=$((STEP + 1))
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "[$STEP/$TOTAL_STEPS] $1"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
}

run_tool() {
    local script="$TOOLS_DIR/$1"
    if [ -f "$script" ]; then
        chmod +x "$script"
        bash "$script"
    else
        echo "⚠️  Script não encontrado: $script"
        return 1
    fi
}

# ── Banner ───────────────────────────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║                                                                    ║"
echo "║       🚀  Dotfiles WSL 2 (Arch Linux) — Setup Automatizado         ║"
echo "║                                                                    ║"
echo "║           github.com/stephanviana/dotfiles-arch                    ║"
echo "║                                                                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo ""

# ── [1/9] Rede e DNS ────────────────────────────────────────────────────────
step "🌐 Configurando rede e DNS..."
run_tool "network.sh"

# ── [2/9] Atualizar sistema e dependências base via Pacman ──────────────────
step "📦 Atualizando sistema e instalando pacotes base via Pacman..."
echo "   → Atualizando base de pacotes..."
sudo pacman -Sy --needed --noconfirm archlinux-keyring || true
sudo pacman -Syu --noconfirm
sudo pacman -S --needed --noconfirm \
    curl \
    wget \
    git \
    unzip \
    base-devel \
    jdk17-openjdk \
    7zip \
    unrar \
    ffmpeg

# Configurar Java 17 como padrão no Arch Linux se archlinux-java estiver disponível
if command -v archlinux-java &>/dev/null; then
    sudo archlinux-java set java-17-openjdk 2>/dev/null || true
fi

# ── [3/9] Linguagens via asdf ────────────────────────────────────────────────
step "🔀 Instalando linguagens via asdf (Node, Ruby, Python, Kotlin)..."
run_tool "asdf.sh"

# ── [4/9] Docker Engine ─────────────────────────────────────────────────────
step "🐳 Instalando Docker Engine..."
run_tool "docker.sh"

# ── [5/9] Android ADB bridge ────────────────────────────────────────────────
step "📱 Configurando Android ADB bridge..."
run_tool "android.sh"

# ── [6/9] CLI Tools ─────────────────────────────────────────────────────────
step "🔧 Instalando CLI tools..."
run_tool "cli-tools.sh"

# ── [7/9] Symlinks ──────────────────────────────────────────────────────────
step "🔗 Criando symlinks..."

create_symlink() {
    local src="$1"
    local dest="$2"
    if [ -f "$dest" ] || [ -L "$dest" ]; then
        echo "   → Backup: $dest → ${dest}.bak"
        mv "$dest" "${dest}.bak" 2>/dev/null || true
    fi
    ln -sf "$src" "$dest"
    echo "   → $src → $dest"
}

create_symlink "$DOTFILES_DIR/wsl/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/wsl/.gitconfig" "$HOME/.gitconfig"

echo "✅ Symlinks criados!"

# ── [8/9] Configurar Zsh como shell padrão ──────────────────────────────────
step "🐚 Configurando Zsh..."
ZSH_BIN="$(command -v zsh || echo '/bin/zsh')"
if [ "$SHELL" != "$ZSH_BIN" ]; then
    echo "   → Definindo Zsh como shell padrão para $USER..."
    if command -v chsh &>/dev/null; then
        chsh -s "$ZSH_BIN" "$USER" || sudo usermod -s "$ZSH_BIN" "$USER"
    else
        sudo usermod -s "$ZSH_BIN" "$USER"
    fi
    echo "✅ Zsh definido como shell padrão!"
else
    echo "   → Zsh já é o shell padrão."
fi

# ── [9/9] Resumo final ──────────────────────────────────────────────────────
step "✅ Ambiente pronto!"

echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║  📋 RESUMO DA INSTALAÇÃO (Arch Linux)                              ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║                                                                    ║"
echo "║  ✅ Rede & DNS configurados (Mirrored + DNS Tunneling)              ║"
echo "║  ✅ Sistema atualizado com Pacman (base-devel, OpenJDK 17, 7zip...) ║"
echo "║  ✅ asdf + Node.js, Ruby, Python, Kotlin                            ║"
echo "║  ✅ Docker Engine + Compose nativo (systemd)                       ║"
echo "║  ✅ Android ADB bridge + scrcpy                                    ║"
echo "║  ✅ CLI tools (zsh, fzf, ripgrep, zoxide, gh, jq, agy, opencode...) ║"
echo "║  ✅ Symlinks (.zshrc, .gitconfig)                                  ║"
echo "║  ✅ Zsh como shell padrão                                          ║"
echo "║                                                                    ║"
echo "╠══════════════════════════════════════════════════════════════════════╣"
echo "║                                                                    ║"
echo "║  👉 Próximo passo: reinicie o terminal ou rode:                    ║"
echo "║     exec zsh                                                       ║"
echo "║                                                                    ║"
echo "║  👉 Para Docker sem sudo, faça logout/login ou rode:               ║"
echo "║     newgrp docker                                                  ║"
echo "║                                                                    ║"
echo "║  👉 Para autenticar no GitHub CLI:                                 ║"
echo "║     gh auth login                                                  ║"
echo "║                                                                    ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
