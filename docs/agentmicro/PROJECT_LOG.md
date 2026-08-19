# AgentMicro Project Change Log

This log records the durable product and engineering decisions needed by international contributors.

## 2026-08-19

### `release`: published AgentMicro 0.1.5

Changes:

- Advanced the direct-download version to `0.1.5` and build number to `6` with versioned GitHub Release notes.
- Finalized the weekly quota card, stable and relevance-ranked project/task/conversation search, smooth status
  animation, and honest per-task CLI CPU surface for the release.
- Restricted conversation indexing to user/assistant roles, excluded system/developer/tool/reasoning content, and
  required three Latin characters or two Chinese characters before transcript matching. Shorter queries still search
  project and task metadata immediately.

Impact:

- The release includes the latest local task surface without publishing the broad false-positive matches observed for
  short queries such as `vo`.

Verification:

- Promoted `feat/agentmicro-0.1.5` through `dev` and `main`; focused AgentMicro tests, `make check`, and the isolated
  retry of the one flaky upstream AppKit group pass.
- GitHub Actions run `32237052176` completed successfully, publishing signed and notarized universal ZIP/DMG assets,
  tag `v0.1.5`, and the Sparkle appcast entry for build `6`.
- Downloaded release checksums match GitHub's published SHA-256 digests. The extracted app reports version `0.1.5`
  build `6`, contains both `arm64` and `x86_64`, passes strict code-signature and Gatekeeper assessment, and has a
  valid notarization ticket.

Known limitations:

- Codex Desktop CPU remains shared because Codex does not expose per-conversation process ownership.
- Conversation search remains bounded to observed tasks and does not show matched snippets.

## 2026-08-15

### `fix`: stabilized search results and input-method composition

Changes:

- Preserved the existing menu header and AppKit field editor whenever task, CPU, or quota data refreshes during an
  active search instead of recreating the search control.
- Stopped task-state reconciliation from cancelling and restarting an unchanged conversation search.
- Deferred query publication while the field editor contains marked text, deduplicated committed queries, and let
  Escape cancel an active input-method composition before it closes search.
- Prevented AgentMicro's supplemental outside-click and resign-active monitors from cancelling menu tracking during
  active search, including interaction with an input-method candidate window.
- Ranked exact task-title/project matches first, followed by prefix, substring, and conversation-only matches; normal
  working/recent priority now breaks ties instead of overriding search relevance.

Impact:

- Search results remain visible instead of briefly appearing and disappearing, while Pinyin and other macOS input
  methods can complete composition without losing the field or its result set.
- The result the user most likely intended appears at the top even when a newer or actively running task also matches.

Verification:

- Focused AgentMicro tests and repository checks pass; the freshly packaged app remains running.

Known limitations:

- Conversation search remains bounded to already observed rollouts and does not display the matched message text.

## 2026-08-13

### `feature`: added honest per-task CPU levels

Changes:

- Added a direct-download process sampler that totals each correlated CLI task's root process and descendants, smooths
  the result, and updates the existing menu row every two seconds only while the menu is open.
- Added a compact 10-point CPU label on the task row's second line and a default-on Task Display setting.
- Labeled Desktop tasks `CPU shared` instead of falsely assigning the shared Codex app process to one conversation;
  IDE/unknown tasks and uncorrelated CLI sessions omit the value. App Store builds do not sample processes.
- Localized the setting and shared-attribution label across all 23 interface languages.

Impact:

- Users can see which CLI tasks are consuming CPU without opening Activity Monitor, including child tool processes,
  while the UI remains explicit where reliable per-conversation attribution is unavailable.

Verification:

- Focused parser/model/settings/UI tests cover descendant aggregation, attribution labels, persistence, and live row
  updates. The focused AgentMicro suite and repository checks pass.

Known limitations:

- Codex Desktop does not expose per-conversation CPU ownership, so its rows intentionally show only `CPU shared`.
- Process-reported CPU may exceed 100% on multicore systems and is a smoothed activity level, not a billing metric.

## 2026-08-12

### `feature`: corrected quota semantics, expanded search, and smoothed icon animation

Changes:

- Changed the shared usage fill to clip against the full rounded track, then corrected AgentMicro's projection so the
  title reports used quota while the bar and all markers use CodexBar's remaining-quota axis (30% used = 70% filled).
- Added a menu-header search button that swaps the title row for a focused input, matches project and task names
  immediately, and asynchronously matches bounded recent user/assistant conversation text before the row limit.
- Kept conversation matching local and transient, excluded tool output, and returned only the corresponding existing
  task/project row so selecting it reuses the existing Codex thread focus path.
- Increased each attention slot's breathing sequence from five frames at 250 ms to 21 frames at 50 ms.
- Fixed the native search interaction so result updates replace only the task/usage/footer region instead of
  destroying and recreating the active search field on every keystroke; focus and the field editor now remain stable.
- Stopped live task reconciliation from clearing and restoring conversation matches on every rollout write. Search
  now retains the last result set, debounces typing by 120 ms, and redraws only when the visible rows actually change.
