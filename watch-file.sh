#!/bin/bash

# File Watcher Script
#
# DESCRIPTION:
#   Monitors a specific file for creation/deletion events using filesystem events.
#   Prints timestamped status changes and sends macOS push notifications.
#   Uses fswatch for real-time monitoring instead of polling.
#
# USAGE:
#   ./watch-file.sh <filename>
#
# EXAMPLES:
#   ./watch-file.sh myfile.txt          # Watch for myfile.txt in current directory
#   ./watch-file.sh /tmp/status.log     # Watch for absolute path
#   ./watch-file.sh ../config.json      # Watch for relative path
#
# OUTPUT FORMAT:
#   YYYY-MM-DD HH:MM:SS true    # When file exists
#   YYYY-MM-DD HH:MM:SS false   # When file doesn't exist
#
# NOTIFICATIONS:
#   - Startup: "Started watching 'filename'" when script begins
#   - File exists: "File 'filename' exists" when file is detected
#
# REQUIREMENTS:
#   - macOS (for osascript notifications)
#   - fswatch (install with: brew install fswatch)
#
# BEHAVIOR:
#   - Prints initial file state immediately
#   - Only prints when file state changes (appears/disappears)
#   - Responds instantly to filesystem events (no polling delay)
#   - Runs continuously until stopped with Ctrl+C

if [ $# -eq 0 ]; then
    echo "File Watcher - Monitor file creation/deletion with notifications"
    echo ""
    echo "Usage: $0 <filename>"
    echo ""
    echo "Examples:"
    echo "  $0 myfile.txt          # Watch for myfile.txt in current directory"
    echo "  $0 /tmp/status.log     # Watch for absolute path"
    echo "  $0 ../config.json      # Watch for relative path"
    echo ""
    echo "Requirements:"
    echo "  - fswatch (install with: brew install fswatch)"
    echo ""
    exit 1
fi

# Check if fswatch is available
if ! command -v fswatch >/dev/null 2>&1; then
    echo "Error: fswatch is not installed. Install with: brew install fswatch"
    exit 1
fi

FILENAME="$1"
DIRNAME=$(dirname "$FILENAME")
BASENAME=$(basename "$FILENAME")

# Function to get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to check if file exists and send notification
check_file() {
    if [ -f "$FILENAME" ]; then
        echo "true"
        # Send push notification when file exists
        osascript -e "display notification \"File '$BASENAME' exists\" with title \"File Watcher\" sound name \"default\""
        return 0
    else
        echo "false"
        return 1
    fi
}

# Send startup notification
osascript -e "display notification \"Started watching '$BASENAME'\" with title \"File Watcher\" subtitle \"Script Started\" sound name \"default\""

# Print initial state
echo "$(get_timestamp) $(check_file)"

# Watch the directory for changes and filter for our specific file
fswatch -0 "$DIRNAME" | while IFS= read -r -d '' event; do
    # Check if the event involves our target file
    if [[ "$event" == *"$BASENAME"* ]]; then
        echo "$(get_timestamp) $(check_file)"
    fi
done
