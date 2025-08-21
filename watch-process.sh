#!/bin/bash

# Usage: ./watch-process.sh <process_name>
# Example: ./watch-process.sh nginx

if [ $# -eq 0 ]; then
    echo "Usage: $0 <process_name>"
    echo "Example: $0 nginx"
    exit 1
fi

PROCESS_NAME="$1"
LAST_STATE=""

# Function to get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to check if process is running and get parent info
check_process() {
    # Exclude this script's PID and its parent shell
    local pids=$(pgrep "$PROCESS_NAME" | grep -v "$$")
    if [ -n "$pids" ]; then
        local result="true"
        # Process each matching PID
        while IFS= read -r pid; do
            local ppid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
            if [ -n "$ppid" ] && [ "$ppid" != "0" ]; then
                local parent_name=$(ps -o comm= -p "$ppid" 2>/dev/null)
                result="$result $parent_name"
            else
                result="$result unknown"
            fi
        done <<< "$pids"
        echo "$result"
    else
        echo "false"
    fi
}

# Initial state check
CURRENT_STATE=$(check_process)
LAST_STATE="$CURRENT_STATE"
echo "$(get_timestamp) $CURRENT_STATE"

# Main watch loop
while true; do
    CURRENT_STATE=$(check_process)

    # Only print if state changed (compare just the true/false part)
    CURRENT_STATUS=$(echo "$CURRENT_STATE" | cut -d' ' -f1)
    LAST_STATUS=$(echo "$LAST_STATE" | cut -d' ' -f1)

    if [ "$CURRENT_STATUS" != "$LAST_STATUS" ]; then
        echo "$(get_timestamp) $CURRENT_STATE"
        LAST_STATE="$CURRENT_STATE"
    fi

    # Sleep for a short interval (0.5 seconds)
    sleep 0.5
done
