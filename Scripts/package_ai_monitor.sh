#!/usr/bin/env bash
# Package the AI Monitor community UI customization (upstream CodexBar).
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"
: "${AI_MONITOR_SIGNING_IDENTITY:?Set AI_MONITOR_SIGNING_IDENTITY to your development certificate SHA-1}"
: "${APP_TEAM_ID:?Set APP_TEAM_ID to your development signing team}"
# Stable product identity, distinct from CodexBar Studio's extension service.
# Keep the host/App Group unchanged so existing account settings remain available.
WIDGET_ID="com.steipete.codexbar.debug.aimonitor.widget"
if [[ "${AI_MONITOR_SKIP_BUILD:-0}" != "1" ]]; then
  CODEXBAR_WIDGET_BUNDLE_ID_OVERRIDE="$WIDGET_ID" CODEXBAR_SIGNING=adhoc ARCHES=arm64 ./Scripts/package_app.sh debug
fi
ACTUAL_WIDGET_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$ROOT/CodexBar.app/Contents/PlugIns/CodexBarWidget.appex/Contents/Info.plist")
if [[ "$ACTUAL_WIDGET_ID" != "$WIDGET_ID" ]]; then
  echo "ERROR: Rebuild with the AI Monitor widget identity; refusing to package a legacy extension." >&2
  exit 1
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
/usr/libexec/PlistBuddy -c 'Set :CFBundleName AI Monitor' "$APP/Contents/PlugIns/CodexBarWidget.appex/Contents/Info.plist"
codesign --force --sign "$AI_MONITOR_SIGNING_IDENTITY" \
  --entitlements "$ROOT/.build/entitlements/CodexBarWidget.entitlements" \
  "$APP/Contents/PlugIns/CodexBarWidget.appex"
codesign --force --sign "$AI_MONITOR_SIGNING_IDENTITY" \
  --entitlements "$ROOT/.build/entitlements/CodexBar.entitlements" "$APP"
codesign --verify --deep --strict --verbose=2 "$APP"
python3 "$ROOT/Scripts/verify_ai_monitor_bundle.py" "$APP"
echo "Packaged: $APP"
