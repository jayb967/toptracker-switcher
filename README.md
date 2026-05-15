# TopTracker Switcher

Automatically switch to the right windows before TopTracker takes screenshots.

TopTracker periodically captures screenshots as proof of work. This tool monitors TopTracker's screenshot schedule and focuses your project's editor and browser windows ~30 seconds before each capture so you never get caught with the wrong window in focus.

## Features

- **Menu bar countdown** — See exactly when the next screenshot is coming via xbar
- **Auto window switching** — Focuses your code editor + Chrome localhost tab before each screenshot
- **Color-coded urgency** — Green > Yellow > Orange > Red as time runs out
- **Notifications** — Audible + visual alerts before screenshots
- **Multi-project support** — Configure different localhost ports per project
- **Keep-alive** — Prevents TopTracker idle timeout with randomized mouse nudges (25-60s intervals)
- **Sleep prevention** — Uses macOS `caffeinate` to keep the display awake while tracking
- **Auto-start** — Runs as a macOS LaunchAgent on login

## How It Works

1. Reads TopTracker's local SQLite database (`~/Library/Application Support/TopTracker/TopTracker.db`) to detect the currently tracked project
2. Parses TopTracker's application log to find the last screenshot timestamp
3. Calculates the next screenshot time based on the configured interval (default: 15 minutes)
4. ~30 seconds before the next screenshot, automatically focuses:
   - Your code editor (CodeLayer-Pro, CodeLayer, VS Code, or Cursor — in priority order)
   - The Chrome tab matching your project's localhost URL (on external monitors)
5. Sends a macOS notification with the switch status
6. The xbar plugin shows a live countdown in the menu bar, refreshing every 5 seconds

## Requirements

