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

require_value AGENTMICRO_GITHUB_REPOSITORY
require_value AGENTMICRO_FEED_URL

ARCHIVE="${1:-$ROOT/.build/agentmicro-release/$AGENTMICRO_VERSION/AgentMicro-macos-universal-$AGENTMICRO_VERSION.zip}"
if [[ ! -f "$ARCHIVE" ]]; then
  echo "ERROR: AgentMicro update archive not found: $ARCHIVE" >&2
  exit 1
fi

GENERATOR="${AGENTMICRO_GENERATE_APPCAST:-$ROOT/.build/artifacts/sparkle/Sparkle/bin/generate_appcast}"
if [[ ! -x "$GENERATOR" ]]; then
  GENERATOR="$(command -v generate_appcast || true)"
fi
if [[ -z "$GENERATOR" || ! -x "$GENERATOR" ]]; then
  echo "ERROR: Sparkle generate_appcast was not found; resolve SwiftPM dependencies first" >&2
  exit 1
fi

FEED_FILENAME="agentmicro-appcast.xml"
FEED_PATH="$ROOT/$FEED_FILENAME"
STAGE="$(mktemp -d "${TMPDIR:-/tmp}/agentmicro-appcast.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT
cp "$ARCHIVE" "$STAGE/"
if [[ -f "$FEED_PATH" ]]; then
  cp "$FEED_PATH" "$STAGE/$FEED_FILENAME"
fi

ARCHIVE_BASENAME="$(basename "$ARCHIVE")"
ARCHIVE_STEM="${ARCHIVE_BASENAME%.zip}"
if [[ -n "${AGENTMICRO_RELEASE_NOTES_FILE:-}" ]]; then
  if [[ ! -f "$AGENTMICRO_RELEASE_NOTES_FILE" ]]; then
    echo "ERROR: Release notes file not found: $AGENTMICRO_RELEASE_NOTES_FILE" >&2
    exit 1
  fi
  cp "$AGENTMICRO_RELEASE_NOTES_FILE" "$STAGE/$ARCHIVE_STEM.md"
fi

KEY_ARGS=()
KEY_FILE="${SPARKLE_PRIVATE_KEY_FILE:-${MAC_RELEASE_SIGNING_KEY_FILE:-}}"
if [[ -n "$KEY_FILE" ]]; then
  case "$KEY_FILE" in
    '~/'*) KEY_FILE="$HOME/${KEY_FILE#\~/}" ;;
    '$HOME/'*) KEY_FILE="$HOME/${KEY_FILE#\$HOME/}" ;;
  esac
  if [[ ! -f "$KEY_FILE" ]]; then
    echo "ERROR: Sparkle private key file not found: $KEY_FILE" >&2
    exit 1
  fi
  KEY_ARGS=(--ed-key-file "$KEY_FILE")
else
  KEY_ARGS=(--account "${AGENTMICRO_SPARKLE_ACCOUNT:-agentmicro}")
fi

DOWNLOAD_PREFIX="https://github.com/$AGENTMICRO_GITHUB_REPOSITORY/releases/download/v$AGENTMICRO_VERSION/"
(
  cd "$STAGE"
  "$GENERATOR" \
    "${KEY_ARGS[@]}" \
    --download-url-prefix "$DOWNLOAD_PREFIX" \
    --link "https://github.com/$AGENTMICRO_GITHUB_REPOSITORY" \
    --versions "$AGENTMICRO_BUILD_NUMBER" \
    --maximum-versions 10 \
    -o "$FEED_FILENAME" \
    "$STAGE"
)

if ! /usr/bin/grep -Fq "sparkle:edSignature=" "$STAGE/$FEED_FILENAME"; then
  echo "ERROR: Generated AgentMicro appcast is missing an Ed25519 signature" >&2
  exit 1
fi
if ! /usr/bin/grep -Fq "$DOWNLOAD_PREFIX$ARCHIVE_BASENAME" "$STAGE/$FEED_FILENAME"; then
  echo "ERROR: Generated AgentMicro appcast does not reference the release archive" >&2
  exit 1
fi

cp "$STAGE/$FEED_FILENAME" "$FEED_PATH"
echo "Generated AgentMicro feed: $FEED_PATH"
echo "Configured feed URL: $AGENTMICRO_FEED_URL"
