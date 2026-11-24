# Funcionalidades reimplementadas por prioridade

## Escopo e critério

- Intervalo analisado, incluindo os extremos: `814ff351cf5ce6b5d54d3bf9cf20600f25f745c1` até `fe60e15da7465396c97465aaf65f78938af4b850`. Os hashes foram apresentados na ordem inversa no pedido; `814ff35` é o mais antigo.
- Base da reconstrução: `fa802f674a063ef39128c8db3a6ac4082f871fca`, pai de `814ff35`.
- Histórico original preservado em `backup/features-fe60e15-before-reimplementation`, apontando para `fe60e15`.
- O intervalo contém oito commits lineares: seis mudanças de comportamento e dois commits de documentação. A lista abaixo mantém todos eles, ordenados pelo impacto na operação do ambiente.
- Prioridade: preservar sessões e recuperar o fluxo Android; simplificar a integração entre plataformas; completar ferramentas e diagnósticos; documentar a operação e a reconstrução.
- O retorno à base foi executado na `main`, com o diretório de trabalho limpo. Cada feature foi reconstruída a partir do patch original revisado, validada e registrada em um novo commit, na ordem abaixo.

## 1. Inicialização do Arch sob demanda e preservação das sessões

Origem: `814ff351cf5ce6b5d54d3bf9cf20600f25f745c1`.

- Retirar a criação e atualização automática de keepalive no logon pelo setup Windows.
- Desabilitar somente as tarefas legadas reconhecidas `ArchWSLKeepAlive` e `DotfilesOpenUbuntu`, conferindo pasta, ações completas, argumentos, descrição, usuário, principal e gatilho.
- Reconhecer o keepalive PowerShell e o comando legado `wsl.exe ... sleep infinity`, além das variantes conhecidas da tarefa Ubuntu.
- Preservar tarefas personalizadas, tarefas ausentes e processos já em execução; informar instâncias pendentes sem pará-las ou removê-las.
- Suportar `-WhatIf`, reaplicação idempotente, verificação da desativação e erros explícitos de consulta, permissão ou desativação ineficaz.
- Criar `.wslconfig` quando necessário, sem shutdown, preservando a configuração existente e as sessões atuais.
- Manter aplicativos, terminal e `keepalive.ps1` para reparo WSLg manual com `-RepairOnly`.
- Explicar que Docker e AgentMemory dependem do Arch ativo e que systemd/linger não mantêm a distribuição ativa sozinhos.

Arquivos: `windows/setup.ps1`, `windows/disable-wsl-logon-tasks.ps1`, `windows/tests/wsl-startup.Tests.ps1`; documentação operacional no item 7.

## 2. Recuperação sob demanda do servidor ADB Windows

Origem: `805c6bc1cfc37a8d76edfcea15a026c53c5612d4`.

- Adicionar `adb-bridge ensure` e `adb-bridge status`, consultar o protocolo ADB, tratar respostas fragmentadas e distinguir servidor acessível, lista vazia, `unauthorized` e `offline`.
- Fazer `status` apenas consultar e preservar servidores saudáveis, sem reiniciar ou encerrar processos existentes.
- Recuperar somente o servidor Windows em loopback `127.0.0.1:5037`, usando helper PowerShell instalado com a ponte ou localizado no checkout.
- Limitar conversão de caminho, chamada PowerShell e espera do cliente; distinguir falha Windows de falha da ponte mirrored/firewall.
- Serializar inicializações com mutex por usuário Windows e conferir dono, endereço e protocolo da porta; recusar porta exposta, programa de terceiro ou listener sem resposta.
- Iniciar `adb.exe start-server` em console oculto independente, sem streams herdados nem espera dos descendentes; limpar variáveis ADB somente no auxiliar e preservar diagnósticos.
- Preservar argumentos no wrapper Linux; ajuda, versão, geração de chaves e `kill-server` não iniciam servidor. Limitar a espera de `kill-server` e delegar `start-server` ao Windows.
- Recusar opções que criariam servidor Linux ou selecionariam outro host/porta; migrar somente o wrapper legado exato ou uma versão gerenciada reconhecida por hash, preservando wrappers personalizados.

Arquivos: `wsl/tools/adb-bridge`, `wsl/tools/adb-client`, `wsl/tools/android.sh`, `windows/ensure-adb-server.ps1`, `windows/tests/adb-server.Tests.ps1`. Testes Linux adicionados no item 3.