- Localized search, close, and empty-result copy across all 23 interface languages.

Impact:

- A reported 30% used value now renders 70% remaining, matching CodexBar and the user's visual expectation.
- Users can find an observed task from its project, title, or recent conversation wording without exposing snippets.
- Search remains editable while synchronous metadata and asynchronous conversation matches update underneath it.
- Thinking and attention states breathe at 20 frames per second instead of stepping at four frames per second.

Verification:

- All 95 focused AgentMicro tests pass, including remaining-quota projection, metadata/content search, tool-output
  exclusion, animation cadence, and complete localization catalogs.
- `make check` passes with SwiftFormat, strict SwiftLint, localization, scripts, documentation, and release checks.

Known limitations:

- Search applies only to tasks already observed locally and indexes at most the latest 8 MiB of each rollout; it does
  not query archived history outside that task set or show the matching message.

## 2026-08-11

### `feature`: added the complete weekly Codex usage block to the direct-download menu

Changes:

- Reused CodexBar's read-only Codex CLI app-server `UsageFetcher`, `UsagePace`, and quota-warning thresholds, and
  projected its weekly rate window into a small AgentMicro-specific presentation model.
- Extracted CodexBar's metric row and progress/pace/warning marker renderer into a shared `CodexBarUI` library target;
  CodexBar and AgentMicro now import the same component.
- Added consumed percentage, localized reset countdown, deficit/reserve pace, projected exhaustion or reset survival,
  and progress markers below the task rows and above the footer actions, with explicit loading and unavailable states
  in all 23 interface languages.
- Matched the card typography to AgentMicro task rows: 13-point semibold headline, 11-point secondary metadata,
  aligned baselines, and a shorter loading/unavailable row.
- Throttled automatic attempts to five minutes while keeping menu Refresh as an explicit forced attempt.
- Compiled the surface out of the Mac App Store variant because its sandbox does not permit launching Codex CLI.

Impact:

- Direct-download users can see the complete compact weekly Codex allowance forecast without leaving the task-focused
  menu.
- Usage-fetch failures remain isolated from task observation, navigation, and state colors.

Validation:

- Added focused projection, clamping, state, refresh-policy, and localization coverage.
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicroUsageModelTests` passes.
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicroLocalizationTests` passes.
- The direct and Mac App Store AgentMicro targets compile, `make check` passes, and `make test` passes all 733
  discovered selections across 62 groups without retries.

Known limitations:

- The first version shows only the standard weekly lane, not session, model-specific, token-history, spend, or
  multiple-account details.
- The Mac App Store edition omits the card until a supported sandbox-compatible Codex usage API exists.

## 2026-08-09

### `distribution`: prepared a Mac App Store build path

Changes:

- Added a compile-time Mac App Store variant that removes Sparkle, avoids sandbox-incompatible process-tool scans,
  and keeps rollout-backed Desktop and CLI state observation.
- Added first-launch and General-settings authorization for a user-selected Codex data folder, persisted as a
  read-only security-scoped bookmark.
- Added App Sandbox entitlements, a privacy manifest with required-reason declarations, localized authorization and
  store-update copy in all 23 interface languages, and profile-derived application/team signing entitlements.
- Added universal App Store package, validation, and upload automation while leaving the Developer ID/Sparkle chain
  intact.

Impact:

- AgentMicro can be packaged for Mac App Store submission without a prohibited independent updater or unrestricted
  home-directory access.
- Store users retain the five-state rollout reducer after explicitly authorizing their local Codex data directory.
  The sandboxed edition does not promise live PID ownership or CLI terminal routing.

Validation:

- `AGENTMICRO_BUILD_ONLY=1 AGENTMICRO_APP_STORE=1 swift build -c debug --product AgentMicro
  --disable-automatic-resolution` succeeds with Xcode 26.6.
- The ad-hoc arm64 sandbox package passes strict code-signature verification, contains the expected two sandbox
  entitlements and valid privacy manifest, and has no Sparkle linkage.
- The App Store variant passes all 88 focused AgentMicro tests.
- `make check` passes, including SwiftFormat, strict SwiftLint, localization, script, documentation, and release
  checks.
- `make test` passes all 732 discovered selections across 61 groups with no failures or retries.
- The packaged App Store settings UI, Codex-folder authorization panel, Store-managed updates copy, and four
  1280-by-800 submission screenshots were inspected locally without granting access to real Codex data.
- Registered the production App ID `com.agentmicro.macos`, created dedicated Mac App Distribution and Mac Installer
  Distribution identities plus the `AgentMicro Mac App Store` profile, and verified all three identities locally.
- The distribution-signed universal `0.1.4 (5)` app passes strict code-signature verification with the expected
  sandbox/read-only entitlements; its signed installer package passes `pkgutil --check-signature` with the Apple
  certificate chain.
- Apple validation exposed two package-only import requirements: the SwiftPM resource bundle needed its own bundle
  identifier/version metadata, and the embedded provisioning profile needed quarantine attributes removed after it
  was copied. The packaging script now handles both before signing.
