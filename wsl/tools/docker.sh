#!/bin/bash
# =============================================================================
# Docker Engine — Instalação nativa para Arch Linux no WSL 2
# =============================================================================
set -euo pipefail

echo "🐳 Instalando Docker Engine..."

# ── Instalar Docker via repositórios oficiais do Arch Linux ──────────────────
echo "   → Instalando docker, docker-compose e docker-buildx via pacman..."
sudo pacman -S --needed --noconfirm \
    docker \
    docker-compose \
    docker-buildx

# ── Adicionar usuário ao grupo docker ──────────────────────────────────────
echo "   → Adicionando $USER ao grupo docker..."
sudo usermod -aG docker "$USER"

# ── Habilitar systemd no /etc/wsl.conf ───────────────────────────────────────
echo "   → Garantindo systemd=true em /etc/wsl.conf..."
if ! grep -q "^\[boot\]" /etc/wsl.conf 2>/dev/null; then
    printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf > /dev/null
else
    if ! grep -q "systemd\s*=\s*true" /etc/wsl.conf 2>/dev/null; then
        sudo sed -i '/^\[boot\]/a systemd=true' /etc/wsl.conf
    fi
fi

# ── Habilitar serviço via systemd ───────────────────────────────────────────
if [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then
    echo "   → systemd detectado — habilitando e iniciando via systemctl..."
    sudo systemctl enable docker.service
    sudo systemctl start docker.service
    echo "   ✅ Docker iniciado via systemd!"
else
    echo "   ⚠️  systemd não está ativo como PID 1 (WSL precisa ser reiniciado)."
    echo ""
    echo "   💡 Para ativar systemd permanentemente, rode no PowerShell do Windows:"
    echo "      wsl --shutdown"
    echo "   E reabra o Arch Linux. O Docker iniciará automaticamente."
fi

echo "✅ Docker instalado com sucesso!"
echo "   Versão: $(docker --version 2>/dev/null || echo 'requer novo login')"
echo "   Compose: $(docker compose version 2>/dev/null || echo 'requer novo login')"
