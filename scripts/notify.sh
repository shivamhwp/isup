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
    log_message "Error: Not enough arguments. Usage: $0 \"title\" \"message\""
    exit 1
fi

TITLE="$1"
MESSAGE="$2"

log_message "Attempting to send notification:"
log_message "Title: $TITLE"
log_message "Message: $MESSAGE"

# Find the isup.svg icon
ICON_PATHS=(
    "isup.png"
    "/usr/share/icons/hicolor/scalable/apps/isup.png"
    "/Applications/isup.app/Contents/Resources/isup.png"
    "./assets/isup.png"
)

ICON=""
for path in "${ICON_PATHS[@]}"; do
    log_message "Checking icon path: $path"
    if [ -f "$path" ]; then
        ICON="$path"
        log_message "Found icon at: $path"
        break
    fi
done

# Try terminal-notifier first if available
if command -v terminal-notifier &> /dev/null; then
    log_message "Using terminal-notifier"
    
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
        log_message "Added icon to terminal-notifier command"
    fi
    
    log_message "Executing terminal-notifier command: ${TERMINAL_NOTIFIER_CMD[*]}"
    
    "${TERMINAL_NOTIFIER_CMD[@]}"
    EXIT_CODE=$?
    
    if [ $EXIT_CODE -eq 0 ]; then
        log_message "Notification sent successfully with terminal-notifier"
        exit 0
    else
        log_message "terminal-notifier failed with code $EXIT_CODE, falling back to AppleScript"
    fi
fi

# Fall back to AppleScript
log_message "Using AppleScript for notification"

# Escape quotes in title and message for AppleScript
TITLE_ESCAPED="${TITLE//\"/\\\"}"
MESSAGE_ESCAPED="${MESSAGE//\"/\\\"}"

APPLESCRIPT_CMD="display notification \"$MESSAGE_ESCAPED\" with title \"$TITLE_ESCAPED\" subtitle \"isup\""
log_message "Executing AppleScript command: $APPLESCRIPT_CMD"

osascript -e "$APPLESCRIPT_CMD"
EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    log_message "Notification sent successfully with AppleScript"
    exit 0
else
    log_message "AppleScript notification failed with code $EXIT_CODE"
    exit $EXIT_CODE
fi 