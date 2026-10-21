#!/usr/bin/env bash
# Install one persistent AgentMemory server in the Arch filesystem.
set -euo pipefail

if ! command -v npm >/dev/null 2>&1; then
    printf 'Install Node.js and npm in Arch first.\n' >&2
    exit 1
fi

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/agentmemory" \
    "$HOME/.agentmemory" "$HOME/.config/systemd/user"
export PATH="$HOME/.local/bin:$PATH"

version="$(npm view @agentmemory/agentmemory dist-tags --json |
    jq -r 'if type == "array" then .[-1].latest else .latest end')"
if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    printf 'Could not resolve the latest stable AgentMemory version.\n' >&2
    exit 1
fi
updated=false
if [[ ! -x "$HOME/.local/bin/agentmemory" ]] || \
    [[ $("$HOME/.local/bin/agentmemory" --version 2>/dev/null) != "$version" ]]; then
    npm install --global --prefix "$HOME/.local" "@agentmemory/agentmemory@$version"
    updated=true
fi

env_file="$HOME/.agentmemory/.env"
if [[ ! -e "$env_file" ]]; then
    cat > "$env_file" <<EOF
AGENTMEMORY_DATA_DIR=$HOME/.local/share/agentmemory
AGENTMEMORY_AGENT_SCOPE=shared
AGENTMEMORY_INJECT_CONTEXT=true
EOF
    chmod 600 "$env_file"
fi

unit="$HOME/.config/systemd/user/agentmemory.service"
if [[ ! -e "$unit" ]]; then
    cat > "$unit" <<EOF
[Unit]
Description=AgentMemory on Arch Linux WSL
After=network-online.target

[Service]
Type=simple
WorkingDirectory=%h
Environment=PATH=$HOME/.local/bin:/usr/local/bin:/usr/bin
Environment=AGENTMEMORY_DATA_DIR=$HOME/.local/share/agentmemory
ExecStart=$HOME/.local/bin/agentmemory --data-dir $HOME/.local/share/agentmemory
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
fi

if [[ $(ps -p 1 -o comm=) == systemd ]]; then
    systemctl --user daemon-reload
    if ! systemctl --user is-active --quiet agentmemory.service && \
        curl --fail --silent --max-time 2 \
        http://127.0.0.1:3111/agentmemory/livez >/dev/null; then
        printf 'Port 3111 is occupied. Stop the conflicting AgentMemory server before continuing.\n' >&2
        exit 1
    else
        if [[ $(loginctl show-user "$USER" -p Linger --value) != yes ]] && \
            ! sudo -n loginctl enable-linger "$USER" 2>/dev/null; then
            printf 'Run sudo loginctl enable-linger %s for automatic startup.\n' "$USER"
        fi
        systemctl --user enable agentmemory.service
        if [[ $updated == true ]]; then
            systemctl --user restart agentmemory.service
        else
            systemctl --user start agentmemory.service
        fi
    fi
fi

printf 'AgentMemory data: %s\n' "$HOME/.local/share/agentmemory"
printf 'AgentMemory unit: %s\n' "$unit"
