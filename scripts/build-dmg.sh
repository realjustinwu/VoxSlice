#!/bin/bash
set -euo pipefail

# VoxSlice DMG Build Script
# Per D-12: Archives app via xcodebuild, creates DMG via create-dmg
# Per D-11: Unsigned DMG for v1 (no code signing or notarization)

PROJECT_NAME="VoxSlice"
SCHEME="VoxSlice"
PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="${PROJECT_DIR}/build"
ARCHIVE_PATH="${BUILD_DIR}/${PROJECT_NAME}.xcarchive"
EXPORT_PATH="${BUILD_DIR}/export"
DMG_NAME="${PROJECT_NAME}.dmg"
DMG_PATH="${BUILD_DIR}/${DMG_NAME}"

echo "=== Building ${PROJECT_NAME} DMG ==="
echo "Project dir: ${PROJECT_DIR}"
echo "Build dir:   ${BUILD_DIR}"

# Step 1: Clean build directory
echo ""
echo "[1/3] Cleaning build directory..."
rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"

# Step 2: Archive the app (Release configuration)
# Per D-11: Unsigned build, no code signing
echo ""
echo "[2/3] Archiving ${PROJECT_NAME}..."
xcodebuild archive \
    -project "${PROJECT_DIR}/${PROJECT_NAME}.xcodeproj" \
    -scheme "${SCHEME}" \
    -configuration Release \
    -archivePath "${ARCHIVE_PATH}" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    ENABLE_PKG_POST_PROCESSING=NO \
    | tail -1

# Step 3: Export app from archive
echo ""
echo "Exporting app from archive..."
mkdir -p "${EXPORT_PATH}"

# Copy the .app from the archive
cp -R "${ARCHIVE_PATH}/Products/Applications/${PROJECT_NAME}.app" "${EXPORT_PATH}/"

if [ ! -d "${EXPORT_PATH}/${PROJECT_NAME}.app" ]; then
    echo "ERROR: ${PROJECT_NAME}.app not found in archive at expected path"
    echo "Looking for .app files in archive..."
    find "${ARCHIVE_PATH}/Products" -name "*.app" 2>/dev/null || true
    exit 1
fi

echo "App exported to: ${EXPORT_PATH}/${PROJECT_NAME}.app"

# Step 4: Create DMG using create-dmg
# Per D-10: Professional DMG with Applications folder shortcut
echo ""
echo "[3/3] Creating DMG..."

# Check for volume icon (asset catalog may not produce .icns file)
VOLICON_ARGS=""
ICNS_PATH="${EXPORT_PATH}/${PROJECT_NAME}.app/Contents/Resources/AppIcon.icns"
if [ -f "${ICNS_PATH}" ]; then
    VOLICON_ARGS="--volicon ${ICNS_PATH}"
fi

# Check if create-dmg is installed
if ! command -v create-dmg &> /dev/null; then
    echo ""
    echo "ERROR: create-dmg is not installed."
    echo "Install it with: brew install create-dmg"
    echo ""
    echo "Falling back to hdiutil for basic DMG creation..."

    # Fallback: create basic DMG with hdiutil
    hdiutil create -volname "${PROJECT_NAME}" \
        -srcfolder "${EXPORT_PATH}" \
        -ov -format UDZO \
        "${DMG_PATH}"

    echo ""
    echo "=== DMG created (basic) ==="
    echo "Path: ${DMG_PATH}"
    ls -lh "${DMG_PATH}"
    exit 0
fi

create-dmg \
    --volname "${PROJECT_NAME}" \
    ${VOLICON_ARGS} \
    --window-pos 200 120 \
    --window-size 600 400 \
    --icon-size 100 \
    --icon "${PROJECT_NAME}.app" 150 190 \
    --app-drop-link 450 190 \
    --hide-extension "${PROJECT_NAME}.app" \
    "${DMG_PATH}" \
    "${EXPORT_PATH}/"

echo ""
echo "=== Build Complete ==="
echo "DMG: ${DMG_PATH}"
ls -lh "${DMG_PATH}"
echo ""
echo "Per D-11: This is an UNSIGNED build."
echo "Users may see a Gatekeeper warning when opening."
echo "Bypass: Right-click the app > Open > Open in the dialog."
echo "Code signing can be added later with an Apple Developer certificate."
