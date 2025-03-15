#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}==> Installing isup launch agent...${NC}"

# Create necessary directories
LAUNCH_AGENT_DIR="$HOME/Library/LaunchAgents"
LOG_DIR="$HOME/.isup/logs"

mkdir -p "$LAUNCH_AGENT_DIR"
mkdir -p "$LOG_DIR"

# Determine install location
if [ -f "$HOME/.local/bin/isup" ]; then
    INSTALL_DIR="$HOME/.local/bin"
elif [ -f "/usr/local/bin/isup" ]; then
    INSTALL_DIR="/usr/local/bin"
else
    echo -e "${YELLOW}==> Could not find isup binary. Please make sure isup is installed.${NC}"
    exit 1
fi

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
        <string>$INSTALL_DIR/isup</string>
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