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

PUBLISH=false
case "${1:-}" in
  "") ;;
  --publish) PUBLISH=true ;;
  *)
    echo "Usage: $(basename "$0") [--publish]" >&2
    exit 2
    ;;
esac

if [[ "$PUBLISH" == true ]]; then
  require_publish_value() {
    local name="$1"
    if [[ -z "${!name:-}" ]]; then
      echo "ERROR: Missing required release setting: $name" >&2
      exit 1
    fi
  }

  require_publish_value AGENTMICRO_GITHUB_REPOSITORY
  require_publish_value AGENTMICRO_FEED_URL
  require_publish_value AGENTMICRO_FEED_BRANCH

  if ! command -v gh >/dev/null 2>&1; then
    echo "ERROR: gh is required for --publish" >&2
    exit 1
  fi
  if ! gh auth status --hostname github.com >/dev/null 2>&1; then
    echo "ERROR: gh is not authenticated for github.com" >&2
    exit 1
  fi
  if ! git -C "$ROOT" remote get-url origin >/dev/null 2>&1; then
    echo "ERROR: AgentMicro repository has no origin remote" >&2
    exit 1
  fi

  CURRENT_BRANCH="$(git -C "$ROOT" branch --show-current)"
  if [[ "$CURRENT_BRANCH" != "$AGENTMICRO_FEED_BRANCH" ]]; then
    echo "ERROR: Publish from $AGENTMICRO_FEED_BRANCH, not ${CURRENT_BRANCH:-detached HEAD}" >&2
    exit 1
  fi

  TAG="v$AGENTMICRO_VERSION"
  if gh release view "$TAG" --repo "$AGENTMICRO_GITHUB_REPOSITORY" >/dev/null 2>&1; then
    echo "ERROR: GitHub release already exists: $TAG" >&2
    exit 1
  fi
fi

DIRTY_PATHS="$(git -C "$ROOT" status --short)"
if [[ "$PUBLISH" == true ]]; then
  UNEXPECTED_DIRTY="$(
    printf '%s\n' "$DIRTY_PATHS" |
      /usr/bin/grep -vE '^(\?\?| M|M ) agentmicro-appcast\.xml$' || true
  )"
else
  UNEXPECTED_DIRTY="$DIRTY_PATHS"
fi
if [[ -n "$UNEXPECTED_DIRTY" ]]; then
  echo "ERROR: AgentMicro releases require a clean git worktree" >&2
  printf '%s\n' "$UNEXPECTED_DIRTY" >&2
  exit 1
fi

"$ROOT/Scripts/sign-and-notarize-agentmicro.sh"
ARCHIVE="$ROOT/.build/agentmicro-release/$AGENTMICRO_VERSION/AgentMicro-macos-universal-$AGENTMICRO_VERSION.zip"
DMG="$ROOT/.build/agentmicro-release/$AGENTMICRO_VERSION/AgentMicro-macos-universal-$AGENTMICRO_VERSION.dmg"
if [[ ! -f "$ARCHIVE" || ! -f "$DMG" ]]; then
  echo "ERROR: AgentMicro release packaging did not produce both ZIP and DMG artifacts." >&2
  exit 1
fi
"$ROOT/Scripts/make_agentmicro_appcast.sh" "$ARCHIVE"

if [[ "$PUBLISH" != true ]]; then
  echo "Release prepared locally. Re-run with --publish after reviewing the archive and appcast."
  exit 0
fi

RELEASE_ARGS=(
  release create "$TAG" "$ARCHIVE" "$DMG"
  --repo "$AGENTMICRO_GITHUB_REPOSITORY"
  --title "AgentMicro $AGENTMICRO_VERSION"
)
DEFAULT_RELEASE_NOTES_FILE="$ROOT/docs/releases/$AGENTMICRO_VERSION.md"
RELEASE_NOTES_FILE="${AGENTMICRO_RELEASE_NOTES_FILE:-$DEFAULT_RELEASE_NOTES_FILE}"
if [[ -n "${AGENTMICRO_RELEASE_NOTES_FILE:-}" && ! -f "$RELEASE_NOTES_FILE" ]]; then
  echo "ERROR: AgentMicro release notes file does not exist: $RELEASE_NOTES_FILE" >&2
  exit 1
fi
if [[ -f "$RELEASE_NOTES_FILE" ]]; then
  RELEASE_ARGS+=(--notes-file "$RELEASE_NOTES_FILE")
else
  RELEASE_ARGS+=(--generate-notes)
fi
gh "${RELEASE_ARGS[@]}"

PUBLISHED_ASSETS="$(
  gh release view "$TAG" \
    --repo "$AGENTMICRO_GITHUB_REPOSITORY" \
    --json assets \
    --jq '.assets[].name'
)"
for expected_asset in "$(basename "$ARCHIVE")" "$(basename "$DMG")"; do
  if ! /usr/bin/grep -Fxq "$expected_asset" <<<"$PUBLISHED_ASSETS"; then
    echo "ERROR: Published release is missing expected asset: $expected_asset" >&2
    exit 1
  fi
done

git -C "$ROOT" add agentmicro-appcast.xml
STAGED_FILES="$(git -C "$ROOT" diff --cached --name-only)"
if [[ "$STAGED_FILES" != "agentmicro-appcast.xml" ]]; then
  echo "ERROR: Refusing to publish with unexpected staged files: $STAGED_FILES" >&2
  exit 1
fi
git -C "$ROOT" commit -m "release(agentmicro): publish $AGENTMICRO_VERSION appcast"
git -C "$ROOT" push origin "HEAD:${AGENTMICRO_FEED_BRANCH:-main}"

echo "Published AgentMicro $TAG and updated $AGENTMICRO_FEED_URL"
