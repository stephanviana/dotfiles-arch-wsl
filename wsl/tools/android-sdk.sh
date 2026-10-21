#!/usr/bin/env bash
# Install a Linux Android SDK without an emulator or Windows SDK paths.
set -euo pipefail

sdk_root="${ANDROID_HOME:-$HOME/Android/Sdk}"
tools_dir="$sdk_root/cmdline-tools/latest"
tools_zip='commandlinetools-linux-15859902_latest.zip'
tools_sha256='4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583'

if [[ ! -x "$tools_dir/bin/sdkmanager" ]]; then
    temp_dir="$(mktemp -d)"
    trap 'rm -rf "$temp_dir"' EXIT
    curl --fail --location --retry 3 \
        "https://dl.google.com/android/repository/$tools_zip" \
        --output "$temp_dir/$tools_zip"
    printf '%s  %s\n' "$tools_sha256" "$temp_dir/$tools_zip" | sha256sum --check
    unzip -q "$temp_dir/$tools_zip" -d "$temp_dir"
    mkdir -p "$sdk_root/cmdline-tools"
    mv "$temp_dir/cmdline-tools" "$tools_dir"
fi

export ANDROID_HOME="$sdk_root"
export ANDROID_SDK_ROOT="$sdk_root"
sdkmanager="$tools_dir/bin/sdkmanager"

# sdkmanager returns the status of the second command in this pipeline.
set +o pipefail
yes | "$sdkmanager" --sdk_root="$sdk_root" --licenses >/dev/null
license_status=${PIPESTATUS[1]}
set -o pipefail
if [[ $license_status -ne 0 ]]; then
    printf 'Android SDK licenses were not accepted.\n' >&2
    exit "$license_status"
fi

"$sdkmanager" --sdk_root="$sdk_root" \
    'platform-tools' 'platforms;android-36' 'build-tools;36.0.0'

printf 'Android SDK: %s\n' "$sdk_root"
"$sdkmanager" --version
"$sdk_root/platform-tools/adb" version | head -n 2
