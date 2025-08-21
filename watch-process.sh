#!/bin/bash

# Process Watcher Script
#
# DESCRIPTION:
#   Monitors processes by exact name match and displays visual process trees.
#   Shows complete ancestry from root (PID 1) down to target process and its children.
#   Prints timestamped status changes and sends macOS push notifications.
#   Uses polling to check for process state changes every 0.5 seconds.
#
# USAGE:
#   ./watch-process.sh <process_name>
#
# EXAMPLES:
#   ./watch-process.sh git              # Watch for processes named exactly "git"
#   ./watch-process.sh nginx            # Watch for processes named exactly "nginx"
#   ./watch-process.sh python3          # Watch for processes named exactly "python3"
#
# OUTPUT FORMAT:
#   YYYY-MM-DD HH:MM:SS false                    # When no processes found
#   YYYY-MM-DD HH:MM:SS true                     # When processes found
#   --- Visual Process Trees ---                 # Followed by tree display
#   Full process tree (root to target and children):
#   ├─ 1 launchd /sbin/launchd
#     ├─ 500 loginwindow ...
#       ├─ 12345 git git status *** TARGET ***
#         ├─ 12346 less less
#
# PROCESS MATCHING:
#   - Uses exact name matching (pgrep -x) - not partial matches
#   - Will NOT match "gitstatusd" when searching for "git"
#   - Excludes the script's own process from results
#
# PROCESS TREE DISPLAY:
#   - Shows complete ancestry from root process (PID 1) to target
#   - Marks target process with "*** TARGET ***"
#   - Shows all child processes of the target
#   - Uses pstree if available, otherwise custom visual tree
#   - Displays PID, command name, and full command line
#
# NOTIFICATIONS:
#   - Startup: "Started watching process 'name'" when script begins
#   - Process found: "Found X 'name' process(es)" when processes appear
#   - Only sends notifications on state changes (not every iteration)
#
# REQUIREMENTS:
#   - macOS (for osascript notifications)
#   - pstree (optional, for enhanced tree display: brew install pstree)
#
# BEHAVIOR:
#   - Prints initial process state immediately
#   - Only prints when process state changes (appears/disappears)
#   - Polls every 0.5 seconds for changes
#   - Runs continuously until stopped with Ctrl+C
#   - Notifications sent only when state transitions occur

