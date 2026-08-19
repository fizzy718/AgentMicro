#!/usr/bin/env bash
set -euo pipefail

MODE="${1:---package}"
case "$MODE" in
  --package|--validate|--upload) ;;
  *)
    echo "Usage: $0 [--package|--validate|--upload]" >&2
    exit 1
    ;;
esac

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
source "$ROOT/agentmicro-version.env"

: "${AGENTMICRO_BUNDLE_ID:=com.agentmicro.macos}"
: "${AGENTMICRO_APP_STORE_APP_IDENTITY:?Set the Mac App Distribution signing identity}"
: "${AGENTMICRO_APP_STORE_INSTALLER_IDENTITY:?Set the Mac Installer Distribution signing identity}"
: "${AGENTMICRO_APP_STORE_PROVISIONING_PROFILE:?Set the Mac App Store provisioning profile path}"

OUTPUT_DIRECTORY="$ROOT/.build/agentmicro-app-store/${AGENTMICRO_VERSION}"
PACKAGE_PATH="$OUTPUT_DIRECTORY/AgentMicro-${AGENTMICRO_VERSION}-${AGENTMICRO_BUILD_NUMBER}.pkg"

mkdir -p "$OUTPUT_DIRECTORY"
cd "$ROOT"

AGENTMICRO_APP_STORE=1 \
AGENTMICRO_SIGNING=app-store \
AGENTMICRO_SIGNING_IDENTITY="$AGENTMICRO_APP_STORE_APP_IDENTITY" \
AGENTMICRO_APP_STORE_PROVISIONING_PROFILE="$AGENTMICRO_APP_STORE_PROVISIONING_PROFILE" \
AGENTMICRO_BUNDLE_ID="$AGENTMICRO_BUNDLE_ID" \
ARCHES="${ARCHES:-arm64 x86_64}" \
  "$ROOT/Scripts/package_agentmicro.sh" release

rm -f "$PACKAGE_PATH"
productbuild \
  --component "$ROOT/AgentMicro-AppStore.app" /Applications \
  --sign "$AGENTMICRO_APP_STORE_INSTALLER_IDENTITY" \
  "$PACKAGE_PATH"

pkgutil --check-signature "$PACKAGE_PATH"

if [[ "$MODE" == "--validate" || "$MODE" == "--upload" ]]; then
  : "${APP_STORE_CONNECT_KEY_ID:?Set APP_STORE_CONNECT_KEY_ID}"
  : "${APP_STORE_CONNECT_ISSUER_ID:?Set APP_STORE_CONNECT_ISSUER_ID}"
  ACTION="--validate-app"
  if [[ "$MODE" == "--upload" ]]; then
    ACTION="--upload-app"
  fi
  xcrun altool "$ACTION" \
    -f "$PACKAGE_PATH" \
    -t macos \
    --apiKey "$APP_STORE_CONNECT_KEY_ID" \
    --apiIssuer "$APP_STORE_CONNECT_ISSUER_ID"
fi

echo "Prepared $PACKAGE_PATH"
