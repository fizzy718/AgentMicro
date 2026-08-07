# AgentMicro Release and Software Updates

AgentMicro has an independent release chain. Never reuse CodexBar’s appcast, Ed25519 key, or release identity.

## One-Time Setup

1. Use [`fizzy718/AgentMicro`](https://github.com/fizzy718/AgentMicro) as `origin` and [`steipete/CodexBar`](https://github.com/steipete/CodexBar) as `upstream`.
2. Create and install an Apple `Developer ID Application` certificate.
3. Create an App Store Connect API key and retain its key ID, issuer ID, and P8 private key.
4. Generate a dedicated Sparkle key:

   ```bash
   .build/artifacts/sparkle/Sparkle/bin/generate_keys --account agentmicro
   ```

5. Copy `.mac-release.env.example` to `.mac-release.env` for local publishing and fill in the AgentMicro repository, feed URL, bundle ID, public key, and Developer ID identity. Never commit the private configuration.

The production feed is:

```text
https://raw.githubusercontent.com/fizzy718/AgentMicro/main/agentmicro-appcast.xml
```

GitHub Releases hosts both the drag-to-install DMG and the Sparkle ZIP. The `main` branch hosts the appcast.
No separate update server is required.

## Version Source

`agentmicro-version.env` is authoritative:

```bash
: "${AGENTMICRO_VERSION:=0.1.3}"
: "${AGENTMICRO_BUILD_NUMBER:=4}"
```

Increase the user version or build number for every release. Sparkle compares `CFBundleVersion`.

## Local Release Preparation

Start from a clean worktree:

```bash
./Scripts/release_agentmicro.sh
```

The script:

1. Builds a universal arm64/x86_64 app.
2. Embeds the AgentMicro feed and public key.
3. Compiles the six-layer Icon Composer source into adaptive `Assets.car` appearances and an ICNS compatibility fallback.
4. Signs Sparkle components and the app with hardened runtime.
5. Submits to Apple notarization and staples the ticket.
6. Produces `.build/agentmicro-release/<version>/AgentMicro-macos-universal-<version>.zip` for Sparkle.
7. Creates a styled DMG with `AgentMicro.app`, an Applications link, a custom background, and fixed Finder layout.
8. Signs the DMG with Developer ID, submits it separately to Apple notarization, and staples its ticket.
9. Signs and updates `agentmicro-appcast.xml` using the ZIP only.

The default command does not upload or commit anything.

## Local Publish

After reviewing the archive, signature, notarization, and appcast:

```bash
./Scripts/release_agentmicro.sh --publish
```

Publish mode creates the GitHub Release, uploads both the DMG and ZIP, verifies both assets are present, stages only
`agentmicro-appcast.xml`, commits it, and pushes it to the configured feed branch. It refuses a dirty worktree or an
existing release tag. The DMG is the recommended first-install artifact; Sparkle continues to consume the ZIP.

When `docs/releases/<version>.md` exists, publish mode uses it as the GitHub Release body. Set
`AGENTMICRO_RELEASE_NOTES_FILE` only to override that versioned file. If neither exists, the script
falls back to GitHub-generated notes.

## GitHub Actions Release

Create a GitHub Environment named `agentmicro-release`. A required reviewer is recommended.

Environment variables:

- `AGENTMICRO_PUBLIC_ED_KEY`
- `AGENTMICRO_SIGNING_IDENTITY`

Environment secrets:

- `AGENTMICRO_DEVELOPER_ID_P12_BASE64`
- `AGENTMICRO_DEVELOPER_ID_P12_PASSWORD`
- `AGENTMICRO_SPARKLE_PRIVATE_KEY_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- `APP_STORE_CONNECT_API_KEY_P8`

To publish:

1. Increase `agentmicro-version.env`.
2. Merge through `feat → dev → main`.
3. Open **Actions → Release AgentMicro → Run workflow**.
4. Enter the exact version from `agentmicro-version.env`.

The workflow validates source, creates a temporary keychain, builds the universal app, signs and notarizes both the
app and final DMG, creates the GitHub Release with DMG and ZIP assets, and commits the ZIP-backed appcast to `main`.
Signing material is deleted at the end of the runner job.

## Update Validation

The first complete update test needs two signed builds:

1. Install an older notarized build containing the production feed.
2. Publish a build with a greater build number.
3. Use **Settings → Updates → Check for Updates** in the old build.
4. Verify discovery, download, Ed25519 validation, replacement, and relaunch.

`0.1.0` cannot self-update because it crashes before Sparkle starts. Users of that build must replace it manually with `0.1.1` once.

## Security Requirements

- Never commit `.mac-release.env`, P8, P12, or Sparkle private keys.
- Never use the CodexBar appcast or public key.
- Do not casually change the bundle ID, Developer ID team, or Ed25519 key after public release.
- Development builds remain ad-hoc signed and must clearly report that updates are unavailable.
- Run `make check` and `make test` before release.
- CI validation does not replace notarization or cross-version update testing.
