#!/bin/bash
set -e

progress() {
    echo "=> $1"
}

# Determine OS
PLATFORM="unknown"
case "$(uname -s)" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="darwin";;
    MSYS*|MINGW*) PLATFORM="windows";;
    *)          
        echo "Error: Unsupported platform: $(uname -s)"
        echo "Please hit me up here : https://x.com/shivamhwp"
        exit 1
        ;;
esac

# Determine install location
if [ "$PLATFORM" = "darwin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
elif [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
fi

# Check if isup is installed
if [ ! -f "$INSTALL_DIR/isup" ]; then
    progress "isup is not installed at $INSTALL_DIR/isup"
    exit 1
fi

# Uninstall launch agent if on macOS
if [ "$PLATFORM" = "darwin" ]; then
    LAUNCH_AGENT_FILE="$HOME/Library/LaunchAgents/com.shivamhwp.isup.plist"
    
    if [ -f "$LAUNCH_AGENT_FILE" ]; then
        progress "unloading and removing launch agent..."
        launchctl unload "$LAUNCH_AGENT_FILE" 2>/dev/null || true
        rm -f "$LAUNCH_AGENT_FILE"
    fi
fi

# Remove the binary
progress "removing isup binary..."
rm -f "$INSTALL_DIR/isup"

# Remove data directory
progress "removing isup data directory..."
rm -rf "$HOME/.isup"

# Clean up PATH if needed
SHELL_NAME="$(basename "$SHELL")"
if [ "$SHELL_NAME" = "zsh" ] && [ -f "$HOME/.zshrc" ]; then
    progress "removing isup from PATH in .zshrc..."
    sed -i.bak "/export PATH=\"$INSTALL_DIR:\$PATH\"/d" "$HOME/.zshrc"
    rm -f "$HOME/.zshrc.bak"
elif [ "$SHELL_NAME" = "bash" ] && [ -f "$HOME/.bashrc" ]; then
    progress "removing isup from PATH in .bashrc..."
    sed -i.bak "/export PATH=\"$INSTALL_DIR:\$PATH\"/d" "$HOME/.bashrc"
    rm -f "$HOME/.bashrc.bak"
fi

progress "✅ isup has been uninstalled successfully!"
progress "note: if you installed any dependencies (like terminal-notifier), they have not been removed" 