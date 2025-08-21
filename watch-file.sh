#!/bin/bash

# Usage: ./watch-file.sh <filename>
# Example: ./watch-file.sh myfile.txt

if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename>"
    echo "Example: $0 myfile.txt"
    exit 1
fi

FILENAME="$1"
LAST_STATE=""

# Function to get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to check if file exists
check_file() {
    if [ -f "$FILENAME" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Initial state check
CURRENT_STATE=$(check_file)
LAST_STATE="$CURRENT_STATE"
echo "$(get_timestamp) $CURRENT_STATE"

# Main watch loop
while true; do
    CURRENT_STATE=$(check_file)
    
    # Only print if state changed
    if [ "$CURRENT_STATE" != "$LAST_STATE" ]; then
        echo "$(get_timestamp) $CURRENT_STATE"
        LAST_STATE="$CURRENT_STATE"
    fi
    
    # Sleep for a short interval (0.5 seconds)
    sleep 0.5
done