## 3. Android Studio com ADB manual e atalhos WSLg

Origem: `fcd73af046de2aa3652ff48c73e458d898920d0a`.

- Extrair `android-studio-wsl`, preparar SDK, tema e socket, exigir display WSLg e recuperar a ponte antes de iniciar o comando original do pacote.
- Reaplicar a ponte também na etapa isolada `--android-studio`, preservando o comando `android-studio` do pacote.
- Configurar apenas o servidor ADB manual e a porta 5037 em `PropertyService.keyToString` de `other.xml`, localizando a versão por `product-info.json`.
- Validar classes/esquema da IDE; detectar IDE aberta por launcher, executável nativo e JVM antes de editar e novamente antes de gravar preferências.
- Preservar componentes e propriedades não relacionados, modos e primeiro backup; fazer escrita atômica e idempotente, com restauração somente das duas chaves ADB por `--restore-from`.
- Recusar links simbólicos, formatos desconhecidos e conteúdo inválido sem substituir preferências.
- Publicar entrada desktop canônica com app ID/startupWmClass e ícone oficial; retirar somente entradas legadas reconhecidas e ocultar a entrada redundante por sobreposição, preservando o arquivo do pacote.
- Preservar entradas personalizadas e evitar republicação idêntica; reparar somente atalhos Windows ausentes após a migração do cache WSLg, com argumentos validados.

Arquivos: `wsl/tools/android-studio.sh`, `wsl/tools/android-studio-wsl`, `wsl/tools/android-studio-adb-settings.py`, `windows/setup-android-studio-shortcut.ps1`, `wsl/tests/test_adb_bridge.py`.

## 4. Separação dos projetos Windows e WSL

Origem: `d2d74b7401977f2bf51bb7ccab3db26b4cfac4da`.

- Excluir `wsl/tools/windows-validation.sh` e `windows/validate-project.ps1`, retirando a implementação de `windows-sync`/`validate-windows`.
- Retirar a instalação automática da ponte e a opção `--windows-runner`, inclusive da ajuda do instalador.
- Retirar a cópia e exigência do runner no setup Windows; preservar o reparo manual WSLg e os demais ajustes locais.
- Adaptar os testes de startup para garantir que o runner aposentado não seja instalado.
- Documentar checkouts independentes e ferramentas nativas para desktop Windows, preservando a compilação cruzada MSVC opcional `--windows-cross`.

Arquivos: `windows/setup.ps1`, `windows/tests/wsl-startup.Tests.ps1`, `wsl/install.sh` e os dois scripts excluídos; documentação no item 7.

## 5. Go estável gerenciado pelo mise

Origem: `a1a8e8fdb61502f12cabee0deeae72696e8dca81`.

- Adicionar `go = "latest"` ao modelo global junto de Node.js, Ruby, Kotlin, Python e uv.
- Executar `go version` na verificação das linguagens, preservando o diretório temporário que isola configurações de projetos.
- Documentar instalação por `--mise`/base e diagnóstico com `go version` e `go env GOROOT GOPATH`.

Arquivos: `wsl/tools/mise.toml`, `wsl/tools/mise.sh`; documentação no item 7.

## 6. Verificação explícita do GitHub CLI na base

Origem: `5c6bea3005914f75a39eaa780504763317805b90`.

- Executar `gh --version` após instalar `github-cli`, propagando eventual falha no instalador.
- Documentar disponibilidade no Arch, verificação e autenticação pessoal por `gh auth status`/`gh auth login`.

Arquivo: `wsl/install.sh`; documentação no item 7.

## 7. Documentação de configuração, operação e preservação

Origem: `61879b4212d2f1600a6f226c824baadd14b424d0`.

- Reorganizar o README em propósito, componentes, pré-requisitos, instalação Windows/Arch, usuário/systemd, configurações pessoais e etapas independentes.
- Explicar operação e diagnóstico de linguagens, GitHub CLI, Docker, VS Code, Android, Supabase, AgentMemory e agentes, incluindo o funcionamento sob demanda.
- Registrar reaplicação, arquivos preservados/substituídos, backups, atualização e personalização; retirar relatos de sessões e projetos pessoais.
- Separar `docs/android.md`: SDK/IDE Linux, servidor USB Windows, mirrored, instalação, launcher, ADB manual, diagnóstico, limites de espera, backups/restauração, reparo WSLg e testes.
- Simplificar `docs/windows-cross.md`, preservando instalação/uso MSVC, isolamento Rust/Cargo, caminhos/cache, SDK/runtime GStreamer opcionais, integridade, arquitetura, inventário, NSIS e limites dos testes.
- Conciliar os guias com checkouts independentes, sem referências operacionais à sincronização retirada, e validar links locais e exemplos Bash.

