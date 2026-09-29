# Dotfiles — WSL 2 (Arch Linux) + Windows

Setup automatizado para ambiente de desenvolvimento em WSL 2 com **Arch Linux** e integração Windows.

---

## O que é instalado

### Windows (via Winget)

| App | Descrição |
|-----|-----------|
| **Bitwarden** | Gerenciador de senhas |
| **VS Code** | Editor de código |
| **Antigravity IDE** | IDE de desenvolvimento AI |
| **IntelliJ IDEA Community** | IDE oficial para Kotlin / Java |
| **Android Studio** | Desenvolvimento Android |
| **USBIPD** | Ponte USB → WSL (para ADB físico) |
| **Chocolatey** | Gerenciador de pacotes para Windows |
| **.NET 10 SDK** | Kit de desenvolvimento .NET |
| **Visual C++ Redist (AIO)** | Runtimes MSVC do 2005 ao 2022+ |
| **Inno Setup** | Criador de instaladores para Windows |
| **Intel Driver & Support Assistant** | Utilitário oficial de drivers de vídeo Intel |
| **NVIDIA App** | Drivers de vídeo NVIDIA |
| **NVIDIA CUDA Toolkit** | Plataforma de computação paralela/GPU |
| **WinRAR** | Compactador e descompactador de arquivos |
| **7-Zip** | Compactador e descompactador open-source |
| **VLC media player** | Reprodutor de mídia multimídia |

### WSL 2 (Arch Linux)

| Ferramenta | Descrição |
|------------|-----------|
| **Zsh + Oh My Zsh** | Shell moderno com plugins (`archlinux`, `git`, `zoxide`, `docker`...) |
| **OpenJDK 17 LTS** | JDK nativo (`jdk17-openjdk`) para Gradle, Kotlin e Android |
| **7zip + unrar** | Suporte completo a arquivos comprimidos via pacman |
| **ffmpeg** | Manipulação e conversão de áudio e vídeo |
| **asdf v0.16+** | Gerenciador de versões unificado (binário Go) |
| **Node.js** (latest) | Runtime JS + npm, yarn, pnpm |
| **Ruby** (latest) | Linguagem Ruby |
| **Python** (latest) | Linguagem Python |
| **Kotlin** (latest) | Linguagem Kotlin |
| **Docker Engine** | Docker oficial para Arch com suporte a systemd |
| **Docker Compose** | Orquestração de containers nativa |
| **Android ADB bridge** | `android-tools` com ponte TCP via WSL Mirrored (método Akita) |
| **scrcpy** | Espelhamento de tela Android de alta performance |
| **Antigravity CLI** (`agy`) | Assistente IA agêntico do Google |
| **OpenCode CLI** | Agente IA open-source |
| **Codex CLI** | Assistente de código IA |
| **agentmemory** | Memória persistente multi-tier para agentes de IA (Claude, Codex, OpenCode, Antigravity) |
| **fzf** | Busca fuzzy interativa no terminal |
| **ripgrep** | Busca textual ultra rápida (`rg`) |
| **zoxide** | Navegação inteligente entre pastas (`z`) |
| **gh** | GitHub CLI oficial (`github-cli`) |
| **jq** | Processador e formatador de JSON |

---

## Requisitos

- Windows 10 (build 19041+) ou Windows 11
- PowerShell rodando como **Administrador**
- WSL 2 habilitado
- Conexão com a internet

---

## Setup em máquina nova

### Parte 1 — Windows (Automação Inicial)

#### 1. Abra o PowerShell como Administrador e rode:

```powershell
irm https://raw.githubusercontent.com/stephanviana/dotfiles-arch/main/windows/setup.ps1 | iex
```

