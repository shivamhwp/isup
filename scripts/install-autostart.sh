#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==> Installing isup auto-start configuration...${NC}"

# Determine OS
PLATFORM="unknown"
case "$(uname -s)" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="darwin";;
    MSYS*|MINGW*) PLATFORM="windows";;
    *)          
        echo -e "${YELLOW}==> Error: Unsupported platform: $(uname -s)${NC}"
        echo -e "${YELLOW}==> Please hit me up here: https://x.com/shivamhwp${NC}"
        exit 1
        ;;
esac

# Create necessary directories
LOG_DIR="$HOME/.isup/logs"
mkdir -p "$LOG_DIR"

# Determine install location
if [ "$PLATFORM" = "darwin" ]; then
    if [ -f "$HOME/.local/bin/isup" ]; then
        INSTALL_DIR="$HOME/.local/bin"
        BINARY_NAME="isup"
    elif [ -f "/usr/local/bin/isup" ]; then
        INSTALL_DIR="/usr/local/bin"
        BINARY_NAME="isup"
    else
        echo -e "${YELLOW}==> Could not find isup binary. Please make sure isup is installed.${NC}"
        exit 1
    fi
elif [ "$PLATFORM" = "windows" ]; then
    if [ -f "$HOME/.local/bin/isup.exe" ]; then
        INSTALL_DIR="$HOME/.local/bin"
        BINARY_NAME="isup.exe"
    else
        echo -e "${YELLOW}==> Could not find isup binary. Please make sure isup is installed.${NC}"
        exit 1
    fi
else # Linux
    if [ -f "$HOME/.local/bin/isup" ]; then
        INSTALL_DIR="$HOME/.local/bin"
        BINARY_NAME="isup"
    elif [ -f "/usr/local/bin/isup" ]; then
        INSTALL_DIR="/usr/local/bin"
        BINARY_NAME="isup"
    else
        echo -e "${YELLOW}==> Could not find isup binary. Please make sure isup is installed.${NC}"
        exit 1
    fi
fi

# macOS - Launch Agent
if [ "$PLATFORM" = "darwin" ]; then
    echo -e "${GREEN}==> Setting up macOS Launch Agent...${NC}"
    
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
        echo -e "${YELLOW}==> Unloading existing launch agent...${NC}"
        launchctl unload "$LAUNCH_AGENT_FILE" 2>/dev/null || true
    fi
    
    # Load the launch agent
    echo -e "${GREEN}==> Loading launch agent...${NC}"
    launchctl load "$LAUNCH_AGENT_FILE"
    
    # Verify it's running
    if launchctl list | grep -q "com.shivamhwp.isup"; then
        echo -e "${GREEN}==> ✅ Launch agent installed and running successfully!${NC}"
        echo -e "${GREEN}==> isup will now start automatically when you log in${NC}"
        echo -e "${GREEN}==> and will continue running in the background.${NC}"
        echo -e "${GREEN}==> Logs are available at: $LOG_DIR${NC}"
    else
        echo -e "${YELLOW}==> ⚠️ Launch agent installation may have failed.${NC}"
        echo -e "${YELLOW}==> Please check the logs or run manually with: launchctl load $LAUNCH_AGENT_FILE${NC}"
    fi

# Linux - Systemd User Service or Desktop Entry
elif [ "$PLATFORM" = "linux" ]; then
    # Check if systemd is available
    if command -v systemctl >/dev/null; then
        echo -e "${GREEN}==> Setting up Linux systemd user service...${NC}"
        
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
        
        echo -e "${GREEN}==> ✅ systemd user service installed and started!${NC}"
        echo -e "${GREEN}==> check status with: systemctl --user status isup.service${NC}"
        echo -e "${GREEN}==> Logs are available at: $LOG_DIR${NC}"
    
    # Fallback to desktop entry if systemd is not available
    else
        echo -e "${GREEN}==> Setting up Linux desktop autostart entry...${NC}"
        
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
        echo -e "${GREEN}==> ✅ desktop autostart entry created!${NC}"
        echo -e "${GREEN}==> isup will start automatically on next login${NC}"
        echo -e "${GREEN}==> Logs are available at: $LOG_DIR${NC}"
    fi

# Windows - Startup Folder
elif [ "$PLATFORM" = "windows" ]; then
    echo -e "${GREEN}==> Setting up Windows startup script...${NC}"
    
    STARTUP_DIR="$APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\Startup"
    mkdir -p "$STARTUP_DIR" 2>/dev/null || true
    
    # Create VBS script to run without showing a command window
    STARTUP_SCRIPT="$STARTUP_DIR\\isup.vbs"
    
    cat > "$STARTUP_SCRIPT" << EOL
Set WshShell = CreateObject("WScript.Shell")
WshShell.Run chr(34) & "$INSTALL_DIR\\$BINARY_NAME" & chr(34) & " daemon", 0
Set WshShell = Nothing
EOL
    
    echo -e "${GREEN}==> ✅ startup script created!${NC}"
    echo -e "${GREEN}==> isup will start automatically on next login${NC}"
    echo -e "${GREEN}==> Logs are available at: $LOG_DIR${NC}"
fi 