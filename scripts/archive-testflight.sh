#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/GlabTouch.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/TestFlight}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT_DIR/Config/TestFlightExportOptions.plist}"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

archive_args=(
  -project "$ROOT_DIR/GlabTouch.xcodeproj"
  -scheme GlabTouch
  -configuration Release
  -destination "generic/platform=iOS"
  -archivePath "$ARCHIVE_PATH"
  -allowProvisioningUpdates
)

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  archive_args+=(DEVELOPMENT_TEAM="$DEVELOPMENT_TEAM")
fi

xcodebuild "${archive_args[@]}" archive

export_args=(
  -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_PATH"
  -exportOptionsPlist "$EXPORT_OPTIONS"
  -allowProvisioningUpdates
)

if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  export_args+=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

xcodebuild "${export_args[@]}"
