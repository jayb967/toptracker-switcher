#!/bin/bash
# TopTracker Switcher Installer
set -e

INSTALL_DIR="$HOME/.toptracker-switcher"
LAUNCH_AGENT="$HOME/Library/LaunchAgents/com.toptracker-switcher.plist"
XBAR_PLUGIN_DIR="$HOME/Library/Application Support/xbar/plugins"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🎯 TopTracker Switcher Installer"
echo "================================"
echo ""

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "❌ This tool only works on macOS"
    exit 1
fi

# Check for TopTracker
if [[ ! -d "$HOME/Library/Application Support/TopTracker" ]]; then
    echo "⚠️  TopTracker not found. Install it from https://www.toptal.com/tracker"
    echo "   Continuing anyway (you can install TopTracker later)..."
fi

# Create install directory
echo "📁 Creating $INSTALL_DIR..."
mkdir -p "$INSTALL_DIR"
mkdir -p "$HOME/.cache/toptracker-switcher"

# Copy scripts
echo "📋 Copying scripts..."
if [[ -f "$SCRIPT_DIR/src/switcher.sh" ]]; then
    # Running from cloned repo
    cp "$SCRIPT_DIR/src/switcher.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/src/config.sh" "$INSTALL_DIR/"
    cp "$SCRIPT_DIR/src/ctl.sh" "$INSTALL_DIR/"
else
    # Running via curl - download from GitHub
    echo "   Downloading from GitHub..."
    curl -fsSL "https://raw.githubusercontent.com/jayb967/toptracker-switcher/main/src/switcher.sh" -o "$INSTALL_DIR/switcher.sh"
    curl -fsSL "https://raw.githubusercontent.com/jayb967/toptracker-switcher/main/src/config.sh" -o "$INSTALL_DIR/config.sh"
    curl -fsSL "https://raw.githubusercontent.com/jayb967/toptracker-switcher/main/src/ctl.sh" -o "$INSTALL_DIR/ctl.sh"
fi

chmod +x "$INSTALL_DIR/switcher.sh"
chmod +x "$INSTALL_DIR/ctl.sh"

# Create CLI symlink
echo "🔗 Creating toptracker-switcher command..."
sudo ln -sf "$INSTALL_DIR/ctl.sh" /usr/local/bin/toptracker-switcher 2>/dev/null || {
    mkdir -p "$HOME/.local/bin"
    ln -sf "$INSTALL_DIR/ctl.sh" "$HOME/.local/bin/toptracker-switcher"
    echo "   Added to ~/.local/bin (add to PATH if needed)"
}

# Install LaunchAgent
echo "⚙️  Installing LaunchAgent..."
cat > "$LAUNCH_AGENT" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.toptracker-switcher</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>-c</string>
        <string>$HOME/.toptracker-switcher/switcher.sh run</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>StandardOutPath</key>
    <string>$HOME/.cache/toptracker-switcher/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.cache/toptracker-switcher/stderr.log</string>
</dict>
</plist>
EOF

# Fix paths in plist (expand $HOME)
sed -i '' "s|\$HOME|$HOME|g" "$LAUNCH_AGENT"

# Install xbar if needed
if ! command -v xbar &>/dev/null && [[ ! -d "/Applications/xbar.app" ]]; then
    echo "📊 Installing xbar for menu bar widget..."
    if command -v brew &>/dev/null; then
        brew install --cask xbar
    else
        echo "   ⚠️  Homebrew not found. Install xbar manually from https://xbarapp.com/"
    fi
fi

# Install xbar plugin
echo "📊 Installing menu bar plugin..."
mkdir -p "$XBAR_PLUGIN_DIR"
if [[ -f "$SCRIPT_DIR/plugins/toptracker.5s.sh" ]]; then
    cp "$SCRIPT_DIR/plugins/toptracker.5s.sh" "$XBAR_PLUGIN_DIR/"
else
    curl -fsSL "https://raw.githubusercontent.com/jayb967/toptracker-switcher/main/plugins/toptracker.5s.sh" -o "$XBAR_PLUGIN_DIR/toptracker.5s.sh"
fi
chmod +x "$XBAR_PLUGIN_DIR/toptracker.5s.sh"

# Start service
echo "🚀 Starting service..."
launchctl unload "$LAUNCH_AGENT" 2>/dev/null || true
launchctl load "$LAUNCH_AGENT"

# Start xbar
if [[ -d "/Applications/xbar.app" ]]; then
    echo "📊 Starting xbar..."
    open -a xbar
fi

echo ""
echo "✅ Installation complete!"
echo ""
echo "📍 Installed to: $INSTALL_DIR"
echo "📊 Menu bar: Look for ⏱️ icon (may need to grant permissions)"
echo ""
echo "Commands:"
echo "  toptracker-switcher status  - Check status"
echo "  toptracker-switcher next    - Next screenshot time"
echo "  toptracker-switcher logs    - View logs"
echo ""
echo "⚙️  Configure projects: edit $INSTALL_DIR/config.sh"
echo ""