- The corrected `0.1.4 (5)` package passed Apple validation, uploaded as delivery
  `cc762605-70cf-46e8-bf75-2f2c8a800c4b`, and completed server-side processing as App-Store-eligible with no
  non-exempt encryption.
- Created App Store Connect app `6799531205`, published the no-data-collected privacy label, configured a free public
  release in all 175 storefronts, set the age rating to 4+, attached build 5, and submitted review submission
  `89764bec-4f2e-45ea-978f-1a8fe62c5a8c`.
- Deployed the dedicated policy page to the production site and verified
  `https://agentmicro.cc/privacy.html` returns the AgentMicro privacy policy over HTTPS.

Known limitations:

- App Store publication is pending Apple's review; App Store Connect currently reports version `0.1.4` as waiting
  for review and is configured to release automatically after approval.

### `release`: prepared AgentMicro 0.1.4

Changes:

- Advanced the public version to `0.1.4` and build number to `5`.
- Added versioned release notes covering resumed old-task rediscovery and bounded background resource use.

Impact:

- The next signed release will restore visibility for resumed tasks created outside the current scan window while
  substantially reducing CPU and wakeups during active Codex writes.

Validation:

- The focused AgentMicro and scanner suites, `make check`, the full 732-selection sharded suite, and Release-mode
  runtime sampling pass before release preparation.

Known limitations:

- Signing, notarization, release-asset verification, appcast publication, and live update-path verification remain
  pending until the release completes from `main`.

### `release`: published AgentMicro 0.1.4

Changes:

- Published the signed and notarized universal ZIP and drag-to-Applications DMG through GitHub Actions.
- Added the `v0.1.4` Sparkle appcast entry with build `5` and its dedicated EdDSA signature.

Impact:

- Existing AgentMicro 0.1.1-and-later installations can discover and install the resumed-task and resource-efficiency
  update through the existing update feed.

Validation:

- GitHub Actions run `31276440826` completed successfully from source commit `8246c1aa`, including source checks,
  Developer ID signing, application and DMG notarization, asset upload, and signing-material cleanup.
- GitHub Release `v0.1.4` is public and contains the universal ZIP and DMG assets.
- Appcast commit `bd25452e` points to the 0.1.4 ZIP, reports build `5`, matches the published archive size, and contains
  a non-empty EdDSA signature.

Known limitation:

- The live Sparkle update prompt was not manually exercised after publication.

### `perf`: made task observation event-driven and bounded repeated work

Changes:

- Replaced 2/5-second fallback polling with 15/30-second safety intervals while preserving immediate debounced file,
  unread-state, and thread-database event reconciliation.
- Dropped overlapping safety polls while retaining one coalesced follow-up for real events.
- Split watched changes into incremental known-rollout/unread reconciliation and 2-second-coalesced discovery for
  session-directory or thread-index changes, preventing active JSONL writes from launching repeated full scans.
- Filtered the full process snapshot to agent candidates before date parsing, selected Codex-only scanning for
  AgentMicro, and cached immutable rollout first-line metadata across append-only updates.
- Pre-rendered and cached five-frame status animation sequences, reduced status-bar redraws from about 14 to 4 per
  second with wakeup tolerance, skipped unchanged native-menu reconstruction, and preserved the initial empty-scan
  transition and explicit presentation/settings rebuilds.
- Skipped status-item image and tooltip assignment entirely when their rendered content is unchanged.
- Throttled optional Accessibility snapshots to one per second and limited label extraction to selected, button, and
  alert elements while keeping bounded traversal and read-only behavior.

Impact:

- AgentMicro no longer schedules the next full scan immediately when a slower scan overlaps a safety tick.
- Stable tasks avoid repeated rollout-header reads, menu-model/state-store work, image creation, and unnecessary
  Accessibility label reads, reducing background CPU and wakeups without weakening watched-event responsiveness.

