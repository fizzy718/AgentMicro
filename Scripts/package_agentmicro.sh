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
APP_STORE_MODE="${AGENTMICRO_APP_STORE:-0}"
if [[ "$APP_STORE_MODE" == "1" ]]; then
  APP_FINAL="$ROOT/AgentMicro-AppStore.app"
else
  APP_FINAL="$ROOT/AgentMicro.app"
fi
APP_STAGE="$ROOT/.build/package-agentmicro/AgentMicro.app"
source "$ROOT/agentmicro-version.env"
VERSION="${AGENTMICRO_VERSION:-0.1.0}"
BUILD_NUMBER="${AGENTMICRO_BUILD_NUMBER:-1}"
BUNDLE_ID="${AGENTMICRO_BUNDLE_ID:-com.agentmicro.macos}"
FEED_URL="${AGENTMICRO_FEED_URL:-}"
PUBLIC_ED_KEY="${AGENTMICRO_PUBLIC_ED_KEY:-}"
SIGNING_MODE="${AGENTMICRO_SIGNING:-adhoc}"
SIGNING_IDENTITY="${AGENTMICRO_SIGNING_IDENTITY:-}"
PROVISIONING_PROFILE="${AGENTMICRO_APP_STORE_PROVISIONING_PROFILE:-}"
APP_STORE_ENTITLEMENTS="${AGENTMICRO_APP_STORE_ENTITLEMENTS:-}"

cd "$ROOT"

case "$SIGNING_MODE" in
  adhoc) ;;
  identity)
    if [[ -z "$SIGNING_IDENTITY" ]]; then
      echo "ERROR: AGENTMICRO_SIGNING_IDENTITY is required for identity signing" >&2
      exit 1
    fi
    ;;
  app-store)
    if [[ "$APP_STORE_MODE" != "1" ]]; then
      echo "ERROR: app-store signing requires AGENTMICRO_APP_STORE=1" >&2
      exit 1
    fi
    if [[ -z "$SIGNING_IDENTITY" || -z "$PROVISIONING_PROFILE" ]]; then
      echo "ERROR: App Store signing identity and provisioning profile are required" >&2
      exit 1
    fi
    if [[ ! -f "$PROVISIONING_PROFILE" ]]; then
      echo "ERROR: App Store provisioning profile is missing" >&2
      exit 1
    fi
    if [[ -n "$APP_STORE_ENTITLEMENTS" && ! -f "$APP_STORE_ENTITLEMENTS" ]]; then
      echo "ERROR: AGENTMICRO_APP_STORE_ENTITLEMENTS does not exist" >&2
      exit 1
    fi
    ;;
  *)
    echo "ERROR: Unsupported AGENTMICRO_SIGNING: $SIGNING_MODE (expected adhoc, identity, or app-store)" >&2
    exit 1
    ;;
esac

