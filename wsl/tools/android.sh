#!/bin/bash
# =============================================================================
# Android ADB Bridge — Ponte TCP (método Akita) + scrcpy no Arch Linux
# =============================================================================
set -euo pipefail

echo "📱 Configurando Android ADB bridge..."

# ── Instalar android-tools e scrcpy via pacman ──────────────────────────────
echo "   → Instalando android-tools e scrcpy..."
sudo pacman -S --needed --noconfirm android-tools scrcpy

# ── Criar diretório Android SDK ──────────────────────────────────────────────
echo "   → Criando diretório Android SDK..."
mkdir -p "$HOME/Android/Sdk/platform-tools"

echo "✅ Android ADB bridge configurado!"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 INSTRUÇÕES — USBIPD (se optar pelo Método Físico via Windows):"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  Método Padrão (Recomendado - TCP Bridge):"
echo "  1. No Windows: inicie o Android Studio ou rode 'adb devices'"
echo "  2. No Arch: simplesmente rode 'adb devices' (ADB_SERVER_SOCKET no .zshrc cuida de tudo)"
echo ""
echo "  Método Alternativo (USBIPD Físico):"
echo "  1. No Arch Linux, instale as ferramentas de usbip:"
echo "     sudo pacman -S --needed --noconfirm usbip hwdata"
echo ""
echo "  2. No PowerShell do Windows (como admin):"
echo "     usbipd list"
echo "     usbipd bind --busid <BUSID>"
echo "     usbipd attach --wsl -d archlinux --busid <BUSID>"
echo ""
echo "  3. No Arch Linux:"
echo "     lsusb"
echo "     adb devices"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