Validation:

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicro` passes all 88 tests.
- `swift test --disable-automatic-resolution --filter
  'AgentSessionParserTests|CodexSessionRolloutTests|CodexThreadMetadataReaderTests'` passes all 35 focused tests.
- `make check` passes with no formatting, lint, documentation, or release-pipeline findings.
- `make test` passes all 732 test selections across 61 groups with no failures, retries, or timeouts.
- A 25-second Release-mode sample spanning active rollout writes and a safety-scan window reports 0.7–4.2% AgentMicro
  CPU in non-initial samples, down from the pre-change 30–74% range on the same host and workload. Steady resident
  memory is approximately 30 MB versus the previous 24–25 MB; the bounded increase holds pre-rendered animation
  frames.
- A 5-second stack sample confirms that the main run loop is sleeping for the overwhelming majority of samples and
  that known-rollout writes no longer continuously invoke full session discovery.

Known limitations:

- The Accessibility tree remains a bounded main-actor compatibility path when Enhanced Status Detection is enabled;
  a notification-driven or dedicated-reader design needs cross-version evidence before adoption.
- Stable host-normalized long-duration energy thresholds are not yet part of CI; this follow-up remains in the backlog.

### `fix`: rediscovered resumed tasks from old creation-date directories

Changes:

- Supplemented the bounded current-date session scan with recently updated, unarchived rollout paths from Codex's local thread database.
- Kept rollout modification time and structured events authoritative while rejecting non-rollout, non-regular, archived, stale, and path-escaping indexed candidates.
- Added the selected Codex state database to the change monitor and deduplicated database and directory candidates.
- Added focused coverage for recent-path queries, old-directory resume discovery, archived/stale/escaping candidates, and database watching.

Impact:

- A Codex conversation can resume from any older creation-date directory and reappear in AgentMicro without a fixed historical lookback or application restart.
- Discovery remains bounded and local instead of recursively scanning the entire session archive on every refresh.

Validation:

- `swift test --disable-automatic-resolution --filter CodexSessionRolloutTests` passes all 17 focused tests.
- `swift test --disable-automatic-resolution --filter CodexThreadMetadataReaderTests` passes all 9 focused tests.
- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicroRefreshPolicyTests` passes all 8 focused tests.
- `make check` passes with no formatting, lint, documentation, or release-pipeline findings.
- A local redacted `AgentMicro --diagnose-once` scan rediscovered the previously omitted July 23 `multica` rollout after it was updated on August 9.
- `make test` was run, but the existing live-power-state adaptive timer tests reject their expected timer advance while this host reports low-power mode; both failures reproduce without the scanner tests and are outside this change.

Known limitations:

- Codex's local thread database remains an undocumented compatibility surface; current-date directory discovery remains the fallback when the index is unavailable or incompatible.

## 2026-08-07

### `fix`: limited menu bar animation to activity and attention states

Changes:

- Kept the six icon slots aligned with menu task order from left to right across the top row, then right to left across the bottom row.
- Filtered the breathing sequence so thinking, unread, needs-input, and error blocks animate while idle, unknown, and empty blocks remain static.
- Added focused coverage for sparse attention slots and the two-row task mapping.

Impact:

- The icon distinguishes tasks with activity or required attention without animating neutral idle slots.

Validation:

- `AGENTMICRO_BUILD_ONLY=1 swift test --disable-automatic-resolution --filter AgentMicroMenuModelTests` passes all 18 focused tests.
- `make check` passes with no SwiftFormat or SwiftLint findings.
- `make test` passes all 732 test selections across 61 groups without failures or retries.

### `release`: prepared AgentMicro 0.1.3

Changes:

- Advanced the public version to `0.1.3` and build number to `4`.
- Added release notes for the attention-aware, task-ordered menu bar animation.

Impact:

- The next signed release will make activity and attention cues precise without animating idle task slots.

Validation:

- The focused AgentMicro menu model tests, `make check`, and the full sharded test suite pass before release preparation.

Known limitations:

- Signing, notarization, release-asset verification, appcast publication, and the live update path remain pending until the GitHub release workflow completes from `main`.

### `ci`: refreshed the generated documentation index for the 0.1.3 release

Changes:

- Regenerated `docs/llms.txt` after the AgentMicro canonical documentation URL changed.

Impact:

- The release workflow's source verification can proceed with a current generated documentation index.

Validation:

- `make check` passes, including the `llms index OK` gate and all SwiftFormat and SwiftLint checks.

### `release`: published AgentMicro 0.1.3

Changes:

- Published the signed and notarized universal ZIP and DMG through GitHub Actions.
- Added the `v0.1.3` Sparkle appcast entry with build `4` and its EdDSA signature.

Impact:

- Existing AgentMicro 0.1.1-and-later installations can discover and install the attention-aware icon update.

Validation:

- GitHub Actions run `31171993293` completed successfully, including source verification, signing, notarization, asset upload, and signing-material cleanup.
- GitHub Release `v0.1.3` is public and marked latest with both universal ZIP and DMG assets.
- The published appcast points to the 0.1.3 ZIP and contains build `4` plus a non-empty EdDSA signature.

Known limitation:

- The live Sparkle update prompt was not manually exercised after publication.

## 2026-07-31

### `marketing`: prepared first authentic Product Hunt media assets

- Exported a 240×240 Product Hunt thumbnail from the real AgentMicro application icon.
- Prepared a gallery-ready version of the existing sanitized menu screenshot; remaining gallery images and the optional demo video must remain real release-build captures with fictitious task data.
- Produced a non-destructive English-localized variant of the menu screenshot for the English Product Hunt gallery, retaining the observed task states, project labels, and elapsed times.

## 2026-07-30

### `marketing`: prepared the Product Hunt launch surface

- Added a focused, static AgentMicro landing page that uses the real menu screenshot and links directly to the public repository and latest release.
- Added a ready-to-paste Product Hunt launch kit with the approved title/tagline, product positioning, a sanitized five-image capture brief, a 37-second demo storyboard, Maker Comment, comment-safe outreach copy, and pre-flight checklist.
- Kept the public story within the V1 boundary: local observation and Desktop navigation, never task control, hosted sync, or AI-agent claims.

