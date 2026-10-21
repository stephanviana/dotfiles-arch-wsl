#!/usr/bin/env bash
# Install a pinned Supabase CLI binary in the Linux home directory.
set -euo pipefail

version='2.118.0'
archive="supabase_${version}_linux_amd64.tar.gz"
sha256='f6089a86fb9d9221c958193a277338daddd6822f706929943812fa32e106c86d'
binary="$HOME/.local/bin/supabase"

if [[ -x "$binary" ]] && "$binary" --version | grep -Fxq "$version"; then
    printf 'Supabase CLI %s already installed.\n' "$version"
    exit 0
fi

temp_dir="$(mktemp -d)"
trap 'rm -rf "$temp_dir"' EXIT
curl --fail --location --retry 3 \
    "https://github.com/supabase/cli/releases/download/v${version}/${archive}" \
    --output "$temp_dir/$archive"
printf '%s  %s\n' "$sha256" "$temp_dir/$archive" | sha256sum --check
tar -xzf "$temp_dir/$archive" -C "$temp_dir" supabase
mkdir -p "$HOME/.local/bin"
install -m 0755 "$temp_dir/supabase" "$binary"
"$binary" --version
