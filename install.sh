#!/usr/bin/env bash
# install.sh — Build Pushling, install to /Applications, set up LaunchAgent
#
# Usage:
#   ./install.sh            # Build release, install, set up LaunchAgent
#   ./install.sh --uninstall  # Remove from /Applications and unload LaunchAgent
#
# This installs Pushling as a login item that starts automatically.
# The app runs as a menu-bar daemon (no dock icon, no windows).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE="${SCRIPT_DIR}/build/Pushling.app"
INSTALL_DIR="/Applications"
INSTALLED_APP="${INSTALL_DIR}/Pushling.app"
LAUNCH_AGENT_PLIST="$HOME/Library/LaunchAgents/com.pushling.daemon.plist"
LOG_DIR="$HOME/Library/Logs/Pushling"

# --- Uninstall ---
if [ "${1:-}" = "--uninstall" ]; then
    echo "==> Uninstalling Pushling..."

    # Stop running instance
    if pgrep -x "Pushling" > /dev/null 2>&1; then
        echo "    Stopping Pushling..."
        pkill -x "Pushling" 2>/dev/null || true
        sleep 0.5
    fi

    # Unload LaunchAgent
    if [ -f "${LAUNCH_AGENT_PLIST}" ]; then
        echo "    Unloading LaunchAgent..."
        launchctl unload "${LAUNCH_AGENT_PLIST}" 2>/dev/null || true
        rm -f "${LAUNCH_AGENT_PLIST}"
    fi

    # Remove from /Applications
    if [ -d "${INSTALLED_APP}" ]; then
        echo "    Removing ${INSTALLED_APP}..."
        rm -rf "${INSTALLED_APP}"
    fi

    echo "==> Pushling uninstalled."
    echo "    Note: State data preserved at ~/.local/share/pushling/"
    echo "    To remove all data: rm -rf ~/.local/share/pushling/"
    exit 0
fi

# --- Build (always release for install) ---
echo "==> Building Pushling (release) for installation..."
"${SCRIPT_DIR}/build.sh" release

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "ERROR: Build failed — ${APP_BUNDLE} not found."
    exit 1
fi

# --- Stop existing instance ---
if pgrep -x "Pushling" > /dev/null 2>&1; then
    echo "==> Stopping existing Pushling instance..."
    pkill -x "Pushling" 2>/dev/null || true
    sleep 0.5
fi

# --- Unload existing LaunchAgent ---
if [ -f "${LAUNCH_AGENT_PLIST}" ]; then
    echo "==> Unloading existing LaunchAgent..."
    launchctl unload "${LAUNCH_AGENT_PLIST}" 2>/dev/null || true
fi

# --- Install to /Applications ---
echo "==> Installing to ${INSTALLED_APP}..."
rm -rf "${INSTALLED_APP}"
cp -R "${APP_BUNDLE}" "${INSTALLED_APP}"

# --- Create log directory ---
mkdir -p "${LOG_DIR}"

# --- Create LaunchAgent plist ---
echo "==> Setting up LaunchAgent..."
mkdir -p "$(dirname "${LAUNCH_AGENT_PLIST}")"

cat > "${LAUNCH_AGENT_PLIST}" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.pushling.daemon</string>

    <key>ProgramArguments</key>
    <array>
        <string>${INSTALLED_APP}/Contents/MacOS/Pushling</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>KeepAlive</key>
    <true/>

    <key>ProcessType</key>
    <string>Interactive</string>

    <key>StandardOutPath</key>
    <string>${LOG_DIR}/pushling.stdout.log</string>

    <key>StandardErrorPath</key>
    <string>${LOG_DIR}/pushling.stderr.log</string>

    <key>EnvironmentVariables</key>
    <dict>
        <key>PUSHLING_LAUNCHED_BY_AGENT</key>
        <string>1</string>
    </dict>
</dict>
</plist>
PLIST

# --- Load LaunchAgent ---
echo "==> Loading LaunchAgent..."
launchctl load "${LAUNCH_AGENT_PLIST}"

# --- Verify ---
sleep 1
if pgrep -x "Pushling" > /dev/null 2>&1; then
    PID="$(pgrep -x Pushling)"
    echo ""
    echo "==> Pushling installed and running!"
    echo "    App:         ${INSTALLED_APP}"
    echo "    PID:         ${PID}"
    echo "    LaunchAgent: ${LAUNCH_AGENT_PLIST}"
    echo "    Logs:        ${LOG_DIR}/"
    echo "    State:       ~/.local/share/pushling/state.db"
    echo "    Socket:      /tmp/pushling.sock"
    echo ""
    echo "    Menu bar: Look for 'P' icon"
    echo "    Quit:     Click 'P' -> Quit Pushling (will auto-restart via LaunchAgent)"
    echo "    Uninstall: ./install.sh --uninstall"
else
    echo ""
    echo "==> Pushling installed but may not have started yet."
    echo "    App:         ${INSTALLED_APP}"
    echo "    LaunchAgent: ${LAUNCH_AGENT_PLIST}"
    echo "    Check logs:  tail -f ${LOG_DIR}/pushling.stderr.log"
    echo ""
    echo "    Try launching manually: open ${INSTALLED_APP}"
fi