Known limitation:

- The final gallery and video remain maker-captured assets. They must be recorded from the release build with fictitious task and project names before external publication.

## 2026-07-28

### `research`: mapped reusable local projects

- Audited CodexBar, abtop, cc-switch, and token-monitor.
- Selected CodexBar as the native macOS foundation.
- Selected abtop’s reducer and fixture ideas as state-model references without adding a Rust sidecar.
- Deferred cc-switch history/resume and token-monitor usage/sync to later roadmap stages.

### `product`: redefined V1 as a focused observer

- Positioned AgentMicro as a local-first Codex task pulse, not a multi-provider usage monitor.
- Established honest state, read-only behavior, menu-bar priority, and progressive enhancement as product principles.
- Excluded task control, remote sync, usage monitoring, and other providers from V1.

### `architecture`: established the observed-task pipeline

- Reused CodexBar local session discovery and native menu infrastructure.
- Added an AgentMicro-owned task model and state engine.
- Chose bounded local rollout parsing and fail-safe state reduction.

### `docs`: created the product documentation system

- Added product definition, V1 specification, roadmap, capability map, backlog, release guide, and project log.
- Made documentation updates part of the completion criteria for material changes.

### `implementation`: completed M0 through M3

- Built the independent menu bar target and app lifecycle.
- Added session discovery, task rows, focus behavior, refresh coalescing, and menu tests.
- Implemented incremental rollout parsing, tool-call pairing, partial-line handling, truncation recovery, and large-file tailing.
- Added title/project display modes, recent completion retention, launch at login, localization, packaging, and real concurrent Desktop/CLI validation.

## 2026-07-29

### `implementation`: adopted the Codex Micro five-color model

- Standardized visible colors as white idle, green unread, blue thinking, orange needs-input, and red error.
- Added a multi-task status icon and shared color source for icon and menu rows.
- Preserved internal unknown evidence without exposing a misleading sixth color.

### `implementation`: improved live synchronization and row design

- Replaced the multi-square task-row glyph with one rounded state block.
- Added project name and current-turn duration while removing redundant provider/state text.
- Added filesystem observation, short polling, refresh bursts, and scan coalescing.

### `fix`: corrected Desktop ownership, unread state, and approval detection

- Stopped assigning one app-server PID to every Desktop task.
- Used rollout lifecycle for Desktop tasks without an independent PID.
- Synchronized Desktop completed/unread state from Codex’s local unread-thread set.
- Prevented automatic or guardian approval activity from being shown as a user block.

### `refine`: fixed hover, duration, and task ordering

- Ensured only one menu row highlights under the pointer and text cannot be accidentally selected.
- Defined duration as current-turn runtime and froze it after the turn stops.
- Sorted working tasks first, then by recent state change.
- Added second-level in-place duration updates while the menu is open.

### `implementation`: finalized the six-slot menu bar identity

- Changed the icon to two rows of three borderless rounded rectangles.
- Kept the same six ordered tasks and the same state-color source as the expanded menu.
- Added a per-slot breathing loop with Reduce Motion support.
- Later changed the rectangles from vertical to horizontal while preserving animation strategy.

### `implementation`: completed settings, languages, and update runtime

- Added system-language following and all 23 CodexBar interface languages, including RTL layout.
- Added direct numeric task-count entry from 1 to 20.
- Added version display, automatic-update preference, manual update checking, and localized unavailable reasons.
- Kept the automatic-update preference editable even when the development updater is unavailable.

### `release`: established independent distribution

- Created AgentMicro-specific version, package, signing, notarization, appcast, and GitHub Release scripts.
- Added GitHub Actions release automation with protected environment variables and secrets.
- Published `0.1.0` through the independent `fizzy718/AgentMicro` repository.
- Preserved CodexBar MIT attribution and separated AgentMicro’s product and release identity.
- Added the black six-light AgentMicro logo above the English and Chinese public README titles.

### `fix`: ended thinking on final answers and detected interactive handoffs

- A final answer now ends blue thinking state immediately.
- Explicit assistant questions, approval requests, and browser-input handoffs enter orange.
- Orange remains latched until the next user continuation.
- Negative or informational browser mentions do not trigger needs-input.

### `refine`: added fast-mode indication

- Detected Codex fast mode from local rollout metadata.
- Added a lightning badge after the task duration.
- Kept task state restricted to the five defined colors.

### `docs`: published the open-source project surface

- Wrote the public English README with product screenshot, installation, privacy, scope, contribution, community, upstream credit, and MIT license information.
- Added the AgentMicro WeChat community QR image.
- Added the public AgentMicro Telegram discussion-group invitation.
- Clarified that inherited provider code is not connected to the Codex-only AgentMicro V1.

### `fix`: repaired first installed launch and application identity

