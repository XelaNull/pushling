#!/usr/bin/env bash
# run.sh — Build and launch Pushling
#
# Usage:
#   ./run.sh              # Debug build + launch
#   ./run.sh release      # Release build + launch
#   ./run.sh --no-build   # Launch existing build without rebuilding
#
# The app runs as a menu-bar daemon (LSUIElement) — no dock icon.
# Look for the "P" in the menu bar. Check Console.app for logs tagged [Pushling].

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_BUNDLE="${SCRIPT_DIR}/build/Pushling.app"

# --- Parse arguments ---
NO_BUILD=false
CONFIG="debug"

for arg in "$@"; do
    case "${arg}" in
        --no-build)
            NO_BUILD=true
            ;;
        release|Release)
            CONFIG="release"
            ;;
        debug|Debug)
            CONFIG="debug"
            ;;
    esac
done

# --- Kill any running instance ---
if pgrep -x "Pushling" > /dev/null 2>&1; then
    echo "==> Stopping existing Pushling instance..."
    pkill -x "Pushling" 2>/dev/null || true
    sleep 0.5
fi

# --- Build if needed ---
if [ "${NO_BUILD}" = false ]; then
    "${SCRIPT_DIR}/build.sh" "${CONFIG}"
fi

# --- Verify the bundle exists ---
if [ ! -d "${APP_BUNDLE}" ]; then
    echo "ERROR: ${APP_BUNDLE} not found. Run ./build.sh first."
    exit 1
fi

# --- Launch ---
echo "==> Launching Pushling..."
echo "    Menu bar: Look for 'P' icon"
echo "    Logs:     Console.app -> filter 'Pushling'"
echo "    Quit:     Click 'P' -> Quit Pushling"
echo ""

# Use 'open' to launch as a proper macOS app
# --stdout and --stderr to terminal for development convenience
open "${APP_BUNDLE}"

echo "==> Pushling launched."
echo "    PID: $(pgrep -x Pushling 2>/dev/null || echo '(starting...)')"
