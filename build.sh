#!/usr/bin/env bash
# build.sh — Build Pushling and wrap it into a proper macOS .app bundle
#
# Usage:
#   ./build.sh              # Debug build (default)
#   ./build.sh release      # Release build (optimized)
#   ./build.sh debug        # Debug build (explicit)
#
# Output: build/Pushling.app

set -euo pipefail

# --- Configuration ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SPM_DIR="${SCRIPT_DIR}/Pushling"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/Pushling.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

# Parse build configuration
CONFIG="${1:-debug}"
case "${CONFIG}" in
    release|Release)
        CONFIG="release"
        SWIFT_FLAGS="-c release"
        echo "==> Building Pushling (release)..."
        ;;
    debug|Debug|*)
        CONFIG="debug"
        SWIFT_FLAGS="-c debug"
        echo "==> Building Pushling (debug)..."
        ;;
esac

# --- Step 1: Build with Swift Package Manager ---
echo "    [1/5] swift build ${SWIFT_FLAGS}"
cd "${SPM_DIR}"
swift build ${SWIFT_FLAGS} 2>&1

# Find the built binary
BIN_PATH="$(swift build ${SWIFT_FLAGS} --show-bin-path)/Pushling"
if [ ! -f "${BIN_PATH}" ]; then
    echo "ERROR: Built binary not found at ${BIN_PATH}"
    exit 1
fi
echo "    Built: ${BIN_PATH}"

# --- Step 2: Create .app bundle structure ---
echo "    [2/5] Creating .app bundle structure..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# --- Step 3: Generate Info.plist ---
echo "    [3/5] Generating Info.plist..."

# Get the git short hash for the build version, or "dev" if not in a repo
GIT_HASH="$(git -C "${SCRIPT_DIR}" rev-parse --short HEAD 2>/dev/null || echo "dev")"
BUILD_DATE="$(date -u +%Y%m%d)"

cat > "${CONTENTS_DIR}/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>

    <key>CFBundleExecutable</key>
    <string>Pushling</string>

    <key>CFBundleIdentifier</key>
    <string>com.pushling.app</string>

    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>

    <key>CFBundleName</key>
    <string>Pushling</string>

    <key>CFBundleDisplayName</key>
    <string>Pushling</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>0.1.0</string>

    <key>CFBundleVersion</key>
    <string>${BUILD_DATE}.${GIT_HASH}</string>

    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>

    <key>LSUIElement</key>
    <true/>

    <key>NSPrincipalClass</key>
    <string>NSApplication</string>

    <key>NSHighResolutionCapable</key>
    <true/>

    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>

    <key>CFBundleIconFile</key>
    <string></string>
</dict>
</plist>
PLIST

# --- Step 4: Copy binary and resources ---
echo "    [4/5] Copying binary and resources..."

# Copy the executable
cp "${BIN_PATH}" "${MACOS_DIR}/Pushling"
chmod +x "${MACOS_DIR}/Pushling"

# Copy the LaunchAgent plist template to Resources
if [ -f "${SPM_DIR}/Resources/com.pushling.daemon.plist" ]; then
    cp "${SPM_DIR}/Resources/com.pushling.daemon.plist" "${RESOURCES_DIR}/"
fi

# Copy any other resources that exist
for ext in png jpg wav mp3 json; do
    find "${SPM_DIR}/Resources" -name "*.${ext}" -exec cp {} "${RESOURCES_DIR}/" \; 2>/dev/null || true
done

# --- Step 5: Ad-hoc code sign ---
echo "    [5/5] Ad-hoc code signing..."
codesign --force --sign - --deep "${APP_BUNDLE}" 2>&1

# --- Step 6: Deploy to /Applications if installed there ---
INSTALLED_APP="/Applications/Pushling.app"
if [ -d "${INSTALLED_APP}" ]; then
    echo "    [6/6] Deploying to ${INSTALLED_APP}..."
    rsync -a --delete "${APP_BUNDLE}/" "${INSTALLED_APP}/"
    echo "    Deployed — hot-reload should trigger automatically"
else
    echo "    [6/6] No installed copy at ${INSTALLED_APP} — skipping deploy"
fi

# --- Done ---
echo ""
echo "==> Build complete: ${APP_BUNDLE}"
echo "    Bundle ID:  com.pushling.app"
echo "    Version:    0.1.0 (${BUILD_DATE}.${GIT_HASH})"
echo "    Config:     ${CONFIG}"
echo "    LSUIElement: true (no dock icon)"
echo ""
echo "    To run:  open ${APP_BUNDLE}"
echo "    Or:      ./run.sh"
