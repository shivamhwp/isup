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
    BINARY_NAME="isup"
elif [ "$PLATFORM" = "windows" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    BINARY_NAME="isup.exe"
elif [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
    BINARY_NAME="isup"
else
    INSTALL_DIR="$HOME/.local/bin"
    BINARY_NAME="isup"
fi

# Check if isup is installed
if [ ! -f "$INSTALL_DIR/$BINARY_NAME" ]; then
    progress "isup is not installed at $INSTALL_DIR/$BINARY_NAME"
    exit 1
fi

# Uninstall auto-start configuration based on platform
if [ "$PLATFORM" = "darwin" ]; then
    # macOS - Launch Agent
    LAUNCH_AGENT_FILE="$HOME/Library/LaunchAgents/com.shivamhwp.isup.plist"
    
    if [ -f "$LAUNCH_AGENT_FILE" ]; then
        progress "unloading and removing launch agent..."
        launchctl unload "$LAUNCH_AGENT_FILE" 2>/dev/null || true
        rm -f "$LAUNCH_AGENT_FILE"
    fi
elif [ "$PLATFORM" = "linux" ]; then
    # Linux - Systemd User Service
    if command -v systemctl >/dev/null; then
        if systemctl --user list-unit-files | grep -q "isup.service"; then
            progress "stopping and disabling systemd service..."
            systemctl --user stop isup.service 2>/dev/null || true
            systemctl --user disable isup.service 2>/dev/null || true
            
            # Remove service file
            SYSTEMD_FILE="$HOME/.config/systemd/user/isup.service"
            if [ -f "$SYSTEMD_FILE" ]; then
                rm -f "$SYSTEMD_FILE"
                systemctl --user daemon-reload
            fi
        fi
    fi
    
    # Linux - Desktop Entry
    DESKTOP_FILE="$HOME/.config/autostart/isup.desktop"
    if [ -f "$DESKTOP_FILE" ]; then
        progress "removing desktop autostart entry..."
        rm -f "$DESKTOP_FILE"
    fi
elif [ "$PLATFORM" = "windows" ]; then
    # Windows - Startup Script
    STARTUP_SCRIPT="$APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\isup.vbs"
    if [ -f "$STARTUP_SCRIPT" ]; then
        progress "removing startup script..."
        rm -f "$STARTUP_SCRIPT"
    fi
fi

# Remove the binary
progress "removing isup binary..."
rm -f "$INSTALL_DIR/$BINARY_NAME"

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