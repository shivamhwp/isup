#!/bin/bash
set -e

progress() {
    echo "=> $1"
}

# Determine latest version if not specified
VERSION=${1:-$(curl -s https://api.github.com/repos/shivamhwp/isup/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/')}

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

ARCH="x86_64"

# Check for platform-specific notification dependencies
if [ "$PLATFORM" = "darwin" ]; then
    progress "checking for terminal-notifier (required for notifications)..."
    if ! command -v terminal-notifier >/dev/null; then
        progress "terminal-notifier not found, installing..."
        if command -v brew >/dev/null; then
            brew install terminal-notifier
        else
            progress "homebrew not found, please install terminal-notifier manually:"
            progress "brew install terminal-notifier"
            progress "or download from: https://github.com/julienXX/terminal-notifier/releases"
        fi
    else
        progress "terminal-notifier is already installed"
    fi
elif [ "$PLATFORM" = "linux" ]; then
    progress "checking for notify-send (required for notifications)..."
    if ! command -v notify-send >/dev/null; then
        progress "notify-send not found, attempting to install..."
        # Try to detect the package manager and install libnotify-bin
        if command -v apt-get >/dev/null; then
            progress "using apt to install libnotify-bin..."
            sudo apt-get update && sudo apt-get install -y libnotify-bin
        elif command -v dnf >/dev/null; then
            progress "using dnf to install libnotify..."
            sudo dnf install -y libnotify
        elif command -v yum >/dev/null; then
            progress "using yum to install libnotify..."
            sudo yum install -y libnotify
        elif command -v pacman >/dev/null; then
            progress "using pacman to install libnotify..."
            sudo pacman -S --noconfirm libnotify
        else
            progress "could not detect package manager, please install notify-send manually:"
            progress "for debian/ubuntu: sudo apt-get install libnotify-bin"
            progress "for fedora: sudo dnf install libnotify"
            progress "for arch: sudo pacman -S libnotify"
        fi
    else
        progress "notify-send is already installed"
    fi
elif [ "$PLATFORM" = "windows" ]; then
    progress "windows notifications use powershell which should be available by default"
    progress "no additional dependencies needed for notifications on windows"
fi

# Construct binary name and URLs
if [ "$PLATFORM" = "windows" ]; then
    BINARY="isup-windows-x86_64.exe"
else
    BINARY="isup-${PLATFORM}-${ARCH}"
fi

DOWNLOAD_URL="https://github.com/shivamhwp/isup/releases/download/v${VERSION}/${BINARY}"
CHECKSUM_URL="${DOWNLOAD_URL}.sha256"

# Create temporary directory
TMP_DIR=$(mktemp -d)
TMP_FILE="${TMP_DIR}/${BINARY}"
TMP_CHECKSUM="${TMP_DIR}/${BINARY}.sha256"

# Download files
progress "downloading isup v${VERSION}..."
if ! curl -sL "$DOWNLOAD_URL" -o "$TMP_FILE" || ! curl -sL "$CHECKSUM_URL" -o "$TMP_CHECKSUM"; then
    echo "Error: Failed to download isup"
    echo "Please check your internet connection or hit me up here : https://x.com/shivamhwp"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Verify checksum (silently)
progress "verifying download..."
EXPECTED_HASH=$(cat "$TMP_CHECKSUM")
if command -v sha256sum >/dev/null; then
    ACTUAL_HASH=$(sha256sum "$TMP_FILE" | awk '{print $1}')
elif command -v shasum >/dev/null; then
    ACTUAL_HASH=$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')
else
    echo "Error: No sha256sum or shasum command found"
    echo "Please install sha256sum or hit me up here : https://x.com/shivamhwp"
    rm -rf "$TMP_DIR"
    exit 1
fi

if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    echo "Error: Verification failed - the download appears to be corrupted"
    echo "Please try again or hit me up here : https://x.com/shivamhwp"
    rm -rf "$TMP_DIR"
    exit 1
fi

# Determine install location
if [ "$PLATFORM" = "darwin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
elif [ "$PLATFORM" = "windows" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
elif [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR"
fi

# Install binary
progress "installing isup..."
if [ "$PLATFORM" = "windows" ]; then
    if ! mv "$TMP_FILE" "$INSTALL_DIR/isup.exe" || ! chmod 755 "$INSTALL_DIR/isup.exe"; then
        echo "Error: Failed to install isup"
        echo "Please check permissions or hit me up here : https://x.com/shivamhwp"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    BINARY_NAME="isup.exe"
else
    if ! mv "$TMP_FILE" "$INSTALL_DIR/isup" || ! chmod 755 "$INSTALL_DIR/isup"; then
        echo "Error: Failed to install isup"
        echo "Please check permissions or hit me up here : https://x.com/shivamhwp"
        rm -rf "$TMP_DIR"
        exit 1
    fi
    BINARY_NAME="isup"
fi

# Handle macOS specific security (silently)
if [ "$PLATFORM" = "darwin" ]; then
    xattr -d com.apple.quarantine "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null || true
fi

# Add to PATH if needed
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    SHELL_NAME="$(basename "$SHELL")"
    if [ "$SHELL_NAME" = "zsh" ] && [ -f "$HOME/.zshrc" ]; then
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.zshrc"
        progress "added $INSTALL_DIR to your PATH in .zshrc"
    elif [ "$SHELL_NAME" = "bash" ] && [ -f "$HOME/.bashrc" ]; then
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc"
        progress "added $INSTALL_DIR to your PATH in .bashrc"
    else
        progress "note: add $INSTALL_DIR to your PATH to use isup from anywhere"
    fi
fi

# Setup auto-start for all platforms
LOG_DIR="$HOME/.isup/logs"
mkdir -p "$LOG_DIR"

# Ask if user wants to install auto-start
read -p "Do you want to install isup to start automatically on login? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    progress "setting up auto-start..."
    
    # macOS - Launch Agent
    if [ "$PLATFORM" = "darwin" ]; then
        LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LAUNCH_AGENT_DIR"
        
        # Create the launch agent plist file
        LAUNCH_AGENT_FILE="$LAUNCH_AGENT_DIR/com.shivamhwp.isup.plist"
        
        cat > "$LAUNCH_AGENT_FILE" << EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.shivamhwp.isup</string>
    <key>ProgramArguments</key>
    <array>
        <string>$INSTALL_DIR/$BINARY_NAME</string>
        <string>daemon</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardErrorPath</key>
    <string>$LOG_DIR/error.log</string>
    <key>StandardOutPath</key>
    <string>$LOG_DIR/output.log</string>
    <key>ProcessType</key>
    <string>Background</string>
</dict>
</plist>
EOL
        
        # Set proper permissions
        chmod 644 "$LAUNCH_AGENT_FILE"
        
        # Check if the service is already running
        if launchctl list | grep -q "com.shivamhwp.isup"; then
            progress "unloading existing launch agent..."
            launchctl unload "$LAUNCH_AGENT_FILE" 2>/dev/null || true
        fi
        
        # Load the launch agent
        progress "loading launch agent..."
        launchctl load "$LAUNCH_AGENT_FILE"
        
        # Verify it's running
        if launchctl list | grep -q "com.shivamhwp.isup"; then
            progress "✅ launch agent installed and running successfully!"
        else
            progress "⚠️ launch agent installation may have failed"
            progress "please check the logs or run manually with: launchctl load $LAUNCH_AGENT_FILE"
        fi
    
    # Linux - Systemd User Service
    elif [ "$PLATFORM" = "linux" ]; then
        # Check if systemd is available
        if command -v systemctl >/dev/null; then
            SYSTEMD_DIR="$HOME/.config/systemd/user"
            mkdir -p "$SYSTEMD_DIR"
            
            # Create systemd service file
            SYSTEMD_FILE="$SYSTEMD_DIR/isup.service"
            
            cat > "$SYSTEMD_FILE" << EOL
[Unit]
Description=isup monitoring service
After=network.target

[Service]
ExecStart=$INSTALL_DIR/$BINARY_NAME daemon
Restart=on-failure
RestartSec=5s

[Install]
WantedBy=default.target
EOL
            
            # Reload systemd
            systemctl --user daemon-reload
            
            # Enable and start the service
            systemctl --user enable isup.service
            systemctl --user start isup.service
            
            progress "✅ systemd user service installed and started!"
            progress "check status with: systemctl --user status isup.service"
        
        # Fallback to desktop entry if systemd is not available
        else
            AUTOSTART_DIR="$HOME/.config/autostart"
            mkdir -p "$AUTOSTART_DIR"
            
            # Create desktop entry
            DESKTOP_FILE="$AUTOSTART_DIR/isup.desktop"
            
            cat > "$DESKTOP_FILE" << EOL
[Desktop Entry]
Type=Application
Name=isup
Exec=$INSTALL_DIR/$BINARY_NAME daemon
Terminal=false
X-GNOME-Autostart-enabled=true
Comment=isup monitoring service
EOL
            
            chmod +x "$DESKTOP_FILE"
            progress "✅ desktop autostart entry created!"
            progress "isup will start automatically on next login"
        fi
    
    # Windows - Startup Folder
    elif [ "$PLATFORM" = "windows" ]; then
        STARTUP_DIR="$APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
        mkdir -p "$STARTUP_DIR" 2>/dev/null || true
        
        # Create VBS script to run without showing a command window
        STARTUP_SCRIPT="$STARTUP_DIR\\isup.vbs"
        
        cat > "$STARTUP_SCRIPT" << EOL
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run chr(34) & "$INSTALL_DIR\\$BINARY_NAME" & chr(34) & " daemon", 0
Set WshShell = Nothing
EOL
        
        progress "✅ startup script created!"
        progress "isup will start automatically on next login"
    fi
fi

# Cleanup
rm -rf "$TMP_DIR"

progress "✅ isup v${VERSION} installed successfully!"

if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    progress "restart your terminal or run 'source ~/.bashrc' or 'source ~/.zshrc'"
fi

progress "run 'isup --help' to get started"
progress "if you encounter any issues, hit me up : https://x.com/shivamhwp" 
