# TopTracker Switcher

🎯 **Automatically switch to the right windows before TopTracker takes screenshots.**

Never get caught with the wrong window in focus again. This tool monitors TopTracker's screenshot schedule and automatically focuses your project's editor and browser windows ~30 seconds before each screenshot.

## Features

- ⏱️ **Menu bar countdown** — See exactly when the next screenshot is coming
- 🔄 **Auto window switching** — Focuses your editor + localhost browser tab
- 🎨 **Color-coded urgency** — Green → Yellow → Orange → Red as time runs out
- 🔔 **Notifications** — Audible + visual alerts before screenshots
- 📊 **Multi-project support** — Configure different ports per project

## Screenshots

Menu bar shows countdown:
- `⏱️ 12m` (green) — Plenty of time
- `⏱️ 2m30s` (yellow) — Getting close
- `📸 25s` (red) — Imminent!

## Requirements

- macOS
- [TopTracker](https://www.toptal.com/tracker) installed and running
- [xbar](https://xbarapp.com/) for menu bar widget (auto-installed)
- Accessibility permissions for window control

## Quick Install

```bash
curl -fsSL https://raw.githubusercontent.com/jayb967/toptracker-switcher/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/jayb967/toptracker-switcher.git
cd toptracker-switcher
./install.sh
```

## Manual Install

1. Clone this repo
2. Copy files to `~/.toptracker-switcher/`
3. Install xbar: `brew install --cask xbar`
4. Copy `plugins/toptracker.5s.sh` to `~/Library/Application Support/xbar/plugins/`
5. Copy the LaunchAgent plist to `~/Library/LaunchAgents/`
6. Run `launchctl load ~/Library/LaunchAgents/com.toptracker-switcher.plist`

## Configuration

Edit `~/.toptracker-switcher/config.sh` to map your projects to localhost ports:

```bash
get_project_port() {
    local project="$1"
    case "$(echo "$project" | tr '[:upper:]' '[:lower:]')" in
        *myproject*)    echo "3000" ;;
        *another*)      echo "3001" ;;
        *webapp*)       echo "8080" ;;
        *)              echo "" ;;
    esac
}
```

## Commands

| Command | Description |
|---------|-------------|
| `toptracker-switcher status` | Check if running |
| `toptracker-switcher start` | Start the service |
| `toptracker-switcher stop` | Stop the service |
| `toptracker-switcher restart` | Restart the service |
| `toptracker-switcher logs` | View recent logs |
| `toptracker-switcher next` | Show next screenshot time |
| `toptracker-switcher test` | Test window switching now |

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/jayb967/toptracker-switcher/main/uninstall.sh | bash
```

Or manually:

```bash
# Stop service
launchctl unload ~/Library/LaunchAgents/com.toptracker-switcher.plist

# Remove files
rm -rf ~/.toptracker-switcher
rm ~/Library/LaunchAgents/com.toptracker-switcher.plist
rm ~/Library/Application\ Support/xbar/plugins/toptracker.5s.sh
```

## How It Works

1. Monitors TopTracker's log file for screenshot timestamps
2. Calculates when the next screenshot will occur (15-min intervals)
3. ~30 seconds before, focuses:
   - Your code editor (CodeLayer, VS Code, or Cursor)
   - Chrome tab with your project's localhost URL
4. Shows countdown in menu bar via xbar

## Supported Editors

- CodeLayer (preferred)
- Visual Studio Code
- Cursor

## Troubleshooting

**Menu bar not showing?**
- Open xbar from Applications
- Grant accessibility permissions when prompted
- Click xbar icon → Refresh All

**Windows not switching?**
- Grant accessibility permissions: System Settings → Privacy & Security → Accessibility
- Check your project-to-port mapping in `config.sh`

**Wrong time displayed?**
- Make sure TopTracker is actively tracking
- Check logs: `toptracker-switcher logs`

## License

MIT

## Credits

Built with 🦞 by [OpenClaw](https://github.com/openclaw/openclaw)
