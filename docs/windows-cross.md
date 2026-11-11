# Compilar Windows x64 no Arch/WSL2

A entrada opcional é `bash wsl/install.sh --windows-cross`. Ela instala LLVM/Clang/LLD, CMake, Ninja, pkgconf, Python, file e curl pelo pacman quando ausentes. Rust usa rustup oficial em um perfil privado; instalações novas usam Rust 1.99.1 e cargo-xwin 0.23.1. Perfis anteriores são preservados e `check` mostra suas versões. A instalação inicial do rustup vem do servidor HTTPS oficial; os componentes Rust são conferidos pelo rustup. Arch é rolling release: versões dos pacotes do sistema acompanham seu snapshot/mirror, não estão travadas aqui.

A instalação também cria `~/.local/bin/windows-cross`, um link para este checkout. Mantenha o checkout disponível. Antes de instalar o launcher, use `bash /caminho/dotfiles/wsl/tools/windows-cross.sh` no lugar de `windows-cross` em todos os exemplos. Nenhuma toolchain privada entra no PATH global. Não execute o script com `source`.

```bash
bash wsl/install.sh --windows-cross
windows-cross check
windows-cross cache
windows-cross test
cd /caminho/projeto-rust
windows-cross exec cargo xwin build --target x86_64-pc-windows-msvc
```

`test` cria e remove somente seu próprio diretório temporário. Confere PE x64 com `file` e LLVM; não executa o resultado. Builds usam um job por padrão; configure `CARGO_BUILD_JOBS` explicitamente para alterar isso.

## Dados e isolamento

| Conteúdo | Local padrão |
| --- | --- |
| Rust/Cargo privados | `~/.local/share/dotfiles-windows-cross/{rustup,cargo}` |
| SDKs opcionais | `~/.local/share/dotfiles-windows-cross/sdks/` |
| Runtimes opcionais | `~/.local/share/dotfiles-windows-cross/runtimes/` |
| NSIS privado | `~/.local/share/dotfiles-windows-cross/packaging/` |
| CRT/SDK Microsoft | `~/.cache/dotfiles-windows-cross/xwin/` |
| Downloads verificados reutilizáveis | `~/.cache/dotfiles-windows-cross/downloads/` |

`XDG_DATA_HOME` e `XDG_CACHE_HOME` permitem escolher outros diretórios absolutos fora do Git. Apenas scripts, manifests de URLs/hashes, testes e documentação são versionados. A preparação conserva os downloads verificados para evitar novo tráfego; a extração completa é temporária, e somente a seleção de arquivos é publicada. A preparação pode exigir vários GB temporariamente. Não há comando de limpeza automática de caches.

