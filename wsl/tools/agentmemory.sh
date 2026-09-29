#!/bin/bash
# =============================================================================
# agentmemory — Memória persistente para Agentes de Código IA
# Repositório: https://github.com/rohitg00/agentmemory
# =============================================================================
set -euo pipefail

echo "🧠 Configurando agentmemory (memória persistente para IA)..."

# ── 1. Garantir ambiente do Node.js e asdf ──────────────────────────────────
export PATH="$HOME/.asdf/shims:$HOME/.local/bin:$PATH"

if ! command -v npm &> /dev/null; then
    echo "   ⚠️  npm não encontrado no PATH atual. Verifique se o asdf instalou o Node.js."
    exit 1
fi

# ── 2. Instalar @agentmemory/agentmemory globalmente ────────────────────────
echo "   → Instalando @agentmemory/agentmemory via npm..."
npm install -g @agentmemory/agentmemory@latest

# Atualizar shims do asdf se o asdf estiver presente
if command -v asdf &> /dev/null; then
    asdf reshim nodejs 2>/dev/null || true
fi

# ── 3. Criar diretório de configuração e .env inicial ───────────────────────
echo "   → Configurando ~/.agentmemory/.env..."
mkdir -p "$HOME/.agentmemory"

if [ ! -f "$HOME/.agentmemory/.env" ]; then
    cat > "$HOME/.agentmemory/.env" << 'EOF'
# =============================================================================
# Configuração do agentmemory (https://github.com/rohitg00/agentmemory)
# =============================================================================

# Provedor de Embeddings:
# 'local' usa Xenova/all-MiniLM-L6-v2 localmente (gratuito, sem chave de API).
# Comente ou deixe vazio para modo sem vetor (busca BM25 pura).
EMBEDDING_PROVIDER=local

# Compactação automática de observações com LLM (requer provedor de LLM configurado)
AGENTMEMORY_AUTO_COMPRESS=false

# Diretório padrão de persistência do iii-engine
# AGENTMEMORY_DATA_DIR=~/.local/share/agentmemory
EOF
    echo "   ✅ ~/.agentmemory/.env criado com suporte a embeddings locais (on-device)."
fi

# ── 4. Instalar Skills do agentmemory para os agentes ───────────────────────
echo "   → Instalando 17 skills nativas do agentmemory via npx..."
npx -y skills add rohitg00/agentmemory -y || true

# ── 5. Configurar serviço Systemd User (inicialização em background no boot) ─
echo "   → Configurando serviço do systemd user para agentmemory..."
AGENTMEMORY_EXEC="$(command -v agentmemory || echo "$HOME/.asdf/shims/agentmemory")"

mkdir -p "$HOME/.config/systemd/user"
cat > "$HOME/.config/systemd/user/agentmemory.service" << EOF
[Unit]
Description=agentmemory - Servidor de memoria persistente para Agentes IA
After=network.target

[Service]
Type=simple
Environment=PATH=$PATH
Environment=HOME=$HOME
ExecStart=$AGENTMEMORY_EXEC
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF

# Habilitar e iniciar serviço caso systemd esteja ativo
if [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then
    echo "   → Habilitando e iniciando serviço agentmemory via systemctl --user..."
    systemctl --user daemon-reload || true
    systemctl --user enable agentmemory.service || true
    systemctl --user start agentmemory.service || true
    echo "   ✅ Serviço agentmemory ativo em background!"
else
    echo "   ⚠️  systemd não está como PID 1. O serviço será ativado após o próximo 'wsl --shutdown'."
fi

# ── 6. Conectar automaticamente com agentes suportados ──────────────────────
echo "   → Conectando agentmemory aos agentes instalados..."

# OpenCode CLI
if command -v opencode &> /dev/null || [ -d "$HOME/.config/opencode" ]; then
    echo "     -> Conectando OpenCode..."
    "$AGENTMEMORY_EXEC" connect opencode 2>/dev/null || true
fi

# Codex CLI
if command -v codex &> /dev/null || [ -d "$HOME/.codex" ]; then
    echo "     -> Conectando Codex CLI (com hooks)..."
    "$AGENTMEMORY_EXEC" connect codex --with-hooks 2>/dev/null || true
fi

# Claude Code
if command -v claude &> /dev/null || [ -d "$HOME/.claude" ]; then
    echo "     -> Conectando Claude Code (com hooks)..."
    "$AGENTMEMORY_EXEC" connect claude-code --with-hooks 2>/dev/null || true
fi

# Cursor
if [ -d "$HOME/.cursor" ]; then
    echo "     -> Conectando Cursor..."
    "$AGENTMEMORY_EXEC" connect cursor 2>/dev/null || true
fi

# GitHub Copilot CLI
if command -v copilot &> /dev/null || [ -d "$HOME/.copilot" ]; then
    echo "     -> Conectando GitHub Copilot CLI..."
    "$AGENTMEMORY_EXEC" connect copilot-cli 2>/dev/null || true
fi

echo ""
echo "✅ agentmemory configurado com sucesso!"
echo "   Porta REST / MCP: http://localhost:3111"
echo "   Visualizador Web: http://localhost:3113"
echo "   Status:           systemctl --user status agentmemory"
