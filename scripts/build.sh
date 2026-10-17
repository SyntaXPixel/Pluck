#!/usr/bin/env bash
set -euo pipefail

# Pluck Build Script
echo "==> Building Pluck (macOS Menu Bar OCR)..."

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

# 1. Regenerate Xcode project if xcodegen is present
if command -v xcodegen &> /dev/null; then
    echo "==> Generating Xcode project with XcodeGen..."
    xcodegen generate
fi

BUILD_DIR="$PROJECT_DIR/build"
DERIVED_DATA="$BUILD_DIR/DerivedData"
OUTPUT_DIR="$BUILD_DIR/Release"

rm -rf "$OUTPUT_DIR"
mkdir -p "$OUTPUT_DIR"

# 2. Build Release Configuration
echo "==> Compiling Pluck..."
xcodebuild -project Pluck.xcodeproj \
    -scheme Pluck \
    -configuration Release \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE="Manual" \
    build

APP_PATH=$(find "$DERIVED_DATA" -name "Pluck.app" -type d | head -n 1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Pluck.app was not found in build outputs."
    exit 1
fi

echo "==> Copying application to $OUTPUT_DIR/Pluck.app..."
cp -R "$APP_PATH" "$OUTPUT_DIR/"

echo "==> Build complete! App located at: $OUTPUT_DIR/Pluck.app"
