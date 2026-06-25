#!/usr/bin/env bash
#
# Build, Developer ID sign, notarize and staple a distributable CueFlow release.
#
# Prerequisites (one-time setup):
#   1. A "Developer ID Application" certificate installed in the login keychain
#      (Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application).
#   2. A stored notarization profile created once with:
#        xcrun notarytool store-credentials cueflow-notary \
#          --apple-id "szwkill@qq.com" \
#          --team-id  "UL48X4L545" \
#          --password "<app-specific-password>"
#      (Team ID must match the Developer ID Application certificate's team.)
#
# Usage:
#   scripts/sign_notarize_release.sh [version]
#   NOTARY_PROFILE=cueflow-notary SIGN_IDENTITY="Developer ID Application: ..." \
#     scripts/sign_notarize_release.sh v1.0.0
#
# Unlike scripts/build_release_zip.sh (which ad-hoc signs for CI), this script
# produces a fully notarized DMG that installs without Gatekeeper warnings.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="${1:-v1.0.0}"
DERIVED_DATA_PATH="$ROOT_DIR/build/release"
OUTPUT_DIR="$ROOT_DIR/dist"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/CueFlow.app"
STAGING_DIR="$ROOT_DIR/build/dmg-staging"
OUTPUT_DMG="$OUTPUT_DIR/CueFlow-${VERSION}-macos.dmg"
VOLUME_NAME="CueFlow"
ENTITLEMENTS="$ROOT_DIR/Config/Cueflow.entitlements"
ZIP_PATH="$ROOT_DIR/build/CueFlow-${VERSION}.zip"

# notarytool keychain profile created via `store-credentials` (see header).
NOTARY_PROFILE="${NOTARY_PROFILE:-cueflow-notary}"

# Auto-detect the Developer ID Application identity; override with SIGN_IDENTITY.
SIGN_IDENTITY="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning \
  | awk -F'"' '/Developer ID Application/{print $2; exit}')}"
if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "ERROR: No 'Developer ID Application' certificate found in the keychain." >&2
  echo "Create one in Xcode > Settings > Accounts > Manage Certificates > + > Developer ID Application." >&2
  exit 1
fi
echo "==> Signing identity: $SIGN_IDENTITY"
echo "==> Notary profile:   $NOTARY_PROFILE"

echo "==> Building Release app (unsigned) for ${VERSION}"
xcodebuild \
  -project "$ROOT_DIR/notchprompt.xcodeproj" \
  -scheme notchprompt \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGN_IDENTITY="" \
  build

[[ -d "$APP_PATH" ]] || { echo "Expected app bundle not found at: $APP_PATH" >&2; exit 1; }

# Sparkle ships nested helpers (XPC services, Autoupdate, Updater.app) that must
# be re-signed inside-out with your Developer ID + hardened runtime before the
# framework and the app, or notarization fails. Guarded so the script still works
# if Sparkle is absent or its layout changes.
SPARKLE_FW="$APP_PATH/Contents/Frameworks/Sparkle.framework"
if [[ -d "$SPARKLE_FW" ]]; then
  echo "==> Signing Sparkle nested components (inside-out)"
  SPARKLE_V="$SPARKLE_FW/Versions/B"
  for item in \
    "$SPARKLE_V/XPCServices/Downloader.xpc" \
    "$SPARKLE_V/XPCServices/Installer.xpc" \
    "$SPARKLE_V/Autoupdate" \
    "$SPARKLE_V/Updater.app"; do
    if [[ -e "$item" ]]; then
      echo "    - ${item#"$APP_PATH"/}"
      codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$item"
    fi
  done
  echo "    - Sparkle.framework"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$SPARKLE_FW"
fi

# Sign any other nested Mach-O (future frameworks/dylibs), skipping the main
# executable (signed with entitlements by the bundle signing below) and Sparkle
# (already handled above).
echo "==> Signing other nested Mach-O binaries (if any)"
while IFS= read -r -d '' f; do
  if file "$f" | grep -q "Mach-O"; then
    echo "    - ${f#"$APP_PATH"/}"
    codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" "$f"
  fi
done < <(find "$APP_PATH/Contents" -type f \
  ! -path "$APP_PATH/Contents/MacOS/*" \
  ! -path "$SPARKLE_FW/*" -print0)

echo "==> Signing app bundle"
codesign --force --options runtime --timestamp \
  --entitlements "$ENTITLEMENTS" \
  --sign "$SIGN_IDENTITY" \
  "$APP_PATH"

echo "==> Verifying code signature"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "==> Zipping app for notarization"
rm -f "$ZIP_PATH"
/usr/bin/ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Submitting app to Apple notary service (may take a few minutes)"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling ticket to app"
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo "==> Packaging DMG"
mkdir -p "$OUTPUT_DIR"
rm -rf "$STAGING_DIR"; mkdir -p "$STAGING_DIR"
rm -f "$OUTPUT_DMG"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGING_DIR" -ov -format UDZO "$OUTPUT_DMG"

echo "==> Signing DMG"
codesign --force --timestamp --sign "$SIGN_IDENTITY" "$OUTPUT_DMG"

echo "==> Submitting DMG to notary service"
xcrun notarytool submit "$OUTPUT_DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling DMG"
xcrun stapler staple "$OUTPUT_DMG"
xcrun stapler validate "$OUTPUT_DMG"

echo "==> Final Gatekeeper assessment"
spctl -a -t open --context context:primary-signature -vvv "$OUTPUT_DMG" || true
spctl -a -t exec -vvv "$STAGING_DIR/CueFlow.app" || true

echo ""
echo "==> DONE"
echo "    Notarized DMG: $OUTPUT_DMG"
