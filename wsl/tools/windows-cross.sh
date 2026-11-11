#!/usr/bin/env bash
# Isolated Windows MSVC cross-compilation environment for Arch Linux.
set -Eeuo pipefail

tools_dir="$(dirname "$(readlink -f "$0")")"
target=x86_64-pc-windows-msvc
cross_version=0.23.1
rust_version=1.99.1
root="${XDG_DATA_HOME:-$HOME/.local/share}/dotfiles-windows-cross"
export RUSTUP_HOME="$root/rustup" CARGO_HOME="$root/cargo"
export XWIN_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-windows-cross/xwin"
export XWIN_ARCH="${XWIN_ARCH:-x86_64}"
export PATH="$CARGO_HOME/bin:$PATH"
export CARGO_BUILD_JOBS="${CARGO_BUILD_JOBS:-1}"
export PYTHONDONTWRITEBYTECODE=1
unset RUSTUP_TOOLCHAIN
# Never fall back to Linux pkg-config metadata for this target.
export PKG_CONFIG_x86_64_pc_windows_msvc="${PKG_CONFIG_x86_64_pc_windows_msvc:-$tools_dir/windows-cross/pkg-config.py}"
export PKG_CONFIG_PATH_x86_64_pc_windows_msvc=
export PKG_CONFIG_LIBDIR_x86_64_pc_windows_msvc="${PKG_CONFIG_LIBDIR_x86_64_pc_windows_msvc:-/nonexistent/windows-cross-no-sdk}"
export PKG_CONFIG_SYSROOT_DIR_x86_64_pc_windows_msvc=
unset PKG_CONFIG_ALLOW_CROSS PKG_CONFIG_ALLOW_CROSS_x86_64_pc_windows_msvc
if [[ -n ${WINDOWS_CROSS_SDK:-} ]]; then
    export PKG_CONFIG_x86_64_pc_windows_msvc="$tools_dir/windows-cross/pkg-config.py"
    export PKG_CONFIG_LIBDIR_x86_64_pc_windows_msvc="$WINDOWS_CROSS_SDK/lib/pkgconfig:$WINDOWS_CROSS_SDK/share/pkgconfig"
fi
packages=(clang llvm lld cmake ninja pkgconf file curl base-devel python)

fail() { printf 'windows-cross: %s\n' "$*" >&2; exit 1; }
check() {
    local missing=0 cmd
    for cmd in clang-cl lld-link llvm-rc llvm-readobj cmake ninja pkgconf file; do
        if ! command -v "$cmd" >/dev/null; then
            printf 'Ausente: %s\n' "$cmd" >&2
            missing=1
        fi
    done
    if [[ ! -x $CARGO_HOME/bin/rustup ]]; then
        printf 'Ausente: rustup isolado em %s\n' "$CARGO_HOME/bin" >&2
        missing=1
    elif ! "$CARGO_HOME/bin/rustup" target list --installed | grep -Fxq "$target"; then
        printf 'Target Rust ausente: %s\n' "$target" >&2
        missing=1
    fi
    if [[ ! -x $CARGO_HOME/bin/cargo-xwin ]]; then
        printf 'Ausente: cargo-xwin isolado\n' >&2
        missing=1
    fi
    if (( missing )); then
        printf 'Execute: bash wsl/install.sh --windows-cross\n' >&2
        return 1
    fi
    rustc --version
    cargo xwin --version
    clang-cl --version | head -n 1
    [[ -z ${WINDOWS_CROSS_SDK:-} ]] || python3 "$tools_dir/windows-cross/native.py" sdk check
    printf 'Ferramentas e target encontrados. Cache do SDK: %s\n' "$XWIN_CACHE_DIR"
}

