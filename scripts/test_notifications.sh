#!/bin/bash

# Test notification script that tries multiple methods to send a notification
echo "Testing notifications through multiple methods..."

# 1. Direct terminal-notifier
if command -v terminal-notifier &> /dev/null; then
    echo "Testing terminal-notifier directly..."
    terminal-notifier -title "ISUP Test" -message "Testing direct terminal-notifier" -sound "Glass"
    echo "terminal-notifier exit code: $?"
else
    echo "terminal-notifier not found"
fi

# 2. Direct AppleScript
echo "Testing AppleScript directly..."
osascript -e 'display notification "Testing direct AppleScript" with title "ISUP Test" sound name "Glass"'
echo "AppleScript exit code: $?"

# 3. Test our shell script
if [ -f "./scripts/notify.sh" ]; then
    echo "Testing through notify.sh script..."
    ./scripts/notify.sh "ISUP Script Test" "Testing through notify.sh script"
else
    echo "notify.sh script not found in expected location"
fi

# Give time for notifications to appear
echo "Tests completed. Check if you received any notifications." 