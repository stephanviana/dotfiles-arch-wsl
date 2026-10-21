#!/usr/bin/env bash
# Install coding CLIs and connect them to the Arch AgentMemory service.
set -euo pipefail

export PATH="$HOME/.local/bin:$PATH"
mkdir -p "$HOME/.local/bin"

if ! command -v npm >/dev/null 2>&1; then
    printf 'Install Node.js and npm in Arch first.\n' >&2
    exit 1
fi

npm install --global --prefix "$HOME/.local" --allow-scripts=opencode-ai \
    opencode-ai@latest
npm install --global --prefix "$HOME/.local" @openai/codex@latest
if ! command -v agy >/dev/null 2>&1; then
    installer="$(mktemp)"
    trap 'rm -f "$installer"' EXIT
    curl --fail --location --silent --show-error \
        https://antigravity.google/cli/install.sh --output "$installer"
    bash "$installer"
    rm -f "$installer"
    trap - EXIT
fi

for name in opencode agy codex; do
    command -v "$name" >/dev/null 2>&1 || {
        printf 'Missing CLI after installation: %s\n' "$name" >&2
        exit 1
    }
done
opencode --version >/dev/null

# agy creates this application directory during its first interactive run;
# create it now so AgentMemory's official adapter can detect the installed CLI.
mkdir -p "$HOME/.gemini/antigravity-cli"

if command -v agentmemory >/dev/null 2>&1; then
    if [[ ! -f "$HOME/.config/opencode/opencode.json" ]] ||
        ! jq -e '.mcp.agentmemory' "$HOME/.config/opencode/opencode.json" >/dev/null; then
        agentmemory connect opencode --with-hooks
    fi
    if [[ ! -f "$HOME/.gemini/config/mcp_config.json" ]] ||
        ! jq -e '.mcpServers.agentmemory' "$HOME/.gemini/config/mcp_config.json" >/dev/null ||
        [[ ! -f "$HOME/.gemini/config/hooks.json" ]]; then
        agentmemory connect antigravity-cli --with-hooks
    fi
    if [[ ! -f "$HOME/.codex/config.toml" ]] ||
        ! grep -Fq '[mcp_servers.agentmemory]' "$HOME/.codex/config.toml" ||
        [[ ! -f "$HOME/.codex/hooks.json" ]]; then
        agentmemory connect codex --with-hooks
    fi

    # The OpenCode adapter wires MCP. Its bundled plugin adds automatic capture.
    plugin_root="$HOME/.local/lib/node_modules/@agentmemory/agentmemory/plugin/opencode"
    opencode_dir="$HOME/.config/opencode"
    mkdir -p "$opencode_dir/plugins" "$opencode_dir/commands"
    install -m 0644 "$plugin_root/agentmemory-capture.ts" \
        "$opencode_dir/plugins/agentmemory-capture.ts"
    install -m 0644 "$plugin_root/commands/recall.md" "$opencode_dir/commands/recall.md"
    install -m 0644 "$plugin_root/commands/remember.md" "$opencode_dir/commands/remember.md"
    config_tmp="$(mktemp "$opencode_dir/opencode.json.XXXXXX")"
    trap 'rm -f "$config_tmp"' EXIT
    jq '.plugin = (((.plugin // []) + ["./plugins/agentmemory-capture.ts"]) | unique)' \
        "$opencode_dir/opencode.json" > "$config_tmp"
    mv "$config_tmp" "$opencode_dir/opencode.json"

    if ! codex plugin list | grep -Fq 'agentmemory@agentmemory'; then
        codex plugin marketplace add rohitg00/agentmemory
        codex plugin add agentmemory@agentmemory
    fi

    if [[ ! -f "$HOME/.agents/skills/recall/SKILL.md" ]]; then
        (cd "$HOME" && npx -y skills add rohitg00/agentmemory -g -y)
    fi
else
    printf 'AgentMemory is not installed. Run --agentmemory, then --agents again.\n' >&2
    exit 1
fi

printf 'OpenCode: %s\n' "$(opencode --version)"
printf 'Antigravity CLI: %s\n' "$(agy --version)"
printf 'Codex CLI: %s\n' "$(codex --version)"