if [ $# -eq 0 ]; then
    echo "Process Watcher - Monitor processes with visual trees and notifications"
    echo ""
    echo "Usage: $0 <process_name>"
    echo ""
    echo "Examples:"
    echo "  $0 git              # Watch for processes named exactly 'git'"
    echo "  $0 nginx            # Watch for processes named exactly 'nginx'"
    echo "  $0 python3          # Watch for processes named exactly 'python3'"
    echo ""
    echo "Features:"
    echo "  - Exact name matching (not partial)"
    echo "  - Complete process ancestry trees"
    echo "  - Real-time notifications"
    echo "  - Visual process hierarchy display"
    echo ""
    echo "Optional:"
    echo "  - pstree (install with: brew install pstree)"
    echo ""
    exit 1
fi

PROCESS_NAME="$1"
LAST_NOTIFIED=""

# Function to get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Function to check if process is running and show visual process tree
check_process() {
    # Use pgrep -x for exact name match, exclude this script's PID
    local pids=$(pgrep -x "$PROCESS_NAME" | grep -v "$$")
    if [ -n "$pids" ]; then
        echo "true"
        echo "--- Visual Process Trees ---"
        while IFS= read -r pid; do
            if [ -n "$pid" ]; then
                # Try pstree first (most visual), fall back to custom full tree
                if command -v pstree >/dev/null 2>&1; then
                    echo "Process tree for PID $pid (using pstree):"
                    pstree -p "$pid" 2>/dev/null
                else
                    show_full_process_tree "$pid"
                fi
                echo ""
            fi
        done <<< "$pids"
    else
        echo "false"
    fi
}

# Function to get the full ancestry chain of a process
get_ancestry() {
    local pid=$1
    local ancestry=()

    while [ "$pid" != "0" ] && [ "$pid" != "1" ]; do
        ancestry=("$pid" "${ancestry[@]}")
        pid=$(ps -o ppid= -p "$pid" 2>/dev/null | tr -d ' ')
        if [ -z "$pid" ]; then
            break
        fi
    done

    # Add root process (PID 1)
    if [ "$pid" = "1" ]; then
        ancestry=("1" "${ancestry[@]}")
    fi

    printf '%s\n' "${ancestry[@]}"
}

# Function to show full process tree from root to target and its children
show_full_process_tree() {
    local target_pid=$1
    local ancestry=($(get_ancestry "$target_pid"))

    echo "Full process tree (root to target and children):"

    # Show the ancestry chain
    for i in "${!ancestry[@]}"; do
        local pid="${ancestry[$i]}"
        local indent=""

        # Create indentation based on depth
        for ((j=0; j<i; j++)); do
            indent="  $indent"
        done

        # Get process info
        local proc_info=$(ps -o pid,comm,args -p "$pid" 2>/dev/null | tail -n +2)
        if [ -n "$proc_info" ]; then
            if [ "$pid" = "$target_pid" ]; then
                echo "${indent}├─ $proc_info *** TARGET ***"
            else
                echo "${indent}├─ $proc_info"
            fi
        fi
    done

    # Show children of the target process
    show_children_tree "$target_pid" $((${#ancestry[@]}))
}

# Function to show children of a process
show_children_tree() {
    local pid=$1
    local depth=$2

    local children=$(pgrep -P "$pid" 2>/dev/null)
    if [ -n "$children" ]; then
        while IFS= read -r child_pid; do
            if [ -n "$child_pid" ]; then
                local indent=""
                for ((i=0; i<depth; i++)); do
                    indent="  $indent"
                done

                local proc_info=$(ps -o pid,comm,args -p "$child_pid" 2>/dev/null | tail -n +2)
                if [ -n "$proc_info" ]; then
                    echo "${indent}├─ $proc_info"
                    show_children_tree "$child_pid" $((depth + 1))
                fi
            fi
        done <<< "$children"
    fi
}

# Function to get just the true/false status
get_status() {
    echo "$1" | head -n1
}

# Send startup notification
osascript -e "display notification \"Started watching process '$PROCESS_NAME'\" with title \"Process Watcher\" subtitle \"Script Started\" sound name \"default\""

# Initial state check
CURRENT_OUTPUT=$(check_process)
CURRENT_STATUS=$(get_status "$CURRENT_OUTPUT")
LAST_STATUS="$CURRENT_STATUS"
echo "$(get_timestamp) $CURRENT_OUTPUT"

# Main watch loop
while true; do
    CURRENT_OUTPUT=$(check_process)
    CURRENT_STATUS=$(get_status "$CURRENT_OUTPUT")

    # Only print if state changed
    if [ "$CURRENT_STATUS" != "$LAST_STATUS" ]; then
        echo "$(get_timestamp) $CURRENT_OUTPUT"

        # Send notification only when state changes to "true" (process found)
        if [ "$CURRENT_STATUS" = "true" ] && [ "$LAST_NOTIFIED" != "true" ]; then
            # Count the processes for the notification
            pids=$(pgrep -x "$PROCESS_NAME" | grep -v "$$")
            pid_count=$(echo "$pids" | wc -l | tr -d ' ')
            osascript -e "display notification \"Found $pid_count '$PROCESS_NAME' process(es)\" with title \"Process Watcher\" sound name \"default\""
            LAST_NOTIFIED="true"
        elif [ "$CURRENT_STATUS" = "false" ]; then
            LAST_NOTIFIED="false"
        fi

        LAST_STATUS="$CURRENT_STATUS"
    fi

    # Sleep for a short interval (0.5 seconds)
    sleep 0.5
done