- Diagnosed the public `0.1.0` launch crash: SwiftPM’s generated `Bundle.module` accessor searched the application root and the CI build path, while the package correctly placed localization resources under `Contents/Resources`.
- Replaced the fatal accessor with a safe resolver for packaged, development, and test layouts.
- Added a dedicated white Icon Composer source with horizontal 2×3 state blocks and exact five-state colors.
- Added reproducible icon export and ICNS packaging with `CFBundleIconFile`.
- Changed menu bar blocks to horizontal rounded rectangles.
- Kept automatic updates switchable in unavailable development builds.
- Bumped the repair release to `0.1.1 (2)`.

Impact:

- The app can launch after being downloaded and moved to `/Applications`.
- Finder and Settings show an independent AgentMicro application icon.
- `0.1.0` users must replace the app manually once because the crash happens before Sparkle can start.
- Full compiled Icon Composer Default/Dark/Clear/Tinted appearances remain deferred as `AM-703`; the current package exports the Default rendition as ICNS.

### `implementation`: added paged settings and first-launch guidance

- Replaced the single crowded form with a CodexBar-style sidebar: Guide, General, Task Display, and Updates.
- Made Guide the first page and documented all five task-state colors in the app.
- Automatically opened Guide on first launch.
- Added a bottom-right “Don’t show this guide on next launch” checkbox that is checked by default.
- Persisted the choice so clearing the checkbox opens Guide on later launches.
- Added the Guide copy to all 23 language catalogs and retained catalog parity tests.

### `docs`: completed the English AgentMicro documentation set

- Added English counterparts for every document in `docs/agentmicro`.
- Removed the duplicate internal Simplified Chinese document set and made English the single source of truth.
- Retained only the repository root `README.zh-CN.md` as the Chinese reader entry point.
- Updated the public README to use English product and release documentation as the default contributor path.

### `fix`: made menu dismissal and Desktop navigation deterministic

- Closed the task menu when the app resigns active or the user clicks elsewhere.
- Deferred custom-row actions until after native menu tracking has ended.
- Verified the local rollout ID against Codex's own task registry and confirmed that Desktop task IDs are valid navigation IDs rather than file paths.
- Traced Codex's packaged macOS event handlers: `codex://threads/<id>` belongs to the protocol/deep-link path, while application-targeted document opening also enters Codex's local-file queue.
- Routed every Desktop task through Launch Services' registered `codex:` protocol handler, after verifying that the handler is the installed Codex application. This avoids dual deep-link/file-open delivery without task-specific exceptions.
- Retained project/window activation only as the fallback for sessions without a supported Desktop deep link.

### `implementation`: shipped the adaptive multilayer application icon

- Enlarged the six horizontal state lights and moved the default background from pure white to a light cool-gray system gradient.
- Split the six lights into independent vector layers while retaining the exact five task-state source colors.
- Replaced Default-only raster export with Xcode asset compilation.
- Packaged `Assets.car` with six-layer Aqua, Dark Aqua, and tintable icon groups, from which macOS renders Default, Dark, Clear, and Tinted appearances.
- Retained `AgentMicro.icns` and `CFBundleIconFile` as the macOS 14+ compatibility path, and added `CFBundleIconName` for the layered icon.
- Verified the source and asset pipeline with Xcode Beta 27 and Xcode 26.6.

Impact:

- Current macOS releases can render the system-selected icon appearance instead of always showing the flattened light icon.
- Older supported macOS releases keep a stable fallback icon.
- The manual SwiftPM package remains reproducible and does not require converting the project to an Xcode app target.

### `research`: modeled Codex Micro as a product system

Changes:

- Added a durable Codex Micro functional model based on OpenAI documentation, the Supply Co. product page, independent coverage, and local `freemicro`, `abtop`, and `opendeck` evidence.
- Separated official facts, observed implementation details, and AgentMicro decisions.
- Documented the six-slot assignment model, controls, five-state lifecycle, selection animation, read closure, source confidence, and product invariants.

Impact:

- Future status changes have an evidence-backed reference instead of relying on remembered screenshots or color labels.
- Green is explicitly modeled as a transient unread result rather than permanent completion history.

### `fix`: closed explicit Desktop read state against stale Codex data

Changes:

- Made an explicit AgentMicro view of the current completion outrank a lagging Codex persisted unread bit.
- Required exact Desktop navigation success before recording the task as viewed; failed deep links and generic app activation do not clear green.
- Kept Codex unread state authoritative when no task-specific local view evidence exists.
- Preserved completion freshness: newer rollout activity invalidates the older read marker and can turn the task green again.
- Added focused resolver coverage for both precedence paths.

Impact:

- A completed task opened from AgentMicro changes from green to white immediately and does not bounce back to green because of stale persisted state.
- Tasks not opened through AgentMicro remain unread until Codex clears them or a supported exact-view signal becomes available.

Known limitations:

- Codex does not publish the exact Desktop sidebar selection as a supported local event. AgentMicro does not clear all unread tasks merely because ChatGPT is frontmost and does not require Accessibility UI scraping.

### `fix`: strengthened failure, handoff, and direct-view state evidence

Changes:

