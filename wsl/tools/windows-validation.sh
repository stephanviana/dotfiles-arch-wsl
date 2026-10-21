#!/usr/bin/env bash
# Managed by dotfiles-wsl-arch.
set -Eeuo pipefail

runtime="$HOME/.local/bin/windows-validation"
if [[ ${1:-} == --install ]]; then
    mkdir -p "$HOME/.local/bin"
    if [[ -e "$runtime" || -L "$runtime" ]]; then
        if [[ -L "$runtime" ]] || ! grep -Fq 'Managed by dotfiles-wsl-arch.' "$runtime"; then
            printf 'Refusing to replace an unrelated launcher: %s\n' "$runtime" >&2
            exit 1
        fi
    fi
    install -m 0755 "$0" "$runtime"
    for alias in windows-sync validate-windows; do
        link="$HOME/.local/bin/$alias"
        if [[ -e "$link" || -L "$link" ]]; then
            if [[ ! -L "$link" || $(readlink "$link") != windows-validation ]]; then
                printf 'Refusing to replace an existing command: %s\n' "$link" >&2
                exit 1
            fi
        else
            ln -s windows-validation "$link"
        fi
    done
    printf 'Installed windows-sync and validate-windows in %s\n' "$HOME/.local/bin"
    exit 0
fi

case $(basename "$0") in
    windows-sync) mode='Sync' ;;
    validate-windows) mode='Validate' ;;
    *) printf 'Run windows-sync or validate-windows instead.\n' >&2; exit 2 ;;
esac
if (( $# > 1 )); then
    printf 'Usage: %s [project-directory]\n' "$(basename "$0")" >&2
    exit 2
fi

if (( $# == 1 )); then
    project_dir="$1"
elif git -C "$PWD" rev-parse --show-toplevel >/dev/null 2>&1; then
    project_dir="$(git -C "$PWD" rev-parse --show-toplevel)"
else
    project_dir="$PWD"
fi
project_dir="$(realpath -e "$project_dir")"
dev_root="$(realpath -e "$HOME/dev")"
if [[ $project_dir != "$dev_root/"* ]] ||
    [[ ${project_dir#"$dev_root/"} == */* ]]; then
    printf 'Project must be directly under %s\n' "$dev_root" >&2
    exit 1
fi
project_name="${project_dir##*/}"
if [[ ! $project_name =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]]; then
    printf 'Project directory must have a simple ASCII name: %s\n' "$project_name" >&2
    exit 1
fi

cmd_exe='/mnt/c/Windows/System32/cmd.exe'
powershell_exe='/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe'
if [[ ! -x $cmd_exe || ! -x $powershell_exe ]]; then
    printf 'Windows interop is unavailable.\n' >&2
    exit 1
fi

localappdata="$("$cmd_exe" /C echo %LOCALAPPDATA% | tr -d '\r' | tail -n 1)"
if [[ ! $localappdata =~ ^[A-Za-z]:\\ ]]; then
    printf 'Could not locate Windows LOCALAPPDATA.\n' >&2
    exit 1
fi
runner_win="$localappdata\\dotfiles-wsl-arch\\validate-project.ps1"
runner_linux="$(wslpath -u "$runner_win")"
if [[ ! -f $runner_linux ]]; then
    printf 'Windows runner missing: %s. Re-run windows/setup.ps1.\n' "$runner_win" >&2
    exit 1
fi

source_win="$(wslpath -w "$project_dir")"
runner_args=(-NoLogo -NoProfile -ExecutionPolicy Bypass
    -File "$runner_win" -Source "$source_win" -Project "$project_name" -Mode "$mode")
if [[ -n ${WINDOWS_VALIDATION_ROOT:-} ]]; then
    runner_args+=(-TargetRoot "$WINDOWS_VALIDATION_ROOT")
fi
exec "$powershell_exe" "${runner_args[@]}"
