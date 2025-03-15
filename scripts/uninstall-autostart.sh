#!/bin/bash
set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}==> Uninstalling isup auto-start configuration...${NC}"

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

# macOS - Launch Agent
if [ "$PLATFORM" = "darwin" ]; then
    # Define the launch agent file path
    LAUNCH_AGENT_FILE="$HOME/Library/LaunchAgents/com.shivamhwp.isup.plist"
    
    # Check if the launch agent exists
    if [ ! -f "$LAUNCH_AGENT_FILE" ]; then
        echo -e "${YELLOW}==> Launch agent not found. Nothing to uninstall.${NC}"
    else
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
    fi

# Linux - Systemd User Service and Desktop Entry
elif [ "$PLATFORM" = "linux" ]; then
    REMOVED=false
    
    # Check for systemd service
    if command -v systemctl >/dev/null; then
        SYSTEMD_FILE="$HOME/.config/systemd/user/isup.service"
        
        if [ -f "$SYSTEMD_FILE" ]; then
            echo -e "${YELLOW}==> Stopping and disabling systemd service...${NC}"
            systemctl --user stop isup.service 2>/dev/null || true
            systemctl --user disable isup.service 2>/dev/null || true
            
            echo -e "${YELLOW}==> Removing systemd service file...${NC}"
            rm -f "$SYSTEMD_FILE"
            systemctl --user daemon-reload
            
            REMOVED=true
            echo -e "${GREEN}==> ✅ Systemd service successfully uninstalled!${NC}"
        fi
    fi
    
    # Check for desktop entry
    DESKTOP_FILE="$HOME/.config/autostart/isup.desktop"
    if [ -f "$DESKTOP_FILE" ]; then
        echo -e "${YELLOW}==> Removing desktop autostart entry...${NC}"
        rm -f "$DESKTOP_FILE"
        
        REMOVED=true
        echo -e "${GREEN}==> ✅ Desktop autostart entry successfully removed!${NC}"
    fi
    
    if [ "$REMOVED" = false ]; then
        echo -e "${YELLOW}==> No auto-start configuration found. Nothing to uninstall.${NC}"
    fi

# Windows - Startup Script
elif [ "$PLATFORM" = "windows" ]; then
    STARTUP_SCRIPT="$APPDATA\\Microsoft\\Windows\\Start Menu\\Programs\\Startup\\isup.vbs"
    
    if [ ! -f "$STARTUP_SCRIPT" ]; then
        echo -e "${YELLOW}==> Startup script not found. Nothing to uninstall.${NC}"
    else
        echo -e "${YELLOW}==> Removing startup script...${NC}"
        rm -f "$STARTUP_SCRIPT"
        
        echo -e "${GREEN}==> ✅ Startup script successfully removed!${NC}"
    fi
fi

echo -e "${YELLOW}==> Note: Log files in ~/.isup/logs have not been removed.${NC}"
echo -e "${YELLOW}==> You can remove them manually if desired.${NC}" 