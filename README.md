# Desenvolvimento híbrido: Windows 11 + Arch Linux no WSL 2

O Arch no WSL 2 é a workstation principal: projetos em `~/dev`, VS Code Server, agentes, toolchains Linux, Docker, Android SDK e um único AgentMemory. O Windows oferece VS Code GUI, WSLg, ADB server/USB e a toolchain usada para validar o target desktop Windows. Os agentes de código são instalados no Arch. As IDEs instaladas pelo setup no Windows são VS Code e IntelliJ IDEA; o Android Studio roda no Arch com WSLg. O Codex Windows já em uso nesta sessão é uma exceção preservada por solicitação do usuário, sem reinstalação automática nos dotfiles.

## Índice

- [Configuração](#configuração)
- [Onde cada ferramenta roda](#onde-cada-ferramenta-roda)
- [VS Code: interface Windows, workspace Arch](#vs-code-interface-windows-workspace-arch)
- [Monorepos e validação Windows](#monorepos-e-validação-windows)
- [Android e ADB](#android-e-adb)
- [Aplicativos Windows](#aplicativos-windows)
- [Desktop Windows e AutoCut](#desktop-windows-e-autocut)
- [Supabase local](#supabase-local)
- [AgentMemory e agentes](#agentmemory-e-agentes)
- [Verificação após a instalação](#verificação-após-a-instalação)
- [Operação diária e serviços](#operação-diária-e-serviços)
- [Atualização e personalização](#atualização-e-personalização)
- [Recuperação e solução de problemas](#recuperação-e-solução-de-problemas)
- [Referências oficiais](#referências-oficiais)

## Configuração

1. No PowerShell do Windows, execute `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup.ps1` a partir deste checkout. O script preserva uma distribuição `archlinux` e um `.wslconfig` já existentes. Em uma máquina com pelo menos 16 GiB de RAM e 8 CPUs lógicas, cria o perfil de referência com 8 GB de memória, 4 CPUs, 2 GB de swap, rede mirrored, DNS tunneling e WSLg habilitado. Registra a tarefa oculta `ArchWSLKeepAlive` no logon para manter os serviços do Arch disponíveis aos aplicativos Windows. Também chama `windows/setup-apps.ps1`, `windows/setup-terminal.ps1` e `windows/setup-desktop.ps1` e instala o runner Windows em `%LOCALAPPDATA%\dotfiles-wsl-arch`.
2. Na primeira inicialização do Arch, crie um usuário normal com `sudo`, configure-o como padrão em `/etc/wsl.conf` e habilite systemd. Uma instalação já configurada é preservada.
3. Clone este repositório em `~/dev` **dentro do filesystem Linux**. No Arch, execute `bash wsl/install.sh --all`. O instalador aceita também `--base`, `--mise`, `--paru`, `--lazyvim`, `--vscode`, `--windows-runner`, `--android`, `--android-studio`, `--supabase`, `--agentmemory` e `--agents` para instalar uma parte por vez. Depois de `--base`, execute `wsl --shutdown` no Windows e abra o Arch novamente para aplicar `appendWindowsPath=false`. Se quiser manter o serviço acessível antes do próximo logon, execute `Start-ScheduledTask -TaskName ArchWSLKeepAlive` no PowerShell.

O perfil de referência está em [windows/.wslconfig](windows/.wslconfig). Ele reserva até 8 GB para o WSL; ajuste esse limite conforme a memória da máquina, o projeto Android e os serviços Supabase usados. O instalador não substitui uma configuração WSL existente automaticamente.
O `autoMemoryReclaim` não é sobrescrito, para manter o comportamento padrão do WSL instalado.

### Primeira instalação, passo a passo

O checkout usado no Windows precisa conter a pasta `windows/` completa: `setup.ps1` chama outros scripts dessa pasta. A instalação inicial da distribuição pode exigir PowerShell elevado. No Windows:

~~~powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup.ps1
adb start-server
wsl -d archlinux
~~~

Se o Arch abrir como root na primeira execução, instale `sudo`, crie um usuário normal e conceda a ele acesso pelo grupo `wheel`. Configure esse usuário como padrão e `systemd=true` em `/etc/wsl.conf`, preservando outras seções que já existam:

~~~bash
pacman -Syu --needed sudo vim
useradd -m -G wheel -s /bin/bash SEU_USUARIO
passwd SEU_USUARIO
EDITOR=vim visudo
~~~

No `visudo`, habilite a regra `%wheel ALL=(ALL:ALL) ALL`. Se o usuário já existir, apenas confirme o grupo `wheel` e a permissão `sudo` antes de prosseguir. Antes de executar `--all` no Arch, confirme que `adb start-server` foi executado no Windows: a etapa Android consulta essa ponte durante a instalação, mesmo sem um telefone conectado.

~~~ini
[boot]
systemd=true

[user]
default=SEU_USUARIO
~~~

Depois execute `wsl --shutdown` no Windows e abra o Arch novamente. Clone o repositório em `~/dev` no filesystem Linux, entre no checkout e execute `bash wsl/install.sh --all` como usuário normal. A etapa base adiciona `appendWindowsPath=false` em `/etc/wsl.conf`; aplique essa alteração com outro `wsl --shutdown`. Abra uma nova sessão Arch para receber o grupo `docker` e o Zsh como shell padrão.

| Etapa do Arch | O que executa |
| --- | --- |
| `--base` | Toolchains, linguagens com mise, bibliotecas Linux, Docker, shell, ambiente e isolamento do `PATH` Windows |
| `--mise` | mise e usage do Arch; Node.js, Ruby, Kotlin, Python e uv estáveis mais recentes; pip e integração Zsh; requer os demais pré-requisitos da base |
| `--paru` | Gerenciador de pacotes do AUR |
| `--lazyvim` | Neovim e template oficial LazyVim |
| `--vscode` | Launcher oficial do VS Code Windows acessível pelo Arch, sem importar todo o `PATH` Windows |
| `--windows-runner` | Comandos `windows-sync` e `validate-windows` no `~/.local/bin` |
| `--android` | Android SDK Linux e cliente ADB para o servidor Windows |
| `--android-studio` | SDK, Paru se necessário, Android Studio Linux e lançador WSLg |
| `--supabase` | Supabase CLI no Arch |
| `--agentmemory` | Servidor AgentMemory e serviço systemd de usuário |
| `--agents` | OpenCode, Antigravity CLI, Codex e clientes AgentMemory no Arch |
| `--all` | Base (incluindo VS Code e runner), Paru, LazyVim, Android, Supabase, AgentMemory e agentes |

As etapas podem ser repetidas isoladamente, por exemplo `bash wsl/install.sh --android-studio`. O instalador recusa execução fora do Arch no WSL 2 ou como root e informa a etapa e a linha quando falha. `--all` inclui o mise e as bibliotecas de desenvolvimento e multimídia na base. Os scripts `cli-tools.sh`, `docker.sh` e `network.sh` atendem funções que já têm suas etapas principais ou servem a diagnóstico.

A tarefa `ArchWSLKeepAlive` executa [windows/keepalive.ps1](windows/keepalive.ps1), copiado pelo setup para `%LOCALAPPDATA%\dotfiles-wsl-arch`. Antes de manter o Arch ativo, verifica o modo gráfico do WSLg. Se detectar a falha de memória compartilhada associada a janelas vazias com `[WARN:COPY MODE]`, tenta recuperar a montagem interna e reinicia o WSL. Essa recuperação fecha as sessões WSL abertas. O procedimento trata o [problema relatado no WSLg](https://github.com/microsoft/wslg/issues/1456), sem acrescentar montagens ao `/etc/fstab` do Arch.

### Entradas Windows e ordem de execução

Execute os comandos abaixo na raiz do checkout Windows. O setup completo instala primeiro os aplicativos, depois o terminal e a toolchain desktop; ao final, copia o runner Windows e registra o keepalive.

| Comando PowerShell | Finalidade e opções |
| --- | --- |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup.ps1` | Setup completo do host; instala `archlinux` quando ausente. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup-apps.ps1` | Aplicativos, IDEs, .NET, runtimes, ferramentas de hardware e YouTube Music Desktop pelo winget. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup-terminal.ps1` | Terminal, fonte, Starship e cores. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup-desktop.ps1` | Compiladores e dependências nativas do target Windows. |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\keepalive.ps1 -RepairOnly` | Diagnóstico/reparo específico do WSLg, sem manter uma sessão permanente. |

Instalações de sistema e o bootstrap do Chocolatey podem pedir elevação. Use a conta Windows que utilizará o ambiente: configurações em `%USERPROFILE%`, `%APPDATA%` e `%LOCALAPPDATA%` pertencem a essa conta. O setup interrompe diante de uma falha; reaplique a etapa responsável após corrigir a mensagem. As instalações e downloads já concluídos não são desfeitos automaticamente.

### Estrutura do repositório e execução

| Arquivo | Responsabilidade |
| --- | --- |
| `AGENTS.md` | Regras para alterações no repositório: compatibilidade WSL 2, verificação antes de commit e Bash em LF. |
| `.gitattributes` | Normalização em LF; arquivos `*.ps1` em CRLF no checkout. |
| `README.md` | Instalação, operação, manutenção e referência das configurações. |
| `windows/setup.ps1` | Entrada Windows, recursos WSL, sequência de instalação, tarefa de logon e cópia do runner. |
| `windows/versions.psd1` | Catálogo de IDs winget/Store, incluindo ADB e Painel de Controle NVIDIA; mínimo Node, GStreamer fixado e CUDA legado por compatibilidade. |
| `windows/setup-apps.ps1` | Aplicativos Windows e IDEs; Chocolatey, .NET, runtimes e componentes Intel/NVIDIA. |
| `windows/.wslconfig` | Modelo de recursos, rede mirrored, DNS tunneling e WSLg. |
| `windows/setup-desktop.ps1` | Dependências de compilação e execução do target desktop Windows. |
| `windows/setup-terminal.ps1` | Instala e aplica o terminal, a fonte e o perfil PowerShell. |
| `windows/terminal/settings.json` | Perfis, fonte, paleta ANSI e atalhos do Windows Terminal. |
| `windows/terminal/profile.ps1` | Starship e realce de parâmetros do PSReadLine. |
| `windows/keepalive.ps1` | Verifica a falha conhecida do WSLg e mantém o Arch ativo. |
| `windows/validate-project.ps1` | Espelha fontes Linux e chama a validação específica do projeto no Windows. |
| `wsl/install.sh` | Entrada Arch; sem argumentos equivale a `--all`. |
| `wsl/.zshrc` | Plugins, aliases e ativação de mise/Starship. |
| `wsl/.gitconfig` | Preferências e aliases Git do usuário. |
| `wsl/gtk-3.0/settings.ini` | Tema e botões GTK usados pelo Android Studio. |
| `wsl/tools/env.sh` | Ambiente compartilhado pelos shells Linux. |
| `wsl/tools/configure-shell.sh` | Oh My Zsh, plugins, locale, arquivos de inicialização e shell padrão. |
| `wsl/tools/mise.sh` e `wsl/tools/mise.toml` | Instalação e seleção global das linguagens e uv. |
| `wsl/tools/interop.sh` | Desativa a importação automática do PATH Windows. |
| `wsl/tools/vscode-wsl.sh` | Link para o launcher oficial do VS Code Windows no Arch. |
| `wsl/tools/windows-validation.sh` | Instala e executa `windows-sync` e `validate-windows`. |
| `wsl/tools/android-sdk.sh` | Command-line Tools, licenças, API, Build Tools e Platform Tools Linux. |
| `wsl/tools/android.sh` e `wsl/tools/adb-client` | Instalação e implementação do cliente da ponte ADB TCP. |
| `wsl/tools/android-studio.sh` | IDE Linux, Wayland/GTK, launcher e entrada de aplicativo WSLg. |
| `wsl/tools/android-smoke.sh` | Compila um APK Kotlin temporário e limpa o projeto ao terminar. |
| `wsl/tools/paru.sh` e `wsl/tools/paru.conf` | Bootstrap do Paru e preferência `BottomUp`. |
| `wsl/tools/lazyvim.sh` | Pacotes do Neovim e template oficial LazyVim Starter. |
| `wsl/tools/supabase.sh` | Binário Supabase Linux com versão e SHA-256 declarados. |
| `wsl/tools/agentmemory.sh` | Servidor único, diretório de dados e unidade systemd de usuário. |
| `wsl/tools/ai-agents.sh` | Agentes Linux e integrações oficiais com AgentMemory. |
| `wsl/tools/docker.sh` | Instalação isolada do Docker; não é chamado por `--all` porque a base já cobre essa etapa. |
| `wsl/tools/network.sh` | Consulta rede, PID 1 e DNS; não muda a configuração. |
| `wsl/tools/cli-tools.sh` | Rotina antiga e alternativa de CLIs; não integra `--all`. Prefira `--base` e `--agents`: essa rotina inclui instaladores anteriores, fzf em `~/.fzf` e tolera falhas dos instaladores de agentes. |

Execute os instaladores a partir do checkout correspondente: `windows/setup.ps1` no Windows e `wsl/install.sh` em uma cópia dentro do Arch. Uma alteração versionada só passa a valer quando sua etapa a aplica ao arquivo instalado. Não há sincronização automática de versões entre plataformas. Os scripts antigos e auxiliares da tabela não são uma segunda sequência necessária de instalação.

### Diretórios, cópias e arquivos preservados

| Destino | Como é criado ou atualizado |
| --- | --- |
| `%USERPROFILE%\.wslconfig` | Criado somente se ausente e se o hardware atender ao perfil; um arquivo existente é preservado. |
| `%LOCALAPPDATA%\dotfiles-wsl-arch` | Recebe cópias de `keepalive.ps1`, `validate-project.ps1`, `profile.ps1` por suas etapas. |
| Configuração do Terminal em `%LOCALAPPDATA%` | Modelo completo substitui o conteúdo, com primeiro backup `settings.json.bak` quando diferente. |
| `%APPDATA%\Code\User\settings.json` | O setup de aplicativos acrescenta a execução Codex em WSL, preservando as demais propriedades JSON. JSON com comentários que não puder ser lido é preservado e pede edição manual. A mudança pode exigir recarregar o VS Code. |
| `~/.config/dotfiles-wsl-arch/env.sh` | Cópia reaplicada por `configure-shell.sh`. |
| `~/.zshenv` e `~/.bash_profile` | Recebem uma linha de carregamento do ambiente quando ausente. |
| `~/.zshrc` e `~/.gitconfig` | Modelo copiado somente se ausente; a ativação mise é acrescentada ao Zsh existente quando necessária. |
| `~/.config/mise/config.toml` | Modelo global reaplicado, com primeiro backup quando diferente. |
| `~/.config/paru/paru.conf` | Criado somente se ausente. |
| `~/.config/nvim` | Starter instalado se ainda não reconhecido; os quatro diretórios Neovim anteriores são movidos para `.bak`. |
| `~/.config/gtk-3.0/settings.ini` | Modelo reaplicado com primeiro backup; o layout também é salvo no dconf por `gsettings`. |
| `~/.config/Google/<dataDirectoryName>/studio64.vmoptions` | A etapa da IDE ajusta somente as propriedades de toolkit e decoração. |
| `~/.local/share/applications/<app_id>.desktop` e `/usr/local/share/applications/<app_id>.desktop` | Entradas geradas do Android Studio para a versão instalada. |
| `~/.agentmemory/.env` e `~/.config/systemd/user/agentmemory.service` | Criados somente se ausentes; alterações posteriores são preservadas. |
| `~/.local/share/agentmemory` | Dados persistentes; reinstalar o CLI não recria nem limpa essa base. |
| `C:\Dev\.targets\<projeto>-win` | Target de validação; contém marcador de origem e cópia `workspace`. |

Os backups são locais e não fazem parte do versionamento. Os backups temporários da migração asdf → mise já foram removidos a pedido do usuário; as regras de preservação dos instaladores continuam válidas para futuras substituições. Não há rollback automático de uma instalação completa.

## Onde cada ferramenta roda

### Configuração do ambiente Arch

A etapa `--base` atualiza o sistema com `pacman -Syu` e instala Git; Docker Engine, Compose e Buildx; Node.js LTS, npm, pnpm e Yarn; Rust/Cargo; OpenJDK 17 e 21, Kotlin e Gradle; Python, pip e virtualenv; Ruby, Bundler e sua biblioteca padrão; `android-tools`; `base-devel`, unzip e bibliotecas de compilação; Zsh, Starship, curl, wget, ripgrep, jq, fzf, zoxide e GitHub CLI. Também instala CMake, Ninja, LLVM/Clang, FFmpeg/FFprobe e GStreamer com GES e plugins. Essas ferramentas fazem parte do ambiente completo do Arch. O JDK 17 é o `JAVA_HOME` padrão em `env.sh`; o JDK 21 está disponível para projetos que o exigem. `wget` é necessário para o download inicial do VS Code Server pela extensão WSL. O `--base` cria `~/dev` e `~/.local/bin`.

### Linguagens com mise e ambiente Python

O [instalador do mise](wsl/tools/mise.sh) usa os pacotes oficiais `mise` e `usage` do Arch. Copia [mise.toml](wsl/tools/mise.toml) para `~/.config/mise/config.toml`, preservando uma configuração anterior diferente em `config.toml.bak` na primeira substituição. A configuração seleciona `latest` para Node.js, Ruby, Kotlin, Python e uv: cada nova instalação resolve as versões estáveis disponíveis, sem fixar números neste repositório. O Python é o CPython convencional, com GIL; o projeto Python não oferece uma edição denominada LTS. Ele usa a distribuição pré-compilada suportada pelo mise (`python.compile=false`) e recebe pip com `ensurepip`, seguido da atualização do pip.

Os executáveis gerenciados ficam em `~/.local/share/mise/installs`. O Zsh carrega `eval "$(mise activate zsh)"`; sessões sem interação usam os shims de `~/.local/share/mise/shims`, incluídos pelo ambiente compartilhado. O pacote `usage` atende à conclusão dos comandos do mise. O Python e as demais linguagens fornecidas pelo pacman continuam disponíveis em `/usr/bin` para as dependências do Arch; a sessão de desenvolvimento seleciona as instalações do mise. Instale dependências de projetos Python em ambientes virtuais, preservando os pacotes Python do sistema.

O uv também é instalado pelo mise. `UV_PYTHON_PREFERENCE=only-system` faz o uv descobrir os interpretadores disponíveis no `PATH`, incluindo o Python selecionado pelo mise; na terminologia do uv, instalações de outros gerenciadores também são consideradas “system”. `UV_PYTHON_DOWNLOADS=never` evita que o uv baixe uma segunda instalação de Python. A seleção de ambientes virtuais permanece no comportamento padrão do uv, sem impor um `UV_PYTHON` global. Para resolver as seleções globais estáveis disponíveis e reaplicar a integração do shell, execute:

~~~bash
bash wsl/install.sh --mise
mise ls
mise doctor
~~~

Abra uma nova sessão Arch após a configuração. Para selecionar uma versão por projeto, use, por exemplo, `mise use python@3.14` dentro do projeto e versione o `mise.toml` que esse comando cria. `mise install` instala as ferramentas declaradas pelo projeto; `mise exec -- python --version` executa um comando nesse ambiente. Revise e confie apenas em configurações de projetos conhecidos quando o mise solicitar isso.

Para iniciar um projeto Python com um ambiente isolado e pip disponível:

~~~bash
uv venv --seed .venv
source .venv/bin/activate
python -m pip --version
uv pip install NOME_DO_PACOTE
deactivate
~~~

Em projetos que já usam uv, prefira `uv sync` e `uv run`, respeitando `pyproject.toml` e `uv.lock`. Uma exigência de Python diferente deve ser atendida pelo mise. A configuração global não cria ambientes nem altera manifests de projetos automaticamente.

O bootstrap roda em um diretório temporário para que a configuração de um projeto não altere suas seleções globais. `jobs=2` limita instalações simultâneas; `MAKE_OPTS` usa `-j2` por padrão para etapas que compilam. A configuração em `wsl/tools/mise.toml` é a referência global do repositório: uma personalização local nesse arquivo será substituída ao reaplicar a etapa. Para personalizações de projeto, mantenha um `mise.toml` no próprio projeto.

As instalações do mise são independentes das instalações do asdf, conforme a [orientação oficial de migração](https://mise.jdx.dev/dev-tools/comparison-to-asdf.html). Arquivos `.tool-versions` de projetos continuam sendo reconhecidos pelo mise. Consulte também a [instalação oficial](https://mise.jdx.dev/getting-started.html) e a [integração de Python e uv](https://mise.jdx.dev/lang/python.html).

### Bibliotecas e ferramentas nativas Linux

| Componente no Arch | Instalação e configuração |
| --- | --- |
| CMake, Ninja e LLVM/Clang | Pacotes `cmake`, `ninja`, `llvm` e `clang`; `LIBCLANG_PATH=/usr/lib` aponta para `libclang.so`, usada por bindgen/whisper-rs. |
| FFmpeg e FFprobe | Pacote `ffmpeg`, com os dois executáveis Linux no `PATH`. |
| GStreamer e GES | `gstreamer`, `gst-editing-services`, `gst-plugins-base`, `gst-plugins-good`, `gst-plugins-bad`, `gst-plugins-ugly` e `gst-libav`; os pacotes incluem runtime, cabeçalhos e arquivos pkg-config. |
| Plugins gráficos e áudio | `glshader` para OpenGL; `pitch` com a biblioteca `soundtouch`; `pulsesink` para o servidor de áudio do WSLg. |
| Python e Ruby | Python, pip, uv e Ruby selecionados pelo mise; dependências de projeto ficam em ambientes virtuais e nos manifests/lockfiles de cada projeto. |

O instalador verifica o carregamento de `libclang.so`, os módulos pkg-config de GStreamer/GL/GES e a existência de `glshader`, `pitch` e `pulsesink`. No Windows, o setup separado instala MSVC x64, WebView2, DLLs e `wasapi2sink`. Os builds Linux usam executáveis ELF e bibliotecas `.so` do Arch; as configurações WSLg fornecidas pelo WSL cuidam dos displays e do áudio.

Para reaplicar todos esses componentes no Arch, execute `bash wsl/install.sh --base`. A seção de mise acima descreve o uso de Python e uv; `python -m venv .venv` também cria um ambiente com o Python selecionado. Projetos Rust encontram GStreamer/GES por pkg-config. O launcher Android mantém o cliente ADB Linux apontando para o servidor Windows.

`wsl/tools/configure-shell.sh` instala Oh My Zsh e os plugins `zsh-autosuggestions` e `zsh-syntax-highlighting`, confirma que o Starship está instalado, define Zsh como shell padrão, gera `en_US.UTF-8` e copia `wsl/tools/env.sh` para `~/.config/dotfiles-wsl-arch/env.sh`. O ambiente é carregado por `~/.zshenv` e `~/.bash_profile`, inclusive quando a sessão abre por um lançador. O arquivo exporta `ANDROID_HOME`, `ANDROID_SDK_ROOT`, `JAVA_HOME`, `ADB_SERVER_SOCKET`, `AGENTMEMORY_URL` e `LIBCLANG_PATH`, além de acrescentar `~/.local/bin`, os shims do mise e as ferramentas do SDK ao `PATH`. A ativação do mise é acrescentada ao `.zshrc` existente quando ausente.

O instalador só copia `wsl/.zshrc` e `wsl/.gitconfig` quando esses arquivos não existem. Para adotar o Starship e os aliases versionados em uma conta Arch já configurada, compare seu `~/.zshrc` com [wsl/.zshrc](wsl/.zshrc): desative o tema do Oh My Zsh com `ZSH_THEME=""` e adicione `eval "$(starship init zsh)"` ao final. O Oh My Zsh continua oferecendo plugins de Git, Docker, Zoxide e Arch Linux. O Git versionado configura `autocrlf=input`, `pull.rebase=true` e outros atalhos; revise o nome e o email em `wsl/.gitconfig` antes de criar commits. Após trocar o shell, abra uma nova sessão e confirme com `echo $SHELL`.

### Distribuição por plataforma

| Windows | Arch WSL 2 |
| --- | --- |
| VS Code GUI, WSLg e outras interfaces nativas | VS Code Server e Android Studio Linux; repositórios e builds em `~/dev` |
| ADB server e conexão USB com o dispositivo | Cliente ADB apontando para `127.0.0.1:5037` |
| Rust MSVC, .NET SDK e ferramentas nativas Windows | JDK 17/21, Kotlin, Gradle e Android SDK Linux |
| Aplicativos pessoais e utilitários de hardware | Docker Engine/Compose, Supabase CLI e servidor AgentMemory |
| Tarefa `ArchWSLKeepAlive` no logon e .NET SDK para targets Windows | OpenCode, Antigravity CLI (`agy`) e Codex CLI |

### Shell, Paru e LazyVim

O script de base adiciona o usuário Arch ao grupo `docker`, habilita o serviço Docker e configura o Zsh como shell padrão. Ele instala o [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh#unattended-install) para os plugins externos listados no `.zshrc` versionado e o [Starship](https://starship.rs/guide/) pelo repositório oficial do Arch; o `.zshrc` existente é preservado. Também gera `en_US.UTF-8` para os símbolos do prompt, sem alterar o idioma padrão do sistema. Abra uma nova sessão para usar Docker sem `sudo` e iniciar no Zsh. O diretório `~/dev` fica no ext4 da distribuição; evite builds Gradle e volumes Docker em `/mnt/c`.

O Paru é compilado do pacote estável `paru` no AUR durante `--all` ou `--paru`, conforme as [instruções do projeto](https://github.com/Morganamilo/paru#installation). A configuração de usuário em `~/.config/paru/paru.conf` ativa `BottomUp` para mostrar resultados do AUR primeiro; uma configuração existente é preservada. O `.zshrc` ativa a conclusão automática fornecida pelo pacote. Use `paru -S <pacote>` para instalar e `paru -Syu` para atualizar pacotes dos repositórios e do AUR.

O LazyVim segue a [instalação oficial](https://www.lazyvim.org/installation): `--all` ou `--lazyvim` instala Neovim e os pré-requisitos no Arch, faz backup dos diretórios Neovim existentes com sufixo `.bak`, clona `LazyVim/starter` em `~/.config/nvim` e remove o `.git` do template. Abra `nvim` para instalar os plugins e execute `:LazyHealth` para conferir a instalação. Um Nerd Font no terminal é opcional para exibir os ícones.

### Shell, aliases e Git

Os comandos do `wsl/.zshrc` são recursos de uma sessão interativa Zsh. O Bash e processos de serviço não recebem esses aliases.

| Grupo | Aliases versionados |
| --- | --- |
| Navegação | `cls` limpa; `ll` lista detalhes; `la` inclui ocultos; `..`, `...` e `....` sobem diretórios; `mkd` cria diretórios. |
| Pacman | `pacin` instala; `pacrem` remove com `-Rns`; `pacup` atualiza com `-Syu`; `pacsearch` consulta. |
| Git no shell | `gs` status; `ga` add; `gc` commit; `gp` push; `gl` pull; `gd` diff; `gco` checkout; `gb` branch; `glog` histórico gráfico. |
| Docker | `dps` lista containers; `dcp` Compose; `dcu` sobe em background; `dcd` derruba a pilha; `dcl` acompanha logs. |
| Ambiente | `ports` consulta sockets; `myip` consulta IP público em ifconfig.me; `reload` troca o processo atual por novo Zsh; `dotfiles` entra em `~/.dotfiles`, que precisa corresponder ao local escolhido para o checkout. |
| Memória | `mem` chama AgentMemory; `memstatus` consulta saúde; `memviewer` mostra a URL do viewer; `memlog` acompanha journal; `memrestart` reinicia a unidade de usuário. |

O template Git define `main` como branch inicial, `code --wait` como editor, `less -FRX` como pager, `autocrlf=input`, pull com rebase, configuração automática de upstream no push, conflitos `diff3` e realce de linhas movidas. Revise a identidade pessoal antes de copiar o arquivo para outra pessoa.

Os aliases internos do Git são `st`, `co`, `br`, `ci`, `lg`, `last`, `unstage`, `amend`, `undo` e `wip`. `git amend` altera o último commit; `git undo` executa `reset --soft HEAD~1`; `git wip` adiciona toda a árvore com `git add -A` e cria um commit. Use-os quando essas operações forem desejadas.

O Paru recebe conclusão pelo pacote do Arch e pelo plugin `archlinux` do Oh My Zsh. O LazyVim exige Neovim ≥ 0.11.2; seu instalador inclui `neovim git gcc tree-sitter-cli curl fzf ripgrep fd lazygit`. Uma instalação reconhecida de LazyVim é preservada. Para trocar o starter, os diretórios de configuração, dados, estado e cache só são movidos quando seus backups `.bak` não estiverem ocupados.

### Variáveis de ambiente e escolha de executáveis

| Variável | Valor/papel no Arch |
| --- | --- |
| `ANDROID_HOME` e `ANDROID_SDK_ROOT` | `~/Android/Sdk`. |
| `JAVA_HOME` | `/usr/lib/jvm/java-17-openjdk`; o Zsh tem fallback para `default-runtime` se esse diretório não existir. |
| `ADB_SERVER_SOCKET` | `tcp:127.0.0.1:5037`, servidor no Windows. |
| `AGENTMEMORY_URL` | `http://127.0.0.1:3111`. |
| `LIBCLANG_PATH` | `/usr/lib`, contendo a biblioteca Linux `libclang.so`. |
| `UV_PYTHON_DOWNLOADS` | `never`, aplicado pelo mise. |
| `UV_PYTHON_PREFERENCE` | `only-system`, aplicado pelo mise; inclui o Python disponibilizado por ele no PATH. |
| `WINDOWS_VALIDATION_ROOT` | Opcional: caminho Windows para outra pasta `.targets`; só é lido pelo launcher de validação. |
| `XDG_CONFIG_HOME` | Respeitado por mise, Paru e GTK nos pontos indicados nos scripts; vários outros caminhos usam explicitamente `~/.config`. |
| `MAKE_OPTS` | Opcional no bootstrap mise; padrão `-j2`. |

O ambiente compartilhado põe `~/.local/bin` e os shims mise antes das ferramentas do SDK/JDK e do PATH recebido. A ativação interativa do mise acrescenta os runtimes selecionados. O cliente `/usr/local/bin/adb` usa explicitamente `/usr/bin/adb`. Para conferir uma seleção, use `command -v python`, `command -v node` e `mise which python` no Arch; no Windows, use `Get-Command <comando> -All`. Variáveis de uma plataforma não são copiadas para a outra.

### Windows Terminal e Starship

O [setup do Windows Terminal](windows/setup-terminal.ps1), chamado por `windows/setup.ps1`, instala o [Starship](https://starship.rs/guide/) pelo winget e ativa o prompt no perfil PowerShell do Terminal. Instala também a CaskaydiaCove Nerd Font caso esteja ausente; nesse caso, usa o instalador de fontes do Oh My Posh apenas para obter a fonte, sem iniciar o prompt do Oh My Posh. O [settings.json versionado](windows/terminal/settings.json) define `CaskaydiaCove NFM` e o esquema `iTerm2 Solarized Dark` como padrões em todos os perfis, incluindo o Arch WSL; o [script PowerShell](windows/terminal/profile.ps1) guarda a inicialização do Starship e é copiado para `%LOCALAPPDATA%\dotfiles-wsl-arch`. Uma configuração `settings.json` anterior recebe backup `.bak` antes da primeira substituição. Para reaplicar apenas essa parte, execute `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup-terminal.ps1`.

O Terminal abre por padrão no Windows PowerShell, com fundo Solarized Dark `#002b36` e texto `#839496`. O esquema também define as 16 cores ANSI, seleção e cursor no JSON versionado. A cor ANSI `brightBlack` usa `#839496` para manter legíveis os operadores e outros trechos antes invisíveis sobre o fundo.

O caminho do Starship mantém o estilo padrão `cyan bold`: `brightCyan` usa azul-ciano claro `#66d9ef`, aplicado tanto ao PowerShell quanto ao Zsh no Windows Terminal. O perfil PowerShell configura os parâmetros do PSReadLine em `#56b6c2`, um tom próximo e um pouco mais escuro, distinguindo opções como `--help` da saída comum. O cursor e `brightGreen` usam o verde Solarized `#859900`; assim o símbolo padrão `❯` do Starship, configurado como `bold green`, aparece verde também no Zsh do Arch.

Alterações de paleta são carregadas pelo Terminal; abra uma nova aba PowerShell para carregar o realce do perfil atualizado. Os atalhos incluem `Ctrl+C` para copiar, `Ctrl+V` para colar, `Ctrl+Shift+F` para buscar e `Alt+Shift+D` para dividir o painel. A fonte Nerd Font torna visíveis os símbolos usados pelo Starship no PowerShell e no Zsh do Arch.


## VS Code: interface Windows, workspace Arch

O setup Windows instala a versão estável do VS Code e a [extensão WSL](https://code.visualstudio.com/docs/remote/wsl) quando estiverem ausentes. O Windows mantém a interface gráfica; o `--base` instala no Arch um link `~/.local/bin/code` para o launcher oficial do VS Code Windows, localizado com `where code` via interoperabilidade WSL. Isso preserva `appendWindowsPath=false` e não instala outra GUI do VS Code no Linux. O launcher já existente no Arch é preservado.

Dentro do Arch, abra o projeto principal com `cd ~/dev/meu-projeto && code .`. Na primeira abertura, a extensão baixa o VS Code Server para `~/.vscode-server`; `wget` está incluído no instalador para essa etapa. Confira **WSL: archlinux** no canto inferior esquerdo. O terminal integrado, Git, depuradores, language servers e extensões ligadas ao workspace passam a operar no Arch. Instale as extensões de linguagem necessárias no contexto **WSL: archlinux**; temas e extensões de interface podem continuar no Windows. De um terminal Windows, use `code --remote wsl+archlinux /home/SEU_USUARIO/dev/meu-projeto`. A [documentação oficial](https://code.visualstudio.com/docs/remote/wsl) descreve ambos os caminhos.

## Monorepos e validação Windows

O único checkout de desenvolvimento fica em `~/dev/<projeto>` no ext4 do Arch. Android, backend, web, Supabase, agentes e código compartilhado usam esse checkout. O Windows recebe uma cópia descartável da árvore de fontes em `C:\Dev\.targets\<projeto>-win\workspace` somente para validar Tauri, Electron e testes específicos do Windows. Não edite essa cópia: a sincronização espelha o estado atual do Arch, inclusive arquivos ainda não commitados, e remove arquivos de fonte que desapareceram. Ela não depende de dois clones Git nem de copiar arquivos manualmente.

No Arch, após instalar as duas plataformas:

~~~bash
cd ~/dev/meu-projeto
windows-sync
validate-windows
~~~

`windows-sync` apenas atualiza o target. `validate-windows` sincroniza e chama `scripts/validate-windows.ps1` do próprio projeto no PowerShell Windows; o código de saída do build ou teste retorna ao comando Arch e ao agente. Os comandos aceitam opcionalmente o caminho do projeto, por exemplo `validate-windows ~/dev/meu-projeto`. Se executados em um subdiretório Git, usam a raiz do repositório. O projeto precisa estar diretamente abaixo de `~/dev` e ter nome simples com letras ASCII, números, ponto, hífen ou sublinhado.

Cada projeto define seus comandos Windows no arquivo `~/dev/meu-projeto/scripts/validate-windows.ps1`. Exemplo para um projeto cujos scripts npm já implementem testes e build Windows:

~~~powershell
$ErrorActionPreference = 'Stop'
Set-Location $env:WINDOWS_VALIDATION_WORKSPACE
& npm.cmd ci
if ($LASTEXITCODE -ne 0) { throw 'npm ci falhou' }
& npm.cmd run test:windows
if ($LASTEXITCODE -ne 0) { throw 'testes Windows falharam' }
& npm.cmd run build:windows
if ($LASTEXITCODE -ne 0) { throw 'build Windows falhou' }
~~~

Adapte o arquivo para pnpm, Tauri, Electron, .NET ou outras tarefas reais do projeto. O runner falha com mensagem clara se esse arquivo não existir. O [runner versionado](windows/validate-project.ps1) usa `robocopy /MIR`, trata os códigos de retorno documentados pela [Microsoft](https://learn.microsoft.com/windows-server/administration/windows-commands/robocopy/) e rejeita targets existentes sem um marcador que os associe ao projeto de origem. Ele exclui `.git` e diretórios de dependências/artefatos, entre eles `node_modules`, `target`, `.gradle`, `dist`, `build`, `coverage` e caches de frameworks. Esses diretórios permanecem próprios de cada plataforma. O processo Windows prioriza o GStreamer MSVC x64, LLVM e o CUDA indicado por `CUDA_PATH` (usuário antes de máquina) no `PATH`, mesmo quando outra ferramenta homônima aparece antes no `PATH` global.

O target padrão é `C:\Dev\.targets`. Para outra unidade local, defina `WINDOWS_VALIDATION_ROOT` no Arch com um caminho Windows que termine em `\.targets`. O runner rejeita caminhos inesperados, junções no target e uma cópia associada a outro projeto. Não compile no caminho `\\wsl.localhost\...`: esse UNC é apenas a origem da cópia. Não execute builds Linux pesados em `/mnt/c`.

## Android e ADB

### Ponte ADB por TCP

O [Android SDK Platform Tools](https://developer.android.com/tools/releases/platform-tools) fornece o ADB Windows. O `windows/setup-apps.ps1`, chamado pelo setup principal, procura `adb.exe` no PATH. Se ele já existir, reaproveita essa instalação; se estiver ausente, instala `Google.PlatformTools` pelo winget, recarrega o PATH e interrompe com mensagem de erro caso o executável continue indisponível. O pacote é instalado na versão disponível no catálogo, sem fixar número. O setup Windows assegura as Platform Tools; o SDK Android completo fica no Arch.

Para instalar somente as Platform Tools em um Windows sem ADB, execute:

~~~powershell
winget install --id Google.PlatformTools --exact --source winget --accept-source-agreements --accept-package-agreements
~~~

Abra um novo PowerShell após a instalação. Conecte o telefone por USB ao Windows, habilite a depuração USB nas opções de desenvolvedor e aceite a autorização RSA no aparelho. Drivers USB específicos do fabricante, quando necessários, são instalados no Windows. Confira o caminho selecionado e inicie o servidor:

~~~powershell
Get-Command adb.exe -All
adb version
adb start-server
adb devices -l
~~~

Na instalação preservada desta máquina, o executável está em `%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe`. Esse caminho não é imposto a instalações novas feitas pelo winget; o instalador verifica o comando no PATH. A [documentação do ADB](https://developer.android.com/tools/adb) descreve o servidor local e a autorização do dispositivo.

O início do servidor Windows é manual: execute `adb start-server` ao retomar o trabalho Android. Os dotfiles não registram tarefa de logon para o ADB; `ArchWSLKeepAlive` mantém o Arch ativo e cuida do reparo WSLg descrito acima. Para reiniciar o servidor ADB, execute `adb kill-server` e depois `adb start-server` no PowerShell.

No Arch, aplique `bash wsl/install.sh --android` para instalar o SDK Linux e o wrapper da ponte. O PATH coloca `/usr/local/bin/adb` antes do cliente original; ele chama `/usr/bin/adb -H 127.0.0.1 -P 5037`. O shell e o lançador Android Studio exportam `ADB_SERVER_SOCKET=tcp:127.0.0.1:5037`. Confira no terminal Arch:

~~~bash
command -v adb
printf '%s\n' "$ADB_SERVER_SOCKET"
adb devices -l
~~~

O telefone autorizado deve aparecer com o mesmo número de série no PowerShell e no Arch. `unauthorized` indica autorização pendente no aparelho; `offline` pede revisar conexão, cabo e servidor; uma lista vazia é normal quando nenhum aparelho está conectado. O USB permanece no Windows, e os clientes Linux usam a ponte TCP local. USBIPD não faz parte do setup.

Com `networkingMode=mirrored`, o loopback Windows/WSL permite usar o servidor ADB do Windows a partir do Arch; veja a [documentação de rede do WSL](https://learn.microsoft.com/windows/wsl/networking). Se o cliente Arch não alcançar o servidor, verifique primeiro se o servidor está ativo no Windows, se a configuração de rede mirrored foi aplicada com `wsl --shutdown` e se o firewall permite o tráfego local.

### Abrir o Android Studio Linux com WSLg

Para instalar IDE, SDK e ponte, use `bash wsl/install.sh --all`; para aplicar por partes, execute `--android` e depois `--android-studio`. A etapa `--android-studio` chama o SDK, mas não instala sozinha o wrapper ADB de `android.sh`. Após essas etapas, reinicie o Arch para aplicar as mudanças em shell e WSL, depois escolha uma das formas abaixo:

| Origem | Como abrir |
| --- | --- |
| Menu Iniciar do Windows | Procure por **Android Studio (Arch WSL)** e abra o atalho publicado pelo WSLg. Pode demorar alguns instantes até o menu atualizar após a instalação. |
| Terminal do Arch | Execute `android-studio-wsl`. |
| PowerShell do Windows | Execute `wsl.exe -d archlinux --exec bash -lc "android-studio-wsl"`. A janela gráfica aparece na área de trabalho Windows. |

O lançador configura `ANDROID_HOME` e `ANDROID_SDK_ROOT` para `~/Android/Sdk` e aponta ADB ao servidor Windows antes de iniciar `/usr/bin/android-studio`. Na primeira execução, conclua o assistente da IDE; escolha o SDK Linux já instalado e use um dispositivo físico conectado ao Windows para executar o app. O [guia oficial da Google](https://developer.android.com/studio/install) descreve o assistente, e a [documentação do WSLg](https://learn.microsoft.com/windows/wsl/tutorials/gui-apps) explica a integração de aplicativos Linux com o menu Iniciar.

Se aparecer uma janela vazia com `[WARN:COPY MODE]`, feche o Android Studio e execute `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\keepalive.ps1 -RepairOnly` no checkout Windows; essa recuperação pode encerrar sessões WSL abertas. Abra a IDE novamente. A opção `-RepairOnly` verifica e repara sem iniciar o processo permanente da tarefa do logon.

O projeto mantém o toolkit Wayland nativo e os controles de janela padrão. Em algumas posições, o menu da engrenagem da tela inicial pode ultrapassar a borda inferior da tela, inclusive com a janela maximizada. Não há plugin para alterar o posicionamento; mova ou restaure a janela para alcançar opções ocultas.

O Android SDK Linux é instalado em `~/Android/Sdk` com API 36, Build Tools 36.0.0 e Platform Tools. O download inicial das Command-line Tools usa `commandlinetools-linux-15859902_latest.zip` e valida o SHA-256 declarado em `android-sdk.sh`. O script aceita as licenças via `sdkmanager --licenses`. O SDK existente é reaproveitado; os pacotes declarados são assegurados a cada execução. Use `adb reverse tcp:<porta> tcp:<porta>` quando o app Android precisar alcançar um serviço local. O emulador Linux não faz parte desta configuração. O script do SDK respeita `ANDROID_HOME` recebido, mas o ambiente e o launcher da IDE padronizam `~/Android/Sdk`; para mudar esse local, ajuste todos esses pontos em conjunto.

O [instalador versionado](wsl/tools/android-studio.sh) verifica WSLg e o SDK, instala o [pacote estável `android-studio` do AUR](https://aur.archlinux.org/packages/android-studio) e bibliotecas gráficas, e grava `-Dawt.toolkit.name=WLToolkit` e `-Dsun.awt.wl.WindowDecorationStyle=gtk` nas opções de usuário da versão instalada. A JetBrains documenta a [seleção entre X11 e Wayland](https://blog.jetbrains.com/platform/2026/02/wayland-by-default-in-2026-1-eap/); seu runtime oferece [decorações GTK](https://github.com/JetBrains/JetBrainsRuntime/blob/main/src/java.desktop/unix/classes/sun/awt/wl/WLDecoratedPeer.java). GTK3 fornece o cabeçalho escuro, sem instalar outro gerenciador de janelas no Arch. O launcher usa `GTK_THEME=Adwaita:dark` quando essa variável não está definida.

O arquivo [settings.ini](wsl/gtk-3.0/settings.ini) é aplicado em `${XDG_CONFIG_HOME:-~/.config}/gtk-3.0/settings.ini`, com backup inicial `.bak` caso o conteúdo anterior seja diferente. Define tema Adwaita escuro e `gtk-decoration-layout=:minimize,maximize,close`. O instalador também grava `org.gnome.desktop.wm.preferences button-layout` com o mesmo layout por `gsettings`, pois essa preferência prevalece sobre o arquivo no backend Wayland. Isso afeta os aplicativos GTK do usuário que respeitam essa configuração. A [documentação GTK](https://docs.gtk.org/gtk3/property.Settings.gtk-decoration-layout.html) explica a ordem dos botões; dialogs podem oferecer apenas fechar, conforme as capacidades da janela. Reabra a IDE após reaplicar o instalador para carregar o layout.

A entrada de aplicativo é gravada como `jetbrains-studio.desktop` nos diretórios `~/.local/share/applications` e `/usr/local/share/applications` para o menu Iniciar. O nome acompanha o `startupWmClass` informado pelo pacote oficial em `product-info.json`, também usado em `StartupWMClass`; assim o WSLg associa a janela Wayland ao lançador. `Icon` aponta diretamente para o PNG oficial `/opt/android-studio/bin/studio.png`. Lançadores antigos `android-studio.desktop` criados por este instalador são movidos para `.bak`; o arquivo fornecido pelo pacote em `/usr/share/applications` é preservado. Reabra a IDE após aplicar essa correção para atualizar a associação do ícone na barra de tarefas.

O [WSLg registra problemas de posicionamento de popups](https://github.com/microsoft/wslg/issues/923), como o menu da engrenagem descrito acima.

### Testar o SDK e manter a IDE

~~~bash
bash wsl/tools/android-smoke.sh
~~~

O teste cria `~/dev/.android-smoke.*`, usa o Gradle disponível no Arch, Android Gradle Plugin 9.4.0, API 36 e uma Activity Kotlin mínima. Limita o Gradle a dois workers e 2 GiB de heap; o projeto e o APK temporários são removidos na saída, inclusive em caso de erro. Caches gerais do Gradle podem permanecer. Não precisa de telefone para compilar; o teste não valida instalação no aparelho.

Para atualizar o Android Studio, use `paru -Syu` e reaplique `bash wsl/install.sh --android-studio` para configurar o diretório da nova versão e o launcher. O instalador só chama o Paru para instalar os pacotes quando algum deles está ausente; ele não força a atualização da IDE já instalada. O conjunto gráfico inclui Mesa, libglvnd, libxkbcommon, GTK3, dconf, gsettings-desktop-schemas e DejaVu. A instalação automatizada da IDE usa `--noconfirm --skipreview`; consulte o PKGBUILD do AUR antes de executá-la quando precisar revisar as alterações do pacote.

## Aplicativos Windows

O [setup de aplicativos](windows/setup-apps.ps1), chamado pelo setup principal, mantém as interfaces e os programas de uso pessoal no Windows. Uma instalação nova consulta o catálogo estável; pacotes já instalados são preservados. Atualizar os programas existentes é uma operação separada, descrita em manutenção.

### Gerenciadores, fontes e repetição do setup

O winget automatiza os aplicativos tanto da fonte `winget` quanto da fonte `msstore`. A primeira consulta o catálogo comunitário de instaladores; a segunda consulta a Microsoft Store, conforme a [documentação das fontes do winget](https://learn.microsoft.com/windows/package-manager/winget/source). O Painel de Controle NVIDIA e o NVIDIA App usam `--source msstore` pelo mesmo gerenciador, sem exigir abrir a loja manualmente. Os demais aplicativos catalogados abaixo usam `--source winget`.

Os IDs e as condições de hardware ficam em `windows/versions.psd1`. Esse arquivo é um catálogo de instalação; os agentes Arch resolvem suas versões separadamente, sem sincronização com o Windows. A execução repetida de `setup-apps.ps1` preserva pacotes reconhecidos pelo winget. O Painel de Controle NVIDIA é detectado pelo pacote Appx da conta atual, o ADB pelo comando disponível e o AIO pelos runtimes Visual C++ já presentes nas arquiteturas x86/x64. O Chocolatey é instalado pelo bootstrap oficial apenas quando ausente e permanece disponível como gerenciador auxiliar.

### Aplicativos e condições de instalação

| Aplicativo | Instalação reproduzida |
| --- | --- |
| Bitwarden | `Bitwarden.Bitwarden` via winget; login e desbloqueio do cofre são feitos pelo usuário. |
| VS Code | `Microsoft.VisualStudioCode` e extensão `ms-vscode-remote.remote-wsl`. |
| IntelliJ IDEA | `JetBrains.IntelliJIDEA`; distribuição estável unificada com funcionalidades essenciais gratuitas. |
| .NET 10 SDK | `Microsoft.DotNet.SDK.10`; runtime isolado não substitui o SDK. |
| Visual C++ Redistributables AIO | `abbodi1406.vcredist`; repack comunitário dos runtimes Microsoft, incluindo famílias antigas. |
| Intel Driver & Support Assistant | `Intel.IntelDriverAndSupportAssistant` quando houver CPU Intel ou GPU Intel. |
| Painel de Controle NVIDIA | ID `9NF8H0H7WMLT` da Microsoft Store quando houver GPU NVIDIA; mantém o pacote existente e verifica sua presença após instalar. |
| NVIDIA App | ID `XP8CLZL93F5Z4P` da Microsoft Store quando houver GPU NVIDIA compatível; a MX110 está na exceção de hardware do catálogo. |
| NVIDIA CUDA Toolkit | `Nvidia.CUDA`, com seleção pela capacidade da GPU. |
| WinRAR | `RARLab.WinRAR`. |
| 7-Zip | `7zip.7zip`. |
| VLC | `VideoLAN.VLC`. |
| Chocolatey | Instalador oficial somente se o comando estiver ausente; a instalação padrão em `ProgramData` requer administrador. |
| Platform Tools | `Google.PlatformTools` quando o Windows ainda não disponibilizar `adb.exe`. |
| YouTube Music Desktop App | `Ytmdesktop.Ytmdesktop` via winget; cliente comunitário, mantido pelo projeto YTMDesktop. |

A [JetBrains unificou as distribuições](https://www.jetbrains.com/help/idea/installation-guide.html) a partir da linha 2025.3. O pacote antigo `JetBrains.IntelliJIDEA.Community` não é a escolha para obter os releases atuais. A IDE inclui seu runtime de execução; projetos Kotlin/Java WSL usam os JDKs e o Gradle do Arch. Abra projetos Linux com a integração WSL da IDE e confira o SDK e o Gradle JVM do projeto. O setup não escolhe automaticamente SDKs de todos os projetos nem instala outro JDK Windows para isso.

A política é instalar somente VS Code e IntelliJ como IDEs Windows. O Android Studio permanece no Arch, aberto por WSLg. Visual Studio **Build Tools** é a toolchain do compilador nativo e não acrescenta a IDE completa. O setup Windows não instala OpenCode, Gemini CLI, Antigravity CLI, AgentMemory ou iii-engine. O Codex Windows já ativo foi preservado por solicitação expressa; os fluxos novos de agentes usam o Arch.

Python/uv, JDKs de desenvolvimento, Gradle e SDK/NDK/emulador Android pertencem ao Arch. O Windows mantém `platform-tools` para o servidor ADB e os drivers USB necessários. O IntelliJ usa seu runtime Java incluído.

Git, Node/npm, Rust MSVC, .NET, Build Tools/Windows SDK, WebView2, FFmpeg/FFprobe, GStreamer, CMake, LLVM e llama-server continuam necessários para os builds Windows descritos abaixo. Os runtimes Visual C++ de gerações e arquiteturas diferentes atendem aplicativos distintos; não são duplicatas a apagar. Bitwarden, compactadores, VLC, YouTube Music e os utilitários de drivers fazem parte da seleção de aplicativos do usuário. O setup não reinstala Antigravity IDE, GlazeWM ou Zebar.

### Painel de Controle NVIDIA

O Painel de Controle NVIDIA é instalado pelo winget a partir da [página oficial na Microsoft Store](https://apps.microsoft.com/detail/9nf8h0h7wmlt?gl=BR&hl=pt-BR), sem fixar versão, quando uma GPU NVIDIA é detectada. O setup consulta `Get-AppxPackage -Name NVIDIACorp.NVIDIAControlPanel` na conta que executa o script e preserva a instalação existente. Essa etapa também atende à MX110, independentemente da exceção de compatibilidade do NVIDIA App. O driver gráfico NVIDIA deve estar instalado para usar o painel. Os ajustes gráficos pessoais continuam sendo feitos pelo usuário.

Para instalar o painel isoladamente e conferir o pacote:

~~~powershell
winget install --id 9NF8H0H7WMLT --exact --source msstore --accept-source-agreements --accept-package-agreements
Get-AppxPackage -Name NVIDIACorp.NVIDIAControlPanel | Select-Object Name, Version, Status
~~~

Abra **Painel de Controle da NVIDIA** pelo menu Iniciar. A execução de `windows/setup-apps.ps1`, também chamado pelo setup principal, reproduz essa instalação automaticamente.

### NVIDIA App, CUDA e drivers

O script identifica GPUs por `Win32_VideoController` e consulta `nvidia-smi --query-gpu=compute_cap`. O NVIDIA App é omitido quando todos os modelos NVIDIA encontrados estiverem na lista `NvidiaAppUnsupportedModels`; a MX110 foi recusada pelo instalador oficial com `CheckIfGPUIsSupported`, e não se força a instalação nesse hardware. GPUs com capacidade de 5.0 até abaixo de 7.5 usam o CUDA 12.9 declarado no catálogo; GPUs a partir de 7.5 usam o pacote estável do catálogo sem número fixado. Hardware anterior a Maxwell ou ausência de driver/consulta válida interrompe essa etapa com mensagem.

A MX110 desta máquina tem capacidade 5.0 (Maxwell). O CUDA 13 removeu compilação e bibliotecas para Maxwell, Pascal e Volta; a [matriz oficial](https://docs.nvidia.com/datacenter/tesla/drivers/latest/cuda-toolkit-driver-and-architecture-matrix.html) justifica usar 12.x nesse hardware. O instalador verifica `nvcc.exe` em `v12.9`, define `CUDA_PATH` do usuário para esse diretório e acrescenta seu `bin` ao PATH. A instalação legada seleciona os componentes `nvcc`, `cudart`, Thrust e as bibliotecas cuBLAS, cuFFT, cuRAND, cuSOLVER, cuSPARSE, NPP, nvJPEG, NVRTC, nvJitLink e NVTX, incluindo os pacotes de desenvolvimento declarados no catálogo. Usa a [seleção silenciosa oficial](https://docs.nvidia.com/cuda/archive/12.9.1/cuda-installation-guide-microsoft-windows/index.html#install-the-cuda-software) e omite `Display.Driver`, preservando o driver gráfico. Verifique também a compatibilidade da versão MSVC com o toolkit: encontrar `nvcc` não comprova a compilação de um projeto CUDA.

O driver é Windows. Instalar CUDA Windows não instala um compilador CUDA Linux no Arch. A [documentação CUDA no WSL](https://docs.nvidia.com/cuda/wsl-user-guide/index.html) exige hardware suportado e descreve suporte a partir de Pascal; a MX110 não permite presumir suporte oficial de computação CUDA no WSL. Não instale um driver NVIDIA Linux convencional dentro do WSL para tentar corrigir isso. O setup instala os utilitários Intel/NVIDIA; escolha e instalação de atualizações de drivers continuam nos aplicativos oficiais, sem atualização forçada pelo dotfiles.

### YouTube Music Desktop pelo winget

O setup instala a distribuição estável do [YTMDesktop](https://github.com/ytmdesktop/ytmdesktop), cliente comunitário do YouTube Music, e preserva uma instalação existente reconhecida pelo winget. Para aplicar isoladamente:

~~~powershell
winget install --id Ytmdesktop.Ytmdesktop --exact --source winget --accept-source-agreements --accept-package-agreements
winget list --id Ytmdesktop.Ytmdesktop --exact --source winget
~~~

Abra **YouTube Music Desktop App** pelo menu Iniciar e faça login na sua conta. A reprodução usa esse pacote desktop; a PWA e a confirmação de instalação do navegador deixaram de fazer parte do processo.

## Desktop Windows e AutoCut

Execute `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\windows\setup-desktop.ps1` para reaplicar apenas os pré-requisitos nativos. O script usa `winget` para os componentes disponíveis no catálogo, instala o pacote oficial do GStreamer com runtime e arquivos de desenvolvimento e valida os executáveis e bibliotecas necessários. É preciso reabrir o terminal após alterações no `PATH` de usuário.

| Componente | Uso e verificação |
| --- | --- |
| VS Code estável e extensão WSL | GUI no Windows e VS Code Server no Arch. O setup instala `Microsoft.VisualStudioCode` via winget se ausente e `ms-vscode-remote.remote-wsl` via CLI do VS Code. |
| Git, Node.js LTS ≥ 20.19 e npm | Instalação, build e testes do frontend. Confira com `git --version`, `node --version` e `npm --version`. |
| Rust via rustup | Toolchain estável `x86_64-pc-windows-msvc` e componente `rustfmt` para o backend Tauri. Confira com `rustup show` e `cargo fmt --version`. |
| Visual Studio Build Tools e WebView2 | Workload **Desktop development with C++** e runtime WebView2 exigidos pelo Tauri no Windows. O instalador usa o `vswhere` para validar a workload. |
| FFmpeg e FFprobe | Áudio, metadados, proxies e renderização. Confira com `ffmpeg -version` e `ffprobe -version`. |
| GStreamer MSVC x64 | Instalador oficial da versão declarada em `windows/versions.psd1` com `/TYPE=devel`: runtime, cabeçalhos, GES e plugins. O script verifica `glshader`, `pitch` e `wasapi2sink` com `gst-inspect-1.0` e adiciona o diretório `bin` ao `PATH` do usuário. |
| CMake e LLVM/Clang | Compilação do `whisper-rs`; `LIBCLANG_PATH` aponta para o diretório de `libclang.dll`. |
| `llama-server` | Servidor de IA local no `PATH`, usado quando a análise local está ativada. |

O GStreamer é um pacote MSVC x64 oficial específico; o instalador não supõe que toda distribuição do GStreamer contenha GES e esses plugins. Ele verifica o executável no diretório oficial da instalação. Se outra instalação de `gst-inspect-1.0` aparecer antes no PATH global, use o executável dentro de `GSTREAMER_1_0_ROOT_MSVC_X86_64`; o runner Windows prioriza esse pacote no processo de build. Os demais componentes também têm verificações próprias e mensagens de erro na instalação.

O setup de aplicativos fornece .NET 10 SDK e garante Platform Tools quando ADB estiver ausente. O Windows mantém o servidor ADB e o dispositivo USB; o Arch recebe o SDK Android Linux.

## Supabase local

O `--base` instala Docker Engine, Compose e Buildx no Arch e habilita o serviço `docker.service` via systemd. A conta do Arch entra no grupo `docker`, que só passa a valer em uma nova sessão. Verifique com `systemctl status docker`, `docker version` e `docker compose version`. O `wsl/tools/interop.sh` grava `appendWindowsPath=false` em `/etc/wsl.conf` para que executáveis Windows não substituam ferramentas Linux no `PATH`; aplique com `wsl --shutdown` no Windows. Se já existir uma seção `[interop]` incompatível, o instalador interrompe e pede revisão do arquivo.

`wsl/tools/supabase.sh` instala a versão e o hash SHA definidos no próprio script em `~/.local/bin/supabase`. A CLI usa o Docker da distribuição Arch; inicie o serviço antes de usar `supabase start`. O download com hash fixo torna a etapa reprodutível, enquanto a atualização da CLI exige mudar esses valores no script.

O CLI fica em `~/.local/bin/supabase`; o Docker roda no Arch. Para manter portas de desenvolvimento no loopback, crie uma vez a rede Docker:

```bash
docker network create -o com.docker.network.bridge.host_binding_ipv4=127.0.0.1 supabase-local-loopback
```

Em um projeto Supabase, use `supabase start --network-id supabase-local-loopback`. Use `--exclude` para serviços dispensáveis ao projeto ou aumente a memória do WSL para a pilha completa. Verifique os bindings com `docker ps`; somente portas necessárias devem ficar publicadas. Em um projeto novo, crie a configuração com `supabase init` antes de iniciar. Consulte `supabase status` para ver os endereços e credenciais locais e `docker ps` para conferir a saúde dos containers. Use `supabase stop` no diretório do projeto ao terminar. A tarefa Windows mantém o WSL ativo; não executa `supabase start` de todos os projetos. Volumes e políticas de reinício dos containers pertencem à pilha do projeto.

A rede `supabase-local-loopback` é uma convenção do procedimento, não um nome obrigatório detectado pelo instalador. Uma rede existente do projeto com o mesmo binding em `127.0.0.1` atende ao mesmo objetivo. O instalador da CLI não cria a rede, não inicializa projetos nem faz login no serviço hospedado. O binário declarado atualmente no script é `2.118.0`; para atualizá-lo, revise a versão, o nome do arquivo e o SHA-256 juntos.

## AgentMemory e agentes

### Servidor, dados e portas

`wsl/tools/agentmemory.sh` instala o pacote estável mais recente do AgentMemory em `~/.local`. O iii-engine é instalado como parte da dependência do pacote, em `~/.agentmemory/bin/iii`; não precisa de uma instalação separada no Windows. O script cria `~/.agentmemory/.env` apenas quando o arquivo ainda não existe, com `AGENTMEMORY_DATA_DIR`, `AGENTMEMORY_AGENT_SCOPE=shared` e `AGENTMEMORY_INJECT_CONTEXT=true`, e define permissão de leitura restrita ao usuário. Edite esse arquivo para configurar outros recursos do servidor. Os dados persistentes ficam em `~/.local/share/agentmemory`. A unidade `~/.config/systemd/user/agentmemory.service` é habilitada com `systemctl --user`; `loginctl enable-linger` mantém o serviço de usuário sem um terminal Arch aberto.

| Porta | Processo e finalidade |
| --- | --- |
| `3111` | API REST/MCP usada pelos clientes no Arch e no Windows; URL padrão desta configuração: `http://127.0.0.1:3111`. |
| `3112` | Streams em tempo real. |
| `3113` | Viewer web do AgentMemory. |
| `49134` | WebSocket interno do iii-engine. |

Após reinstalar ou mudar `~/.agentmemory/.env`, reinicie com `systemctl --user restart agentmemory`. Consulte `systemctl --user status agentmemory`, `journalctl --user -u agentmemory -n 100` e `curl http://127.0.0.1:3111/agentmemory/livez`. O keepalive Windows evita que a distribuição pare quando não houver terminal ativo; não substitui a unidade systemd.

### Agentes e integrações no Arch

`bash wsl/install.sh --agents` instala OpenCode e Codex via npm com `--prefix "$HOME/.local"`, usando as tags `latest` de `opencode-ai` e `@openai/codex`. O Antigravity CLI (`agy`) usa o instalador oficial somente quando estiver ausente. Os agentes independem da presença dos seus CLIs Windows.

| Agente | Integração reproduzida |
| --- | --- |
| OpenCode | `agentmemory connect opencode --with-hooks` quando faltar MCP; arquivos em `~/.config/opencode`, plugin `plugins/agentmemory-capture.ts` e comandos `commands/recall.md` e `commands/remember.md`. O instalador mantém a referência do plugin sem duplicá-la. |
| Antigravity CLI | Cria `~/.gemini/antigravity-cli` para detecção pelo adaptador; `agentmemory connect antigravity-cli --with-hooks` quando faltar MCP ou hooks; arquivos em `~/.gemini/config`. A integração da IDE Antigravity é separada. |
| Codex CLI | `agentmemory connect codex --with-hooks` quando faltarem configuração/hooks; instala o plugin `agentmemory@agentmemory` pelo marketplace oficial se ausente. |
| Skills | `npx -y skills add rohitg00/agentmemory -g -y`, executado no HOME quando a skill `recall` ainda não existir em `~/.agents/skills`. |

O serviço deve estar instalado antes de `--agents`; `--all` respeita essa ordem. Se os arquivos de uma integração já existirem, alguns adaptadores não são executados novamente. Para uma configuração personalizada com problemas, confira o arquivo correspondente e reaplique o comando oficial `agentmemory connect` do agente, depois a etapa `--agents` para recopiá-los quando aplicável.

Faça o login interativo em cada agente e aceite as permissões de hooks necessárias no próprio cliente. Autenticação, assinaturas e credenciais não são copiadas dos perfis Windows. Na raiz de um projeto Linux:

~~~bash
cd ~/dev/meu-projeto
opencode
agy
codex
~~~

Confira as integrações com `opencode mcp list`, `agy mcp list` e `codex mcp list`. A instalação de um CLI e a conexão MCP não comprovam login no provedor. A [documentação oficial do AgentMemory](https://github.com/rohitg00/agentmemory) é a referência dos adaptadores e opções da versão instalada.

### Operação, contexto e persistência

O iii-engine faz parte da arquitetura e da instalação do AgentMemory. O servidor mantém as observações e sessões no diretório de dados, atende a API REST e fornece streams/viewer. Os clientes MCP e hooks são pontes para esse servidor; a integração não exige uma base adicional no Windows.

O arquivo `~/.agentmemory/.env` recebe linhas `CHAVE=valor`, sem prefixo `export`. O template deste repositório escolhe `AGENTMEMORY_AGENT_SCOPE=shared` e `AGENTMEMORY_INJECT_CONTEXT=true`; preserve as chaves de provedor fora do Git. Recursos que usam um provedor LLM dependem das opções e credenciais configuradas e podem consumir tokens. A instalação básica pode ser usada sem chave de LLM; verifique as funcionalidades efetivamente habilitadas na versão instalada.

A unidade systemd declara seu próprio PATH (`~/.local/bin:/usr/local/bin:/usr/bin`), diretório de trabalho HOME, caminho de dados e `Restart=on-failure` com intervalo de cinco segundos. Ela não carrega o `.zshrc` nem os aliases/mise da sessão interativa. O CLI é instalado em `~/.local`; o Node disponível no PATH da unidade vem dos pacotes do Arch. A unidade e o `.env` já existentes são preservados pelo instalador.

Se `linger` estiver desativado, o instalador tenta habilitá-lo com `sudo -n`. Quando não conseguir, execute `sudo loginctl enable-linger "$USER"` manualmente. O linger permite iniciar o serviço de usuário, e o keepalive mantém a distribuição WSL em execução. São duas camadas diferentes.

~~~bash
systemctl --user status agentmemory
journalctl --user -u agentmemory -n 100
systemctl --user restart agentmemory
curl --fail http://127.0.0.1:3111/agentmemory/livez
~~~

O instalador recusa outro AgentMemory respondendo em 3111 quando a unidade gerenciada não estiver ativa. Confirme o dono da porta antes de iniciar uma segunda instância. Alterar a porta exige ajustar as integrações dos clientes e os endereços de diagnóstico, não apenas o `.env`.

O nome lógico do projeto vem do repositório Git ou diretório. Quando necessário, configure `AGENTMEMORY_PROJECT_NAME` por projeto para associar cópias do mesmo repositório; não use um nome global para todos. O escopo compartilhado permite consulta entre agentes. Em gravações MCP/REST que aceitem `agentId`, passe identificadores distintos para registrar autoria; não atribua um único `AGENT_ID` no servidor a todos os clientes.

O Codex Windows usado nesta sessão permanece instalado, com seus dados e plugin preservados. A remoção autorizada dos outros CLIs Windows não transforma `~/.codex` em uma pasta descartável. Em uma instalação nova, o setup Windows não instala agentes; o fluxo normal de desenvolvimento e memória usa os clientes Arch.

## Verificação após a instalação

Faça as verificações na plataforma indicada. Elas conferem o ambiente instalado agora, sem depender do estado de uma máquina anterior.

| Plataforma | Comando ou ação | Resultado esperado |
| --- | --- | --- |
| Windows | `wsl --list --verbose` | `archlinux` em WSL 2. |
| Windows | `Get-ScheduledTask -TaskName ArchWSLKeepAlive` | Tarefa registrada para o logon. |
| Windows | `Get-Command adb.exe -All` e `adb version` | Executável Windows selecionado no PATH; instalação existente ou `Google.PlatformTools`. |
| Windows | `adb devices -l` | Servidor ADB ativo; o telefone aparece se conectado e autorizado. |
| Windows com NVIDIA | `Get-AppxPackage -Name NVIDIACorp.NVIDIAControlPanel` | Pacote do Painel de Controle registrado na conta atual. |
| Windows com NVIDIA | `Get-Service NVDisplay.ContainerLocalSystem` e `nvidia-smi` | Serviço do driver em execução e GPU identificada. |
| Windows com MX110 | `Get-Command nvcc.exe` e `nvcc --version` | CUDA 12.9 selecionado; essa consulta não substitui um teste real de compilação CUDA. |
| Windows | Execute `& "$env:GSTREAMER_1_0_ROOT_MSVC_X86_64\bin\gst-inspect-1.0.exe" --exists glshader` (repita para `pitch` e `wasapi2sink`). | Cada comando retorna código 0 na instalação MSVC x64. |
| Arch | `systemctl status docker`, `docker compose version` | Docker ativo e Compose disponível. |
| Arch | `node --version`, `java -version`, `gradle --version` | Ferramentas de build Linux disponíveis. |
| Arch | `paru --version`, `nvim --version`, `echo $SHELL` | Paru, Neovim e Zsh disponíveis. |
| Arch | `code --version` e `code .` dentro de `~/dev/meu-projeto` | VS Code Server instalado; janela identificada como **WSL: archlinux**. |
| Arch | `adb devices -l` | Cliente Linux consulta o mesmo servidor ADB Windows. |
| Arch | `systemctl --user status agentmemory` e `curl http://127.0.0.1:3111/agentmemory/livez` | Serviço e endpoint de saúde ativos. |
| Arch | `opencode mcp list`, `agy mcp list`, `codex mcp list` | AgentMemory listado nos agentes instalados. |
| WSLg | Abra **Android Studio (Arch WSL)** pelo menu Iniciar ou `android-studio-wsl` no Arch. | A IDE mostra sua interface e usa `~/Android/Sdk`. |
| Projeto | `windows-sync` e `validate-windows` na raiz em `~/dev`. | Fonte atualizada em `C:\Dev\.targets` e código de saída 0 somente após a validação Windows passar. |

Para um teste de compilação Android sem projeto próprio, execute `bash wsl/tools/android-smoke.sh` no Arch. Ele cria um projeto Kotlin temporário em `~/dev`, gera o APK e remove o projeto de teste. Um dispositivo físico só é necessário para testar instalação e `adb reverse`. Para verificar o Supabase, execute `supabase start --network-id supabase-local-loopback` dentro de um projeto e examine `docker ps`; pare os serviços com `supabase stop` quando terminar.

## Operação diária e serviços

Use os terminais de cada plataforma para as tarefas correspondentes. Um fluxo de projeto completo é:

1. Abra o Arch e entre em `~/dev/<projeto>`.
2. Confira a seleção do projeto com `mise ls` e instale o que estiver declarado com `mise install`.
3. Abra `code .`, ou a integração WSL do IntelliJ; para Android, use `android-studio-wsl`.
4. Instale as dependências do projeto no Arch: por exemplo, `npm ci`, `pnpm install --frozen-lockfile`, `bundle install` ou `uv sync`, de acordo com os manifests existentes.
5. Inicie apenas a pilha Supabase/Docker usada pelo projeto e execute os testes Linux/Android.
6. Chame `windows-sync` ou `validate-windows` quando precisar validar o target nativo Windows.
7. Faça commits no checkout Arch. O target Windows é uma cópia de trabalho para validação e não recebe desenvolvimento independente.

~~~mermaid
flowchart LR
    UI["Windows: VS Code / IntelliJ"] --> SRC["Arch: ~/dev/projeto"]
    SRC --> LINUX["Builds e agentes Linux"]
    STUDIO["Android Studio no Arch"] --> WSLG["WSLg: janela no Windows"]
    SRC --> COPY["windows-sync / validate-windows"]
    COPY --> TARGET["Windows: .targets/projeto-win/workspace"]
    TARGET --> BUILD["Toolchain e testes Windows"]
    LINUX --> MEMORY["AgentMemory único no Arch"]
~~~

| Componente | Como inicia e como parar |
| --- | --- |
| Arch WSL | `wsl -d archlinux`; `wsl --terminate archlinux` encerra a distribuição. `wsl --shutdown` encerra todas as distribuições e a VM WSL. |
| Docker | `docker.service` habilitado na base; `sudo systemctl start docker` / `sudo systemctl stop docker`. Parar o daemon afeta os containers em execução. |
| AgentMemory | Unidade systemd de usuário habilitada; `systemctl --user start/stop/restart agentmemory`. |
| Supabase | `supabase start` / `supabase stop` no projeto; não é iniciado pelo setup de dotfiles. |
| ADB | `adb start-server` / `adb kill-server` no Windows. No Arch, o wrapper é cliente desse servidor. |
| Keepalive | Tarefa `ArchWSLKeepAlive` no logon; `Start-ScheduledTask` / `Stop-ScheduledTask` controlam a execução Windows. |
| Android Studio e editores | Abertos pelo usuário; concluir assistentes e abrir projetos não faz parte da instalação silenciosa. |

Parar a tarefa do keepalive não equivale a desabilitar seu próximo logon; use `Disable-ScheduledTask -TaskName ArchWSLKeepAlive` se essa for a intenção. Reative com `Enable-ScheduledTask`. Se quiser parar o Arch, pare primeiro o keepalive e depois termine a distribuição. Para manter os serviços disponíveis novamente:

~~~powershell
Enable-ScheduledTask -TaskName ArchWSLKeepAlive
Start-ScheduledTask -TaskName ArchWSLKeepAlive
~~~

O script mantém um `sleep infinity` em primeiro plano no WSL. Na recuperação gráfica, detecta `use_gfxredir = 0` junto da falha `rdp_allocate_shared_memory` em `/mnt/wslg/weston.log`, faz a montagem temporária na distribuição de sistema do WSLg, restaura a montagem e executa `wsl --shutdown`. Ele não faz um reparo genérico de todo problema de GUI, nem instala outro compositor.

## Atualização e personalização

### Política de versões

| Componente | Política do setup e como atualizar |
| --- | --- |
| Arch/pacman | A base usa `pacman -Syu --needed`. Para manutenção do sistema, use `sudo pacman -Syu`. |
| Paru/AUR | Bootstrap compila `paru` estável se ausente; use `paru -Syu` para atualizar pacotes do sistema e AUR. |
| mise | Pacotes `mise` e `usage` pertencem ao pacman; seleções globais das cinco ferramentas usam `latest`. Reaplique `--mise` para resolver as ferramentas e atualizar pip. |
| Node/Ruby/Kotlin/Python por projeto | Declare versões no `mise.toml` do projeto e versione o lockfile/configuração correspondente conforme o projeto exigir. Isso é independente da seleção global. |
| Agentes Arch | `--agents` reinstala as tags `latest` de OpenCode/Codex; o instalador Antigravity só roda se `agy` estiver ausente. Para atualizar um `agy` existente, siga o mecanismo da versão instalada e o guia oficial. |
| AgentMemory | `--agentmemory` resolve a tag estável do npm, instala se necessário e reinicia a unidade quando atualizou o pacote. Os dados, `.env` e unidade existentes são preservados. |
| Supabase CLI | Versão e SHA-256 no script; altere ambos e reaplique `--supabase`. |
| Android SDK | Command-line Tools com arquivo/hash declarados; API 36 e Build Tools 36.0.0 explícitos. Revise o script para mudar a plataforma reproduzida. |
| Smoke Android | AGP 9.4.0 explícito no teste; o Gradle vem do Arch. Não substitui o wrapper Gradle dos projetos reais. |
| Aplicativos Windows | Instalação estável do catálogo quando ausentes; existentes são preservados. Use atualização seletiva por ID quando desejar atualizar. |
| Painel de Controle NVIDIA | Pacote da Microsoft Store, sem versão fixada; a instalação existente da conta é preservada. Atualize pela Store ou pelo winget com a fonte `msstore`. |
| ADB Windows | `Google.PlatformTools` quando ausente; instalações existentes são preservadas pelo caminho do executável. Atualize pelo canal que forneceu essa instalação e confira `Get-Command adb.exe -All`. |
| GStreamer Windows | Instalador oficial 1.28.6, definido em `versions.psd1`. Uma instalação com os arquivos exigidos já presentes pode ser reaproveitada. |
| CUDA Windows | Último pacote estável em GPUs atuais; versão 12.9 para Maxwell/Pascal/Volta por compatibilidade. |
| Rust Windows | Toolchain `stable-x86_64-pc-windows-msvc` assegurada se ausente; `rustup update stable-x86_64-pc-windows-msvc` atualiza uma instalação existente. |
| LazyVim/Oh My Zsh | Os instaladores preservam instalações reconhecidas. Atualizações de plugins são feitas pelos respectivos gerenciadores. |

No Windows, exemplos de atualizações seletivas:

~~~powershell
winget upgrade --id Bitwarden.Bitwarden --exact --source winget
winget upgrade --id JetBrains.IntelliJIDEA --exact --source winget
winget upgrade --id Microsoft.DotNet.SDK.10 --exact --source winget
winget upgrade --id Ytmdesktop.Ytmdesktop --exact --source winget
winget upgrade --id 9NF8H0H7WMLT --exact --source msstore
choco upgrade chocolatey --yes
~~~

Use a fonte `msstore` para o Painel de Controle NVIDIA e, em GPUs compatíveis, para o NVIDIA App. Para Platform Tools instaladas pelo winget, use `winget upgrade --id Google.PlatformTools --exact --source winget`; uma cópia preservada de outra origem pode não estar registrada sob esse ID. O Chocolatey é disponibilizado para uso no Windows; o setup usa winget para os aplicativos catalogados, evitando cadastrar o mesmo programa em dois gerenciadores. Atualize seletivamente: o CUDA legado da MX110 deve permanecer em uma versão compatível.

Para atualizar o WSL, execute `wsl --update` no Windows e reinicie a distribuição após salvar o trabalho. Reaplicar `windows/setup.ps1` também reaplica os modelos; não é apenas um comando de atualização de pacotes.

### Alterar configurações e reaplicá-las

| Personalização | Arquivo de referência e aplicação |
| --- | --- |
| Recursos/rede WSL | Edite `windows/.wslconfig` para futuras instalações; ajuste conscientemente o `%USERPROFILE%\.wslconfig` existente, pois o setup o preserva. Aplique com `wsl --shutdown`. |
| Ferramentas globais mise | Edite `wsl/tools/mise.toml` e reaplique `--mise`. |
| Shell e aliases | Edite `wsl/.zshrc` e compare/aplique ao `~/.zshrc` já existente; o instalador não o substitui por completo. |
| Ambiente Linux | Edite `wsl/tools/env.sh` e reaplique `bash wsl/tools/configure-shell.sh` após a base; abra uma sessão nova. |
| Identidade/preferências Git | Edite `wsl/.gitconfig` e aplique ao perfil desejado, preservando credenciais locais. |
| Terminal/PowerShell | Edite `windows/terminal/settings.json` ou `profile.ps1`; reaplique `setup-terminal.ps1` e abra uma aba nova. |
| Tema/botões GTK | Edite `wsl/gtk-3.0/settings.ini`; reaplique `--android-studio` e reabra a IDE. O layout correspondente também é definido no script por `gsettings`. |
| Agentes/MCP | Configurações pertencem ao perfil Arch; confira os adaptadores e reaplique `--agents`. |
| AgentMemory | Edite `~/.agentmemory/.env` e reinicie o serviço. Se alterar a unidade manualmente, faça `systemctl --user daemon-reload` antes do restart. |
| Validação Windows por projeto | Edite `scripts/validate-windows.ps1` no checkout Arch; a próxima execução sincroniza o arquivo. |

O perfil PowerShell copiado pelo setup pertence ao perfil **Windows PowerShell** do Terminal, que o executa com `-File`. Ele não substitui automaticamente todos os arquivos `$PROFILE` nem configura todos os hosts PowerShell. Os perfis adicionais do JSON incluem cmd, Azure Cloud Shell, Developer Command Prompt/PowerShell das versões VS e Arch; a disponibilidade depende dos programas instalados. O perfil Arch tem GUID do modelo: em outra instalação, confira o perfil WSL descoberto pelo Terminal.

O Starship usa o tema padrão nos dois shells; não há um `starship.toml` personalizado neste repositório. Oh My Zsh oferece plugins com `ZSH_THEME=""`. O Oh My Posh, se necessário para instalar a fonte, não é inicializado como prompt. O desenho do prompt, a paleta ANSI do Terminal e o GTK das janelas WSLg são camadas diferentes.

### Paleta completa do Terminal

| Cor normal | Valor | Cor intensa | Valor |
| --- | --- | --- | --- |
| black | `#073642` | brightBlack | `#839496` |
| red | `#dc322f` | brightRed | `#cb4b16` |
| green | `#859900` | brightGreen | `#859900` |
| yellow | `#b58900` | brightYellow | `#657b83` |
| blue | `#268bd2` | brightBlue | `#839496` |
| purple | `#d33682` | brightPurple | `#6c71c4` |
| cyan | `#2aa198` | brightCyan | `#66d9ef` |
| white | `#eee8d5` | brightWhite | `#fdf6e3` |

Fundo `#002b36`; texto `#839496`; seleção `#073642`; cursor `#859900`. O PSReadLine usa `#56b6c2` para parâmetros. A fonte padrão é `CaskaydiaCove NFM`.

## Recuperação e solução de problemas

| Sintoma | Verificação e ação |
| --- | --- |
| Comandos Linux chamam executáveis Windows | Confira `command -v` e `/etc/wsl.conf`. Aplique `appendWindowsPath=false` e `wsl --shutdown`; o `code` e os runners têm pontes explícitas. |
| Instalador para em `[interop]` | Revise a seção existente e acrescente o valor correto sem duplicar a seção. O script preserva uma configuração conflitante. |
| mise não seleciona Python/Node | Abra um novo Arch, execute `mise doctor`, `mise ls` e confira o arquivo do projeto e o global. |
| uv instala fora do ambiente esperado | Confira `VIRTUAL_ENV`, `uv python find` e variáveis `UV_*`; não imponha um `UV_PYTHON` global. Use `uv venv --seed .venv` e ative o ambiente desejado. |
| Docker pede permissão | Confira `id -nG`; abra uma sessão nova após adicionar o usuário ao grupo `docker`. Confirme o daemon systemd. |
| systemd de usuário não atende | Confira PID 1, a sessão do usuário e `loginctl show-user "$USER" -p Linger`; confirme `[boot] systemd=true` e reinicie o WSL. |
| Serviço inacessível no Windows | Confira a tarefa keepalive, o serviço no Arch, as portas e a rede mirrored antes de alterar o cliente. |
| ADB Arch não lista o telefone | Confira primeiro `adb devices -l` no Windows, autorização no aparelho e servidor 5037. Depois teste o wrapper Arch. Lista vazia sem telefone conectado não é falha de instalação. |
| ADB Windows não encontrado após instalar | Abra um novo PowerShell, confira `Get-Command adb.exe -All` e reaplique `windows/setup-apps.ps1`. A mensagem `ADB ausente apos a instalacao de Platform Tools` indica que a etapa não encontrou o executável no PATH atualizado. |
| Aparelho `unauthorized` ou `offline` | Desbloqueie o aparelho e aceite a autorização RSA; revise depuração USB, cabo e drivers do fabricante no Windows. Reinicie o servidor pelo PowerShell se necessário. |
| Wrapper `/usr/local/bin/adb` diferente | O instalador não o substitui; compare com `wsl/tools/adb-client` e resolva a configuração existente. |
| `code .` não abre WSL | Confirme VS Code Windows no PATH do host, extensão WSL e link `~/.local/bin/code`; reaplique `--vscode` quando o launcher estiver ausente. |
| Android Studio vazio ou COPY MODE | Use `keepalive.ps1 -RepairOnly` e confira `/mnt/wslg/weston.log`; o reparo pode encerrar todas as sessões WSL. |
| Menu inicial da IDE cortado | Restaure ou mova a janela; é limitação de popup, sem plugin próprio para reposicioná-lo. |
| Controles GTK ou ícone incorretos | Reaplique `--android-studio`, confira as duas opções VM e o `<app_id>.desktop`, e reabra a IDE. |
| Target Windows recusado | Confirme origem diretamente em `~/dev`, nome ASCII, marcador e ausência de junções. Não force o runner a usar uma pasta pertencente a outro projeto. |
| Build Windows falha | Confira o código de saída do validador do projeto e suas dependências Windows; sucesso de sincronização não comprova sucesso de build. |
| Plugin GStreamer não encontrado | Use o binário da instalação correta: Arch com `pulsesink`; Windows MSVC x64 com `wasapi2sink`. Confira também GES via pkg-config ou os arquivos de desenvolvimento correspondentes. |
| CUDA não atende a GPU | Confira capacidade, driver, versão do toolkit e `CUDA_PATH`. Para a MX110, use o toolkit Windows 12.x compatível. |
| Painel de Controle NVIDIA ausente | Confira o driver, o serviço `NVDisplay.ContainerLocalSystem`, a conta atual e `Get-AppxPackage -Name NVIDIACorp.NVIDIAControlPanel`; reaplique `setup-apps.ps1` ou o comando winget da seção do painel. |
| NVIDIA App recusado na MX110 | O instalador oficial rejeitou essa GPU; o catálogo omite o NVIDIA App nesse modelo. O Painel de Controle tem uma etapa própria e continua incluído. |
| Fonte `msstore` indisponível | Confira `winget source list` e `winget source update`. Use a mesma conta Windows do ambiente e examine o erro apresentado pelo winget antes de reaplicar a etapa. |
| Script PowerShell bloqueado | Execute a entrada com `powershell.exe -NoProfile -ExecutionPolicy Bypass -File ...`, como nos exemplos; não é necessário mudar globalmente a política. |

### Preservar dados e restaurar configurações

Um `.bak` descrito neste README só existe quando a condição de backup do instalador ocorreu e o arquivo não foi removido depois. Antes de restaurar, confira seu conteúdo e o destino. Reaplicar um instalador que copia um modelo voltará a aplicar o conteúdo versionado.

Para AgentMemory, pare a unidade antes de copiar sua base e mantenha o `.env` com acesso restrito. Exemplo de backup local no Arch:

~~~bash
systemctl --user stop agentmemory
(umask 077; mkdir -p "$HOME/Backups"; tar -C "$HOME" -czf "$HOME/Backups/agentmemory-$(date +%Y%m%d-%H%M%S).tar.gz" .agentmemory/.env .local/share/agentmemory .config/systemd/user/agentmemory.service)
systemctl --user start agentmemory
~~~

Ao restaurar em outra conta, confira os caminhos absolutos no `.env` e na unidade antes de iniciá-la. O comando copia dados e configuração de serviço; os pacotes e agentes são reproduzidos pelos instaladores. Credenciais e dados de memória não devem ser commitados nos dotfiles.

Para exportar a distribuição inteira, salve os projetos, pare a tarefa keepalive e termine o Arch antes de `wsl --export archlinux D:\Backups\archlinux.tar`, com a pasta de backup já existente. Depois reinicie a tarefa. A importação usa `wsl --import <nome> <diretorio> <arquivo.tar> --version 2`; conferir usuário padrão e configurações de integração faz parte da restauração. Não é necessário remover ou registrar novamente a distribuição original para gerar o backup.


## Referências oficiais

[WSL config](https://learn.microsoft.com/windows/wsl/wsl-config), [Android SDK](https://developer.android.com/tools/sdkmanager), [Supabase local](https://supabase.com/docs/guides/local-development), [AgentMemory](https://github.com/rohitg00/agentmemory), [OpenCode](https://opencode.ai/docs), [Antigravity CLI](https://antigravity.google/docs/cli/install), [Codex CLI](https://developers.openai.com/codex/cli), [Tauri no Windows](https://v2.tauri.app/start/prerequisites/), [GStreamer para Windows](https://gstreamer.freedesktop.org/download/).
