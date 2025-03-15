#!/bin/bash
set -e

# Fix any potential Windows line endings without dos2unix
sed -i.bak 's/\r$//' "$0" 2>/dev/null || true
rm -f "$0.bak" 2>/dev/null || true

# Ensure the script is executable
chmod +x "$0" 2>/dev/null || true

# Simple progress function
progress() {
    echo "=> $1"
}

# Error handling function
handle_error() {
    echo "Error: $1"
    echo "Please hit me up here : https://x.com/shivamhwp"
    # Clean up if temp dir exists
    if [ -d "$TMP_DIR" ]; then
        rm -rf "$TMP_DIR"
    fi
    exit 1
}

# Determine latest version if not specified
VERSION=${1:-$(curl -s https://api.github.com/repos/shivamhwp/isup/releases/latest | grep '"tag_name":' | sed -E 's/.*"v([^"]+)".*/\1/' || echo "latest")}

# Determine OS
PLATFORM="unknown"
case "$(uname -s)" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="darwin";;
    MSYS*|MINGW*) PLATFORM="windows";;
    *)          
        handle_error "Unsupported platform: $(uname -s)"
        ;;
esac

ARCH="x86_64"

# Check for platform-specific notification dependencies
if [ "$PLATFORM" = "darwin" ]; then
    progress "checking for terminal-notifier..."
    if ! command -v terminal-notifier >/dev/null; then
        progress "terminal-notifier not found, attempting to install..."
        if command -v brew >/dev/null; then
            brew install terminal-notifier >/dev/null 2>&1 || progress "couldn't install terminal-notifier, but continuing anyway"
        else
            progress "homebrew not found, skipping terminal-notifier installation"
            progress "you may want to install terminal-notifier manually for notifications"
        fi
    else
        progress "terminal-notifier is already installed"
    fi
elif [ "$PLATFORM" = "linux" ]; then
    if ! command -v notify-send >/dev/null; then
        progress "notify-send not found, attempting to install..."
        if command -v apt-get >/dev/null; then
            sudo apt-get update -qq >/dev/null 2>&1
            sudo apt-get install -y libnotify-bin >/dev/null 2>&1 || progress "couldn't install libnotify-bin, but continuing anyway"
        elif command -v dnf >/dev/null; then
            sudo dnf install -y libnotify >/dev/null 2>&1 || progress "couldn't install libnotify, but continuing anyway"
        elif command -v yum >/dev/null; then
            sudo yum install -y libnotify >/dev/null 2>&1 || progress "couldn't install libnotify, but continuing anyway"
        elif command -v pacman >/dev/null; then
            sudo pacman -S --noconfirm libnotify >/dev/null 2>&1 || progress "couldn't install libnotify, but continuing anyway"
        else
            progress "no package manager found, skipping libnotify installation"
            progress "you may want to install libnotify manually for notifications"
        fi
    fi
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
TMP_DIR=$(mktemp -d) || handle_error "Failed to create temporary directory"
TMP_FILE="${TMP_DIR}/${BINARY}"
TMP_CHECKSUM="${TMP_DIR}/${BINARY}.sha256"

# Download files
progress "downloading isup v${VERSION}..."
if ! curl -sL "$DOWNLOAD_URL" -o "$TMP_FILE" || ! curl -sL "$CHECKSUM_URL" -o "$TMP_CHECKSUM"; then
    handle_error "Failed to download isup. Please check your internet connection."
fi

# Verify checksum (silently)
progress "verifying download..."
EXPECTED_HASH=$(cat "$TMP_CHECKSUM")
if command -v sha256sum >/dev/null; then
    ACTUAL_HASH=$(sha256sum "$TMP_FILE" | awk '{print $1}')
elif command -v shasum >/dev/null; then
    ACTUAL_HASH=$(shasum -a 256 "$TMP_FILE" | awk '{print $1}')
else
    handle_error "No sha256sum or shasum command found. Please install sha256sum or shasum."
fi

if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
    handle_error "Verification failed - the download appears to be corrupted. Please try again."
fi

