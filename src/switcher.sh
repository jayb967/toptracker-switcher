#!/bin/bash
# TopTracker Smart Window Switcher
# Switches windows BEFORE screenshots, not during

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.sh"
[[ -f "$CONFIG_FILE" ]] && source "$CONFIG_FILE"

# Defaults (can be overridden in config.sh)
TOPTRACKER_EMAIL="${TOPTRACKER_EMAIL:-}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-900}"
WARN_BEFORE="${WARN_BEFORE:-30}"
KEEPALIVE_ENABLED="${KEEPALIVE_ENABLED:-1}"
PREVENT_SLEEP="${PREVENT_SLEEP:-1}"

# Caffeinate management (prevents screen sleep)
caffeinate_pid=""
last_project_seen=0
SLEEP_GRACE_PERIOD=300  # Keep screen awake for 5 min after tracking stops

start_caffeinate() {
    if [[ "$PREVENT_SLEEP" != "1" ]]; then return; fi
    if [[ -z "$caffeinate_pid" ]] || ! kill -0 "$caffeinate_pid" 2>/dev/null; then
        caffeinate -d -i &
        caffeinate_pid=$!
        log "☕ Caffeinate started (preventing sleep)"
    fi
}
stop_caffeinate() {
    if [[ -n "$caffeinate_pid" ]] && kill -0 "$caffeinate_pid" 2>/dev/null; then
        kill "$caffeinate_pid" 2>/dev/null
        caffeinate_pid=""
        log "☕ Caffeinate stopped (sleep allowed)"
    fi
}
maybe_stop_caffeinate() {
    local now=$(date +%s)
    # Only stop if no project for SLEEP_GRACE_PERIOD seconds
    if [[ $((now - last_project_seen)) -ge $SLEEP_GRACE_PERIOD ]]; then
        stop_caffeinate
    fi
}
trap stop_caffeinate EXIT

DB_PATH="$HOME/Library/Application Support/TopTracker/TopTracker.db"
LOG_PATH="$HOME/Library/Application Support/TopTracker/application.log"
STATE_FILE="$HOME/.cache/toptracker-switcher/state"

mkdir -p "$(dirname "$STATE_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Keep-alive: nudge mouse 1px to prevent idle detection
last_keepalive=0
next_keepalive_interval=0
keepalive_nudge() {
    if [[ "$KEEPALIVE_ENABLED" != "1" ]] && [[ "$KEEPALIVE_INTERVAL" -le 0 ]]; then
        return
    fi
    
    local now=$(date +%s)
    
    # Set random interval if not set (25-60 seconds)
    if [[ $next_keepalive_interval -eq 0 ]]; then
        next_keepalive_interval=$((25 + RANDOM % 36))
    fi
    
    if [[ $((now - last_keepalive)) -ge $next_keepalive_interval ]]; then
        # Get current mouse position and nudge 1px right then back
        if command -v cliclick &>/dev/null; then
            local pos=$(cliclick p 2>/dev/null)
            if [[ -n "$pos" ]]; then
                local x=$(echo "$pos" | cut -d',' -f1)
                local y=$(echo "$pos" | cut -d',' -f2)
                cliclick m:"$((x+1)),$y" m:"$x,$y" 2>/dev/null
            fi
        else
            # Fallback: use osascript for a tiny mouse move
            osascript -e 'tell application "System Events" to key code 63' 2>/dev/null || true  # fn key (no visible effect)
        fi
        last_keepalive=$now
        # Set next random interval (25-60 seconds)
        next_keepalive_interval=$((25 + RANDOM % 36))
        log "♥ Keep-alive (next in ${next_keepalive_interval}s)"
    fi
}

