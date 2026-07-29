#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/Scripts/package_agentmicro.sh"
SIGN="$ROOT/Scripts/sign-and-notarize-agentmicro.sh"
APPCAST="$ROOT/Scripts/make_agentmicro_appcast.sh"
RELEASE="$ROOT/Scripts/release_agentmicro.sh"

for script in "$PACKAGE" "$SIGN" "$APPCAST" "$RELEASE"; do
  bash -n "$script"
done

/usr/bin/grep -Fq 'ARCH_LIST=( ${ARCHES:-} )' "$PACKAGE"
/usr/bin/grep -Fq 'AGENTMICRO_SIGNING=identity' "$SIGN"
/usr/bin/grep -Fq 'xcrun notarytool submit' "$SIGN"
/usr/bin/grep -Fq 'agentmicro-appcast.xml' "$APPCAST"
/usr/bin/grep -Fq 'sparkle:edSignature=' "$APPCAST"
/usr/bin/grep -Fq 'AGENTMICRO_GITHUB_REPOSITORY' "$RELEASE"

if /usr/bin/grep -Eq \
  'AGENTMICRO_PUBLIC_ED_KEY=[A-Za-z0-9+/]{40,}={0,2}' \
  "$ROOT/.mac-release.env.example"; then
  echo "ERROR: Release example must not contain a real AgentMicro public key" >&2
  exit 1
fi

echo "AgentMicro release pipeline tests passed."
