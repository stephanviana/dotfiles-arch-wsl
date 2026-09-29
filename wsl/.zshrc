# =============================================================================
# Dotfiles — .zshrc (Arch Linux no WSL 2)
# =============================================================================

# ---------------------------------------------------------------------------
# PATH essencial (deve vir antes dos plugins do Oh My Zsh)
# ---------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"

# ---------------------------------------------------------------------------
# Oh My Zsh
# ---------------------------------------------------------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(
    git
    zoxide
    docker
    docker-compose
    archlinux
    zsh-autosuggestions
    zsh-syntax-highlighting
)

source "$ZSH/oh-my-zsh.sh"

# ---------------------------------------------------------------------------
# asdf v0.16+ (binário Go)
# ---------------------------------------------------------------------------
export ASDF_DATA_DIR="$HOME/.asdf"
# completions
fpath=("${ASDF_DATA_DIR}/completions" $fpath)
autoload -Uz compinit && compinit

# ---------------------------------------------------------------------------
# Java JDK (OpenJDK 17 LTS - Arch Linux)
# ---------------------------------------------------------------------------
if [ -d "/usr/lib/jvm/java-17-openjdk" ]; then
    export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
elif [ -d "/usr/lib/jvm/default-runtime" ]; then
    export JAVA_HOME="/usr/lib/jvm/default-runtime"
fi
[ -n "${JAVA_HOME:-}" ] && export PATH="$JAVA_HOME/bin:$PATH"

# ---------------------------------------------------------------------------
# Android ADB Bridge (ponte TCP — método Akita)
# ---------------------------------------------------------------------------
export ADB_SERVER_SOCKET=tcp:host.docker.internal:5037
export ANDROID_HOME="$HOME/Android/Sdk"
export PATH="$PATH:$ANDROID_HOME/platform-tools"

# ---------------------------------------------------------------------------
# Docker — iniciar se não estiver rodando
# ---------------------------------------------------------------------------
if ! pgrep -x "dockerd" > /dev/null 2>&1; then
    if [ "$(ps -p 1 -o comm= 2>/dev/null)" = "systemd" ]; then
        sudo systemctl start docker > /dev/null 2>&1 || true
    fi
fi

# ---------------------------------------------------------------------------
# Aliases — Navegação
# ---------------------------------------------------------------------------
alias cls="clear"
alias ll="ls -lah --color=auto"
alias la="ls -A --color=auto"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias mkd="mkdir -pv"

# ---------------------------------------------------------------------------
# Aliases — Pacman (Arch Linux)
# ---------------------------------------------------------------------------
alias pacin="sudo pacman -S"
alias pacrem="sudo pacman -Rns"
alias pacup="sudo pacman -Syu"
alias pacsearch="pacman -Ss"

# ---------------------------------------------------------------------------
# Aliases — Git
# ---------------------------------------------------------------------------
alias gs="git status -sb"
alias ga="git add"
alias gc="git commit"
alias gp="git push"
alias gl="git pull"
alias gd="git diff"
alias gco="git checkout"
alias gb="git branch"
alias glog="git log --oneline --graph --decorate --all"

# ---------------------------------------------------------------------------
# Aliases — Docker
# ---------------------------------------------------------------------------
alias dps="docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"
alias dcp="docker compose"
alias dcu="docker compose up -d"
alias dcd="docker compose down"
alias dcl="docker compose logs -f"

# ---------------------------------------------------------------------------
# Aliases — Utilitários
# ---------------------------------------------------------------------------
alias ports="ss -tulnp"
alias myip="curl -s ifconfig.me"
alias reload="exec zsh"
alias dotfiles="cd ~/.dotfiles"

# ---------------------------------------------------------------------------
# agentmemory (https://github.com/rohitg00/agentmemory)
# ---------------------------------------------------------------------------
export AGENTMEMORY_URL="http://localhost:3111"

alias mem="agentmemory"
alias memstatus="curl -s http://localhost:3111/agentmemory/health | jq . 2>/dev/null || agentmemory status"
alias memviewer="echo 'Visualizador em: http://localhost:3113'"
alias memlog="journalctl --user -u agentmemory -f"
alias memrestart="systemctl --user restart agentmemory"

# ---------------------------------------------------------------------------
# FZF
# ---------------------------------------------------------------------------
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# ---------------------------------------------------------------------------
# Zoxide (substituição do cd)
# ---------------------------------------------------------------------------
eval "$(zoxide init zsh)"

# ---------------------------------------------------------------------------
# PATH extras
# ---------------------------------------------------------------------------
export PATH="$HOME/.local/bin:$PATH"