O uso do cargo-xwin implica aceitar a [licença Microsoft](https://go.microsoft.com/fwlink/?LinkId=2086102). O cargo-xwin valida downloads segundo os manifests Microsoft; SDK/CRT seguem a seleção upstream, que pode mudar. Para fixar um build de projeto, registre `XWIN_VERSION`, `XWIN_SDK_VERSION` e `XWIN_CRT_VERSION` conforme a [documentação oficial](https://github.com/rust-cross/cargo-xwin), junto das versões de Rust, cargo-xwin e do lockfile do projeto. Os dotfiles não afirmam gerar artefatos idênticos byte a byte entre instalações.

## SDKs nativos opcionais

O primeiro perfil é GStreamer/GES **1.26.11 MSVC x64**. A série 1.26 usa MSI de runtime e desenvolvimento separados; a série 1.28 usa Inno Setup. Não se pode trocar apenas a URL para um EXE 1.28. A preparação implementada usa `msiextract`, do pacote oficial Arch `msitools`. Não executa instaladores Windows.

```bash
sudo pacman -Syu --needed msitools
windows-cross sdk prepare
windows-cross sdk check
windows-cross sdk test  # linka um programa Rust com GStreamer e GES
sdk="$(windows-cross sdk path)"
windows-cross exec-sdk "$sdk" cargo xwin build --target x86_64-pc-windows-msvc
```

O SDK contém headers, `.pc`, import libraries `.lib` e arquivos de licença quando presentes na distribuição. Não contém DLLs de runtime, plugins, executáveis nem bibliotecas estáticas `.a`. A arquitetura das import libraries GStreamer, GES e GLib é verificada por LLVM; o inventário SHA-256 detecta arquivos removidos ou alterados. A validação do adaptador pkg-config também verifica cada biblioteca solicitada. Preparação repetida verifica a instalação existente, sem baixar/copiar novamente. Uma instalação incompleta ou um download com hash errado é recusado e preservado; escolha outro `XDG_DATA_HOME`/`XDG_CACHE_HOME` para refazer sem apagar arquivos preexistentes.

Para outras bibliotecas, prepare um SDK Windows separado e defina um adaptador por projeto em `PKG_CONFIG_x86_64_pc_windows_msvc`; use `windows-cross exec ...` para executar o projeto. Não selecione `WINDOWS_CROSS_SDK` nesse caso, pois essa variável ativa o perfil GStreamer validado deste módulo. O perfil `exec-sdk` valida o inventário GStreamer dos dotfiles; SDKs arbitrários usam seu próprio verificador e `PKG_CONFIG_x86_64_pc_windows_msvc` explícito. O diretório do SDK nunca entra no PATH Linux.

Sem SDK selecionado, o adaptador padrão falha em qualquer consulta de pkg-config para Windows. Com SDK, ele ignora buscas globais e permite apenas headers e `.lib` dentro da raiz selecionada, rejeitando ELF, outras arquiteturas e flags não reconhecidas. Variáveis do target só existem no processo iniciado. Consultas do host Linux permanecem independentes. Um adaptador específico definido explicitamente pelo projeto é preservado; esse adaptador assume a responsabilidade pelo isolamento. Não defina `PKG_CONFIG_ALLOW_CROSS=1` globalmente.

## Runtimes e redistribuição

```bash
windows-cross runtime prepare
windows-cross runtime check
windows-cross runtime path
```

O runtime GStreamer 1.26.11 é obtido do MSI oficial, com SHA-256 fixado em `artifacts.json` a partir do arquivo `.sha256sum` publicado pelo GStreamer. Inclui DLLs, plugins, scanner, ferramentas Windows e dados; eles ficam separados dos arquivos de compilação e não entram no PATH Linux. O projeto deve escolher e copiar os componentes que usa para seu pacote, junto das licenças obtidas dos fontes oficiais de cada componente. O MSI de runtime consultado não inclui textos de licença: não trate sua extração como pacote pronto para redistribuição. A presença dos arquivos não comprova que um codec ou preview funciona no Windows: valide a execução e os elementos `glshader`, `pitch`, `wasapi2sink` no processo Windows.

FFmpeg e llama.cpp não são impostos nem baixados automaticamente. Cada projeto define versão, URL HTTPS oficial ou fornecedor aprovado, SHA-256 publicado por fonte confiável, arquitetura e licenças. Disponibilize esses runtimes em uma pasta fora do Git antes de empacotar, e configure os caminhos do empacotador do projeto; não use a instalação anterior do aplicativo como fonte. O teste de hash é reutilizável em `native.py`, mas adicionar um novo fornecedor requer um perfil de extração e validação apropriado. Não derive um hash confiável apenas do download que ele deveria verificar. Modelos e pesos de IA não pertencem aos dotfiles.

GStreamer é predominantemente LGPL, mas plugins e dependências têm licenças próprias; a seleção redistribuída exige revisar e fornecer os textos de licença dos componentes selecionados. FFmpeg pode incluir componentes GPL e codecs com condições adicionais. O projeto é responsável por avisos, fontes/ofertas e condições de redistribuição aplicáveis. VC++ Redistributable e WebView2 são runtimes Windows permitidos, obtidos pelos instaladores oficiais ou pelo empacotador do aplicativo.

## NSIS opcional

```bash
windows-cross nsis prepare
windows-cross nsis check
windows-cross nsis test
windows-cross exec-nsis npm run tauri -- build --runner cargo-xwin --target x86_64-pc-windows-msvc --bundles nsis
```

O Arch consultado não fornece NSIS em seus repositórios oficiais. O perfil usa os pacotes oficiais Debian trixie `nsis` e `nsis-common` 3.11-1 amd64, com hashes do índice Debian HTTPS, extraídos localmente com bsdtar. Requer host x86_64/glibc compatível; `check` executa o compilador Linux e confere stubs Unicode, MUI2 e plugins padrão. Nenhum pacote Debian é instalado no sistema. Os arquivos de copyright Debian acompanham o pacote.

O Tauri baixa e verifica seu plugin `nsis_tauri_utils` conforme a versão do CLI fixada pelo projeto. Esse plugin específico e quaisquer plugins customizados não fazem parte do NSIS padrão; permita rede no primeiro bundle. Não use `--no-bundle` ao gerar NSIS. Para combinar com SDK, use `WINDOWS_CROSS_SDK="$sdk" windows-cross exec-nsis ...`. O empacotamento deve ter seus runtimes preparados previamente. MSI e assinatura não são preparados por este módulo.

## Validação

```bash
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s wsl/tools/windows-cross -p test_native.py -v
bash -n wsl/tools/windows-cross.sh
```

Os testes cobrem downloads adulterados, preservação de caches, instalação incompleta, inventário corrompido, arquitetura incorreta e rejeição de caminhos Linux. Rode também `windows-cross sdk test` para conferir linkedição real com GStreamer/GES e `windows-cross test` para validar realmente o Rust/MSVC, e um build do seu projeto para validar dependências nativas. A execução Windows exige interoperabilidade WSL e as DLLs/runtimes do aplicativo; não há Wine nem ferramentas de compilação Windows neste fluxo.

Fontes: [GStreamer e formatos dos instaladores](https://gstreamer.freedesktop.org/download/), [distribuição MSI 1.26.11 e hashes](https://gstreamer.freedesktop.org/data/pkg/windows/1.26.11/msvc/), [Tauri Windows/NSIS](https://v2.tauri.app/distribute/windows-installer/), [NSIS em POSIX](https://nsis.sourceforge.io/Docs/AppendixG.html).

## Resultados da validação em 2026-11-11

Exemplo de execução nesta máquina, não requisito de instalação: reaplicação da toolchain reutilizou os componentes existentes; nove testes automatizados passaram; Rust mínimo gerou PE x64 e executou nativamente no Windows via WSL. `sdk test` linkou Rust com GStreamer/GES 1.26.11 e confirmou PE x64. O runtime recém-extraído reconheceu `glshader`, `pitch` e `wasapi2sink` ao executar `gst-inspect-1.0.exe` pelo PowerShell Windows. Os arquivos extraídos de MSI não recebem permissão de execução Linux: use PowerShell com caminho Windows para essas ferramentas, ou copie o runtime para o pacote do aplicativo.

`nsis test` gerou um instalador com MUI2, System, nsDialogs e NSISdl. O teste não instalou esse pacote no Windows. O build adicional do AutoCut passou com seu adaptador e SDK 1.28.6 anteriores, preservando suas features; a interface do AutoCut não foi testada nesta execução. Seu adaptador atual exige uma DLL junto do SDK, portanto ainda precisa ser adaptado no próprio projeto para consumir diretamente os novos diretórios separados de SDK/runtime. O smoke GStreamer deste módulo usa somente o SDK compartilhado 1.26.11 recém-preparado.

Espaço aproximado observado: SDK reduzido 36 MB, runtime 288 MB, NSIS 8,3 MB, downloads preservados 439 MB, cache Microsoft 631 MB. Rust/rustup e Cargo privados somavam cerca de 1,4 GB após os builds, incluindo crates acumuladas. Esses tamanhos variam com uso e filesystem.

O `sudo` desta sessão exigiu senha: `msitools` não foi instalado no sistema. Para validar a extração, foram usados temporariamente os pacotes oficiais Arch de msitools, gcab e libgsf, com assinaturas verificadas pelo keyring Arch. Em instalação limpa, execute o comando pacman da seção SDK. FFmpeg/llama.cpp e a seleção de licenças para redistribuição continuam sob configuração de cada projeto; nenhuma instalação anterior do aplicativo é necessária para obter os arquivos GStreamer deste módulo.