# Auto-detect TopTracker email if not set
detect_email() {
    if [[ -z "$TOPTRACKER_EMAIL" ]]; then
        TOPTRACKER_EMAIL=$(sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name LIKE '%_activity'" 2>/dev/null | head -1 | sed 's/_activity$//')
    fi
}

get_current_project() {
    detect_email
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
    # Get the most recent activity start (after any tracking restart)
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
    local now=$(date +%s)
    
    # If activity started after last screenshot, use activity start as baseline
    if [[ -n "$activity_start" ]] && [[ -n "$last_screenshot" ]]; then
        if [[ $activity_start -gt $last_screenshot ]]; then
            # New session - calculate from activity start
            echo $((activity_start + INTERVAL_SECONDS))
            return
        fi
    fi
    
    # Normal case - calculate from last screenshot
    if [[ -n "$last_screenshot" ]]; then
        echo $((last_screenshot + INTERVAL_SECONDS))
        return
    fi
    
    # Fallback - use activity start if no screenshots yet
    if [[ -n "$activity_start" ]]; then
        echo $((activity_start + INTERVAL_SECONDS))
        return
    fi
}

# Default port mapping (override in config.sh)
if ! declare -f get_project_port &>/dev/null; then
    get_project_port() {
        echo ""
    }
fi

focus_chrome_on_external() {
    local port="$1"
    osascript <<EOF 2>/dev/null
tell application "Google Chrome"
    set windowList to every window
    repeat with w in windowList
        set winBounds to bounds of w
        -- Check if window is on external monitor (x >= 1700)
        if item 1 of winBounds >= 1700 then
            set tabList to every tab of w
            set tabIndex to 0
            repeat with t in tabList
                set tabIndex to tabIndex + 1
                if URL of t contains "localhost:$port" then
                    set active tab index of w to tabIndex
                    set index of w to 1
                    return "focused"
                end if
            end repeat
        end if
    end repeat
end tell
return "not found"
EOF
}

focus_editor_on_builtin() {
    # Prefer CodeLayer if running
    if pgrep -f "CodeLayer.app" &>/dev/null; then
        log "  ✓ Editor: CodeLayer"
        osascript -e 'tell application "CodeLayer" to activate' 2>/dev/null || true
        return 0
    fi
    
    # Then VS Code
    if pgrep -f "Visual Studio Code.app" &>/dev/null; then
        log "  ✓ Editor: VS Code"
        osascript -e 'tell application "Visual Studio Code" to activate' 2>/dev/null || true
        return 0
    fi
    
    # Then Cursor
    if pgrep -f "Cursor.app" &>/dev/null; then
        log "  ✓ Editor: Cursor"
        osascript -e 'tell application "Cursor" to activate' 2>/dev/null || true
        return 0
    fi
    
    return 1
}

focus_project_windows() {
    local project="$1"
    local time_remaining="${2:-30}"
    local focused=0
    
    log "Switching to: $project"
    
    # Focus editor
    if focus_editor_on_builtin "$project"; then
        focused=$((focused + 1))
    fi
    
    # Focus Chrome
    local port=$(get_project_port "$project")
    if [[ -n "$port" ]]; then
        if [[ $(focus_chrome_on_external "$port") == "focused" ]]; then
            log "  ✓ Chrome: localhost:$port"
            focused=$((focused + 1))
        fi
    fi
    
    # Notification with actual time remaining
    if [[ $focused -gt 0 ]]; then
        osascript -e "display notification \"Screenshot in ~${time_remaining}s! Focused $focused window(s) for $project\" with title \"📸 TopTracker\" sound name \"Glass\""
    else
        osascript -e "display notification \"Screenshot in ~${time_remaining}s! No windows found for $project\" with title \"⚠️ TopTracker\" sound name \"Basso\""
    fi
    
    return $focused
}

# Main predictive loop
main() {
    log "TopTracker Switcher - Predictive Mode"
    log "Interval: ${INTERVAL_SECONDS}s, Warning: ${WARN_BEFORE}s before"
    if [[ "$KEEPALIVE_ENABLED" == "1" ]]; then
        log "Keep-alive: enabled (random 25-60s)"
    fi
    if [[ "$PREVENT_SLEEP" == "1" ]]; then
        log "Prevent sleep: enabled (caffeinate)"
    fi
    
    local last_warned=0
    
    while true; do
        local project=$(get_current_project)
        
        if [[ -z "$project" ]]; then
            maybe_stop_caffeinate
            sleep 30
            continue
        fi
        
        # Track when we last saw an active project
        last_project_seen=$(date +%s)
        
        # Keep screen awake while tracking
        start_caffeinate
        
        local now=$(date +%s)
        local next_screenshot=$(get_next_screenshot_time)
        
        if [[ -n "$next_screenshot" ]]; then
            local time_until=$((next_screenshot - now))
            local warn_at=$((next_screenshot - WARN_BEFORE))
            
            # Debug every minute
            if (( now % 60 < 5 )); then
                log "Project: $project | Next screenshot in: ${time_until}s"
            fi
            
            # Time to warn?
            if [[ $now -ge $warn_at ]] && [[ $now -lt $next_screenshot ]] && [[ $last_warned -lt $warn_at ]]; then
                log "⚠️ Screenshot in ~${time_until}s - switching windows!"
                focus_project_windows "$project" "$time_until"
                last_warned=$now
            fi
            
            # After expected screenshot time, check if it happened and reset
            if [[ $now -gt $next_screenshot ]]; then
                local new_next=$(get_next_screenshot_time)
                if [[ "$new_next" != "$next_screenshot" ]]; then
                    log "Screenshot taken. Next in ${INTERVAL_SECONDS}s"
                    last_warned=0
                fi
            fi
        fi
        
        # Keep-alive nudge to prevent idle detection
        keepalive_nudge
        
        sleep 5
    done
}

# CLI
case "${1:-run}" in
    run)
        main
        ;;
    test)
        project=$(get_current_project)
        log "Testing for project: $project"
        focus_project_windows "$project" "30"
        ;;
    next)
        now=$(date +%s)
        next=$(get_next_screenshot_time)
        last=$(get_last_screenshot_time)
        activity=$(get_activity_start_time)
        
        if [[ -n "$next" ]]; then
            remaining=$((next - now))
            [[ -n "$last" ]] && log "Last screenshot: $(date -r $last '+%H:%M:%S')"
            [[ -n "$activity" ]] && [[ $activity -gt ${last:-0} ]] && log "Activity restart: $(date -r $activity '+%H:%M:%S')"
            log "Next screenshot: $(date -r $next '+%H:%M:%S') (in ${remaining}s)"
        else
            log "No screenshot data found"
        fi
        ;;
    *)
        echo "Usage: $0 [run|test|next]"
        ;;
esac
