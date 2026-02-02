#!/bin/bash
# TopTracker Switcher Control Script

INSTALL_DIR="$HOME/.toptracker-switcher"
PLIST="$HOME/Library/LaunchAgents/com.toptracker-switcher.plist"
SERVICE="com.toptracker-switcher"
LOG_DIR="$HOME/.cache/toptracker-switcher"

case "${1:-status}" in
    start)
        launchctl load "$PLIST" 2>/dev/null
        echo "✓ Started toptracker-switcher"
        ;;
    stop)
        launchctl unload "$PLIST" 2>/dev/null
        echo "✓ Stopped toptracker-switcher"
        ;;
    restart)
        launchctl unload "$PLIST" 2>/dev/null
        sleep 1
        launchctl load "$PLIST" 2>/dev/null
        echo "✓ Restarted toptracker-switcher"
        ;;
    status)
        if launchctl list 2>/dev/null | grep -q "$SERVICE"; then
            echo "✓ Running"
            launchctl list 2>/dev/null | grep "$SERVICE"
        else
            echo "✗ Not running"
        fi
        ;;
    logs)
        echo "=== stdout ==="
        tail -30 "$LOG_DIR/stdout.log" 2>/dev/null || echo "(no stdout log)"
        echo ""
        echo "=== stderr ==="
        tail -10 "$LOG_DIR/stderr.log" 2>/dev/null || echo "(no stderr log)"
        ;;
    next)
        "$INSTALL_DIR/switcher.sh" next
        ;;
    test)
        "$INSTALL_DIR/switcher.sh" test
        ;;
    config)
        ${EDITOR:-nano} "$INSTALL_DIR/config.sh"
        ;;
    *)
        echo "TopTracker Switcher"
        echo ""
        echo "Usage: toptracker-switcher [command]"
        echo ""
        echo "Commands:"
        echo "  status   Check if service is running"
        echo "  start    Start the service"
        echo "  stop     Stop the service"
        echo "  restart  Restart the service"
        echo "  logs     View recent logs"
        echo "  next     Show next screenshot time"
        echo "  test     Test window switching now"
        echo "  config   Edit project configuration"
        exit 1
        ;;
esac
