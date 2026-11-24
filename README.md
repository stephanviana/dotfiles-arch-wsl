# Dotfiles para Arch Linux no WSL 2

Este repositório reúne configurações e instaladores para um ambiente de desenvolvimento com **Arch Linux no WSL 2 e Windows 11**. Ele prepara o shell, as linguagens, os serviços Linux e a integração com os aplicativos Windows.

Os scripts são executados por plataforma: PowerShell no Windows e Bash no Arch. A configuração é dividida em etapas que podem ser instaladas ou reaplicadas separadamente.

## O que é configurado

| Área | Configuração |
| --- | --- |
| Arch | Zsh, Oh My Zsh, Starship, Git, GitHub CLI (`gh`), ferramentas de terminal e Neovim/LazyVim. |
| Linguagens | mise para Node.js, Go, Ruby, Kotlin, Python e uv; Rust/Cargo, JDK 17/21, Gradle e ferramentas nativas pelo Arch. |
| Serviços Linux | Docker Engine, Compose, Buildx, Supabase CLI e AgentMemory com serviço systemd de usuário. |
| Android | SDK e Android Studio no Linux, interface via WSLg e ADB usando o servidor USB do Windows. |
| Windows | VS Code com extensão WSL, IntelliJ IDEA, Windows Terminal, fonte, Starship, ADB, Node.js e runtimes. Outros aplicativos e utilitários de hardware seguem o [catálogo](windows/versions.psd1). |
| Agentes | OpenCode, Codex e Antigravity CLI no Arch, com integração ao AgentMemory. |
| Ferramentas opcionais | Compilação cruzada Windows MSVC no Arch. |

O catálogo Windows também inclui Bitwarden, 7-Zip, WinRAR, VLC e YouTube Music Desktop. Os utilitários Intel/NVIDIA são selecionados conforme o hardware; os aplicativos usam winget/Store e o setup também disponibiliza Chocolatey.

Mantenha projetos Linux em `~/dev`, no filesystem da distribuição. Abra o VS Code com `code .` nesse diretório e confira a indicação **WSL: archlinux**. As dependências, credenciais e comandos de build de cada aplicação são configurados pelo próprio projeto. Projetos desktop Windows usam checkout próprio, por exemplo em `C:\PROJETOS`, e ferramentas nativas no PowerShell.

**O Arch inicia sob demanda**, ao abrir um terminal ou aplicativo WSL. O setup não cria keepalive nem abre distribuições no logon. Docker e AgentMemory só ficam disponíveis enquanto o Arch estiver ativo; systemd e linger não mantêm a distribuição ativa por conta própria.

## Pré-requisitos

- Windows 11 com suporte ao WSL 2, WSLg e rede `mirrored`.
- Acesso de administrador no Windows quando solicitado para instalar componentes ou alterar tarefas antigas.
- Um checkout completo deste repositório acessível no Windows.
- No Arch, um usuário normal com `sudo`, systemd habilitado e acesso à internet.
- Para Android em aparelho físico: cabo USB de dados, depuração USB, driver Windows quando necessário e autorização RSA no telefone.

## Instalação

Os comandos abaixo são para uma instalação nova ou para reaplicar uma etapa. Um ambiente já configurado não precisa executar o setup novamente para uso diário. Feche o Android Studio antes de instalar ou reaplicar sua configuração.

### 1. Configurar o Windows

No PowerShell, na raiz do checkout Windows:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup.ps1
```

O setup instala `archlinux` quando ausente, configura os aplicativos e o Terminal e copia os auxiliares Windows para `%LOCALAPPDATA%\dotfiles-wsl-arch`. Use a conta Windows que utilizará o ambiente; o script informa quando precisar de elevação ou reinicialização.

A configuração existente em `%USERPROFILE%\.wslconfig` é preservada. Se estiver ausente e o computador tiver pelo menos 16 GiB de RAM e 8 CPUs lógicas, o setup aplica o [modelo](windows/.wslconfig): até 8 GB de memória, 4 CPUs, 2 GB de swap, rede mirrored, DNS tunneling e WSLg. Para outro hardware, ajuste esse arquivo manualmente. O setup deixa sua aplicação para o próximo início do WSL, preservando as sessões atuais.

O setup também desabilita `ArchWSLKeepAlive` e `DotfilesOpenUbuntu` quando suas ações, descrições e gatilhos correspondem às tarefas antigas dos dotfiles. Tarefas personalizadas são preservadas. Uma instância já em execução continua ativa; o script informa essa pendência sem encerrar seus processos.

### 2. Preparar o usuário e o systemd no Arch

Abra a distribuição no Windows:

```powershell
wsl -d archlinux
```

Se a primeira sessão abrir como root e você ainda não tiver um usuário de desenvolvimento, crie-o. Substitua `SEU_USUARIO` pelo nome escolhido:

```bash
pacman -Syu --needed sudo git vim
useradd -m -G wheel -s /bin/bash SEU_USUARIO
passwd SEU_USUARIO
EDITOR=vim visudo
```

No `visudo`, habilite `%wheel ALL=(ALL:ALL) ALL`. Se o usuário já existir, confira seu acesso ao grupo `wheel` e ao `sudo`, sem recriá-lo.

Em `/etc/wsl.conf`, preserve as demais seções e configure:

```ini
[boot]
systemd=true

