#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
DERIVED_DATA="${DERIVED_DATA:-$ROOT_DIR/build/DerivedData}"
DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
BUNDLE_ID="com.zephyrdeng.GlabTouch"

"$ROOT_DIR/scripts/run-unit-tests.sh"

xcodebuild \
  -project "$ROOT_DIR/GlabTouch.xcodeproj" \
  -scheme GlabTouch \
  -configuration Debug \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_PATH="$DERIVED_DATA/Build/Products/Debug-iphonesimulator/GlabTouch.app"
xcrun simctl bootstatus booted -b
xcrun simctl install booted "$APP_PATH"
xcrun simctl launch booted "$BUNDLE_ID"
sleep "${SMOKE_SCREENSHOT_DELAY:-3}"
xcrun simctl io booted screenshot "$ROOT_DIR/build/e2e-login.png"

echo "E2E smoke passed: $ROOT_DIR/build/e2e-login.png"
