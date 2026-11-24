#!/usr/bin/env bash
# Install the stable Android Studio package and its WSLg desktop launcher.
set -Eeuo pipefail

tools_dir="$(cd "$(dirname "$0")" && pwd)"
sdk_root="$HOME/Android/Sdk"

# Do not modify any files owned by an open IDE (including VM options).
/usr/bin/python "$tools_dir/android-studio-adb-settings.py" --check-closed

if [[ ! -f /etc/arch-release ]] || [[ $EUID -eq 0 ]]; then
    printf 'Run this installer as a normal Arch Linux user.\n' >&2
    exit 1
fi
if [[ ! -d /mnt/wslg ]] || [[ -z ${DISPLAY:-} && -z ${WAYLAND_DISPLAY:-} ]]; then
    printf 'WSLg is unavailable; enable GUI applications in WSL 2 and restart the distribution.\n' >&2
    exit 1
fi
if [[ ! -x "$sdk_root/cmdline-tools/latest/bin/sdkmanager" ]]; then
    printf 'Linux Android SDK missing at %s; run wsl/install.sh --android first.\n' "$sdk_root" >&2
    exit 1
fi

if ! command -v paru >/dev/null 2>&1; then
    bash "$tools_dir/paru.sh"
fi

# The AUR stable package downloads the official Google tarball and verifies its checksum.
packages=(android-studio mesa libglvnd libxkbcommon gtk3 dconf gsettings-desktop-schemas ttf-dejavu jq)
if ! pacman -Qq "${packages[@]}" >/dev/null 2>&1; then
    export TMPDIR="$HOME/.cache/dotfiles-wsl-arch/tmp"
    mkdir -p "$TMPDIR"
    paru -S --needed --noconfirm --skipreview "${packages[@]}"
fi
if [[ ! -x /opt/android-studio/bin/studio ]]; then
    printf 'Android Studio was not installed at /opt/android-studio/bin/studio.\n' >&2
    exit 1
fi

# Install/update the bridge even when only --android-studio was requested.
bash "$tools_dir/android.sh"
/usr/bin/python "$tools_dir/android-studio-adb-settings.py"

# GTK client-side decorations should expose the usual Windows controls.
gtk_config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-3.0"
mkdir -p "$gtk_config_dir"
if [[ -f "$gtk_config_dir/settings.ini" ]] && \
    ! cmp -s "$tools_dir/../gtk-3.0/settings.ini" "$gtk_config_dir/settings.ini" && \
    [[ ! -e "$gtk_config_dir/settings.ini.bak" ]]; then
    cp -- "$gtk_config_dir/settings.ini" "$gtk_config_dir/settings.ini.bak"
fi
install -m 0644 "$tools_dir/../gtk-3.0/settings.ini" "$gtk_config_dir/settings.ini"
# GTK's GNOME settings backend takes precedence over settings.ini on Wayland.
gsettings set org.gnome.desktop.wm.preferences button-layout ':minimize,maximize,close'
if [[ $(gsettings get org.gnome.desktop.wm.preferences button-layout) != "':minimize,maximize,close'" ]]; then
    printf 'GTK window button layout was not saved.\n' >&2
    exit 1
fi

# Keep the native Wayland window controls used by Android Studio on WSLg.
data_dir="$(jq -er '.dataDirectoryName' /opt/android-studio/product-info.json)"
vm_options="${XDG_CONFIG_HOME:-$HOME/.config}/Google/$data_dir/studio64.vmoptions"
mkdir -p "$(dirname "$vm_options")"
if grep -q '^-Dawt.toolkit.name=' "$vm_options" 2>/dev/null; then
    sed -i 's/^-Dawt.toolkit.name=.*/-Dawt.toolkit.name=WLToolkit/' "$vm_options"
else
    printf '%s\n' '-Dawt.toolkit.name=WLToolkit' >> "$vm_options"
fi

# JBR's Wayland backend otherwise falls back to its basic frame decorations
# when GTK3 is absent. Keep modern GTK controls without changing WSLg itself.
if grep -q '^-Dsun.awt.wl.WindowDecorationStyle=' "$vm_options" 2>/dev/null; then
    sed -i 's/^-Dsun.awt.wl.WindowDecorationStyle=.*/-Dsun.awt.wl.WindowDecorationStyle=gtk/' "$vm_options"