# Determine install location
if [ "$PLATFORM" = "darwin" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR" || handle_error "Failed to create installation directory"
elif [ "$PLATFORM" = "windows" ]; then
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR" || handle_error "Failed to create installation directory"
elif [ -w "/usr/local/bin" ]; then
    INSTALL_DIR="/usr/local/bin"
else
    INSTALL_DIR="$HOME/.local/bin"
    mkdir -p "$INSTALL_DIR" || handle_error "Failed to create installation directory"
fi

# Install binary
progress "installing isup..."
if [ "$PLATFORM" = "windows" ]; then
    mv "$TMP_FILE" "$INSTALL_DIR/isup.exe" 2>/dev/null || sudo mv "$TMP_FILE" "$INSTALL_DIR/isup.exe" || handle_error "Failed to move binary to installation directory"
    chmod 755 "$INSTALL_DIR/isup.exe" 2>/dev/null || sudo chmod 755 "$INSTALL_DIR/isup.exe" || handle_error "Failed to set permissions on binary"
    BINARY_NAME="isup.exe"
else
    mv "$TMP_FILE" "$INSTALL_DIR/isup" 2>/dev/null || sudo mv "$TMP_FILE" "$INSTALL_DIR/isup" || handle_error "Failed to move binary to installation directory"
    chmod 755 "$INSTALL_DIR/isup" 2>/dev/null || sudo chmod 755 "$INSTALL_DIR/isup" || handle_error "Failed to set permissions on binary"
    BINARY_NAME="isup"
fi

# Verify the binary is executable
if [ ! -x "$INSTALL_DIR/$BINARY_NAME" ]; then
    handle_error "The installed binary is not executable"
fi

# Handle macOS specific security (silently)
if [ "$PLATFORM" = "darwin" ]; then
    xattr -d com.apple.quarantine "$INSTALL_DIR/$BINARY_NAME" 2>/dev/null || true
fi

# Add to PATH if needed
if [[ ":$PATH:" != *":$INSTALL_DIR:"* ]]; then
    SHELL_NAME="$(basename "$SHELL")"
    if [ "$SHELL_NAME" = "zsh" ] && [ -f "$HOME/.zshrc" ]; then
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.zshrc" 2>/dev/null || sudo sh -c "echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> $HOME/.zshrc" || progress "couldn't update .zshrc, you may need to add $INSTALL_DIR to your PATH manually"
        progress "added $INSTALL_DIR to your PATH in .zshrc"
    elif [ "$SHELL_NAME" = "bash" ] && [ -f "$HOME/.bashrc" ]; then
        echo "export PATH=\"$INSTALL_DIR:\$PATH\"" >> "$HOME/.bashrc" 2>/dev/null || sudo sh -c "echo 'export PATH=\"$INSTALL_DIR:\$PATH\"' >> $HOME/.bashrc" || progress "couldn't update .bashrc, you may need to add $INSTALL_DIR to your PATH manually"
        progress "added $INSTALL_DIR to your PATH in .bashrc"
    else
        progress "note: add $INSTALL_DIR to your PATH to use isup from anywhere"
    fi
fi

# Setup auto-start for all platforms
LOG_DIR="$HOME/.isup/logs"
mkdir -p "$LOG_DIR" || handle_error "Failed to create log directory"

# Ask if user wants to install auto-start
read -p "Do you want to install isup to start automatically on login? [y/N] " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    progress "setting up auto-start..."
    
    # macOS - Launch Agent
    if [ "$PLATFORM" = "darwin" ]; then
        LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
        mkdir -p "$LAUNCH_AGENT_DIR" || handle_error "Failed to create LaunchAgents directory"
        
        # Create the launch agent plist file
        LAUNCH_AGENT_FILE="$LAUNCH_AGENT_DIR/com.shivamhwp.isup.plist"
        
        cat > "$LAUNCH_AGENT_FILE" << EOL || handle_error "Failed to create launch agent file"
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
        chmod 644 "$LAUNCH_AGENT_FILE" || handle_error "Failed to set permissions on launch agent file"
        
        # Check if the service is already running
        if launchctl list | grep -q "com.shivamhwp.isup"; then
            progress "unloading existing launch agent..."
            launchctl unload "$LAUNCH_AGENT_FILE" 2>/dev/null || true
        fi
        
        # Load the launch agent
        progress "loading launch agent..."
        launchctl load "$LAUNCH_AGENT_FILE" || progress "failed to load launch agent, you may need to run: launchctl load $LAUNCH_AGENT_FILE"
        
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
            mkdir -p "$SYSTEMD_DIR" || handle_error "Failed to create systemd user directory"
            
            # Create systemd service file
            SYSTEMD_FILE="$SYSTEMD_DIR/isup.service"
            
            cat > "$SYSTEMD_FILE" << EOL || handle_error "Failed to create systemd service file"
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
            systemctl --user daemon-reload || progress "failed to reload systemd daemon"
            
            # Enable and start the service
            systemctl --user enable isup.service || progress "failed to enable isup service"
            systemctl --user start isup.service || progress "failed to start isup service"
            
            progress "✅ systemd user service installed and started!"
            progress "check status with: systemctl --user status isup.service"
        
        # Fallback to desktop entry if systemd is not available
        else
            AUTOSTART_DIR="$HOME/.config/autostart"
            mkdir -p "$AUTOSTART_DIR" || handle_error "Failed to create autostart directory"
            
            # Create desktop entry
            DESKTOP_FILE="$AUTOSTART_DIR/isup.desktop"
            
            cat > "$DESKTOP_FILE" << EOL || handle_error "Failed to create desktop entry file"
[Desktop Entry]
Type=Application
Name=isup
Exec=$INSTALL_DIR/$BINARY_NAME daemon
Terminal=false
X-GNOME-Autostart-enabled=true
Comment=isup monitoring service
EOL
            
            chmod +x "$DESKTOP_FILE" || handle_error "Failed to set permissions on desktop entry file"
            progress "✅ desktop autostart entry created!"
            progress "isup will start automatically on next login"
        fi
    
    # Windows - Startup Folder
    elif [ "$PLATFORM" = "windows" ]; then
        STARTUP_DIR="$APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
        mkdir -p "$STARTUP_DIR" 2>/dev/null || true
        
        # Create VBS script to run without showing a command window
        STARTUP_SCRIPT="$STARTUP_DIR\\isup.vbs"
        
        cat > "$STARTUP_SCRIPT" << EOL || handle_error "Failed to create startup script"
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