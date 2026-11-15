#!/usr/bin/env bash
# Package the AI Monitor community UI customization (upstream CodexBar).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${AI_MONITOR_SIGNING_IDENTITY:?Set AI_MONITOR_SIGNING_IDENTITY to your development certificate SHA-1}"
: "${APP_TEAM_ID:?Set APP_TEAM_ID to your development signing team}"
if [[ "${AI_MONITOR_SKIP_BUILD:-0}" != "1" ]]; then
  CODEXBAR_SIGNING=adhoc ARCHES=arm64 ./Scripts/package_app.sh debug
fi
APP="$ROOT/AI Monitor.app"
if [[ -e "$APP" ]]; then
  echo "Remove or move the previous AI Monitor output before packaging: $APP" >&2
  exit 1
fi
ditto "$ROOT/CodexBar.app" "$APP"
/usr/libexec/PlistBuddy -c 'Set :CFBundleName AI Monitor' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName AI Monitor' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :SUEnableAutomaticChecks false' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :SUAutomaticallyUpdate false' "$APP/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Set :CFBundleDisplayName AI Monitor' "$APP/Contents/PlugIns/CodexBarWidget.appex/Contents/Info.plist"
codesign --force --sign "$AI_MONITOR_SIGNING_IDENTITY" \
  --entitlements "$ROOT/.build/entitlements/CodexBarWidget.entitlements" \
  "$APP/Contents/PlugIns/CodexBarWidget.appex"
codesign --force --sign "$AI_MONITOR_SIGNING_IDENTITY" \
  --entitlements "$ROOT/.build/entitlements/CodexBar.entitlements" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
echo "Packaged: $APP"
