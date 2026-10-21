#!/usr/bin/env bash
# Build a minimal Kotlin Android app on the Linux filesystem.
set -euo pipefail

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${JAVA_HOME:-/usr/lib/jvm/java-17-openjdk}"
export PATH="$JAVA_HOME/bin:$PATH"

mkdir -p "$HOME/dev"
workdir="$(mktemp -d "$HOME/dev/.android-smoke.XXXXXX")"
cleanup() {
    if [[ $workdir == "$HOME/dev/.android-smoke."* ]]; then
        rm -rf -- "$workdir"
    fi
}
trap cleanup EXIT

mkdir -p "$workdir/app/src/main/kotlin/dev/smoke"
cat > "$workdir/settings.gradle" <<'EOF'
pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }
}
dependencyResolutionManagement {
    repositoriesMode.set(RepositoriesMode.FAIL_ON_PROJECT_REPOS)
    repositories {
        google()
        mavenCentral()
    }
}
rootProject.name = 'android-smoke'
include ':app'
EOF
cat > "$workdir/build.gradle" <<'EOF'
plugins {
    id 'com.android.application' version '9.4.0' apply false
}
EOF
cat > "$workdir/app/build.gradle" <<'EOF'
plugins {
    id 'com.android.application'
}
android {
    namespace 'dev.smoke'
    compileSdk 36
    defaultConfig {
        applicationId 'dev.smoke'
        minSdk 24
        targetSdk 36
    }
}
EOF
cat > "$workdir/gradle.properties" <<'EOF'
org.gradle.jvmargs=-Xmx2g -Dfile.encoding=UTF-8
org.gradle.workers.max=2
EOF
cat > "$workdir/app/src/main/AndroidManifest.xml" <<'EOF'
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application android:label="Smoke">
        <activity android:name=".MainActivity" android:exported="true">
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>
    </application>
</manifest>
EOF
cat > "$workdir/app/src/main/kotlin/dev/smoke/MainActivity.kt" <<'EOF'
package dev.smoke

import android.app.Activity

class MainActivity : Activity()
EOF

gradle --project-dir "$workdir" --no-daemon --console=plain :app:assembleDebug
test -s "$workdir/app/build/outputs/apk/debug/app-debug.apk"
printf 'Android/Kotlin APK built successfully on the Arch filesystem.\n'