ARCH_LIST=( ${ARCHES:-} )
if [[ ${#ARCH_LIST[@]} -eq 0 ]]; then
  ARCH_LIST=("$(uname -m)")
fi

PRODUCT_STAGE_ROOT="$ROOT/.build/package-agentmicro-products/$CONFIGURATION"
rm -rf "$PRODUCT_STAGE_ROOT"
PREFERRED_BIN_DIR=""
for ARCH in "${ARCH_LIST[@]}"; do
  AGENTMICRO_BUILD_ONLY=1 AGENTMICRO_APP_STORE="$APP_STORE_MODE" swift build \
    -c "$CONFIGURATION" \
    --arch "$ARCH" \
    --product AgentMicro \
    --disable-automatic-resolution
  BIN_DIR="$(
    AGENTMICRO_BUILD_ONLY=1 AGENTMICRO_APP_STORE="$APP_STORE_MODE" swift build \
      -c "$CONFIGURATION" \
      --arch "$ARCH" \
      --disable-automatic-resolution \
      --show-bin-path
  )"
  BINARY="$BIN_DIR/AgentMicro"
  if [[ ! -x "$BINARY" ]]; then
    echo "ERROR: AgentMicro binary not found at $BINARY" >&2
    exit 1
  fi
  if ! lipo -archs "$BINARY" | tr ' ' '\n' | grep -qx "$ARCH"; then
    echo "ERROR: AgentMicro binary does not contain required architecture: $ARCH" >&2
    exit 1
  fi
  mkdir -p "$PRODUCT_STAGE_ROOT/$ARCH"
  cp "$BINARY" "$PRODUCT_STAGE_ROOT/$ARCH/AgentMicro"
  if [[ -z "$PREFERRED_BIN_DIR" ]]; then
    PREFERRED_BIN_DIR="$BIN_DIR"
  fi
done

rm -rf "$APP_STAGE"
mkdir -p "$APP_STAGE/Contents/MacOS" "$APP_STAGE/Contents/Resources" "$APP_STAGE/Contents/Frameworks"
if [[ ${#ARCH_LIST[@]} -gt 1 ]]; then
  BINARIES=()
  for ARCH in "${ARCH_LIST[@]}"; do
    BINARIES+=("$PRODUCT_STAGE_ROOT/$ARCH/AgentMicro")
  done
  lipo -create "${BINARIES[@]}" -output "$APP_STAGE/Contents/MacOS/AgentMicro"
  chmod 755 "$APP_STAGE/Contents/MacOS/AgentMicro"
else
  install -m 755 \
    "$PRODUCT_STAGE_ROOT/${ARCH_LIST[0]}/AgentMicro" \
    "$APP_STAGE/Contents/MacOS/AgentMicro"
fi

ACTUAL_ARCHES="$(lipo -archs "$APP_STAGE/Contents/MacOS/AgentMicro")"
for ARCH in "${ARCH_LIST[@]}"; do
  if ! tr ' ' '\n' <<<"$ACTUAL_ARCHES" | grep -qx "$ARCH"; then
    echo "ERROR: Packaged AgentMicro binary is missing architecture: $ARCH" >&2
    exit 1
  fi
done

RESOURCE_BUNDLE="$PREFERRED_BIN_DIR/CodexBar_AgentMicro.bundle"
if [[ ! -d "$RESOURCE_BUNDLE" ]]; then
  echo "ERROR: AgentMicro resource bundle not found at $RESOURCE_BUNDLE" >&2
  exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_STAGE/Contents/Resources/"
PACKAGED_RESOURCE_INFO="$APP_STAGE/Contents/Resources/CodexBar_AgentMicro.bundle/Info.plist"
/usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${BUNDLE_ID}.resources" \
  "$PACKAGED_RESOURCE_INFO" 2>/dev/null ||
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}.resources" \
    "$PACKAGED_RESOURCE_INFO"
/usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string BNDL" \
  "$PACKAGED_RESOURCE_INFO" 2>/dev/null ||
  /usr/libexec/PlistBuddy -c "Set :CFBundlePackageType BNDL" "$PACKAGED_RESOURCE_INFO"
/usr/libexec/PlistBuddy -c "Add :CFBundleShortVersionString string ${VERSION}" \
  "$PACKAGED_RESOURCE_INFO" 2>/dev/null ||
  /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString ${VERSION}" \
    "$PACKAGED_RESOURCE_INFO"
/usr/libexec/PlistBuddy -c "Add :CFBundleVersion string ${BUILD_NUMBER}" \
  "$PACKAGED_RESOURCE_INFO" 2>/dev/null ||
  /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER}" "$PACKAGED_RESOURCE_INFO"
plutil -lint "$PACKAGED_RESOURCE_INFO"
cp "$ROOT/Config/AgentMicro-PrivacyInfo.xcprivacy" \
  "$APP_STAGE/Contents/Resources/PrivacyInfo.xcprivacy"
"$ROOT/Scripts/build_agentmicro_icon.sh" \
  "$ROOT/AgentMicro.icon" \
  "$APP_STAGE/Contents/Resources/AgentMicro.icns"
if [[ "$APP_STORE_MODE" != "1" ]]; then
  SPARKLE_FRAMEWORK="$PREFERRED_BIN_DIR/Sparkle.framework"
  if [[ ! -d "$SPARKLE_FRAMEWORK" ]]; then
    echo "ERROR: Sparkle framework not found at $SPARKLE_FRAMEWORK" >&2
    exit 1
  fi
  cp -R "$SPARKLE_FRAMEWORK" "$APP_STAGE/Contents/Frameworks/"
  if ! otool -l "$APP_STAGE/Contents/MacOS/AgentMicro" |
    grep -Fq "@executable_path/../Frameworks"; then
    install_name_tool -add_rpath "@executable_path/../Frameworks" \
      "$APP_STAGE/Contents/MacOS/AgentMicro"
  fi
fi

if [[ -n "$FEED_URL" || -n "$PUBLIC_ED_KEY" ]]; then
  if [[ -z "$FEED_URL" || -z "$PUBLIC_ED_KEY" ]]; then
    echo "ERROR: AGENTMICRO_FEED_URL and AGENTMICRO_PUBLIC_ED_KEY must be set together" >&2
    exit 1
  fi
fi

if [[ "$SIGNING_MODE" == "identity" && (-z "$FEED_URL" || -z "$PUBLIC_ED_KEY") ]]; then
  echo "ERROR: identity-signed releases require AgentMicro feed URL and public Ed25519 key" >&2
  exit 1
fi

BUILD_TIMESTAMP="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
GIT_COMMIT="$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")"

cat > "$APP_STAGE/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>es</string>
        <string>ca</string>
        <string>pt-BR</string>
        <string>de</string>
        <string>sv</string>
        <string>fr</string>
        <string>it</string>
        <string>nl</string>
        <string>ja</string>
        <string>ko</string>
        <string>vi</string>
        <string>tr</string>
        <string>uk</string>
        <string>ru</string>
        <string>id</string>
        <string>pl</string>
        <string>ar</string>
        <string>fa</string>
        <string>th</string>
        <string>gl</string>
    </array>
    <key>CFBundleDisplayName</key><string>AgentMicro</string>
    <key>CFBundleExecutable</key><string>AgentMicro</string>
    <key>CFBundleIconFile</key><string>AgentMicro</string>
    <key>CFBundleIconName</key><string>AgentMicro</string>
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
    <key>ITSAppUsesNonExemptEncryption</key><false/>
    <key>AgentMicroBuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>AgentMicroGitCommit</key><string>${GIT_COMMIT}</string>
</dict>
</plist>
PLIST

if [[ -n "$FEED_URL" && "$APP_STORE_MODE" != "1" ]]; then
  /usr/libexec/PlistBuddy -c "Add :SUFeedURL string $FEED_URL" \
    "$APP_STAGE/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUPublicEDKey string $PUBLIC_ED_KEY" \
    "$APP_STAGE/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :SUEnableAutomaticChecks bool true" \
    "$APP_STAGE/Contents/Info.plist"
fi

plutil -lint "$APP_STAGE/Contents/Info.plist"
xattr -cr "$APP_STAGE"

source "$ROOT/Scripts/sparkle_signing_paths.sh"
if [[ "$SIGNING_MODE" == "identity" ]]; then
  CODESIGN_ARGS=(--force --timestamp --options runtime --sign "$SIGNING_IDENTITY")
elif [[ "$SIGNING_MODE" == "app-store" ]]; then
  cp "$PROVISIONING_PROFILE" "$APP_STAGE/Contents/embedded.provisionprofile"
  if [[ -z "$APP_STORE_ENTITLEMENTS" ]]; then
    PROFILE_PLIST="$ROOT/.build/package-agentmicro/profile.plist"
    APP_STORE_ENTITLEMENTS="$ROOT/.build/package-agentmicro/app-store.entitlements"
    security cms -D -i "$PROVISIONING_PROFILE" > "$PROFILE_PLIST"
    /usr/libexec/PlistBuddy -x -c "Print :Entitlements" "$PROFILE_PLIST" > "$APP_STORE_ENTITLEMENTS"
    /usr/libexec/PlistBuddy -c "Set :com.apple.security.app-sandbox true" \
      "$APP_STORE_ENTITLEMENTS" 2>/dev/null ||
      /usr/libexec/PlistBuddy -c "Add :com.apple.security.app-sandbox bool true" \
        "$APP_STORE_ENTITLEMENTS"
    /usr/libexec/PlistBuddy -c "Set :com.apple.security.files.user-selected.read-only true" \
      "$APP_STORE_ENTITLEMENTS" 2>/dev/null ||
      /usr/libexec/PlistBuddy -c "Add :com.apple.security.files.user-selected.read-only bool true" \
        "$APP_STORE_ENTITLEMENTS"
    PROFILE_APP_IDENTIFIER="$(/usr/libexec/PlistBuddy -c \
      "Print :com.apple.application-identifier" "$APP_STORE_ENTITLEMENTS")"
    if [[ "$PROFILE_APP_IDENTIFIER" != *".$BUNDLE_ID" ]]; then
      echo "ERROR: Provisioning profile does not match bundle ID $BUNDLE_ID" >&2
      exit 1
    fi
  fi
  plutil -lint "$APP_STORE_ENTITLEMENTS"
  CODESIGN_ARGS=(--force --timestamp --sign "$SIGNING_IDENTITY" --entitlements "$APP_STORE_ENTITLEMENTS")
else
  if [[ "$APP_STORE_MODE" == "1" ]]; then
    CODESIGN_ARGS=(
      --force
      --sign -
      --entitlements "$ROOT/Config/AgentMicro-AppStore.entitlements"
    )
  else
    CODESIGN_ARGS=(--force --sign -)
  fi
fi

# Inputs copied from Downloads or the developer portal can retain quarantine
# attributes. App Store server-side import rejects any quarantined payload file,
# including the embedded provisioning profile, so clear them after all copying.
xattr -cr "$APP_STAGE"

if [[ "$APP_STORE_MODE" != "1" ]]; then
  SPARKLE="$APP_STAGE/Contents/Frameworks/Sparkle.framework"
  SPARKLE_SIGNING_TARGETS="$(codexbar_sparkle_signing_targets "$SPARKLE")"
  while IFS= read -r SIGNING_TARGET; do
    codesign "${CODESIGN_ARGS[@]}" "$SIGNING_TARGET"
  done <<<"$SPARKLE_SIGNING_TARGETS"
fi
codesign "${CODESIGN_ARGS[@]}" "$APP_STAGE"
codesign --verify --deep --strict --verbose=2 "$APP_STAGE"

rm -rf "$APP_FINAL"
mv "$APP_STAGE" "$APP_FINAL"

echo "Packaged $APP_FINAL (${ARCH_LIST[*]}, $SIGNING_MODE)"
