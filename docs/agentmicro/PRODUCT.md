# AgentMicro Product Definition

## Positioning

AgentMicro is a local-first macOS menu bar companion that makes concurrent Codex task state visible and lets the user return to a Desktop task quickly.

## User Problem

People running several Codex tasks at once repeatedly ask:

- Which task is still working?
- Which task has finished with a result I have not seen?
- Which task is blocked on my approval, answer, or browser action?
- Which project owns this task?
- How long has the current turn been running?
- Can I return to the correct Codex conversation without searching?

Codex presents these answers inside its own window. AgentMicro provides a compact, always-available overview without becoming another task manager.

## Core Value

Reduce the cost of monitoring and returning to concurrent Codex work while preserving honest state semantics and local privacy.

## Target Users

- macOS users who run multiple Codex Desktop tasks.
- Developers who mix Codex Desktop and Codex CLI sessions.
- Users who want attention cues without uploading task content to another service.

## Product Principles

### Honest state

Show a state only when local evidence supports it. A stale file timestamp is not sufficient evidence that a task is thinking. Uncertain evidence falls back to idle instead of inventing an extra user-visible color.

Read state is completion-specific evidence, not a permanent task attribute. An explicit view of the current completion outranks a lagging persisted unread bit, while any newer completion invalidates that view.

### Local first

Task observation happens on the user’s Mac. AgentMicro does not require a hosted task backend.

Local observation must also remain lightweight. Known filesystem and database changes drive refreshes; bounded safety
polls exist only to recover missed events and must not keep the scanner continuously busy.

### Read-only first

V1 observes and navigates. It does not approve actions, send answers, stop tasks, or mutate Codex state.

### Menu-bar first

The menu bar icon and compact menu are the primary product surface. Information must remain understandable without opening a dashboard.
The six icon slots preserve menu task order in a two-row snake, and animation identifies tasks that are running or need attention.

### Progressive enhancement

Desktop deep links, unread synchronization, optional Accessibility-backed status detection, and signed updates enhance the experience, but failure of one optional integration must not block task observation.

### Distribution-aware capability

AgentMicro has two release channels with the same read-only task model. The direct-download build can correlate local
Codex processes and updates through its signed Sparkle feed. The Mac App Store build is sandboxed, asks the user to
grant read-only access to the Codex data folder, derives task state from authorized rollout and thread metadata, and
receives updates only from the Mac App Store. Channel-specific platform restrictions must be visible rather than
silently overstating equivalent process or terminal integration.

## Product Boundary

V1 includes:

- Local Codex Desktop and CLI task discovery.
- Dynamic rediscovery of recently active Codex threads when an old conversation is resumed.
- Five visible task states.
- Current-turn duration and fast-mode indication.
- Direct-download per-task CPU level for CLI process trees, with honest shared-CPU labeling for Desktop tasks.
- Project and task naming controls.
- One-click return to Codex Desktop conversations.
- Optional Enhanced Status Detection for a selected Codex task and visible approval/error controls.
- A compact weekly Codex quota card in the direct-download menu, including consumed percentage, reset countdown,
  pace variance, projected exhaustion, and quota markers.
- Header search across project names, task titles, and recent local conversation text for observed tasks.
- Configurable recent task count.
- First-launch color guide and paged settings.
- Launch at login and localization.
- A notarized drag-to-install DMG with signed Sparkle updates, plus a separately sandboxed Mac App Store edition.

V1 excludes:

- Other agent providers.
- Per-task token accounting, spend monitoring, usage history, and multiple-account management.
- Task approval or command execution.
- Remote synchronization.
- Full transcript browsing.
- A hosted account or telemetry service.

## Observed vs. Managed Tasks

An observed task is owned by Codex and read by AgentMicro from bounded local metadata. A managed task would be created or controlled by AgentMicro. V1 supports only observed tasks. Managed tasks require a later product phase with explicit safety and ownership rules.

## Privacy Promise

AgentMicro:

- Reads only known Codex process and local session locations. The Mac App Store edition requires explicit read-only
  folder authorization and does not scan the process table.
- Samples the direct-download process table only while the menu is open and task CPU display is enabled; samples stay
  in memory and are discarded when the menu closes.
- Does not require Full Disk Access.
- Does not require Accessibility permission; Enhanced Status Detection requests it only after the user enables that option.
- Does not read Keychain credentials.
- Does not upload prompts, responses, source code, command output, or session files.
- Searches project names, task titles, and bounded recent prompt/response text only after the user opens search. The
  conversation index is transient in memory, includes only user/assistant messages, excludes system, developer, tool,
  and reasoning content, and never shows matched message text. Conversation matching starts at three Latin characters
  or two Chinese characters; shorter queries still search project and task metadata.
- The direct-download edition may launch Codex CLI's read-only app-server to request the signed-in account's weekly
  quota. Codex may contact OpenAI using its own existing login; AgentMicro does not read or store the credential.
- Otherwise uses network access only for the optional AgentMicro update feed. The Mac App Store edition contains
  neither the updater nor the CLI-backed quota surface.
- Offers a project-only display mode for shared-screen privacy.
- When Enhanced Status Detection is enabled, reads visible Codex accessibility labels locally and never clicks, types, approves, or sends content.

## V1 Success Criteria

- A user can distinguish idle, unread, thinking, needs-input, and error states at a glance.
- Working tasks appear first, followed by the most recently changed tasks.
- Resuming an unarchived task from an older creation-date directory makes it visible without restarting AgentMicro.
- Normal idle operation does not continuously scan the process table, rollout headers, menu model, or Accessibility
  tree; safety scans remain bounded and non-overlapping.
- Thinking, unread, needs-input, and error blocks animate in the menu bar icon, following its two-row task order; idle blocks remain static.
- A Desktop task opens the correct Codex conversation with one click.
- Current-turn durations update once per second while the menu is open.
- Direct-download CLI rows show a smoothed CPU level for the task process and its descendants; Desktop rows never
  claim per-conversation attribution and instead say that CPU is shared.
- The direct-download menu shows weekly Codex quota consumption, reset timing, pace against elapsed time, projected
  exhaustion, and warning markers below the task rows without displacing the task-focused surface.
- A user can turn the menu header into a search field, match a project name, task title, or recent conversation text,
  and open the corresponding Codex conversation without AgentMicro displaying the matched message text. Search stays
  focused through background refreshes, accepts composed text from macOS input methods, and places the strongest
  title/project matches before conversation-only matches.
- The first launch explains every color and does not reopen the guide by default.
- Task observation and navigation work offline; weekly quota and software updates degrade independently when their
  upstream services are unavailable.
- Signed direct releases install from a drag-to-Applications DMG and update independently from CodexBar.
- The sandboxed edition can be signed, packaged, and submitted through App Store Connect without Sparkle.
