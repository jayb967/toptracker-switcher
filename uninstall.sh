#!/bin/bash
# TopTracker Switcher Uninstaller
set -e

INSTALL_DIR="$HOME/.toptracker-switcher"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.toptracker-switcher.plist"
XBAR_PLUGIN="$HOME/Library/Application Support/xbar/plugins/toptracker.5s.sh"
CACHE_DIR="$HOME/.cache/toptracker-switcher"

echo "🗑️  TopTracker Switcher Uninstaller"
echo "==================================="
echo ""

# Stop service
echo "⏹️  Stopping service..."
launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true

# Remove LaunchAgent
if [[ -f "$LAUNCH_AGENT" ]]; then
    echo "📄 Removing LaunchAgent..."
    rm "$LAUNCH_AGENT"
fi

# Remove CLI symlink
echo "🔗 Removing command..."
sudo rm -f /usr/local/bin/toptracker-switcher 2>/dev/null || true
rm -f "$HOME/.local/bin/toptracker-switcher" 2>/dev/null || true

# Remove xbar plugin
if [[ -f "$XBAR_PLUGIN" ]]; then
    echo "📊 Removing menu bar plugin..."
    rm "$XBAR_PLUGIN"
fi

# Remove install directory
if [[ -d "$INSTALL_DIR" ]]; then
    echo "📁 Removing $INSTALL_DIR..."
    rm -rf "$INSTALL_DIR"
fi

# Remove cache
if [[ -d "$CACHE_DIR" ]]; then
    echo "🗃️  Removing cache..."
    rm -rf "$CACHE_DIR"
fi

echo ""
echo "✅ Uninstall complete!"
echo ""
echo "Note: xbar was left installed (you may use it for other plugins)"
echo "      To remove xbar: brew uninstall --cask xbar"
echo ""
