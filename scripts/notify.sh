#!/bin/bash

# Enable error tracing
set -x

# Log file for debugging
LOG_FILE="/tmp/isup_notify.log"

# Function to log messages
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if we have enough arguments
if [ $# -lt 2 ]; then
    log_message "error: not enough arguments. usage: $0 \"title\" \"message\""
    exit 1
fi

TITLE="$1"
MESSAGE="$2"

log_message "attempting to send notification:"
log_message "title: $TITLE"
log_message "message: $MESSAGE"

# Detect platform
PLATFORM="unknown"
case "$(uname -s)" in
    Linux*)     PLATFORM="linux";;
    Darwin*)    PLATFORM="darwin";;
    MSYS*|MINGW*) PLATFORM="windows";;
    *)          PLATFORM="unknown";;
esac

log_message "detected platform: $PLATFORM"

# Find the isup icon
ICON_PATHS=(
    "isup.png"
    "/usr/share/icons/hicolor/scalable/apps/isup.png"
    "/Applications/isup.app/Contents/Resources/isup.png"
    "./assets/isup.png"
)

ICON=""
for path in "${ICON_PATHS[@]}"; do
    log_message "checking icon path: $path"
    if [ -f "$path" ]; then
        ICON="$path"
        log_message "found icon at: $path"
        break
    fi
done

# Handle notifications based on platform
if [ "$PLATFORM" = "darwin" ]; then
    # macOS notifications
    # Check if terminal-notifier is installed
    if ! command -v terminal-notifier &> /dev/null; then
        log_message "warning: terminal-notifier not found. for best experience, install it with:"
        log_message "  brew install terminal-notifier"
        log_message "falling back to applescript notification"
    else
        log_message "using terminal-notifier"
        
        TERMINAL_NOTIFIER_CMD=(
            "terminal-notifier"
            "-title" "$TITLE"
            "-message" "$MESSAGE"
            "-timeout" "30"
            "-ignoreDnD"
            "-activate" "com.apple.Terminal"
            "-sender" "com.apple.Terminal"
            "-group" "isup-notifications"
            "-execute" "open -a Terminal"
            "-actions" "View,Dismiss"
        )
        
        # Add icon if we found one
        if [ -n "$ICON" ]; then
            TERMINAL_NOTIFIER_CMD+=("-appIcon" "$ICON")
            log_message "added icon to terminal-notifier command"
        fi
        
        log_message "executing terminal-notifier command: ${TERMINAL_NOTIFIER_CMD[*]}"
        
        "${TERMINAL_NOTIFIER_CMD[@]}"
        EXIT_CODE=$?
        
        if [ $EXIT_CODE -eq 0 ]; then
            log_message "notification sent successfully with terminal-notifier"
            exit 0
        else
            log_message "terminal-notifier failed with code $EXIT_CODE, falling back to applescript"
        fi
    fi
    
    # Fall back to AppleScript
    log_message "using applescript for notification"
    
    # Escape quotes in title and message for AppleScript
    TITLE_ESCAPED="${TITLE//\"/\\\"}"
    MESSAGE_ESCAPED="${MESSAGE//\"/\\\"}"
    
    APPLESCRIPT_CMD="display notification \"$MESSAGE_ESCAPED\" with title \"$TITLE_ESCAPED\" subtitle \"isup\""
    log_message "executing applescript command: $APPLESCRIPT_CMD"
    
    osascript -e "$APPLESCRIPT_CMD"
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        log_message "notification sent successfully with applescript"
        exit 0
    else
        log_message "applescript notification failed with code $EXIT_CODE"
    fi
elif [ "$PLATFORM" = "linux" ]; then
    # Linux notifications
    if command -v notify-send &> /dev/null; then
        log_message "using notify-send for linux notification"
        
        NOTIFY_CMD=(
            "notify-send"
            "--urgency=critical"
            "--app-name=isup"
        )
        
        # Add icon if we found one
        if [ -n "$ICON" ]; then
            NOTIFY_CMD+=("--icon=$ICON")
        fi
        
        NOTIFY_CMD+=("$TITLE" "$MESSAGE")
        
        log_message "executing notify-send command: ${NOTIFY_CMD[*]}"
        "${NOTIFY_CMD[@]}"
        
        if [ $? -eq 0 ]; then
            log_message "notification sent successfully with notify-send"
            exit 0
        else
            log_message "notify-send failed, falling back to console"
        fi
    else
        log_message "notify-send not found, please install libnotify-bin package"
    fi
elif [ "$PLATFORM" = "windows" ]; then
    # Windows notifications
    if command -v powershell &> /dev/null; then
        log_message "using powershell for windows notification"
        
        # Escape single quotes for PowerShell
        TITLE_ESC="${TITLE//\'/\'\'}"
        MESSAGE_ESC="${MESSAGE//\'/\'\'}"
        
        PS_SCRIPT="Add-Type -AssemblyName System.Windows.Forms; \
        \$notify = New-Object System.Windows.Forms.NotifyIcon; \
        \$notify.Icon = [System.Drawing.SystemIcons]::Information; \
        \$notify.Visible = \$true; \
        \$notify.BalloonTipTitle = 'isup: $TITLE_ESC'; \
        \$notify.ShowBalloonTip(0, 'isup: $TITLE_ESC', '$MESSAGE_ESC', [System.Windows.Forms.ToolTipIcon]::Info);"
        
        powershell -Command "$PS_SCRIPT"
        
        if [ $? -eq 0 ]; then
            log_message "notification sent successfully with powershell"
            exit 0
        else
            log_message "powershell notification failed, falling back to console"
        fi
    else
        log_message "powershell not found, cannot send windows notification"
    fi
fi

# Fall back to console notification
log_message "using console notification as fallback"
echo ""
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo "! $TITLE"
echo "! $MESSAGE"
echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
echo ""
exit 0 