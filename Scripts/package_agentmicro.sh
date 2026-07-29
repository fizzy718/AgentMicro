#!/usr/bin/env bash
set -euo pipefail

CONFIGURATION="${1:-release}"
case "$CONFIGURATION" in
  debug|release) ;;
  *)
    echo "ERROR: Unsupported build configuration: $CONFIGURATION (expected debug or release)" >&2
    exit 1
    ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_FINAL="$ROOT/AgentMicro.app"
APP_STAGE="$ROOT/.build/package-agentmicro/AgentMicro.app"
VERSION="${AGENTMICRO_VERSION:-0.1.0}"
BUILD_NUMBER="${AGENTMICRO_BUILD_NUMBER:-1}"
BUNDLE_ID="${AGENTMICRO_BUNDLE_ID:-com.agentmicro.macos}"

cd "$ROOT"

AGENTMICRO_BUILD_ONLY=1 swift build \
  -c "$CONFIGURATION" \
  --product AgentMicro \
  --disable-automatic-resolution

BIN_DIR="$(
  AGENTMICRO_BUILD_ONLY=1 swift build \
    -c "$CONFIGURATION" \
    --disable-automatic-resolution \
    --show-bin-path
)"
BINARY="$BIN_DIR/AgentMicro"
if [[ ! -x "$BINARY" ]]; then
  echo "ERROR: AgentMicro binary not found at $BINARY" >&2
  exit 1
fi

rm -rf "$APP_STAGE"
mkdir -p "$APP_STAGE/Contents/MacOS" "$APP_STAGE/Contents/Resources"
install -m 755 "$BINARY" "$APP_STAGE/Contents/MacOS/AgentMicro"

BUILD_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"

cat > "$APP_STAGE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleDisplayName</key><string>AgentMicro</string>
    <key>CFBundleExecutable</key><string>AgentMicro</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleName</key><string>AgentMicro</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSHumanReadableCopyright</key><string>AgentMicro contributors. MIT License.</string>
    <key>AgentMicroBuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>AgentMicroGitCommit</key><string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST

plutil -lint "$APP_STAGE/Contents/Info.plist"
codesign --force --deep --sign - "$APP_STAGE"
codesign --verify --deep --strict "$APP_STAGE"

rm -rf "$APP_FINAL"
mv "$APP_STAGE" "$APP_FINAL"

echo "Packaged $APP_FINAL"
