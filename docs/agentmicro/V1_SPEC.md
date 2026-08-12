# AgentMicro V1 Specification

## Version Name

Codex Task Pulse

## Goal

Give macOS users an honest, glanceable view of concurrent Codex task state and a fast path back to the correct Desktop conversation, without uploading task content or controlling Codex.

## Supported Scope

### Required

- Codex Desktop sessions with local rollout data.
- Codex CLI sessions discovered from known process and session locations.
- Multiple concurrent tasks, including tasks in the same project.
- macOS 14 or later on Apple Silicon and Intel.

### Best Effort

- IDE-launched Codex CLI processes.
- CLI sessions with ambiguous PID ownership.
- Local Codex metadata formats that are not documented public APIs.

The direct-download edition may use bounded `ps`/`lsof` correlation for CLI ownership. The Mac App Store edition does
not launch those tools inside its sandbox; it observes Desktop and CLI rollout files under a user-authorized Codex
data folder. Consequently, file-backed state remains available while live PID ownership and CLI terminal routing are
not promised in the store edition.

### Excluded

- Claude, OpenCode, and other agents.
- Per-task token accounting, spend history, and multiple-account management.
- Task approval, answering, stopping, retrying, or resuming from AgentMicro.
- Remote synchronization and transcript browsing.

## Task Identity

A visible task is an observed Codex session, identified by host and session ID. Desktop tasks may have no independent PID; rollout lifecycle is authoritative enough to keep them visible. AgentMicro does not assign a generic app-server PID to every Desktop task.

Codex keeps a resumed conversation's rollout in its original creation-date directory. AgentMicro therefore combines bounded current-date directory discovery with recently updated, unarchived `rollout_path` entries from Codex's local thread database. Database timestamps select candidates only; the rollout file timestamp and structured events remain authoritative for retention and task state. Indexed paths must resolve to regular `rollout-*.jsonl` files inside the active `CODEX_HOME/sessions` tree. Duplicate directory and database candidates collapse to one session.

Normal subagents are hidden. A guardian/subagent may only help recover a still-active parent rollout and is not shown as its own user task.

Codex thread archive state is `active`, `archived`, or `unknown`. Active threads remain eligible for the normal task-retention rules, archived threads are excluded before guardian recovery and state reduction, and unknown state is retained for at most two hours. A guardian can recover only a readable parent rollout outside `archived_sessions`; AgentMicro never scans `archived_sessions` as a task source.

When multiple CLI processes share a directory and ownership is ambiguous, AgentMicro keeps rollout tasks separate but does not guess which PID belongs to which task.

## Visible State Model

| State | Color | Meaning |
| --- | --- | --- |
| Idle | `#FFFFFF` | The task exists but has no active work. |
| Unread | `#9BF396` | A new completed result has not been viewed. |
| Thinking | `#9CD5FE` | The current turn is actively running. |
| Needs input | `#FFD0B8` | Codex is blocked on approval, an answer, or an interactive browser action. |
| Error | `#FF7373` | The current turn failed or reached a blocking error. |

`unknown` is allowed internally when evidence is incomplete, but it uses the idle presentation instead of introducing a sixth color.

## State Reduction

- Explicit turn start, active reasoning, pending tool calls, and tool execution can keep a task thinking.
- Tool output closes its matching tool call even when unrelated malformed lines appear.
- A final answer ends the active turn immediately.
- A rate-limit, structured failure event, unresolved terminal tool failure, or explicit failed final answer enters error when it blocks the turn. Recovered warnings and user interruption do not.
- An explicit approval request, structured question tool, direct question, or required browser handoff enters needs-input.
- Merely mentioning a browser or a possible action is not enough.
- Needs-input remains latched until the user resumes the task.
- A recent file modification timestamp alone is not proof of thinking.
- Partial JSONL lines are held until complete; truncation resets the incremental cursor.
- Initial scans of large rollouts start from a bounded complete-line tail and then continue incrementally.

Completed Desktop unread state primarily follows Codex’s locally persisted unread-thread set. A successful exact AgentMicro navigation or, in opt-in Enhanced Status Detection, a uniquely matched selected task in the focused Codex window is stronger, completion-specific read evidence and must not be reversed by a lagging Codex unread bit. Generic application activation, ambiguous labels, and failed navigation do not count as viewing a Desktop task. Newer task activity invalidates the local read marker, allowing the next completion to become green again. If Codex state is missing or malformed, AgentMicro fails closed to local read records; missing data must never be interpreted as an empty unread set.

Enhanced Status Detection is disabled by default and the app must not request Accessibility permission at launch. When explicitly enabled and trusted, it may also promote the uniquely selected task to needs-input for paired visible approval/rejection controls, or error for a visible blocking error dialog. It only reads the focused Codex accessibility tree; it never performs an accessibility action. Missing permission or changing UI labels silently returns observation to the base reducer.

## Titles and Projects

Display modes:

