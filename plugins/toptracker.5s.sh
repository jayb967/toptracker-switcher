#!/bin/bash
# TopTracker Status for xbar
# Refreshes every 5 seconds

CONFIG_FILE="$HOME/.toptracker-switcher/config.sh"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Defaults
TOPTRACKER_EMAIL="${TOPTRACKER_EMAIL:-}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-900}"

DB_PATH="$HOME/Library/Application Support/TopTracker/TopTracker.db"
LOG_PATH="$HOME/Library/Application Support/TopTracker/application.log"

# Auto-detect email if not set
if [[ -z "$TOPTRACKER_EMAIL" ]]; then
    TOPTRACKER_EMAIL=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%_activity'" 2>/dev/null | head -1 | sed 's/_activity$//')
fi

get_current_project() {
    if [[ -z "$TOPTRACKER_EMAIL" ]]; then
        return
    fi
    sqlite3 "$DB_PATH" "SELECT p.name FROM '${TOPTRACKER_EMAIL}_activity' a 
        JOIN '${TOPTRACKER_EMAIL}_project_list_cache' p ON a.projectId=p.id 
        WHERE a.active=1" 2>/dev/null | head -1
}

get_last_screenshot_time() {
    local last_line=$(grep "Screenshot of screen #1 captured" "$LOG_PATH" 2>/dev/null | tail -1)
    if [[ -n "$last_line" ]]; then
        local timestamp=$(echo "$last_line" | grep -oE '\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | tr -d '[')
        if [[ -n "$timestamp" ]]; then
            date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null
        fi
    fi
}

get_activity_start_time() {
    local last_line=$(grep "Sent create activity request" "$LOG_PATH" 2>/dev/null | tail -1)
    if [[ -n "$last_line" ]]; then
        local timestamp=$(echo "$last_line" | grep -oE '\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | tr -d '[')
        if [[ -n "$timestamp" ]]; then
            date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null
        fi
    fi
}

get_next_screenshot_time() {
    local last_screenshot=$(get_last_screenshot_time)
    local activity_start=$(get_activity_start_time)
    
    if [[ -n "$activity_start" ]] && [[ -n "$last_screenshot" ]]; then
        if [[ $activity_start -gt $last_screenshot ]]; then
            echo $((activity_start + INTERVAL_SECONDS))
            return
        fi
    fi
    
    if [[ -n "$last_screenshot" ]]; then
        echo $((last_screenshot + INTERVAL_SECONDS))
        return
    fi
    
    if [[ -n "$activity_start" ]]; then
        echo $((activity_start + INTERVAL_SECONDS))
        return
    fi
}

format_time() {
    local seconds=$1
    if [[ $seconds -lt 0 ]]; then
        echo "now!"
    elif [[ $seconds -lt 60 ]]; then
        echo "${seconds}s"
    else
        local mins=$((seconds / 60))
        local secs=$((seconds % 60))
        echo "${mins}m${secs}s"
    fi
}

# Get current state
project=$(get_current_project)
now=$(date +%s)
next_screenshot=$(get_next_screenshot_time)
last_screenshot=$(get_last_screenshot_time)

if [[ -z "$project" ]]; then
    # Not tracking
    echo "⏸️ TT"
    echo "---"
    echo "TopTracker: Not tracking"
    echo "---"
    echo "No active project"
    exit 0
fi

if [[ -n "$next_screenshot" ]]; then
    time_until=$((next_screenshot - now))
    formatted=$(format_time $time_until)
    
    # Color based on urgency
    if [[ $time_until -le 30 ]]; then
        # Red - imminent
        echo "📸 $formatted | color=red"
    elif [[ $time_until -le 60 ]]; then
        # Orange - soon
        echo "📸 $formatted | color=orange"
    elif [[ $time_until -le 180 ]]; then
        # Yellow - 3 minutes
        echo "⏱️ $formatted | color=yellow"
    else
        # Green - plenty of time
        echo "⏱️ $formatted | color=green"
    fi
else
    echo "⏱️ --"
fi

echo "---"
echo "Project: $project | color=blue"
echo "---"
if [[ -n "$last_screenshot" ]]; then
    echo "Last: $(date -r $last_screenshot '+%H:%M:%S')"
    echo "Next: $(date -r $next_screenshot '+%H:%M:%S')"
    echo "Remaining: $formatted"
else
    echo "No screenshot data found"
fi
echo "---"
echo "Test Switch | bash=$HOME/.toptracker-switcher/ctl.sh param1=test terminal=false"
echo "View Logs | bash=$HOME/.toptracker-switcher/ctl.sh param1=logs terminal=true"
echo "Edit Config | bash=$HOME/.toptracker-switcher/ctl.sh param1=config terminal=true"
echo "---"
echo "Refresh | refresh=true"
echo "Open TopTracker | bash=open param1=-a param2=TopTracker terminal=false"
