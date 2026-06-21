#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_FILE="$ROOT_DIR/notchprompt.xcodeproj/project.pbxproj"
APP_PATH="${1:-$ROOT_DIR/build/release/Build/Products/Release/CueFlow.app}"

if [[ ! -f "$PROJECT_FILE" ]]; then
  echo "Project file not found: $PROJECT_FILE" >&2
  exit 1
fi

echo "==> Deployment target(s) from project"
awk '/MACOSX_DEPLOYMENT_TARGET = / { gsub(/;/, "", $3); print $3 }' "$PROJECT_FILE" | sort -u | sed 's/^/ - /'

if [[ ! -d "$APP_PATH" ]]; then
  echo "Built app not found: $APP_PATH" >&2
  exit 1
fi

PLIST="$APP_PATH/Contents/Info.plist"
if [[ ! -f "$PLIST" ]]; then
  echo "Info.plist not found in app bundle: $PLIST" >&2
  exit 1
fi

min_version="$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$PLIST" 2>/dev/null || true)"
if [[ -z "$min_version" ]]; then
  min_version="$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$PLIST" 2>/dev/null || true)"
fi
if [[ -z "$min_version" ]]; then
  min_version="(not set)"
fi

echo "==> Built app minimum macOS version"
echo " - $min_version"