O script vai:
- Verificar se o **Arch Linux** está presente no WSL (se não estiver, executa `wsl --install archlinux`)
- Copiar o `.wslconfig` otimizado para `C:\Users\<user>\` (4GB RAM, 4 CPUs, rede Mirrored e DNS Tunneling)
- Instalar os apps de desenvolvimento via Winget
- Instalar o Chocolatey
- Registrar uma tarefa para abrir o Arch Linux automaticamente após o login/reboot

#### 2. Reboot (Apenas se o WSL foi instalado do zero)

Se o WSL 2 **não estava habilitado**, reinicie o PC. Se o WSL já estava ativo, nenhum reboot completo é necessário — o `.wslconfig` é aplicado diretamente via `wsl --shutdown`.

---

### Parte 2 — Configurações Iniciais do Arch Linux

> [!NOTE]
> No Arch Linux oficial para WSL, a primeira execução inicia diretamente como **root**. É necessário criar seu usuário, conceder permissões de sudo e configurá-lo como o usuário padrão do WSL.

Abra o terminal do Arch Linux e siga os passos abaixo:

#### Passo 1: No terminal do Arch Linux (como root)

1. **Crie o novo usuário** definindo a pasta home e o shell padrão:
   ```bash
   useradd -m -g wheel -s /bin/bash nome_do_usuario
   ```

2. **Defina uma senha** para esse usuário:
   ```bash
   passwd nome_do_usuario
   ```

3. **Ative as permissões de sudo** para o grupo wheel:
   ```bash
   echo "%wheel ALL=(ALL:ALL) ALL" > /etc/sudoers.d/wheel
   ```

4. **Defina uma senha para o root** (para evitar ficar bloqueado caso precise acessar o root diretamente no futuro):
   ```bash
   passwd root
   ```

5. **Instale o sudo** (se ainda não estiver instalado):
   ```bash
   pacman -Sy sudo
   ```

#### Passo 2: Definir o usuário como padrão do WSL

Existem dois caminhos possíveis:

- **Método A (Recomendado — dentro do Arch Linux):**
  Edite ou crie o arquivo `/etc/wsl.conf`:
  ```bash
  nano /etc/wsl.conf
  ```
  Adicione as linhas:
  ```ini
  [user]
  default=nome_do_usuario
  ```
  Salve o arquivo (`Ctrl + O`, `Enter` e `Ctrl + X`).

- **Método B (Via PowerShell no Windows):**
  Feche o terminal do Arch e abra o PowerShell no Windows:
  ```powershell
  wsl --manage archlinux --set-default-user nome_do_usuario
  ```

---

### Parte 3 — Instalação dos Dotfiles no Arch Linux

Feche o terminal root e abra o Arch Linux normalmente (ele já entrará na sua conta de usuário criada).

#### 1. Clonar o repositório

```bash
git clone https://github.com/stephanviana/dotfiles-arch ~/.dotfiles
```

#### 2. Rodar o instalador

```bash
cd ~/.dotfiles
chmod +x wsl/install.sh wsl/tools/*.sh
./wsl/install.sh
```

O instalador executa em **10 etapas organizadas**:

```text
[1/10] 🌐 Rede e DNS (Mirrored + DNS Tunneling com systemd-resolved)
[2/10] 📦 Atualização do Pacman e dependências base (base-devel, OpenJDK 17, 7zip, ffmpeg)
[3/10] 🔀 asdf (binário Go) + Node.js (yarn/pnpm), Ruby, Python, Kotlin
[4/10] 🐳 Docker Engine + Compose nativo (systemd-aware)
[5/10] 📱 Android ADB bridge (android-tools) + scrcpy
[6/10] 🔧 CLI tools (zsh, fzf, ripgrep, zoxide, gh, jq, agy, opencode, codex)
[7/10] 🧠 agentmemory (memória persistente e multi-tier para agentes de IA)
[8/10] 🔗 Symlinks (.zshrc → ~/.zshrc, .gitconfig → ~/.gitconfig)
[9/10] 🐚 Zsh como shell padrão
[10/10] ✅ Resumo final
```

#### 3. Ativar o systemd (necessário para Docker automático)

Após a instalação, reinicie a instância do WSL no PowerShell do Windows:

```powershell
wsl --shutdown
```

Reabra o Arch Linux. A partir daí o Docker e os serviços de rede iniciam automaticamente via systemd.

#### 4. Recarregar o shell

```bash
exec zsh
```

---

## 🛠️ Guia de Configuração Pós-Instalação

### 1. Docker Engine (Sem Sudo e com Systemd)

#### Docker sem `sudo`
O instalador adiciona seu usuário ao grupo `docker`. Para aplicar essa permissão na sessão atual sem precisar deslogar:
```bash
newgrp docker
```
Teste executando:
```bash
docker run hello-world
```

#### Status do serviço
Com o `systemd=true` ativo no `/etc/wsl.conf`, o Docker inicia automaticamente no boot. Verifique com:
```bash
sudo systemctl status docker
```

---

### 2. Android ADB Bridge

Para debugar apps Android (React Native, Flutter, Kotlin Nativo) a partir do Arch no WSL 2:

#### Método A: TCP Bridge (Método Akita) — Padrão e Recomendado
Já vem pré-configurado no `.zshrc`. Os comandos `adb` dentro do Arch Linux comunicam-se via socket TCP (`host.docker.internal:5037`) com o servidor ADB do Windows.

1. No **Windows**: inicie o **Android Studio** ou rode no terminal:
   ```cmd
   adb devices
   ```
2. No **Arch Linux**:
   ```bash
   adb devices
   ```
   O dispositivo conectado no Windows será listado imediatamente.

#### Método B: USBIPD (Passagem Física do Dispositivo USB)
Se precisar que o Arch reconheça o cabo USB diretamente:

1. No **Arch Linux**, instale o cliente USBIP:
   ```bash
   sudo pacman -S --needed --noconfirm usbip hwdata
   ```
2. Conecte o aparelho Android via USB no PC.
3. No **PowerShell do Windows** (como Admin):
   ```powershell
   usbipd list
   usbipd bind --busid <BUSID>
   usbipd attach --wsl -d archlinux --busid <BUSID>
   ```
4. No **Arch Linux**:
   ```bash
   lsusb
   adb devices
   ```

---

### 3. asdf (Gerenciador de Versões)

Os plugins `nodejs`, `ruby`, `python` e `kotlin` já vêm instalados na versão mais recente (`latest`).

```bash
# Listar versões disponíveis
asdf list all nodejs

# Instalar versão específica
asdf install nodejs 20.18.0

# Definir versão global ou local no projeto
asdf global nodejs 20.18.0
asdf local nodejs 20.18.0
```

---

### 4. Git e Chaves SSH

#### Ajustar nome e e-mail
Como `~/.gitconfig` é um symlink para `~/.dotfiles/wsl/.gitconfig`, altere suas informações diretamente no repositório:
```bash
nano ~/.dotfiles/wsl/.gitconfig
```

#### Criar chave SSH para o GitHub
```bash
ssh-keygen -t ed25519 -C "seu-email@gmail.com"
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
```
Copie a chave gerada e adicione nas configurações de SSH da sua conta no GitHub.

---

### 5. Dicas de Produtividade (CLI Tools)

- **zoxide (`z`)**: Substitui o comando `cd` aprendendo os diretórios mais frequentes:
  ```bash
  z dotfiles   # Navega diretamente para ~/.dotfiles de qualquer lugar
  zi           # Menu interativo com histórico
  ```
- **fzf**: Busca fuzzy inteligente no terminal:
  - `Ctrl + R` — Busca no histórico de comandos
  - `Ctrl + T` — Busca rápida de arquivos
  - `Alt + C` — Navegação rápida entre diretórios
- **Aliases Pacman**:
  - `pacin <pacote>` — `sudo pacman -S`
  - `pacrem <pacote>` — `sudo pacman -Rns`
  - `pacup` — `sudo pacman -Syu`
  - `pacsearch <termo>` — `pacman -Ss`

---

### 6. agentmemory (Memória Persistente para Agentes IA)

O [agentmemory](https://github.com/rohitg00/agentmemory) fornece uma camada de memória persistente multi-tier para agentes de código (Claude Code, Codex, OpenCode, Antigravity, Cursor, etc.), evitando que eles "esqueçam" detalhes de arquitetura, decisões e preferências entre sessões.

- **Serviço em Background:** Gerenciado via systemd user (`systemctl --user status agentmemory`), iniciando automaticamente com o WSL.
- **Portas Utilizadas:**
  - `3111` — API REST e servidor MCP (Model Context Protocol).
  - `3113` — **Visualizador Web em Tempo Real** (abra [http://localhost:3113](http://localhost:3113) no seu navegador para ver as memórias e replay de sessões).
  - `49134` — Comunicação interna do engine `iii`.
- **Embeddings Locais (On-Device):** Pré-configurado com `EMBEDDING_PROVIDER=local` em `~/.agentmemory/.env`, executando o modelo `all-MiniLM-L6-v2` localmente e de forma 100% gratuita.

#### Comandos Úteis e Aliases
```bash
memstatus    # Verifica a integridade da API do agentmemory
memviewer    # Exibe o link do visualizador web (http://localhost:3113)
memlog       # Acompanha logs do serviço via journalctl
memrestart   # Reinicia o serviço no systemd user
```

#### Conectar outros agentes manualmente:
```bash
agentmemory connect <agente>   # Ex: claude-code, codex, opencode, cursor
agentmemory doctor             # Diagnóstico interativo do ambiente
```

---

## Estrutura do Repositório

```text
dotfiles-arch/
├── AGENTS.md              # Diretrizes de desenvolvimento
├── README.md              # Documentação completa
├── windows/
│   ├── setup.ps1          # Setup Windows: WSL 2 (Arch) + Winget + .wslconfig
│   └── .wslconfig         # Configurações do WSL 2 (RAM, CPU, Mirrored Network)
└── wsl/
    ├── install.sh         # Instalador principal para Arch Linux (10 etapas)
    ├── .zshrc             # Configuração do Zsh (asdf, aliases pacman/agentmemory, Docker, ADB)
    ├── .gitconfig         # Configuração do Git (aliases, diff, rebase)
    └── tools/
        ├── network.sh     # Rede + DNS (systemd-resolved + preservação de /etc/wsl.conf)
        ├── asdf.sh        # asdf v0.16+ Go binary + Node, Ruby, Python, Kotlin
        ├── docker.sh      # Docker Engine + Compose nativo Arch (systemd)
        ├── android.sh     # ADB bridge + scrcpy + instruções USBIPD
        ├── cli-tools.sh   # Oh My Zsh, plugins, fzf, ripgrep, zoxide, gh, jq, IAs
        └── agentmemory.sh # agentmemory + skills + systemd user + auto connect
```

---

## Personalização

| Arquivo | Finalidade |
|---------|------------|
| `wsl/.gitconfig` | Nome, e-mail, aliases e editor preferido |
| `wsl/.zshrc` | Variáveis de ambiente, aliases e plugins do Zsh |
| `windows/.wslconfig` | Ajuste de limites de memória, núcleos de CPU e rede do WSL |

Para atualizar suas configurações após alterações no repositório:
```bash
cd ~/.dotfiles
git pull
exec zsh
```
