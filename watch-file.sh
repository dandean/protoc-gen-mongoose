#!/bin/bash

# Usage: ./watch-file.sh <filename>
# Example: ./watch-file.sh myfile.txt

if [ $# -eq 0 ]; then
    echo "Usage: $0 <filename>"
    echo "Example: $0 myfile.txt"
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

# Function to check if file exists
check_file() {
    if [ -f "$FILENAME" ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Print initial state
echo "$(get_timestamp) $(check_file)"

# Watch the directory for changes and filter for our specific file
fswatch -0 "$DIRNAME" | while IFS= read -r -d '' event; do
    # Check if the event involves our target file
    if [[ "$event" == *"$BASENAME"* ]]; then
        echo "$(get_timestamp) $(check_file)"
    fi
done
