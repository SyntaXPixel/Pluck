#!/usr/bin/env bash
set -euo pipefail

# Pluck DMG Packaging Script
echo "==> Creating Pluck DMG..."

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$PROJECT_DIR/build/Release/Pluck.app}"
DMG_PATH="${2:-$PROJECT_DIR/build/Release/Pluck.dmg}"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Application not found at $APP_PATH. Please run scripts/build.sh first."
    exit 1
fi

DMG_ASSETS_DIR="$PROJECT_DIR/build/dmg-assets"
mkdir -p "$DMG_ASSETS_DIR"
mkdir -p "$(dirname "$DMG_PATH")"

echo "==> Generating custom DMG background (black and white style)..."
swift "$PROJECT_DIR/scripts/generate-dmg-background.swift" "$PROJECT_DIR" "$DMG_ASSETS_DIR"

# Ensure dmgbuild is installed
if ! python3 -c "import dmgbuild" >/dev/null 2>&1; then
    echo "==> Installing dmgbuild for styled DMG assembly..."
    python3 -m pip install --quiet dmgbuild
fi

rm -f "$DMG_PATH"

echo "==> Building stylized DMG with dmgbuild..."
python3 -m dmgbuild \
    -s "$PROJECT_DIR/scripts/dmg_settings.py" \
    -Dproject_dir="$PROJECT_DIR" \
    -Dapp_path="$APP_PATH" \
    -Dbackground_path="$DMG_ASSETS_DIR/dmg_background.png" \
    "Pluck" \
    "$DMG_PATH"

echo "==> DMG successfully created at: $DMG_PATH"
ls -lh "$DMG_PATH"