1. Task title and project — default.
2. Task title only.
3. Project name only.

Title resolution prefers explicit Codex metadata and safe fallbacks. The privacy-oriented project-only mode never reveals the task title.

## Current Action

Current action is an internal diagnostic aid derived from bounded rollout events. V1 does not show verbose reasoning or tool payloads in the menu.

## Menu

- Base width follows the compact CodexBar menu, approximately 310 points.
- Header: `AgentMicro — N active` when at least one task is active; otherwise `AgentMicro`.
- Working tasks appear first.
- Within the same activity group, the most recently changed tasks appear first.
- The menu displays the configured 1–20 most recent tasks; default is 6.
- Each row shows:
  - One rounded state block on the left.
  - Task title.
  - Project on the second line when the selected naming mode requires it.
  - Current-turn duration on the right.
  - A lightning badge after the duration when Codex fast mode is enabled.
- There is no separate unread dot on the right.
- Hover highlighting belongs to only one row and text must not become accidentally selected.
- Clicking a Desktop row opens `codex://threads/<session-id>`, with window focus and app activation as fallback.
- Direct-download edition only: a noninteractive weekly Codex usage card appears below the task rows. It uses the
  shared CodexBar usage-metric component and shows consumed percentage, a filled usage bar, localized relative reset
  timing, elapsed-time pace (deficit/reserve/on pace), projected exhaustion or reset survival, and warning/pace
  markers when the source fields are available. Its 13-point semibold title matches task rows; reset and forecast
  metadata use 11-point secondary text. Loading and unavailable states collapse to a single compact row.
- Footer actions: Refresh, Settings, optional Check for Updates, and Quit.

The duration is the current turn’s execution time, not time since last activity. It updates every second while a working task is visible in an open menu. Stopped tasks keep a frozen duration.

## Menu Bar Icon

- Six borderless horizontal rounded rectangles in a 2×3 grid.
- The six blocks mirror the same first six tasks shown by menu ordering, even if the menu limit is greater.
- Empty slots use a neutral system color.
- Each block uses the same state-color source as its menu row.
- Task slots follow menu order from left to right across the top row, then right to left across the bottom row.
- Thinking, unread, needs-input, and error blocks breathe one at a time in task order because they indicate activity or require attention.
- Idle, unknown, and empty blocks remain static. Reduce Motion disables all icon animation.
- No numeric badge is attached to the icon.

## Application Icon

- Independent AgentMicro branding; no CodexBar brand asset is reused.
- A light cool-gray background in the default appearance, with a system-rendered dark background in Dark Mode.
- A 2×3 grid of horizontal rounded rectangles using only the five official state colors.
- Each rectangle is an independent vector layer in the Icon Composer document.
- Xcode's asset compiler produces an `Assets.car` containing Aqua, Dark Aqua, and tintable six-layer icon groups.
- macOS derives Clear and Tinted appearances from the tintable group.
- The package also includes an ICNS fallback for macOS 14+ compatibility.

## Return to Task

Desktop deep links are preferred because they identify the exact thread. If the deep link cannot be opened, AgentMicro attempts known window matching and application activation. CLI terminal routing remains best effort and must not select an unrelated session.

## Refresh

- Watch known Codex session directories, discovered rollout files, the selected Codex thread database and its active SQLite sidecars, and Desktop unread state.
- Debounce file changes by approximately 200 milliseconds.
- Changes to an already known rollout or Desktop unread state run the incremental reducer without repeating process
  and session discovery. Session-directory and thread-index changes coalesce discovery for up to 2 seconds.
- Use watched changes as the primary refresh path. Poll every 15 seconds as a safety fallback while Codex Desktop is
  running, a task is working, or a task has an independent process; poll every 30 seconds otherwise.
- Opening the menu, clicking a task, and known rollout changes trigger immediate reconciliation plus a bounded burst.
- Weekly quota uses the shared CodexBar `UsageFetcher` against Codex CLI's read-only, untrusted app-server. It loads
  at launch, refreshes on menu open only when the last attempt is at least five minutes old, and refreshes
  unconditionally with the menu Refresh action. A failed fetch keeps task observation operational and shows the
  unavailable state. It is compiled out of the Mac App Store edition because that sandbox cannot launch the CLI.
- Menu duration updates use a separate 1-second text timer and do not rescan sessions.
- Event-triggered scans are coalesced; an event arriving during a scan requests at most one follow-up scan. A safety
  poll that overlaps an existing scan is dropped instead of queuing continuous work.
- AgentMicro filters the process snapshot to Codex candidates before parsing process dates, excludes Claude before
  session correlation, and caches immutable rollout-header metadata across append-only updates.
- The menu bar animation advances through five cached pre-rendered frames per attention slot every 250 milliseconds,
  with timer tolerance for wakeup coalescing. It does not rebuild menu rows, reread local state, or recreate an image
  on every tick.
- The native menu rebuilds only when visible task content changes, when the initial scan completes, or when an explicit
  presentation/settings event requires a rebuild. Duration text remains live while the menu is open.
