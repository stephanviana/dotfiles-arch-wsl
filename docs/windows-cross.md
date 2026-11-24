# Compilação cruzada Windows x64 no Arch/WSL 2

Este módulo opcional prepara uma toolchain isolada para gerar executáveis `x86_64-pc-windows-msvc` a partir do Arch. Ele não faz parte de `--all`; os comandos e dependências da aplicação continuam no próprio projeto.

## Instalar e usar

Na raiz do checkout Arch:

```bash
bash wsl/install.sh --windows-cross
windows-cross check
windows-cross test
```

A etapa instala as ferramentas necessárias do Arch, prepara um perfil Rust/Cargo privado, instala cargo-xwin e obtém o SDK/CRT Microsoft. As versões iniciais estão em [windows-cross.sh](../wsl/tools/windows-cross.sh); perfis existentes são preservados e `check` informa suas versões.

Para compilar um projeto Cargo:

```bash
cd /caminho/projeto-rust
windows-cross exec cargo xwin build --target x86_64-pc-windows-msvc
```

`windows-cross test` cria um projeto temporário e confirma que o resultado é PE x64. Não executa o binário nem valida dependências ou interface da aplicação. Os builds usam um job por padrão; ajuste `CARGO_BUILD_JOBS` se necessário.

O comando `windows-cross` é um link para este checkout, que precisa permanecer disponível. Execute-o normalmente, sem `source`; as variáveis da toolchain ficam restritas ao processo iniciado.

## Arquivos e cache

| Conteúdo | Local padrão |
| --- | --- |
| Rust/Cargo privados | `~/.local/share/dotfiles-windows-cross/{rustup,cargo}` |
| SDKs, runtimes e NSIS opcionais | `~/.local/share/dotfiles-windows-cross/{sdks,runtimes,packaging}` |
| SDK/CRT Microsoft | `~/.cache/dotfiles-windows-cross/xwin` |
| Downloads reutilizáveis | `~/.cache/dotfiles-windows-cross/downloads` |

`XDG_DATA_HOME` e `XDG_CACHE_HOME` permitem alterar essas raízes. A preparação pode usar vários GB temporariamente e preserva downloads verificados para reutilização. Não há limpeza automática de caches.

Os pacotes do sistema acompanham o Arch. Para controlar versões de SDK/CRT por projeto, use as opções documentadas pelo [cargo-xwin](https://github.com/rust-cross/cargo-xwin). Instalar os dotfiles em máquinas diferentes não garante artefatos idênticos byte a byte.

## SDK e runtime GStreamer opcionais

O perfil disponível é GStreamer/GES 1.26.11 MSVC x64. Ele usa URLs e hashes do [manifesto](../wsl/tools/windows-cross/artifacts.json) e extrai os pacotes MSI sem executar instaladores Windows. Instale `msitools` antes de preparar os arquivos:

```bash
sudo pacman -Syu --needed msitools
windows-cross sdk prepare
windows-cross sdk check
windows-cross sdk test
sdk="$(windows-cross sdk path)"
windows-cross exec-sdk "$sdk" cargo xwin build --target x86_64-pc-windows-msvc
```

O SDK contém headers, metadados pkg-config e import libraries `.lib`. As DLLs, plugins, ferramentas e dados de execução ficam separados:

```bash
windows-cross runtime prepare
windows-cross runtime check
windows-cross runtime path
```

O adaptador valida inventário e arquitetura e restringe a busca aos arquivos Windows do SDK selecionado. Sem um SDK, consultas pkg-config para o target falham em vez de usar bibliotecas Linux. Instalações incompletas ou arquivos alterados são recusados e preservados para revisão.

`exec-sdk` usa o perfil GStreamer validado. Para outras bibliotecas, o projeto deve fornecer um SDK Windows e seu próprio `PKG_CONFIG_x86_64_pc_windows_msvc`, usando `windows-cross exec`. Não defina `PKG_CONFIG_ALLOW_CROSS=1` globalmente. A seleção de runtimes e seu empacotamento pertencem à aplicação.

## NSIS opcional

```bash
windows-cross nsis prepare
windows-cross nsis check
windows-cross nsis test
windows-cross exec-nsis makensis /caminho/instalador.nsi
```

O perfil extrai os pacotes NSIS definidos no manifesto para um diretório privado, sem instalá-los no sistema. O projeto fornece o script `.nsi`, os arquivos da aplicação e plugins adicionais. MSI e assinatura não são preparados por este módulo.

## Validar o módulo

Na raiz do checkout:

```bash
PYTHONDONTWRITEBYTECODE=1 python -m unittest discover -s wsl/tools/windows-cross -p test_native.py -v
bash -n wsl/tools/windows-cross.sh
```

Os testes verificam integridade dos arquivos, caches, inventários, arquitetura e isolamento das bibliotecas Linux. `windows-cross test` e `windows-cross sdk test` verificam compilação e linkedição reais. A execução e o comportamento do programa gerado precisam ser testados no Windows com seus runtimes.