- **macOS** (this tool uses macOS-specific APIs and is not cross-platform)
- **[TopTracker](https://www.toptal.com/tracker)** installed and running
- **[xbar](https://xbarapp.com/)** for the menu bar widget (auto-installed during setup)
- **Accessibility permissions** granted for window control (System Settings > Privacy & Security > Accessibility)
- **sqlite3** (pre-installed on macOS)
- **cliclick** (optional, for precise mouse-based keep-alive; falls back to `osascript` if not installed)

## Installation

### Quick Install (via curl)

```bash
curl -fsSL https://raw.githubusercontent.com/jayb967/toptracker-switcher/main/install.sh | bash
```

### Install from Source

```bash
git clone https://github.com/jayb967/toptracker-switcher.git
cd toptracker-switcher
./install.sh
```

### What the Installer Does

1. Creates `~/.toptracker-switcher/` and copies the scripts there
2. Creates a CLI symlink at `/usr/local/bin/toptracker-switcher` (or `~/.local/bin/` as fallback)
3. Installs xbar via Homebrew if not already present
4. Copies the xbar plugin to `~/Library/Application Support/xbar/plugins/`
5. Creates and loads a macOS LaunchAgent (`com.toptracker-switcher`) for auto-start on login
6. Creates a log directory at `~/.cache/toptracker-switcher/`

### Post-Install

After installation, you will need to:

1. **Grant accessibility permissions** when prompted (or manually in System Settings > Privacy & Security > Accessibility)
2. **Open xbar** and allow it to run if this is your first time using it
3. **Configure your projects** — see the Configuration section below

## Configuration

Edit `~/.toptracker-switcher/config.sh` (or run `toptracker-switcher config`):

```bash
# Map TopTracker project names to localhost ports.
# The project name is matched case-insensitively using glob patterns.
get_project_port() {
    local project="$1"
    case "$(echo "$project" | tr '[:upper:]' '[:lower:]')" in
        *myproject*)        echo "3000" ;;
        *webapp*)           echo "3001" ;;
        *api*)              echo "8080" ;;
        *frontend*)         echo "5173" ;;
        *)                  echo "" ;;
    esac
}

# Your TopTracker account email (auto-detected from DB if left empty)
TOPTRACKER_EMAIL="you@example.com"

# Screenshot interval in seconds (TopTracker default is 15 minutes = 900)
INTERVAL_SECONDS=900

# How many seconds before the screenshot to switch windows
WARN_BEFORE=30

# Keep-alive: prevent idle detection with randomized mouse nudges (1=on, 0=off)
KEEPALIVE_ENABLED=1

# Prevent screen sleep while tracking using caffeinate (1=on, 0=off)
PREVENT_SLEEP=1
```

### Configuration Options

| Setting | Default | Description |
|---------|---------|-------------|
| `get_project_port()` | — | Maps TopTracker project names to localhost port numbers for Chrome tab matching |
| `TOPTRACKER_EMAIL` | auto-detected | Your TopTracker account email; used to query the correct database tables |
| `INTERVAL_SECONDS` | `900` (15 min) | Time between screenshots; must match your TopTracker settings |
| `WARN_BEFORE` | `30` | Seconds before the screenshot to switch windows |
| `KEEPALIVE_ENABLED` | `1` | Enable/disable mouse nudge keep-alive to prevent idle timeout |
| `PREVENT_SLEEP` | `1` | Enable/disable `caffeinate` to prevent screen sleep while tracking |

## Commands

Use the `toptracker-switcher` CLI to manage the service:

| Command | Description |
|---------|-------------|
| `toptracker-switcher status` | Check if the service is running |
| `toptracker-switcher start` | Start the service |
| `toptracker-switcher stop` | Stop the service |
| `toptracker-switcher restart` | Restart the service |
| `toptracker-switcher logs` | View recent stdout and stderr logs |
| `toptracker-switcher next` | Show the next predicted screenshot time |
| `toptracker-switcher test` | Manually trigger a window switch right now |
| `toptracker-switcher config` | Open the config file in your default editor |

## Menu Bar Widget

The xbar plugin displays a live countdown in your macOS menu bar:

| Display | Meaning |
|---------|---------|
| `⏱️ 12m30s` (green) | Plenty of time |
| `⏱️ 2m30s` (yellow) | Under 3 minutes |
| `📸 55s` (orange) | Under 1 minute |
| `📸 25s` (red) | Imminent — windows will switch |
| `⏸️ TT` | TopTracker is not actively tracking |

Clicking the menu bar icon shows the current project, last/next screenshot times, and quick actions (test switch, view logs, edit config, open TopTracker).

## Supported Editors

The switcher detects and focuses editors in this priority order:

1. **CodeLayer-Pro** (preferred)
2. **CodeLayer** (legacy)
3. **Visual Studio Code**
4. **Cursor**

The first running editor found is activated. Chrome tabs are focused on external monitors (windows with x-coordinate >= 1700).

## File Locations

| Path | Purpose |
|------|---------|
| `~/.toptracker-switcher/` | Installed scripts and config |
| `~/.toptracker-switcher/config.sh` | Your project configuration |
| `~/.cache/toptracker-switcher/stdout.log` | Service stdout log |
| `~/.cache/toptracker-switcher/stderr.log` | Service stderr log |
| `~/Library/LaunchAgents/com.toptracker-switcher.plist` | macOS LaunchAgent for auto-start |
| `~/Library/Application Support/xbar/plugins/toptracker.5s.sh` | xbar menu bar plugin |

## Troubleshooting

**Menu bar countdown not showing?**
- Make sure xbar is installed and running: `open -a xbar`
- Grant accessibility permissions: System Settings > Privacy & Security > Accessibility
- Click the xbar icon > Refresh All

**Windows not switching?**
- Grant accessibility permissions for Terminal/iTerm and the switcher
- Verify your project-to-port mapping in `config.sh` matches the project name in TopTracker
- Test manually: `toptracker-switcher test`

**Wrong countdown time displayed?**
- Make sure TopTracker is actively tracking a project
- Check logs for errors: `toptracker-switcher logs`
- Restart the service: `toptracker-switcher restart`
- Restart xbar: close and reopen the xbar application

**Keep-alive not working?**
- Install `cliclick` for reliable mouse nudges: `brew install cliclick`
- Check that `KEEPALIVE_ENABLED=1` in your config
- The fallback uses `osascript` with an Fn key press which has no visible effect

**Service not starting on login?**
- Verify the LaunchAgent exists: `ls ~/Library/LaunchAgents/com.toptracker-switcher.plist`
- Manually load it: `launchctl load ~/Library/LaunchAgents/com.toptracker-switcher.plist`
- Check stderr log for errors: `cat ~/.cache/toptracker-switcher/stderr.log`

## Uninstall

### Quick Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/jayb967/toptracker-switcher/main/uninstall.sh | bash
```

### Manual Uninstall

```bash
# Stop and remove the service
launchctl unload ~/Library/LaunchAgents/com.toptracker-switcher.plist
rm ~/Library/LaunchAgents/com.toptracker-switcher.plist

# Remove installed files
rm -rf ~/.toptracker-switcher
rm -rf ~/.cache/toptracker-switcher

# Remove CLI symlink
sudo rm -f /usr/local/bin/toptracker-switcher

# Remove xbar plugin
rm ~/Library/Application\ Support/xbar/plugins/toptracker.5s.sh

# Optionally remove xbar itself
# brew uninstall --cask xbar
```

## Project Structure

```
toptracker-switcher/
├── README.md                  # This file
├── LICENSE                    # MIT License
├── install.sh                 # Automated installer
├── uninstall.sh               # Clean removal script
├── src/
│   ├── switcher.sh            # Main service — monitoring loop, window switching, keep-alive
│   ├── config.sh              # Configuration template — project mappings and settings
│   └── ctl.sh                 # CLI control script — start/stop/restart/status/logs
└── plugins/
    └── toptracker.5s.sh       # xbar menu bar plugin — live countdown widget
```

## License

MIT

## Credits

Built by [OpenClaw](https://github.com/openclaw/openclaw)
