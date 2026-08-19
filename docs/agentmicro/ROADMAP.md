# AgentMicro Product Roadmap

Roadmap stages are gated by explicit entry conditions. A later-stage idea is not a shipped feature.

## V1 — Codex Task Pulse

Status: complete, with the latest task-surface improvements prepared for `0.1.5`.

Delivered:

- Independent macOS menu bar application.
- Codex Desktop and CLI session discovery, including database-indexed rediscovery when old conversations resume.
- Event-driven observation with non-overlapping 15/30-second safety scans, Codex-only process filtering, rollout
  metadata caching, and bounded UI/Accessibility refresh work.
- Incremental rollout reduction with structured/user-handoff and terminal-failure classification.
- Five visible states: idle, unread, thinking, needs input, and error.
- Working-first, recent-state-change ordering.
- Configurable 1–20 task menu and fixed six-slot menu bar icon with smooth, attention-aware, task-ordered animation.
- Header search over project names, task titles, and bounded recent local conversation text before the configured limit.
- Direct-download weekly Codex quota card below the task list, backed by CodexBar's read-only CLI app-server fetcher,
  pace/threshold calculations, and shared usage-metric UI.
- Project/title display modes, second-level current-turn duration, and fast-mode badge.
- Direct-download CLI process-tree CPU levels while the menu is open, with explicit shared attribution for Desktop.
- Desktop unread synchronization, explicit-view closure, optional Enhanced Status Detection, and one-click thread deep links.
- CodexBar-style paged settings and first-launch five-color guide.
- System language plus 23 selectable languages.
- Adaptive six-layer Icon Composer application icon with Default, Dark, Clear, and Tinted appearances.
- Launch at login, a notarized drag-to-Applications DMG, and independent signed Sparkle updates.
- A sandboxed Mac App Store variant with explicit read-only Codex-folder authorization and store-delivered updates.

### V1 Milestones

| Milestone | Status | Exit condition |
| --- | --- | --- |
| M0 — Runnable slice | Complete | Independent app builds, discovers sessions, and opens a stable menu. |
| M1 — Task State Engine | Complete | Fixtures cover lifecycle, partial lines, truncation, malformed JSONL, and tool pairing. |
| M2 — Productized menu | Complete | Menu, paged settings, onboarding, localization, icon, packaging, and updater tests pass. |
| M3 — Real scenarios | Complete | Concurrent Desktop and CLI tasks remain independently visible and navigable. |
| M3.1 — Runtime efficiency | Complete | Idle work is event-driven, fallback scans do not overlap, and hot UI paths reuse unchanged state. |
| M4 — Release hardening | In progress | A notarized DMG installs cleanly, and an older signed build completes a Sparkle update to a newer build. |
| M5 — Mac App Store | In progress | A distribution-signed universal package passes App Store Connect processing and App Review with accurate sandbox limitations and metadata. |

## V1.1 — Attention Signals

Entry condition: V1 state semantics are stable enough that notifications do not amplify false positives.

Candidates:

- Optional notification when a task first enters needs-input, error, or unread.
- Per-state notification controls.
- Quiet hours and duplicate suppression.
- Accessibility announcements that share the same state reducer.

## V1.2 — History and Resume

Entry condition: a bounded local index can be maintained without retaining sensitive transcript content.

Candidates:

- Recent task history grouped by project.
- Persisted-history search over title, project, state, and timestamps; live observed-task conversation search remains
  transient and does not expand into retained transcript indexing.
- Resume/open actions for known Desktop tasks.
- Clear retention controls.

## V2 — Managed Tasks

Entry condition: Codex exposes a stable, supported control surface with explicit ownership and approval semantics.

Candidates:

- Start a task from AgentMicro.
- Stop, retry, or continue a managed task.
- Safe approval handoff.

V2 must not infer control authority from read-only rollout files.

## V2.5 — Advanced Usage and Limits

Entry condition: usage data can be added without obscuring the task-focused product.

Candidates:

- Optional session-window and model-specific limit details beyond the shipped weekly summary.
- Local token/cost history with explicit retention and estimation labels.
- Reuse of proven CodexBar provider infrastructure behind a separate view.
- No provider claims until the provider is actually wired to AgentMicro.

## V3 — Multi-device and Companion

Entry condition: the product has a clear trust, encryption, and account model.

Candidates:

- End-to-end encrypted state synchronization.
- Mobile or web companion.
- Explicit device ownership and revocation.

## Guardrails

- Do not trade state honesty for animation.
- Do not upload task content to simplify synchronization.
- Do not expand to other agents before Codex behavior is reliable.
- Do not add task control without a supported upstream API.
- Keep AgentMicro release identity, feed, and assets separate from CodexBar.
- Keep direct and App Store update mechanisms mutually exclusive in their packaged binaries.
