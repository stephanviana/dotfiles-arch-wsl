#!/bin/bash
# =============================================================================
# Network & System Config — WSL 2 (Mirrored + DNS Tunneling) para Arch Linux
#
# Estratégia:
#   .wslconfig  → networkingMode=mirrored, dnsTunneling=true
#   wsl.conf    → systemd=true, generateResolvConf=false (preservando [user])
#   resolv.conf → symlink para stub do systemd-resolved (127.0.0.53)
#
# Fluxo DNS:
#   App → 127.0.0.53 (systemd-resolved stub)
#       → 10.255.255.254 (DNS Tunnel via hypervisor)
#           → Windows DNS (dinâmico via DHCP)
# =============================================================================
set -euo pipefail

echo "🌐 Configurando rede e DNS..."

# ── 1. Configurar /etc/wsl.conf preservando configurações existentes (ex: [user])
echo "   → Atualizando /etc/wsl.conf..."
sudo touch /etc/wsl.conf

# Garantir [boot] com systemd=true
if ! grep -q "^\[boot\]" /etc/wsl.conf 2>/dev/null; then
    printf '\n[boot]\nsystemd=true\n' | sudo tee -a /etc/wsl.conf > /dev/null
else
    if ! grep -q "systemd\s*=\s*true" /etc/wsl.conf 2>/dev/null; then
        sudo sed -i '/^\[boot\]/a systemd=true' /etc/wsl.conf
    fi
fi

# Garantir [network] com generateResolvConf = false
if ! grep -q "^\[network\]" /etc/wsl.conf 2>/dev/null; then
    printf '\n[network]\ngenerateResolvConf = false\n' | sudo tee -a /etc/wsl.conf > /dev/null
else
    if ! grep -q "generateResolvConf\s*=\s*false" /etc/wsl.conf 2>/dev/null; then
        sudo sed -i '/^\[network\]/a generateResolvConf = false' /etc/wsl.conf
    fi
fi

echo "   ✅ /etc/wsl.conf configurado (preservando [user] e demais seções)."

# ── 2. Apontar resolv.conf para o stub do systemd-resolved ───────────────────
echo "   → Configurando /etc/resolv.conf → stub do systemd-resolved..."

# Remover imutabilidade se existir
sudo chattr -i /etc/resolv.conf 2>/dev/null || true

# Remover arquivo/symlink antigo e criar symlink para o stub
sudo rm -f /etc/resolv.conf
sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

echo "   ✅ /etc/resolv.conf → /run/systemd/resolve/stub-resolv.conf"

# ── 3. Habilitar e reiniciar systemd-resolved ────────────────────────────────
echo "   → Configurando serviço systemd-resolved..."
if [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then
    sudo systemctl enable --now systemd-resolved || true
    sudo systemctl restart systemd-resolved || true
    echo "   ✅ systemd-resolved reiniciado."
else
    echo "   ⚠️  systemd ainda não está ativo como PID 1 (necessário 'wsl --shutdown' no Windows)."
fi

# ── 4. Validar resolução DNS ─────────────────────────────────────────────────
echo "   → Testando resolução DNS..."
sleep 1
if getent hosts archlinux.org &>/dev/null || getent hosts google.com &>/dev/null; then
    echo "   ✅ Resolução DNS (Mirrored + DNS Tunneling) funcionando!"
else
    echo "   ⚠️  DNS ainda não resolve. Tente reiniciar o WSL:"
    echo "      1. No PowerShell do Windows: wsl --shutdown"
    echo "      2. Reabra o terminal do Arch Linux"
    echo "      3. Verifique que %USERPROFILE%\\.wslconfig tem networkingMode=mirrored e dnsTunneling=true"
fi