else
    printf '%s\n' '-Dsun.awt.wl.WindowDecorationStyle=gtk' >> "$vm_options"
fi

mkdir -p "$HOME/.local/bin" "$HOME/.local/share/applications"
launcher="$HOME/.local/bin/android-studio-wsl"
install -m 0755 "$tools_dir/android-studio-wsl" "$launcher"

# WSLg scans system application directories for Windows Start menu entries.
# The desktop file ID must match the app_id published by JBR on Wayland.
app_id="$(jq -er '.launch[] | select(.os == "Linux") | .startupWmClass' /opt/android-studio/product-info.json | head -n 1)"
if [[ ! $app_id =~ ^[a-zA-Z0-9_-]+$ ]] || [[ ! -r /opt/android-studio/bin/studio.png ]]; then
    printf 'Android Studio application ID or official PNG icon is unavailable.\n' >&2
    exit 1
fi
desktop_entry="$HOME/.local/share/applications/$app_id.desktop"
# Remove old same-name entries before publishing the canonical name. WSLg can
# otherwise delete the new Windows shortcut when processing the old removal.
mask="$HOME/.local/lib/dotfiles-wsl-arch/android-studio-hidden.desktop"
cat > "$mask" <<'EOF'
[Desktop Entry]
# dotfiles-wsl-arch: hide the package menu entry, preserve its command
Type=Application
Name=Android Studio
Hidden=true
NoDisplay=true
EOF
for legacy_entry in "$HOME/.local/share/applications/android-studio.desktop" \
    /usr/local/share/applications/android-studio.desktop; do
    [[ $app_id != android-studio ]] || continue
    if [[ -f $legacy_entry ]] && ! cmp -s "$mask" "$legacy_entry"; then
        if grep -Fxq "Exec=$launcher" "$legacy_entry" && \
           grep -Fxq 'Name=Android Studio (Arch WSL)' "$legacy_entry"; then
            if [[ -w $(dirname "$legacy_entry") ]]; then
                mv --backup=numbered -- "$legacy_entry" "$legacy_entry.bak"
            else
                sudo mv --backup=numbered -- "$legacy_entry" "$legacy_entry.bak"
            fi
        else
            printf 'Custom desktop entry preserved: %s\n' "$legacy_entry" >&2
            continue
        fi
    fi
    if ! cmp -s "$mask" "$legacy_entry"; then
        if [[ -w $(dirname "$legacy_entry") ]]; then
            install -m 0644 "$mask" "$legacy_entry"
        else
            sudo install -m 0644 "$mask" "$legacy_entry"
        fi
    fi
done

cat > "$desktop_entry" <<EOF
[Desktop Entry]
Type=Application
Version=1.0
Name=Android Studio (Arch WSL)
Comment=Android Studio with the Linux SDK and Windows ADB bridge
Exec=$launcher
Icon=/opt/android-studio/bin/studio.png
Terminal=false
Categories=Development;IDE;
StartupNotify=true
StartupWMClass=$app_id
EOF
# Publish after legacy removals. Preserve an unchanged entry on reapplication;
# replacing it would emit a delete event and churn the Windows shortcut again.
sudo install -d -m 0755 /usr/local/share/applications
if ! cmp -s "$desktop_entry" "/usr/local/share/applications/$app_id.desktop"; then
    sudo install -m 0644 "$desktop_entry" "/usr/local/share/applications/$app_id.desktop"
fi

# The Windows app-list cache can retain a deleted same-name shortcut even after
# newAppId was sent. Reconcile only a missing shortcut; preserve existing ones.
shortcut_setup="$tools_dir/../../windows/setup-android-studio-shortcut.ps1"
timeout 12 /mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe \
    -NoProfile -NonInteractive -ExecutionPolicy Bypass \
    -File "$(/usr/bin/wslpath -m "$shortcut_setup")" \
    -Distro "${WSL_DISTRO_NAME:-archlinux}" -Launcher "$launcher"

printf 'Android Studio %s configured for WSLg and SDK %s.\n' \
    "$(pacman -Q android-studio | awk '{print $2}')" "$sdk_root"
