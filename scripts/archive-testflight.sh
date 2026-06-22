#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/build/GlabTouch.xcarchive}"
EXPORT_PATH="${EXPORT_PATH:-$ROOT_DIR/build/TestFlight}"
EXPORT_OPTIONS="${EXPORT_OPTIONS:-$ROOT_DIR/Config/TestFlightExportOptions.plist}"
RESOLVED_EXPORT_OPTIONS="${RESOLVED_EXPORT_OPTIONS:-$ROOT_DIR/build/TestFlightExportOptions.resolved.plist}"
PRODUCT_BUNDLE_IDENTIFIER="${PRODUCT_BUNDLE_IDENTIFIER:-com.zephyrdeng.GlabTouch}"

mkdir -p "$(dirname "$ARCHIVE_PATH")" "$EXPORT_PATH"

auth_args=()
if [[ -n "${ASC_KEY_PATH:-}" && -n "${ASC_KEY_ID:-}" && -n "${ASC_ISSUER_ID:-}" ]]; then
  auth_args+=(
    -authenticationKeyPath "$ASC_KEY_PATH"
    -authenticationKeyID "$ASC_KEY_ID"
    -authenticationKeyIssuerID "$ASC_ISSUER_ID"
  )
fi

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

if [[ -n "${CODE_SIGN_STYLE:-}" ]]; then
  archive_args+=(CODE_SIGN_STYLE="$CODE_SIGN_STYLE")
fi

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  archive_args+=(CODE_SIGN_IDENTITY="$CODE_SIGN_IDENTITY")
fi

if [[ -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ]]; then
  archive_args+=(PROVISIONING_PROFILE_SPECIFIER="$PROVISIONING_PROFILE_SPECIFIER")
fi

if [[ -n "${PROVISIONING_PROFILE:-}" ]]; then
  archive_args+=(PROVISIONING_PROFILE="$PROVISIONING_PROFILE")
fi

archive_args+=("${auth_args[@]}")

xcodebuild "${archive_args[@]}" archive

cp "$EXPORT_OPTIONS" "$RESOLVED_EXPORT_OPTIONS"

set_export_option() {
  local key="$1"
  local type="$2"
  local value="$3"

  /usr/libexec/PlistBuddy -c "Set :$key $value" "$RESOLVED_EXPORT_OPTIONS" 2>/dev/null ||
    /usr/libexec/PlistBuddy -c "Add :$key $type $value" "$RESOLVED_EXPORT_OPTIONS"
}

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  set_export_option "teamID" "string" "$DEVELOPMENT_TEAM"
fi

if [[ -n "${PROVISIONING_PROFILE_SPECIFIER:-}" ]]; then
  /usr/libexec/PlistBuddy -c "Delete :provisioningProfiles" "$RESOLVED_EXPORT_OPTIONS" 2>/dev/null || true
  /usr/libexec/PlistBuddy -c "Add :provisioningProfiles dict" "$RESOLVED_EXPORT_OPTIONS"
  /usr/libexec/PlistBuddy -c "Add :provisioningProfiles:$PRODUCT_BUNDLE_IDENTIFIER string $PROVISIONING_PROFILE_SPECIFIER" "$RESOLVED_EXPORT_OPTIONS"
fi

export_args=(
  -exportArchive
  -archivePath "$ARCHIVE_PATH"
  -exportPath "$EXPORT_PATH"
  -exportOptionsPlist "$RESOLVED_EXPORT_OPTIONS"
  -allowProvisioningUpdates
)

export_args+=("${auth_args[@]}")

xcodebuild "${export_args[@]}"
