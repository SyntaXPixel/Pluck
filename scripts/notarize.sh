#!/usr/bin/env bash
set -euo pipefail

# Pluck Notarization Script
echo "==> Notarizing Pluck..."

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$PROJECT_DIR/build/Release/Pluck.app}"

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Application not found at $APP_PATH. Please run scripts/build.sh first."
    exit 1
fi

KEYCHAIN_PROFILE="${KEYCHAIN_PROFILE:-}"
APPLE_ID="${APPLE_ID:-}"
TEAM_ID="${TEAM_ID:-}"
PASSWORD="${APPLE_PASSWORD:-}"

ZIP_PATH="$PROJECT_DIR/build/Release/Pluck.zip"
echo "==> Creating archive for notarization: $ZIP_PATH..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

if [ -n "$KEYCHAIN_PROFILE" ]; then
    echo "==> Submitting to notarytool with keychain profile: $KEYCHAIN_PROFILE..."
    xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
elif [ -n "$APPLE_ID" ] && [ -n "$TEAM_ID" ] && [ -n "$PASSWORD" ]; then
    echo "==> Submitting to notarytool with credentials..."
    xcrun notarytool submit "$ZIP_PATH" --apple-id "$APPLE_ID" --team-id "$TEAM_ID" --password "$PASSWORD" --wait
else
    echo "WARNING: Neither KEYCHAIN_PROFILE nor (APPLE_ID, TEAM_ID, APPLE_PASSWORD) provided."
    echo "Usage with keychain profile:"
    echo "  KEYCHAIN_PROFILE=\"AC_PASSWORD\" ./scripts/notarize.sh"
    echo "Usage with environment variables:"
    echo "  APPLE_ID=\"you@example.com\" TEAM_ID=\"XXXXXXXXXX\" APPLE_PASSWORD=\"xxxx-xxxx-xxxx-xxxx\" ./scripts/notarize.sh"
    exit 1
fi

echo "==> Stapling ticket to application..."
xcrun stapler staple "$APP_PATH"
echo "==> Notarization and stapling complete!"
