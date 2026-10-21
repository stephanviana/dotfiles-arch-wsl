# Shared Arch shell environment. Source from Bash or Zsh.
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="/usr/lib/jvm/java-17-openjdk"
export ADB_SERVER_SOCKET="tcp:127.0.0.1:5037"
export AGENTMEMORY_URL="http://127.0.0.1:3111"
export LIBCLANG_PATH="/usr/lib"
export PATH="$HOME/.local/bin:${XDG_DATA_HOME:-$HOME/.local/share}/mise/shims:$ANDROID_HOME/cmdline-tools/latest/bin:$JAVA_HOME/bin:$PATH"