- Enhanced Status Detection reuses Accessibility evidence for one second and reads labels only from selected,
  button, or alert elements while retaining the existing bounded tree traversal.

## Settings

The settings window uses a native CodexBar-style sidebar in this fixed order:

1. Guide.
2. General.
3. Task Display.
4. Updates.

### Guide

The Guide explains the complete white, green, blue, orange, and red state semantics. It opens automatically on first launch. A bottom-right checkbox labeled “Don’t show this guide on next launch” is checked by default, so the Guide automatically appears only once. If the user clears it, the Guide opens on every later launch. The preference controls only automatic presentation; the Guide always remains in the sidebar.

### General

- Mac App Store edition only: current read-only Codex data-folder authorization and a system folder chooser to grant
  or replace it. The selected folder must contain recognizable Codex session state, and the security-scoped bookmark
  is stored locally.
- Interface language: Follow System by default, or one of 23 languages aligned with CodexBar.
- Launch AgentMicro at login.
- Enhanced Status Detection: disabled by default; enabling it explicitly requests Accessibility permission and explains the read-only scope.
- Local-first privacy explanation.

### Task Display

- Naming mode.
- Task count from 1 to 20, with direct numeric entry and stepper.
- Show recently completed tasks; enabled by default with a fixed 24-hour retention.

### Updates

- Direct-download edition: automatically check for updates is enabled by default, the preference remains editable in
  development builds, manual checking requires a signed updater, and unavailable builds explain missing feed, key,
  or Developer ID signing.
- Mac App Store edition: show `version (build)` and explain that updates are delivered by the Mac App Store; do not
  expose Sparkle preferences or manual feed checks.

Language overrides are stored only in AgentMicro defaults and never modify global `AppleLanguages`. Arabic and Persian use right-to-left layout. Every locale must contain the same key set as English.

## Packaging and Updates

- Produce a universal arm64/x86_64 app.
- Place `CodexBar_AgentMicro.bundle` in `Contents/Resources` and resolve it without `Bundle.module` fatal traps.
- Include the compiled Icon Composer `Assets.car`, `AgentMicro.icns` fallback, and `CFBundleIconName`.
- Direct-download edition: embed Sparkle only in packaged builds and use an AgentMicro-specific bundle ID, feed,
  Ed25519 key, Developer ID signature, and notarization.
- Publish both a ZIP for Sparkle and a styled DMG for direct installation. The DMG places `AgentMicro.app`
  opposite an Applications link, is signed with the same Developer ID identity, and receives its own
  notarization ticket.
- Mac App Store edition: compile without Sparkle, enable App Sandbox and user-selected read-only file access, include
  a privacy manifest, embed the matching distribution provisioning profile, sign with Mac App Distribution, and
  package with Mac Installer Distribution before App Store Connect validation/upload. The sandboxed binary must not
  include or claim the CLI-backed weekly quota surface.
- Development builds remain ad-hoc signed and cannot perform online updates.

## Acceptance Criteria

- Watched local events normally appear within 3 seconds. If an event is missed, the safety poll recovers it within
  15 seconds during active/Desktop operation or 30 seconds while otherwise idle.
- Resuming an unarchived task from any older creation-date directory makes it visible within the normal refresh window; no fixed creation-age lookback applies.
- Two concurrent tasks remain separate and sort correctly.
- A Desktop completion opened through AgentMicro changes from green to white immediately, even if Codex's persisted unread set lags.
- With Enhanced Status Detection enabled and trusted, uniquely selecting a completed task directly in Codex changes that completion from green to white.
- New completion activity after that view becomes green again.
- Questions, approvals, and explicit browser handoffs enter orange and clear only after user continuation.
- Blocking failure events and unresolved terminal failures enter red; interrupted or recovered work does not.
- Base mode remains fully usable without Accessibility permission, and the app never requests it before explicit opt-in.
- Final answers stop blue state without waiting for process exit.
- Working duration advances every second; stopped duration does not.
- The direct-download menu renders the Codex weekly consumed percentage, reset countdown, pace variance, projected
  exhaustion, and quota/pace markers below task rows, clamps only displayed percentages to 0–100%, and keeps
  loading/fetch failures separate from task state.
- The first launch opens the localized Guide with all five colors and the default checked suppression option.
- Every selectable language has a complete catalog.
- Opening the release DMG presents `AgentMicro.app` and an Applications drop target; dragging the app installs
  it in `/Applications`.
- The packaged app launches without a resource crash, shows the adaptive icon, and reports the correct version.
- Signed releases pass code-signing, Gatekeeper, notarization, Sparkle signature, and cross-version update checks.
- The Mac App Store package contains no Sparkle linkage or feed keys, has the expected sandbox entitlements and root
  privacy manifest, and passes App Store Connect processing before review.
- Offline task observation remains functional; weekly quota and update retrieval may be unavailable independently.