[user]
default=SEU_USUARIO
```

Salve o trabalho das sessões WSL e saia do Arch. No PowerShell, execute `wsl --shutdown` e abra `wsl -d archlinux` novamente para aplicar essas opções. **Esse comando encerra todas as sessões e distribuições WSL.**

### 3. Instalar as ferramentas no Arch

Como usuário normal, clone no filesystem Linux:

```bash
mkdir -p ~/dev
cd ~/dev
git clone https://github.com/stephanviana/dotfiles-arch-wsl.git
cd dotfiles-arch-wsl
bash wsl/install.sh --all
```

`--all` instala a base, Paru, LazyVim, Android SDK/Studio, Supabase, AgentMemory e agentes. A compilação cruzada Windows é uma etapa opcional separada. O instalador pede `sudo` para alterações de sistema e para diante de uma falha, indicando a etapa afetada.

A base grava `appendWindowsPath=false` em `/etc/wsl.conf`, habilita Docker, adiciona o usuário ao grupo `docker` e configura o Zsh. Após a instalação inicial, salve o trabalho e aplique a opção de interoperabilidade com `wsl --shutdown` no Windows. Abra uma nova sessão Arch para usar o grupo e o shell configurados. Reiniciar o WSL não é necessário para reaplicar apenas a ponte ADB ou as preferências da IDE.

### 4. Concluir as configurações pessoais

- Confira nome e email do Git antes de criar commits.
- Faça login nos agentes e nos serviços usados. O setup não fornece credenciais.
- Abra o Android Studio com `android-studio-wsl` e conclua seu assistente usando `~/Android/Sdk`.
- Conecte e autorize o telefone para validar a integração Android.
- Confira o perfil Arch no Windows Terminal: o modelo inclui perfis cujos identificadores podem variar entre instalações.

## Instalação por etapas

Execute os comandos a partir da raiz do checkout Arch, depois de preparar os pré-requisitos.

| Etapa | O que instala ou reaplica |
| --- | --- |
| `bash wsl/install.sh --base` | Ferramentas Arch, GitHub CLI, Docker, shell, mise, ambiente e launcher VS Code. |
| `bash wsl/install.sh --mise` | Linguagens do mise, incluindo Go, e integração do shell; requer as dependências da base. |
| `bash wsl/install.sh --paru` | Gerenciador de pacotes do AUR. |
| `bash wsl/install.sh --lazyvim` | Neovim e configuração inicial LazyVim. |
| `bash wsl/install.sh --vscode` | Launcher do VS Code Windows para o workspace WSL. |
| `bash wsl/install.sh --android` | SDK Linux e ponte ADB Windows. |
| `bash wsl/install.sh --android-studio` | SDK, ponte ADB, IDE Linux, preferências e atalho WSLg. Requer IDE fechada. |
| `bash wsl/install.sh --supabase` | Supabase CLI; usa o Docker do Arch. |
| `bash wsl/install.sh --agentmemory` | Servidor, dados e serviço systemd de usuário. |
| `bash wsl/install.sh --agents` | Agentes e integrações; instale o AgentMemory antes. |
| `bash wsl/install.sh --windows-cross` | Toolchain isolada para Windows MSVC x64. |
| `bash wsl/install.sh --all` | Conjunto completo descrito na instalação; também é o padrão sem argumentos. |

No Windows, as etapas podem ser executadas separadamente no PowerShell:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup-apps.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup-terminal.ps1
```

## Uso e verificação

