#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==> Uninstalling isup launch agent...${NC}"

# Define the launch agent file path
LAUNCH_AGENT_FILE="$HOME/Library/LaunchAgents/com.shivamhwp.isup.plist"

# Check if the launch agent exists
if [ ! -f "$LAUNCH_AGENT_FILE" ]; then
    echo -e "${YELLOW}==> Launch agent not found. Nothing to uninstall.${NC}"
    exit 0
fi

# Unload the launch agent
echo -e "${YELLOW}==> Unloading launch agent...${NC}"
launchctl unload "$LAUNCH_AGENT_FILE" 2>/dev/null || true

# Remove the launch agent file
echo -e "${YELLOW}==> Removing launch agent file...${NC}"
rm -f "$LAUNCH_AGENT_FILE"

# Verify it's no longer running
if ! launchctl list | grep -q "com.shivamhwp.isup"; then
    echo -e "${GREEN}==> ✅ Launch agent successfully uninstalled!${NC}"
else
    echo -e "${YELLOW}==> ⚠️ Launch agent may still be running.${NC}"
    echo -e "${YELLOW}==> Please try again or restart your computer.${NC}"
fi

echo -e "${YELLOW}==> Note: Log files in ~/.isup/logs have not been removed.${NC}"
echo -e "${YELLOW}==> You can remove them manually if desired.${NC}" 