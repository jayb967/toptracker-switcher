#!/bin/bash
# TopTracker Status for xbar
# Refreshes every 5 seconds

# Ensure clean environment
export PATH="/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:$PATH"
export LC_ALL=en_US.UTF-8

# Heartbeat: proves xbar is still executing plugins (watchdog checks this file's age)
mkdir -p "$HOME/.cache/xbar-watchdog" && touch "$HOME/.cache/xbar-watchdog/heartbeat"

CONFIG_FILE="$HOME/.toptracker-switcher/config.sh"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

TOPTRACKER_EMAIL="${TOPTRACKER_EMAIL:-}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-900}"

DB_PATH="$HOME/Library/Application Support/TopTracker/TopTracker.db"
LOG_PATH="$HOME/Library/Application Support/TopTracker/application.log"

# Check if TopTracker DB exists
if [[ ! -f "$DB_PATH" ]]; then
    echo "⏸️ TT"
    echo "---"
    echo "TopTracker not installed"
    echo "---"
    echo "Refresh xbar | bash=/usr/bin/true terminal=false refresh=true"
    exit 0
fi

# Auto-detect email if not set
if [[ -z "$TOPTRACKER_EMAIL" ]]; then
    TOPTRACKER_EMAIL=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%_activity'" 2>/dev/null | head -1 | sed 's/_activity$//')
fi

# Bail early if no email found
if [[ -z "$TOPTRACKER_EMAIL" ]]; then
    echo "⏸️ TT"
    echo "---"
    echo "TopTracker: No account found"
    echo "---"
    echo "Refresh xbar | bash=/usr/bin/true terminal=false refresh=true"
    exit 0
fi

get_current_project() {
    sqlite3 "$DB_PATH" "SELECT p.name FROM '${TOPTRACKER_EMAIL}_activity' a JOIN '${TOPTRACKER_EMAIL}_project_list_cache' p ON a.projectId=p.id WHERE a.active=1 LIMIT 1" 2>/dev/null
}

get_current_description() {
    sqlite3 "$DB_PATH" "SELECT a.description FROM '${TOPTRACKER_EMAIL}_activity' a WHERE a.active=1 LIMIT 1" 2>/dev/null
}

get_last_screenshot_time() {
    # Check last ~2000 lines for performance (handles longer sessions)
    # Priority: "Making new snapshot" (captures rejected too) > "Sending create image" (only accepted)
    local last_line=$(tail -2000 "$LOG_PATH" 2>/dev/null | grep -E "Making new snapshot at tracking interval" | tail -1)
    if [[ -z "$last_line" ]]; then
        # Fall back to old method if new pattern not found
        last_line=$(tail -2000 "$LOG_PATH" 2>/dev/null | grep -E "(Sending create image request|Screenshot of screen #1 captured)" | tail -1)
    fi
    if [[ -n "$last_line" ]]; then
        local timestamp=$(echo "$last_line" | grep -oE '\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | tr -d '[')
        if [[ -n "$timestamp" ]]; then
            date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null
        fi
    fi
}

# Get screenshot time only if it's AFTER the current session started
get_last_screenshot_time_for_session() {
    local session_start=$1
    local screenshot_time=$(get_last_screenshot_time)
    
    # If no session start or no screenshot, return empty
    if [[ -z "$session_start" ]] || [[ -z "$screenshot_time" ]]; then
        echo ""
        return
    fi
    
    # Only return screenshot time if it's from THIS session (after session started)
    if [[ $screenshot_time -ge $session_start ]]; then
        echo "$screenshot_time"
    else
        echo ""  # Screenshot is from old session, ignore it
    fi
}

get_activity_start_time() {
    local last_line=$(tail -5000 "$LOG_PATH" 2>/dev/null | grep "Sent create activity request" | tail -1)
    if [[ -n "$last_line" ]]; then
        local timestamp=$(echo "$last_line" | grep -oE '\[20[0-9]{2}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}' | tr -d '[')
        if [[ -n "$timestamp" ]]; then
            date -j -f "%Y-%m-%d %H:%M:%S" "$timestamp" "+%s" 2>/dev/null
        fi
    fi
}

get_next_screenshot_time() {
    local activity_start=$(get_activity_start_time)
    
    # No activity = no next screenshot
    if [[ -z "$activity_start" ]]; then
        return
    fi
    
    # Get screenshot time ONLY if it's from this session
    local last_screenshot=$(get_last_screenshot_time_for_session "$activity_start")
    
    if [[ -n "$last_screenshot" ]]; then
        # We have a screenshot from this session, next is screenshot + interval
        echo $((last_screenshot + INTERVAL_SECONDS))
    else
        # No screenshot yet this session, next is session start + interval
        echo $((activity_start + INTERVAL_SECONDS))
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

# --- Main ---
project=$(get_current_project)
description=$(get_current_description)
now=$(date +%s)

if [[ -z "$project" ]]; then
    echo "⏸️ TT"
    echo "---"
    echo "TopTracker: Not tracking"
    echo "---"
    echo "No active project"
    echo "---"
    echo "Open TopTracker | bash=/usr/bin/open param1=-a param2=TopTracker terminal=false"
    echo "Refresh xbar | bash=/usr/bin/true terminal=false refresh=true"
    exit 0
fi

next_screenshot=$(get_next_screenshot_time)
last_screenshot=$(get_last_screenshot_time)

if [[ -n "$next_screenshot" ]]; then
    time_until=$((next_screenshot - now))
    formatted=$(format_time $time_until)

    if [[ $time_until -le 30 ]]; then
        echo "📸 $formatted | color=red"
    elif [[ $time_until -le 60 ]]; then
        echo "📸 $formatted | color=orange"
    elif [[ $time_until -le 180 ]]; then
        echo "⏱️ $formatted | color=yellow"
    else
        echo "⏱️ $formatted | color=white"
    fi
else
    echo "🟢 Tracking"
fi

echo "---"
echo "Project: $project | color=blue"
if [[ -n "$description" ]]; then
    echo "Task: $description"
fi
echo "---"
activity_start=$(get_activity_start_time)
# Get screenshot only from current session
session_screenshot=$(get_last_screenshot_time_for_session "$activity_start")
if [[ -n "$next_screenshot" ]]; then
    if [[ -n "$session_screenshot" ]]; then
        echo "Last: $(date -r $session_screenshot '+%H:%M:%S')"
    else
        echo "Last: None this session"
    fi
    echo "Next: $(date -r $next_screenshot '+%H:%M:%S')"
    echo "Remaining: $formatted"
    if [[ -n "$activity_start" ]]; then
        elapsed=$((now - activity_start))
        elapsed_min=$((elapsed / 60))
        elapsed_sec=$((elapsed % 60))
        echo "Session: ${elapsed_min}m ${elapsed_sec}s"
    fi
else
    echo "Waiting for first screenshot..."
fi
echo "---"
echo "Test Switch | bash=$HOME/.toptracker-switcher/ctl.sh param1=test terminal=false"
echo "View Logs | bash=$HOME/.toptracker-switcher/ctl.sh param1=logs terminal=true"
echo "Edit Config | bash=$HOME/.toptracker-switcher/ctl.sh param1=config terminal=true"
echo "---"
echo "Refresh xbar | bash=/usr/bin/true terminal=false refresh=true"
echo "Restart xbar | bash=/bin/bash param1=-c param2=\"killall -9 xbar; sleep 2; open -a xbar\" terminal=false"
echo "Open TopTracker | bash=/usr/bin/open param1=-a param2=TopTracker terminal=false"