- Added structured terminal-failure events, unresolved nonzero tool exits, failed final answers, and blocking abort reasons to the red-state reducer while excluding user interruption and recovered failures.
- Expanded orange detection for structured question tools and explicit browser/user handoffs without treating Guardian escalation metadata as a user approval request.
- Added optional Enhanced Status Detection in General settings, disabled by default.
- When explicitly enabled and granted macOS Accessibility permission, matched a unique selected Codex task and read paired approval/rejection controls or visible blocking error dialogs.
- Used exact enhanced selection as task-specific read evidence, preserving the green-to-white closure for views made directly inside Codex.
- Added the setting and explanatory copy to every AgentMicro language catalog.

Impact:

- Base mode remains fully functional and never asks for Accessibility permission.
- Users who opt in receive faster, more accurate direct-Codex viewed state and visible approval/error detection.
- AgentMicro's Accessibility integration is read-only: it never clicks, types, approves, declines, or sends content.

Validation:

- Focused state, unread, enhanced-status, and settings suites passed 53 tests.
- App-localization parity, SwiftFormat, and SwiftLint rules passed.
- The full sharded suite passed all 732 test selections across 61 groups with no retries.

Known limitations:

- Codex accessibility labels and local rollout formats are not supported public APIs and may change.
- Ambiguous task labels fail closed rather than clearing unread or assigning an actionable state to the wrong task.

### `release`: prepared AgentMicro 0.1.1

Changes:

- Added the user-facing 0.1.1 GitHub Release notes as a versioned repository document.
- Made local and GitHub Actions publishing select the matching versioned notes automatically.
- Kept `agentmicro-version.env` at the next continuous public version, 0.1.1 build 2.

Impact:

- The signed 0.1.1 universal archive, GitHub Release, and Sparkle feed share one reviewed release description.
- Users of 0.1.0 receive an explicit manual-upgrade notice because that build cannot start Sparkle reliably.

Validation:

- Release script syntax and repository release-pipeline checks pass through `make check`.

Known limitations:

- A complete Sparkle update test begins with 0.1.1 and requires a later signed build as the update target.

## 2026-07-30

### `fix`: removed archived guardian parents from the task menu

Changes:

- Added active, archived, and unknown Codex thread archive metadata with legacy-database fallback.
- Excluded explicitly archived threads before guardian recovery and state reduction.
- Prevented guardian records from recovering parents under `archived_sessions` or presenting themselves when no valid parent rollout can be resolved.
- Limited unknown archive metadata to a two-hour retention window without changing the normal behavior of active Desktop tasks, which commonly have no independent PID.

Impact:

- Archiving a Codex task removes it from AgentMicro instead of leaving a broken menu row that opens “conversation not found.”
- Active threads remain visible, and temporary database incompatibility does not classify them as archived.

Validation:

- Added metadata compatibility and guardian-archive regression coverage for current and legacy Codex database schemas.

Known limitations:

- Archive metadata remains a best-effort local Codex integration rather than a supported public API.

### `release`: added a notarized drag-to-install DMG

Changes:

- Added a native `hdiutil` DMG builder with a custom AgentMicro background, fixed Finder layout, and an Applications drop target.
- Kept the existing ZIP as the Sparkle artifact while adding the DMG as a second GitHub Release asset.
- Extended the release pipeline to Developer ID-sign, separately notarize, staple, assess, and verify the final DMG.
- Added release guards that fail if either artifact is absent locally or from the published GitHub Release.

Impact:

- New users can install AgentMicro through the standard macOS drag-to-Applications experience.
- Automatic updates retain the established ZIP appcast and Ed25519 signature contract.
- GitHub Actions remains the authoritative signed release builder without adding Homebrew or third-party DMG tooling.

Validation:

- The release checks type-check the deterministic AppKit background renderer and validate the native DMG, notarization,
  Applications-link, and dual-asset publishing paths.
- A local ad-hoc disk-image smoke test verifies the finished DMG can be mounted and contains both required install items.
- `make check` passes with zero formatting or lint findings, and the complete sharded test suite passes all 732 selections
  across 61 groups without failures or retries.

Known limitations:

- The signed DMG path is fully exercised only by the protected GitHub release environment because local development builds do not have release signing and notarization credentials.

### `release`: published AgentMicro 0.1.1

Changes:

- Published the signed universal `v0.1.1` release from source commit `47f28c1` through GitHub Actions run `30475516851`.
- Apple Notary Service accepted the application, the release archive received a stapled ticket, and the workflow published the reviewed versioned notes.
- Updated the production Sparkle appcast in commit `b318be6` with build 2, the release archive size, and its Ed25519 signature.

Impact:

- New installations receive the first production build with the closed-loop task state model, optional Enhanced Status Detection, expanded localization, and the updated menu and settings experience.
- AgentMicro 0.1.1 can use the production appcast for future signed updates. Users on 0.1.0 must install 0.1.1 manually because 0.1.0 cannot reliably start Sparkle.

Validation:

- GitHub's macOS 15 runner verified that the signed app is valid on disk and satisfies its designated requirement.
- Apple notarization completed with an `Accepted` status.
- The published ZIP returned HTTP 200; its app reports version 0.1.1, build 2, contains both arm64 and x86_64 slices, and matches the live appcast entry.

