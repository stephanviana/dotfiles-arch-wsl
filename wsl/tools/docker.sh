#!/usr/bin/env bash
# Docker Engine and Compose from Arch repositories, managed by systemd.
set -euo pipefail

sudo pacman -S --needed --noconfirm docker docker-compose docker-buildx
if [[ $(ps -p 1 -o comm=) != systemd ]]; then
    printf 'Enable systemd in /etc/wsl.conf and restart WSL first.\n' >&2
    exit 1
fi
sudo systemctl enable --now docker.service
if ! id -nG | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    printf 'Open a new Arch session before using Docker without sudo.\n'
fi
docker --version
docker compose version