| Componente | Como usar ou conferir |
| --- | --- |
| Distribuição | No Windows: `wsl --list --verbose`; `archlinux` deve usar WSL 2. Abra com `wsl -d archlinux`. |
| Linguagens | No Arch: `mise ls`, `mise doctor` e `mise install` no projeto. As seleções globais estão em [mise.toml](wsl/tools/mise.toml). |
| Go | `go version` e `go env GOROOT GOPATH`; o mise instala a versão estável selecionada pelo modelo. |
| GitHub CLI | `gh --version` e `gh auth status`; faça login com `gh auth login` quando necessário. |
| Python | Use ambientes por projeto, como `uv venv --seed .venv`, ou `uv sync` em projetos que já usam uv. |
| Docker | `systemctl status docker`, `docker version` e `docker compose version`. Abra uma nova sessão após entrar no grupo `docker`. |
| VS Code | `code .` dentro do projeto no Arch; confirme **WSL: archlinux**. |
| Android Studio | `android-studio-wsl` ou **Android Studio (Arch WSL)** no menu Iniciar. |
| ADB | `adb-bridge status` consulta sem iniciar; `adb devices -l` recupera o servidor Windows quando necessário. |
| Supabase | `supabase start` e `supabase stop` no projeto, com Docker ativo. |
| AgentMemory | `systemctl --user status agentmemory`; saúde em `http://127.0.0.1:3111/agentmemory/livez`, viewer em `http://127.0.0.1:3113`. |
| Agentes | `opencode mcp list`, `agy mcp list` e `codex mcp list` conferem as conexões configuradas. |

O serviço AgentMemory usa `~/.agentmemory/.env`, dados em `~/.local/share/agentmemory` e a unidade `~/.config/systemd/user/agentmemory.service`. Após editar o ambiente, execute `systemctl --user restart agentmemory`. Para diagnosticar, use `journalctl --user -u agentmemory -n 100`. Se o instalador não conseguir habilitar linger, ele informa o comando `sudo loginctl enable-linger "$USER"`.

## Personalização, atualização e preservação

Altere o modelo no repositório e execute a etapa correspondente para aplicá-lo. Arquivos do checkout e arquivos instalados não são sincronizados automaticamente.

| Configuração | Comportamento ao reaplicar |
| --- | --- |
| `%USERPROFILE%\.wslconfig` | Preservado se já existir; alterações locais são manuais. |
| `~/.zshrc` e `~/.gitconfig` | Modelos copiados apenas quando ausentes. A integração mise e o carregamento do ambiente são acrescentados quando necessário. |
| Ambiente do shell | [env.sh](wsl/tools/env.sh) é copiado novamente para `~/.config/dotfiles-wsl-arch/env.sh`. |
| mise | O modelo substitui `~/.config/mise/config.toml`, com primeiro backup `.bak` quando diferente. |
| Windows Terminal | O modelo completo substitui `settings.json`, com primeiro backup `.bak` quando diferente. Perfil e Starship são copiados novamente. |
| Android Studio | Só as duas preferências ADB são alteradas em `other.xml`, com backup; IDE aberta ou formato desconhecido interrompe a etapa. Opções VM e configurações GTK são reaplicadas. |
| Ponte ADB | O wrapper legado reconhecido e versões gerenciadas são atualizados; wrappers personalizados são preservados. |
| AgentMemory | `.env`, unidade e dados existentes são preservados. Uma atualização do pacote reinicia seu serviço. |
| LazyVim | A instalação inicial pode mover configurações Neovim anteriores para `.bak`; instalações já reconhecidas são preservadas. |

Pacotes do Arch acompanham o sistema; atualize com `sudo pacman -Syu` e use `paru -Syu` para os pacotes AUR. O mise resolve as versões declaradas no modelo, atualmente `latest`; use um `mise.toml` no projeto para suas versões específicas. Aplicativos Windows usam winget/Store e reaproveitam instalações existentes. O [catálogo Windows](windows/versions.psd1) e os scripts de cada etapa são a referência das versões e dependências.

Reaplicar uma etapa pode atualizar ferramentas ou substituir modelos: não é uma garantia de versões idênticas entre máquinas. Confira os backups antes de restaurar; não há rollback automático do setup completo. Preserve separadamente projetos, credenciais e dados do AgentMemory.

## Guias e estrutura

- [Android, ADB e WSLg](docs/android.md): configuração da ponte, diagnóstico, preferências e reparo gráfico manual.
- [Compilação cruzada Windows](docs/windows-cross.md): ferramenta opcional para gerar PE x64 a partir do Arch.
- [windows/](windows/): instaladores PowerShell e modelos do host Windows.
- [wsl/](wsl/): instalador Arch, configurações de shell e ferramentas Linux.
- [AGENTS.md](AGENTS.md): regras de desenvolvimento do repositório.

Para aplicar somente a migração de tarefas antigas, use `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\disable-wsl-logon-tasks.ps1` no checkout Windows. A opção `-WhatIf` simula a mudança. Confira `Settings.Enabled` das tarefas reconhecidas; a ausência de janelas extras exige também observar um próximo logon normal.