install_toolchain() {
    [[ -f /etc/arch-release ]] || fail 'Instalacao disponivel somente no Arch Linux.'
    if ! pacman -Qq "${packages[@]}" >/dev/null 2>&1; then
        sudo pacman -Syu --needed --noconfirm "${packages[@]}"
    fi
    if [[ ! -x $CARGO_HOME/bin/rustup ]]; then
        local temp
        temp="$(mktemp -d)"
        ( trap 'rm -rf -- "$temp"' EXIT
          curl --fail --location --proto '=https' --tlsv1.2 \
              https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init \
              --output "$temp/rustup-init" || fail 'Download do rustup falhou; confira rede e DNS.'
          chmod +x "$temp/rustup-init"
          "$temp/rustup-init" -y --no-modify-path --profile minimal --default-toolchain "$rust_version"
        )
    fi
    if ! rustup target list --installed | grep -Fxq "$target"; then
        rustup target add "$target"
    fi
    if [[ ! -x $CARGO_HOME/bin/cargo-xwin ]]; then
        cargo install --locked --version "$cross_version" --jobs "$CARGO_BUILD_JOBS" cargo-xwin
    fi
    install_launcher
    check
    printf 'Preparando SDK Microsoft. Licenca: https://go.microsoft.com/fwlink/?LinkId=2086102\n'
    cargo xwin cache xwin
}

install_launcher() {
    local launcher="$HOME/.local/bin/windows-cross"
    mkdir -p "$(dirname "$launcher")"
    if [[ -e $launcher || -L $launcher ]]; then
        [[ -L $launcher && $(readlink "$launcher") == "$tools_dir/windows-cross.sh" ]] || fail "Launcher existente preservado: $launcher"
    else
        ln -s "$tools_dir/windows-cross.sh" "$launcher"
    fi
}

smoke() {
    check
    local temp exe headers
    temp="$(mktemp -d)"
    ( trap 'rm -rf -- "$temp"' EXIT
      mkdir -p "$temp/src"
      cat > "$temp/Cargo.toml" <<'EOF'
[package]
name = "windows-cross-smoke"
version = "0.1.0"
edition = "2021"
EOF
      printf 'fn main() { println!("Windows cross-compilation OK"); }\n' > "$temp/src/main.rs"
      cd "$temp"
      export CARGO_TARGET_DIR="$temp/target"
      cargo xwin build --target "$target" --jobs "$CARGO_BUILD_JOBS" || fail 'Falha na compilacao de teste com cargo-xwin.'
      exe="$temp/target/$target/debug/windows-cross-smoke.exe"
      [[ -f $exe ]] || fail 'Executavel de teste nao encontrado.'
      file "$exe"
      headers="$(llvm-readobj --file-headers "$exe")" || fail 'Nao foi possivel ler os cabecalhos PE.'
      [[ $headers == *'Format: COFF-x86-64'* && $headers == *'IMAGE_FILE_MACHINE_AMD64'* ]] || fail 'O arquivo gerado nao e um PE Windows x64.'
      printf 'Teste de compilacao Windows PE x64 concluido.\n'
    )
}

case "${1:-}" in
    sdk|runtime|nsis) [[ $# == 2 ]] || fail 'Uso: windows-cross {sdk|runtime|nsis} {prepare|check|path}'; python3 "$tools_dir/windows-cross/native.py" "$@" ;;
    exec-sdk) shift; (( $# >= 2 )) || fail 'Uso: windows-cross exec-sdk /sdk comando [args]'; export WINDOWS_CROSS_SDK="$(realpath -e "$1")"; shift; check; exec "$@" ;;
    exec-nsis) shift; (( $# )) || fail 'Uso: windows-cross exec-nsis comando [args]'; nsis_root="$(python3 "$tools_dir/windows-cross/native.py" nsis path | tail -n 1)"; export NSISDIR="$nsis_root/usr/share/nsis"; export PATH="$nsis_root/usr/bin:$PATH"; check; exec "$@" ;;
    install) [[ $# == 1 ]] || fail 'Uso: windows-cross.sh install'; install_toolchain ;;
    check) [[ $# == 1 ]] || fail 'Uso: windows-cross.sh check'; check ;;
    cache) [[ $# == 1 ]] || fail 'Uso: windows-cross.sh cache'; check; cargo xwin cache xwin ;;
    test) [[ $# == 1 ]] || fail 'Uso: windows-cross.sh test'; smoke ;;
    exec) shift; (( $# )) || fail 'Uso: windows-cross.sh exec comando [argumentos...]'; check; exec "$@" ;;
    *) printf 'Uso: %s {install|check|cache|test|sdk|runtime|nsis|exec|exec-sdk|exec-nsis}\n' "$0" >&2; exit 2 ;;
esac
