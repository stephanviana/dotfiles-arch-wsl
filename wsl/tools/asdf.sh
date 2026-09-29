#!/bin/bash
# =============================================================================
# asdf v0.16+ (Go binary) — Gerenciador de versões unificado para Arch Linux
# Plugins: Node.js, Ruby, Python, Kotlin
# =============================================================================
set -euo pipefail

echo "🔀 Instalando asdf version manager (Go binary)..."

ASDF_VERSION="0.16.7"
INSTALL_DIR="$HOME/.local/bin"
ASDF_BIN="$INSTALL_DIR/asdf"

# ── Dependências de build (Arch Linux) ───────────────────────────────────────
echo "   → Instalando dependências de compilação (pacman)..."
sudo pacman -S --needed --noconfirm \
    base-devel \
    curl \
    git \
    openssl \
    readline \
    zlib \
    libyaml \
    libffi \
    gdbm \
    ncurses \
    bzip2 \
    sqlite \
    xz \
    tk \
    libxml2 \
    libxslt

# ── Instalar binário Go do asdf ──────────────────────────────────────────────
echo "   → Instalando asdf v${ASDF_VERSION} (binário Go)..."
mkdir -p "$INSTALL_DIR"

if command -v asdf &>/dev/null && asdf version 2>/dev/null | grep -q "^${ASDF_VERSION}"; then
    echo "   → asdf v${ASDF_VERSION} já instalado, pulando..."
else
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)  ARCH_TAG="linux-amd64" ;;
        aarch64) ARCH_TAG="linux-arm64" ;;
        *)        echo "   ERRO: arquitetura $ARCH não suportada"; exit 1 ;;
    esac

    curl -fsSL \
        "https://github.com/asdf-vm/asdf/releases/download/v${ASDF_VERSION}/asdf-v${ASDF_VERSION}-${ARCH_TAG}.tar.gz" \
        | tar -xz -C "$INSTALL_DIR"

    chmod +x "$ASDF_BIN"
    echo "   ✅ asdf v${ASDF_VERSION} instalado em $ASDF_BIN"
fi

# Garantir que asdf está no PATH desta sessão
export PATH="$INSTALL_DIR:$PATH"

# Verificar instalação
asdf version

# ── Função helper ────────────────────────────────────────────────────────────
install_plugin() {
    local plugin="$1"
    local label="$2"

    echo ""
    echo "   ── $label ──"

    if ! asdf plugin list 2>/dev/null | grep -q "^${plugin}$"; then
        echo "   → Adicionando plugin $plugin..."
        asdf plugin add "$plugin"
    else
        echo "   → Plugin $plugin já existe, atualizando..."
        asdf plugin update "$plugin" || true
    fi

    echo "   → Instalando $plugin latest..."
    asdf install "$plugin" latest
    asdf set --home "$plugin" latest

    local version
    version=$(asdf current "$plugin" 2>/dev/null | awk '{print $2}')
    echo "   ✅ $plugin $version instalado!"
}

# ── Instalar linguagens ──────────────────────────────────────────────────────
install_plugin "nodejs"  "⬢  Node.js"

# ── Node.js globals (logo após instalar o Node) ──────────────────────────────
echo ""
echo "   → Instalando pacotes globais do Node.js (yarn, pnpm)..."
npm install -g yarn pnpm
echo "   ✅ yarn $(yarn --version 2>/dev/null || echo 'ok') e pnpm $(pnpm --version 2>/dev/null || echo 'ok') instalados!"

install_plugin "ruby"    "💎 Ruby"
install_plugin "python"  "🐍 Python"
install_plugin "kotlin"  "🟣 Kotlin"

# ── Resumo ───────────────────────────────────────────────────────────────────
echo ""
echo "✅ asdf instalado com sucesso!"
echo ""
echo "   asdf:   $(asdf version)"
echo ""
echo "   Versões ativas:"
asdf current 2>/dev/null | awk '{printf "   %-10s %s\n", $1, $2}'
echo ""
echo "   Node globals:"
echo "   yarn:   $(yarn --version 2>/dev/null || echo 'ok')"
echo "   pnpm:   $(pnpm --version 2>/dev/null || echo 'ok')"
