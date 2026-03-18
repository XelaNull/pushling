#!/usr/bin/env bash
# reload.sh — Build Pushling and let hot-reload handle the restart
#
# Usage:
#   ./reload.sh              # Debug build + hot-reload
#   ./reload.sh release      # Release build + hot-reload
#
# The HotReloadMonitor in the running app detects the new binary and
# triggers a graceful restart (save state → exit → launchd relaunches).
# If the app isn't running, the script reports that and suggests launching.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Build
echo "==> Building..."
"${SCRIPT_DIR}/build.sh" "${1:-debug}"

# Step 2: Check if app is running
if pgrep -f "Pushling.app/Contents/MacOS/Pushling" > /dev/null 2>&1; then
    echo ""
    echo "==> Pushling is running — hot-reload should trigger automatically."
    echo "    The app will save state, exit, and launchd will relaunch it."
    echo ""
    echo "    If it doesn't restart within 5 seconds, you can manually reload:"
    echo "    echo '{\"command\":\"reload\"}' | nc -U /tmp/pushling.sock"
else
    echo ""
    echo "==> Pushling is not running."
    echo "    To launch: open ${SCRIPT_DIR}/build/Pushling.app"
fi
