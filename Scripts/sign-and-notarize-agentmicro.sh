#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG_FILE="${AGENTMICRO_RELEASE_CONFIG:-$ROOT/.mac-release.env}"
if [[ -f "$CONFIG_FILE" ]]; then
  # shellcheck disable=SC1090
  source "$CONFIG_FILE"
fi
# shellcheck disable=SC1091
source "$ROOT/agentmicro-version.env"

require_value() {
  local name="$1"
  if [[ -z "${!name:-}" ]]; then
    echo "ERROR: Missing required release setting: $name" >&2
    exit 1
  fi
}

require_value AGENTMICRO_FEED_URL
require_value AGENTMICRO_PUBLIC_ED_KEY
require_value AGENTMICRO_BUNDLE_ID
require_value AGENTMICRO_SIGNING_IDENTITY
require_value APP_STORE_CONNECT_API_KEY_P8
require_value APP_STORE_CONNECT_KEY_ID
require_value APP_STORE_CONNECT_ISSUER_ID

if ! /usr/bin/security find-identity -v -p codesigning 2>/dev/null |
  /usr/bin/grep -F "$AGENTMICRO_SIGNING_IDENTITY" >/dev/null; then
  echo "ERROR: Developer ID identity is not installed: $AGENTMICRO_SIGNING_IDENTITY" >&2
  exit 1
fi

ARCHES_VALUE="${ARCHES:-arm64 x86_64}"
APP="$ROOT/AgentMicro.app"
RELEASE_DIR="$ROOT/.build/agentmicro-release/$AGENTMICRO_VERSION"
ZIP_NAME="AgentMicro-macos-universal-$AGENTMICRO_VERSION.zip"
ZIP_PATH="$RELEASE_DIR/$ZIP_NAME"
TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/agentmicro-notarize.XXXXXX")"
API_KEY_PATH="$TEMP_DIR/AuthKey_${APP_STORE_CONNECT_KEY_ID}.p8"
NOTARIZATION_ZIP="$TEMP_DIR/AgentMicro-notarization.zip"
trap 'rm -rf "$TEMP_DIR"' EXIT

mkdir -p "$RELEASE_DIR"
(
  umask 077
  printf '%s' "$APP_STORE_CONNECT_API_KEY_P8" | /usr/bin/sed 's/\\n/\n/g' >"$API_KEY_PATH"
)

echo "Building and signing AgentMicro $AGENTMICRO_VERSION ($AGENTMICRO_BUILD_NUMBER)"
ARCHES="$ARCHES_VALUE" \
  AGENTMICRO_SIGNING=identity \
  AGENTMICRO_SIGNING_IDENTITY="$AGENTMICRO_SIGNING_IDENTITY" \
  AGENTMICRO_BUNDLE_ID="$AGENTMICRO_BUNDLE_ID" \
  AGENTMICRO_FEED_URL="$AGENTMICRO_FEED_URL" \
  AGENTMICRO_PUBLIC_ED_KEY="$AGENTMICRO_PUBLIC_ED_KEY" \
  "$ROOT/Scripts/package_agentmicro.sh" release

/usr/bin/codesign --verify --deep --strict --verbose=2 "$APP"
/usr/bin/ditto --norsrc -c -k --keepParent "$APP" "$NOTARIZATION_ZIP"

echo "Submitting AgentMicro to Apple notarization"
/usr/bin/xcrun notarytool submit "$NOTARIZATION_ZIP" \
  --key "$API_KEY_PATH" \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

/usr/bin/xcrun stapler staple "$APP"
/usr/bin/xcrun stapler validate "$APP"
/usr/bin/xattr -cr "$APP"
/usr/bin/find "$APP" -name '._*' -delete

rm -f "$ZIP_PATH"
/usr/bin/ditto --norsrc -c -k --keepParent "$APP" "$ZIP_PATH"

if command -v syspolicy_check >/dev/null 2>&1; then
  syspolicy_check distribution "$APP"
else
  /usr/sbin/spctl --assess --type execute --verbose "$APP"
fi

echo "Prepared notarized update archive: $ZIP_PATH"
