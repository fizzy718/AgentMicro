#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/Scripts/package_agentmicro.sh"
SIGN="$ROOT/Scripts/sign-and-notarize-agentmicro.sh"
APPCAST="$ROOT/Scripts/make_agentmicro_appcast.sh"
RELEASE="$ROOT/Scripts/release_agentmicro.sh"
WORKFLOW="$ROOT/.github/workflows/release-agentmicro.yml"

for script in "$PACKAGE" "$SIGN" "$APPCAST" "$RELEASE"; do
  bash -n "$script"
done

/usr/bin/grep -Fq 'ARCH_LIST=( ${ARCHES:-} )' "$PACKAGE"
/usr/bin/grep -Fq 'AGENTMICRO_SIGNING=identity' "$SIGN"
/usr/bin/grep -Fq 'xcrun notarytool submit' "$SIGN"
/usr/bin/grep -Fq 'agentmicro-appcast.xml' "$APPCAST"
/usr/bin/grep -Fq 'sparkle:edSignature=' "$APPCAST"
/usr/bin/grep -Fq 'AGENTMICRO_GITHUB_REPOSITORY' "$RELEASE"
/usr/bin/grep -Fq 'gh auth status --hostname github.com' "$RELEASE"
/usr/bin/grep -Fq 'Publish from $AGENTMICRO_FEED_BRANCH' "$RELEASE"

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
