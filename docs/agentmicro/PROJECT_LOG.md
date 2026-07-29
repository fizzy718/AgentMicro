# AgentMicro Project Change Log

This log records the durable product and engineering decisions needed by international contributors.

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