Known limitations:

- Developer ID verification on the local beta macOS installation is not trustworthy: the same host reports equivalent trust or signature failures for Apple/Xcode and ChatGPT applications. Release acceptance therefore uses the clean GitHub runner and Apple Notary Service as the authoritative checks.
- End-to-end automatic-update installation can first be exercised when a later signed release is available as the update target.

### `release`: prepared AgentMicro 0.1.2

Changes:

- Advanced the public version to `0.1.2` and build number to `3`.
- Added versioned release notes covering archived-task filtering and the drag-to-Applications DMG.
- Kept the ZIP as the Sparkle update artifact while making the signed and notarized DMG the preferred first-install package.

Impact:

- Users receive a focused patch release with a cleaner current-task list and a standard macOS installation experience.
- AgentMicro 0.1.1 becomes the first production build that can exercise a complete Sparkle update to a newer signed release.

Validation:

- `make check` passes, and all 732 test selections pass across 61 groups without failures or retries.
- The protected GitHub release workflow remains responsible for Developer ID signing, Apple notarization, DMG and ZIP publication, and appcast generation.

Known limitations:

- Final notarization, release-asset verification, and the 0.1.1-to-0.1.2 update test require the GitHub release workflow to finish successfully.

### `release`: published AgentMicro 0.1.2

Changes:

- Published the signed universal `v0.1.2` release from source commit `3682fe9` through GitHub Actions run `30511528292`.
- Published both `AgentMicro-macos-universal-0.1.2.dmg` for first installation and the Sparkle-signed ZIP for updates.
- Updated the production appcast in commit `b03760d` with version 0.1.2, build 3, archive size, and Ed25519 signature.

Impact:

- New users can install through the standard drag-to-Applications DMG.
- AgentMicro 0.1.1 can discover and authenticate 0.1.2 through its existing production update configuration.

Validation:

- Apple Notary Service accepted the application and DMG independently, and both stapled tickets validate.
- The downloaded DMG and ZIP match the SHA-256 digests recorded by GitHub; the application is version 0.1.2 build 3 with arm64 and x86_64 slices.
- The DMG contains `AgentMicro.app` and the `/Applications` drag target, while both the application and DMG pass signature verification.
- The live appcast matches `main`, and its Ed25519 signature for the downloaded ZIP validates against the public key embedded in both 0.1.1 and 0.1.2.

Known limitations:

- The currently installed application was already 0.1.2, so validation did not destructively downgrade it solely to replay the interactive 0.1.1-to-0.1.2 replacement UI.

### `docs`: adopted the macOS 27 light application icon

Changes:

- Recompiled the latest layered `AgentMicro.icon` source with Xcode Beta and exported its light fallback for GitHub rendering.
- Replaced the legacy dark SVG above both public README titles with the current light application icon.

Impact:

- The repository landing page now matches the current macOS 27 application identity rather than showing the retired dark logo.

Validation:

- `make check` passes, including documentation links, repository resource checks, formatting, and lint.

### `fix`: kept release checks portable in Linux CI

Changes:

- Restricted the AppKit DMG-background Swift type-check to macOS while keeping every portable release-script and workflow assertion active on Linux.

Impact:

- Ubuntu lint runners no longer fail with exit 127 solely because `/usr/bin/xcrun` is a macOS tool.
- macOS checks still type-check the deterministic DMG background renderer with the selected Xcode toolchain.

Validation:

- The release-pipeline check passes through both its native macOS path and a simulated Linux path that has no `xcrun`.
- `make check` passes, and all 732 test selections pass across 61 groups without failures or retries.

### `deployment`: containerized AgentMicro landing page

Changes:

- Added an isolated Nginx container definition for the AgentMicro landing page.
- Bound the container only to the server loopback interface so the host reverse proxy remains the single public ingress point.
- Packaged the exact landing page, logo, and product screenshot that the page references; no application telemetry or runtime service is introduced.
- Added the dedicated host Nginx virtual-host template for `agentmicro.cc`; its upstream is only the AgentMicro container.
- Updated the Product Hunt launch kit to use the live canonical product URL.

Impact:

- `agentmicro.cc` can be deployed independently of the existing CodexBar documentation site and its domain configuration.

Validation:

- Validated the Compose configuration locally before publishing.
- Built and started the production container on the server; it is reachable only at `127.0.0.1:8089`.
- Added the Cloudflare-proxied apex DNS record, validated the dedicated host proxy, and issued the independent `agentmicro.cc` Let's Encrypt certificate.
- Verified public HTTP redirects to HTTPS, the public homepage and both required image assets return `200`, and the server renewal timer is enabled and active.

Known limitations:

- The `www` hostname is not configured yet; the published canonical URL is `https://agentmicro.cc`.

## Future Entry Template

```markdown
## YYYY-MM-DD

### `implementation`: concise change title

Changes:

- ...

Impact:

- ...

Validation:

- ...

Known limitations:

- ...
```
