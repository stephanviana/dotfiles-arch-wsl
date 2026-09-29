#!/bin/bash
# =============================================================================
# CLI Tools — Ferramentas de qualidade de vida para Arch Linux
# =============================================================================
set -euo pipefail

echo "🔧 Instalando CLI tools..."

# ── Pacotes essenciais via Pacman ────────────────────────────────────────────
echo "   → Instalando zsh, ripgrep, zoxide, github-cli, jq via pacman..."
sudo pacman -S --needed --noconfirm \
    zsh \
    ripgrep \
    zoxide \
    github-cli \
    jq

# ── Oh My Zsh ────────────────────────────────────────────────────────────────
echo "   → Instalando Oh My Zsh..."
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    RUNZSH=no KEEP_ZSHRC=yes \
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
else
    echo "     Oh My Zsh já instalado, pulando..."
fi

# ── Plugins do Oh My Zsh ─────────────────────────────────────────────────────
echo "   → Instalando plugins do Oh My Zsh..."

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# zsh-autosuggestions
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-autosuggestions" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions \
        "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
fi

# zsh-syntax-highlighting
if [ ! -d "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" ]; then
    git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting \
        "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
fi

# ── fzf — busca fuzzy ───────────────────────────────────────────────────────
echo "   → Instalando fzf..."
if [ ! -d "$HOME/.fzf" ]; then
    git clone --depth=1 https://github.com/junegunn/fzf.git "$HOME/.fzf"
    "$HOME/.fzf/install" --all --no-bash --no-fish
else
    echo "     fzf já instalado, pulando..."
fi

# ── Antigravity CLI (agy) ───────────────────────────────────────────────────
echo "   → Instalando Antigravity CLI (agy)..."
if ! command -v agy &> /dev/null; then
    curl -fsSL https://antigravity.google/cli/install.sh | bash || true
else
    echo "     Antigravity CLI já instalado, pulando..."
fi

# ── OpenCode CLI ─────────────────────────────────────────────────────────────
echo "   → Instalando OpenCode CLI..."
if ! command -v opencode &> /dev/null; then
    curl -fsSL https://opencode.ai/install | bash || true
else
    echo "     OpenCode CLI já instalado, pulando..."
fi

# ── Codex CLI ────────────────────────────────────────────────────────────────
echo "   → Instalando Codex CLI..."
if ! command -v codex &> /dev/null; then
    curl -fsSL https://chatgpt.com/codex/install.sh | sh || true
else
    echo "     Codex CLI já instalado, pulando..."
fi

echo ""
echo "✅ CLI tools instalados!"
echo "   zsh:         $(zsh --version 2>/dev/null || echo 'instalado')"
echo "   fzf:         $(~/.fzf/bin/fzf --version 2>/dev/null || echo 'instalado')"
echo "   ripgrep:     $(rg --version 2>/dev/null | head -1 || echo 'instalado')"
echo "   zoxide:      $(zoxide --version 2>/dev/null || echo 'instalado')"
echo "   gh:          $(gh --version 2>/dev/null | head -1 || echo 'instalado')"
echo "   jq:          $(jq --version 2>/dev/null || echo 'instalado')"
echo "   antigravity: $(agy --version 2>/dev/null || echo 'instalado')"
echo "   opencode:    $(opencode --version 2>/dev/null || echo 'instalado')"
echo "   codex:       $(codex --version 2>/dev/null || echo 'instalado')"