Arquivos: `README.md`, `docs/android.md`, `docs/windows-cross.md`.

## 8. Inventário priorizado e rastreabilidade da reconstrução

Origem: `fe60e15da7465396c97465aaf65f78938af4b850`.

- Registrar todas as features do intervalo, sua prioridade, origem e arquivos afetados neste documento.
- Atualizar hashes, backup, data e evidências para esta reconstrução, substituindo referências à reconstrução anterior.
- Comparar conteúdo, modos e exclusões da árvore reconstruída com `fe60e15`, admitindo somente a atualização deste inventário.

Arquivo: `docs/features-reimplementadas.md`.

## Limpeza e validação em 24/11/2026

Conforme o pedido adicional, foram removidos **697 arquivos descartáveis datados de 19/11/2026**, totalizando **102.463.121 bytes (97,7 MiB)**, de `~/.cache/go-build` e `~/.cache/mise`. O critério de data usa o fuso `America/Sao_Paulo`. Foram preservados locks do mise, instalações de ferramentas, configurações e dados. Não havia cache local do repositório para limpar nem arquivos dessa data nos caches próprios dos dotfiles.

Reconstrução concluída sobre a base solicitada. Os 53 arquivos funcionais/documentais da árvore original correspondem integralmente a `fe60e15`, incluindo conteúdo, modos registrados pelo Git e exclusões, com a única exceção intencional deste inventário atualizado. A árvore sem o inventário tem SHA `3c397dd05fb56c8691a1125b69d729eef0b64b1d`.

Verificações executadas nesta reconstrução:

- 13 testes Linux da ponte ADB, wrapper e preferências Android Studio: aprovados.
- 9 testes Linux de integridade e isolamento da compilação cruzada Windows: aprovados.
- 74 verificações no Windows PowerShell 5.1 de inicialização, setup e reparo WSLg, com tarefas e comandos WSL simulados: aprovadas.
- 8 cenários PowerShell de recuperação ADB, sem iniciar ou encerrar servidores reais: aprovados.
- Sintaxe e LF de 21 scripts Bash, sintaxe de 6 arquivos Python e leitura dos modelos TOML: aprovadas.
- 15 links locais e sintaxe de 12 exemplos Bash dos guias: aprovados.
- Go resolvido pelo mise; `go version`, `go vet`, compilação forçada com `-a -buildvcs=false` e execução Linux: aprovados, com cache temporário inicialmente vazio e sem dependências externas. O diretório temporário e seu cache foram removidos após a verificação.
- `gh --version`: aprovado. Não foi alterada a autenticação do usuário.
- Opção `--windows-runner` recusada com código 2 e ausente da ajuda, scripts de sincronização excluídos e `--windows-cross` preservado: aprovado.
- Comparação das árvores e `git diff --check`: aprovados.
- Nova varredura dos caches Go, mise e dotfiles: nenhum arquivo descartável de 19/11/2026 restante, excetuando os locks deliberadamente preservados.

A validação não executou instaladores no ambiente do usuário nem alterou tarefas ou sessões reais. Interface da IDE, atalhos no menu Iniciar, telefone físico e próximo logon exigem verificação interativa; não foram apresentados como testados nesta execução.

## Novos commits por prioridade

1. `338e351` — fix(wsl): reconstruir inicializacao sob demanda e preservar sessoes
2. `d1dfa69` — feat(android): reconstruir recuperacao ADB Windows sob demanda
3. `0a357c8` — feat(android): reconstruir integracao do Studio com ADB e WSLg
4. `002c2c1` — refactor(interop): reconstruir separacao dos projetos Windows e WSL
5. `8a34b9f` — feat(wsl): reconstruir instalacao e verificacao de Go pelo mise
6. `0e9ba29` — chore(wsl): reconstruir verificacao do GitHub CLI na base
7. `8e51095` — docs: reconstruir guias de configuracao e operacao do ambiente
8. Inventário e evidências: commit que adiciona esta versão de `docs/features-reimplementadas.md`.
