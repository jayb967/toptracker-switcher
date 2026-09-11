#!/bin/bash
# Start TopTracker + xbar + Switcher
# Run: ~/.toptracker-switcher/start-all.sh

echo "🚀 Starting TopTracker stack..."

# 1. Start TopTracker app if not running
if ! pgrep -x "TopTracker" > /dev/null; then
    echo "  → Starting TopTracker app..."
    open -a "TopTracker"
    sleep 2
else
    echo "  ✓ TopTracker already running"
fi

# 2. Start xbar if not running
if ! pgrep -x "xbar" > /dev/null; then
    echo "  → Starting xbar..."
    open -a "xbar"
    sleep 1
else
    echo "  ✓ xbar already running"
fi

# 3. Start switcher service
echo "  → Starting switcher service..."
launchctl unload ~/Library/LaunchAgents/com.toptracker-switcher.plist 2>/dev/null
sleep 1
launchctl load ~/Library/LaunchAgents/com.toptracker-switcher.plist
echo "  ✓ Switcher loaded"

echo ""
echo "✅ All started! Check your menu bar for the timer."
echo ""
echo "Quick commands:"
echo "  ~/.toptracker-switcher/ctl.sh status  - Check switcher status"
echo "  ~/.toptracker-switcher/ctl.sh logs    - View logs"
echo "  ~/.toptracker-switcher/ctl.sh stop    - Stop switcher"
