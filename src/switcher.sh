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

DB_PATH="$HOME/Library/Application Support/TopTracker/TopTracker.db"
LOG_PATH="$HOME/Library/Application Support/TopTracker/application.log"
STATE_FILE="$HOME/.cache/toptracker-switcher/state"

mkdir -p "$(dirname "$STATE_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
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
    
    local last_warned=0
    
    while true; do
        local project=$(get_current_project)
        
        if [[ -z "$project" ]]; then
            sleep 30
            continue
        fi
        
        local last_screenshot=$(get_last_screenshot_time)
        local now=$(date +%s)
        
        if [[ -n "$last_screenshot" ]]; then
            local next_screenshot=$((last_screenshot + INTERVAL_SECONDS))
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
            
            # After screenshot, reset
            if [[ $now -gt $next_screenshot ]]; then
                local new_last=$(get_last_screenshot_time)
                if [[ "$new_last" != "$last_screenshot" ]]; then
                    log "Screenshot taken. Next in ${INTERVAL_SECONDS}s"
                    last_warned=0
                fi
            fi
        fi
        
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
        last=$(get_last_screenshot_time)
        now=$(date +%s)
        if [[ -n "$last" ]]; then
            next=$((last + INTERVAL_SECONDS))
            remaining=$((next - now))
            log "Last screenshot: $(date -r $last '+%H:%M:%S')"
            log "Next screenshot: $(date -r $next '+%H:%M:%S') (in ${remaining}s)"
        else
            log "No screenshot found in log"
        fi
        ;;
    *)
        echo "Usage: $0 [run|test|next]"
        ;;
esac
