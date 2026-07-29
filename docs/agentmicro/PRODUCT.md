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

### Read-only first

V1 observes and navigates. It does not approve actions, send answers, stop tasks, or mutate Codex state.

### Menu-bar first

The menu bar icon and compact menu are the primary product surface. Information must remain understandable without opening a dashboard.

### Progressive enhancement

Desktop deep links, unread synchronization, optional Accessibility-backed status detection, and signed updates enhance the experience, but failure of one optional integration must not block task observation.

## Product Boundary

V1 includes:

- Local Codex Desktop and CLI task discovery.
- Five visible task states.
- Current-turn duration and fast-mode indication.
- Project and task naming controls.
- One-click return to Codex Desktop conversations.
- Optional Enhanced Status Detection for a selected Codex task and visible approval/error controls.
- Configurable recent task count.
- First-launch color guide and paged settings.
- Launch at login, localization, and signed Sparkle updates.

V1 excludes:

- Other agent providers.
- Token, spend, and quota monitoring.
- Task approval or command execution.
- Remote synchronization.
- Full transcript browsing.
- A hosted account or telemetry service.

## Observed vs. Managed Tasks

An observed task is owned by Codex and read by AgentMicro from bounded local metadata. A managed task would be created or controlled by AgentMicro. V1 supports only observed tasks. Managed tasks require a later product phase with explicit safety and ownership rules.

## Privacy Promise

AgentMicro:

- Reads only known Codex process and local session locations.
- Does not require Full Disk Access.
- Does not require Accessibility permission; Enhanced Status Detection requests it only after the user enables that option.
- Does not read Keychain credentials.
- Does not upload prompts, responses, source code, command output, or session files.
- Uses network access only for the optional AgentMicro update feed.
- Offers a project-only display mode for shared-screen privacy.
- When Enhanced Status Detection is enabled, reads visible Codex accessibility labels locally and never clicks, types, approves, or sends content.

## V1 Success Criteria

- A user can distinguish idle, unread, thinking, needs-input, and error states at a glance.
- Working tasks appear first, followed by the most recently changed tasks.
- A Desktop task opens the correct Codex conversation with one click.
- Current-turn durations update once per second while the menu is open.
- The first launch explains every color and does not reopen the guide by default.
- The app works offline except for software updates.
- Signed release builds install, launch, and update independently from CodexBar.
