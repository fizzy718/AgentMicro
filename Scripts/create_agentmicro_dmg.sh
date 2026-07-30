#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="${1:-$ROOT/AgentMicro.app}"
DMG_PATH="${2:-$ROOT/.build/AgentMicro.dmg}"
VOLUME_NAME="${AGENTMICRO_DMG_VOLUME_NAME:-AgentMicro}"
BACKGROUND_RENDERER="$ROOT/Scripts/render_agentmicro_dmg_background.swift"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "ERROR: AgentMicro DMG creation requires macOS." >&2
  exit 1
fi
if [[ ! -d "$APP_PATH" ]]; then
  echo "ERROR: AgentMicro app bundle not found: $APP_PATH" >&2
  exit 1
fi
if [[ ! -f "$APP_PATH/Contents/Info.plist" ]]; then
  echo "ERROR: Invalid AgentMicro app bundle: $APP_PATH" >&2
  exit 1
fi
if [[ ! -f "$BACKGROUND_RENDERER" ]]; then
  echo "ERROR: DMG background renderer not found: $BACKGROUND_RENDERER" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agentmicro-dmg.XXXXXX")"
TEMP_DIR="$(cd "$TEMP_DIR" && pwd -P)"
STAGING_DIR="$TEMP_DIR/staging"
MOUNT_DIR=""
VERIFY_MOUNT_DIR=""
READ_WRITE_DMG="$TEMP_DIR/AgentMicro-read-write.dmg"
DEVICE=""
VERIFY_DEVICE=""

cleanup() {
  if [[ -n "$VERIFY_DEVICE" ]]; then
    /usr/bin/hdiutil detach "$VERIFY_DEVICE" -force >/dev/null 2>&1 || true
  fi
  if [[ -n "$DEVICE" ]]; then
    /usr/bin/hdiutil detach "$DEVICE" -force >/dev/null 2>&1 || true
  fi
  /bin/rm -rf "$TEMP_DIR"
}
trap cleanup EXIT

device_and_mount_from_plist() {
  local plist_path="$1"
  local index
  local entity_mount
  local entity_device

  for index in {0..31}; do
    entity_mount="$(
      /usr/bin/plutil \
        -extract "system-entities.$index.mount-point" \
        raw \
        -o - \
        "$plist_path" 2>/dev/null || true
    )"
    if [[ -n "$entity_mount" ]]; then
      entity_device="$(
        /usr/bin/plutil \
        -extract "system-entities.$index.dev-entry" \
        raw \
        -o - \
        "$plist_path"
      )"
      printf '%s\t%s\n' "$entity_device" "$entity_mount"
      return
    fi
  done
  return 1
}

/bin/mkdir -p "$STAGING_DIR/.background"
/usr/bin/ditto --norsrc "$APP_PATH" "$STAGING_DIR/AgentMicro.app"
/bin/ln -s /Applications "$STAGING_DIR/Applications"
/bin/mkdir -p "$TEMP_DIR/swift-module-cache"
SWIFT_MODULECACHE_PATH="$TEMP_DIR/swift-module-cache" \
  CLANG_MODULE_CACHE_PATH="$TEMP_DIR/swift-module-cache" \
  /usr/bin/xcrun swift "$BACKGROUND_RENDERER" "$STAGING_DIR/.background/background.png"
/usr/bin/chflags hidden "$STAGING_DIR/.background"

/bin/mkdir -p "$(dirname "$DMG_PATH")"
/bin/rm -f "$DMG_PATH"
/usr/bin/hdiutil create \
  -ov \
  -volname "$VOLUME_NAME" \
  -fs HFS+ \
  -format UDRW \
  -srcfolder "$STAGING_DIR" \
  "$READ_WRITE_DMG" >/dev/null

ATTACH_PLIST="$TEMP_DIR/attach.plist"
/usr/bin/hdiutil attach \
  "$READ_WRITE_DMG" \
  -readwrite \
  -noverify \
  -noautoopen \
  -plist >"$ATTACH_PLIST"
ATTACH_INFO="$(device_and_mount_from_plist "$ATTACH_PLIST" || true)"
IFS=$'\t' read -r DEVICE MOUNT_DIR <<<"$ATTACH_INFO"
if [[ -z "$DEVICE" || -z "$MOUNT_DIR" ]]; then
  echo "ERROR: Unable to determine the mounted DMG device." >&2
  exit 1
fi

/usr/bin/osascript - "$(/usr/bin/basename "$MOUNT_DIR")" "$MOUNT_DIR" <<'APPLESCRIPT'
on run arguments
    set volumeName to item 1 of arguments
    set mountPath to item 2 of arguments
    set backgroundFile to POSIX file (mountPath & "/.background/background.png") as alias
    tell application "Finder"
        tell disk volumeName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set pathbar visible of container window to false
            set bounds of container window to {200, 120, 860, 520}
            tell icon view options of container window
                set arrangement to not arranged
                set icon size to 96
                set text size to 13
                set background picture to backgroundFile
            end tell
            set position of item "AgentMicro.app" of container window to {170, 215}
            set position of item "Applications" of container window to {490, 215}
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
APPLESCRIPT

/bin/sync
/usr/bin/hdiutil detach "$DEVICE" >/dev/null
DEVICE=""

/usr/bin/hdiutil convert \
  "$READ_WRITE_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$DMG_PATH" >/dev/null
/usr/bin/hdiutil verify "$DMG_PATH" >/dev/null

VERIFY_ATTACH_PLIST="$TEMP_DIR/verify-attach.plist"
/usr/bin/hdiutil attach \
  "$DMG_PATH" \
  -readonly \
  -noverify \
  -noautoopen \
  -nobrowse \
  -plist >"$VERIFY_ATTACH_PLIST"
VERIFY_ATTACH_INFO="$(device_and_mount_from_plist "$VERIFY_ATTACH_PLIST" || true)"
IFS=$'\t' read -r VERIFY_DEVICE VERIFY_MOUNT_DIR <<<"$VERIFY_ATTACH_INFO"
if [[ -z "$VERIFY_DEVICE" || -z "$VERIFY_MOUNT_DIR" ]]; then
  echo "ERROR: Unable to mount the finished DMG for verification." >&2
  exit 1
fi
if [[ ! -d "$VERIFY_MOUNT_DIR/AgentMicro.app" ]]; then
  echo "ERROR: Finished DMG does not contain AgentMicro.app." >&2
  exit 1
fi
if [[ ! -L "$VERIFY_MOUNT_DIR/Applications" ]] ||
  [[ "$(/usr/bin/readlink "$VERIFY_MOUNT_DIR/Applications")" != "/Applications" ]]; then
  echo "ERROR: Finished DMG does not contain the Applications drop target." >&2
  exit 1
fi

/usr/bin/hdiutil detach "$VERIFY_DEVICE" >/dev/null
VERIFY_DEVICE=""

echo "Created drag-to-install DMG: $DMG_PATH"
