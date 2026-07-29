#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="${1:-$ROOT/AgentMicro.icon}"
OUTPUT="${2:-$ROOT/.build/agentmicro-icon/AgentMicro.icns}"
ASSET_CATALOG_OUTPUT="${3:-$(dirname "$OUTPUT")/Assets.car}"
MINIMUM_DEPLOYMENT_TARGET="${AGENTMICRO_MINIMUM_MACOS:-14.0}"

if [[ ! -e "$SOURCE" ]]; then
  echo "ERROR: AgentMicro icon source not found at $SOURCE" >&2
  exit 1
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agentmicro-icon.XXXXXX")"
COMPILED_DIR="$TEMP_DIR/compiled"
PARTIAL_INFO_PLIST="$TEMP_DIR/icon-info.plist"
trap 'rm -rf "$TEMP_DIR"' EXIT
mkdir -p "$COMPILED_DIR" "$(dirname "$OUTPUT")" "$(dirname "$ASSET_CATALOG_OUTPUT")"

if [[ -n "${XCODE_APP:-}" ]]; then
  XCODE_ROOT="$XCODE_APP"
elif [[ -n "${DEVELOPER_DIR:-}" ]]; then
  XCODE_ROOT="$(dirname "$(dirname "$DEVELOPER_DIR")")"
else
  XCODE_ROOT="$(dirname "$(dirname "$(/usr/bin/xcode-select -p)")")"
fi
DEVELOPER_ROOT="$XCODE_ROOT/Contents/Developer"
ACTOOL="$DEVELOPER_ROOT/usr/bin/actool"
if [[ ! -x "$ACTOOL" ]]; then
  echo "ERROR: Xcode asset compiler not found under $XCODE_ROOT" >&2
  exit 1
fi

DEVELOPER_DIR="$DEVELOPER_ROOT" "$ACTOOL" \
  --compile "$COMPILED_DIR" \
  --platform macosx \
  --minimum-deployment-target "$MINIMUM_DEPLOYMENT_TARGET" \
  --app-icon AgentMicro \
  --output-partial-info-plist "$PARTIAL_INFO_PLIST" \
  "$SOURCE" >/dev/null

COMPILED_ICON="$COMPILED_DIR/AgentMicro.icns"
COMPILED_ASSETS="$COMPILED_DIR/Assets.car"
if [[ ! -s "$COMPILED_ICON" ]]; then
  echo "ERROR: Xcode did not generate the AgentMicro ICNS fallback" >&2
  exit 1
fi
if [[ ! -s "$COMPILED_ASSETS" ]]; then
  echo "ERROR: Xcode did not generate the AgentMicro layered asset catalog" >&2
  exit 1
fi
if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIconName' "$PARTIAL_INFO_PLIST")" != "AgentMicro" ]]; then
  echo "ERROR: Xcode icon metadata did not name AgentMicro" >&2
  exit 1
fi

install -m 0644 "$COMPILED_ICON" "$OUTPUT"
install -m 0644 "$COMPILED_ASSETS" "$ASSET_CATALOG_OUTPUT"
echo "Generated AgentMicro fallback icon at $OUTPUT"
echo "Generated AgentMicro layered appearances at $ASSET_CATALOG_OUTPUT"
