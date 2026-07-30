#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/Scripts/package_agentmicro.sh"
SIGN="$ROOT/Scripts/sign-and-notarize-agentmicro.sh"
APPCAST="$ROOT/Scripts/make_agentmicro_appcast.sh"
RELEASE="$ROOT/Scripts/release_agentmicro.sh"
BUILD_ICON="$ROOT/Scripts/build_agentmicro_icon.sh"
CREATE_DMG="$ROOT/Scripts/create_agentmicro_dmg.sh"
RENDER_DMG_BACKGROUND="$ROOT/Scripts/render_agentmicro_dmg_background.swift"
WORKFLOW="$ROOT/.github/workflows/release-agentmicro.yml"

for script in "$PACKAGE" "$SIGN" "$APPCAST" "$RELEASE" "$BUILD_ICON" "$CREATE_DMG"; do
  bash -n "$script"
done
DMG_MODULE_CACHE="$ROOT/.build/agentmicro-release-check/module-cache"
/bin/mkdir -p "$DMG_MODULE_CACHE"
/usr/bin/xcrun swiftc \
  -module-cache-path "$DMG_MODULE_CACHE" \
  -typecheck \
  "$RENDER_DMG_BACKGROUND"

/usr/bin/grep -Fq 'ARCH_LIST=( ${ARCHES:-} )' "$PACKAGE"
/usr/bin/grep -Fq 'AgentMicro.icon' "$PACKAGE"
/usr/bin/grep -Fq 'CFBundleIconFile' "$PACKAGE"
/usr/bin/grep -Fq 'CFBundleIconName' "$PACKAGE"
/usr/bin/grep -Fq 'CodexBar_AgentMicro.bundle' "$PACKAGE"
/usr/bin/grep -Fq 'actool' "$BUILD_ICON"
/usr/bin/grep -Fq 'Assets.car' "$BUILD_ICON"
/usr/bin/grep -Fq '#9CD5FE' "$ROOT/AgentMicro.icon/Assets/thinking-primary.svg"
/usr/bin/grep -Fq '#9CD5FE' "$ROOT/AgentMicro.icon/Assets/thinking-secondary.svg"
/usr/bin/grep -Fq '#9BF396' "$ROOT/AgentMicro.icon/Assets/unread.svg"
/usr/bin/grep -Fq '#FFD0B8' "$ROOT/AgentMicro.icon/Assets/requires-input.svg"
/usr/bin/grep -Fq '#FF7373' "$ROOT/AgentMicro.icon/Assets/error.svg"
/usr/bin/grep -Fq '#FFFFFF' "$ROOT/AgentMicro.icon/Assets/idle.svg"
/usr/bin/grep -Fq 'AGENTMICRO_SIGNING=identity' "$SIGN"
/usr/bin/grep -Fq 'xcrun notarytool submit' "$SIGN"
/usr/bin/grep -Fq 'create_agentmicro_dmg.sh' "$SIGN"
/usr/bin/grep -Fq 'stapler staple "$DMG_PATH"' "$SIGN"
/usr/bin/grep -Fq 'context:primary-signature' "$SIGN"
/usr/bin/grep -Fq 'hdiutil create' "$CREATE_DMG"
/usr/bin/grep -Fq 'hdiutil convert' "$CREATE_DMG"
/usr/bin/grep -Fq 'AgentMicro.app' "$CREATE_DMG"
/usr/bin/grep -Fq '/Applications' "$CREATE_DMG"
/usr/bin/grep -Fq 'background.png' "$CREATE_DMG"
/usr/bin/grep -Fq 'agentmicro-appcast.xml' "$APPCAST"
/usr/bin/grep -Fq 'sparkle:edSignature=' "$APPCAST"
/usr/bin/grep -Fq 'AGENTMICRO_GITHUB_REPOSITORY' "$RELEASE"
/usr/bin/grep -Fq 'gh auth status --hostname github.com' "$RELEASE"
/usr/bin/grep -Fq 'Publish from $AGENTMICRO_FEED_BRANCH' "$RELEASE"
/usr/bin/grep -Fq 'docs/releases/$AGENTMICRO_VERSION.md' "$RELEASE"
/usr/bin/grep -Fq 'AgentMicro-macos-universal-$AGENTMICRO_VERSION.dmg' "$RELEASE"
/usr/bin/grep -Fq 'release create "$TAG" "$ARCHIVE" "$DMG"' "$RELEASE"

test -f "$WORKFLOW"
/usr/bin/grep -Fq 'workflow_dispatch:' "$WORKFLOW"
/usr/bin/grep -Fq 'environment: agentmicro-release' "$WORKFLOW"
/usr/bin/grep -Fq 'permissions:' "$WORKFLOW"
/usr/bin/grep -Fq 'contents: write' "$WORKFLOW"
/usr/bin/grep -Fq './Scripts/release_agentmicro.sh --publish' "$WORKFLOW"
/usr/bin/grep -Fq 'AGENTMICRO_DEVELOPER_ID_P12_BASE64' "$WORKFLOW"
/usr/bin/grep -Fq 'AGENTMICRO_SPARKLE_PRIVATE_KEY_BASE64' "$WORKFLOW"

if /usr/bin/grep -Eq \
  'AGENTMICRO_PUBLIC_ED_KEY=[A-Za-z0-9+/]{40,}={0,2}' \
  "$ROOT/.mac-release.env.example"; then
  echo "ERROR: Release example must not contain a real AgentMicro public key" >&2
  exit 1
fi

echo "AgentMicro release pipeline tests passed."
