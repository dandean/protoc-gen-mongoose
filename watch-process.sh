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
