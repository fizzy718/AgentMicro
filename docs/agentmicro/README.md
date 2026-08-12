# AgentMicro Product Documentation

This directory is the product and engineering source of truth for AgentMicro. The public overview lives in the repository [README](../../README.md).

## Documents

- [Product definition](PRODUCT.md): audience, problem, principles, privacy, and V1 success criteria.
- [V1 specification](V1_SPEC.md): supported task model, state reduction, menu behavior, settings, and acceptance criteria.
- [Codex Micro functional model](CODEX_MICRO_REFERENCE.md): official behavior, observed implementation details, evidence levels, and AgentMicro implications.
- [Roadmap](ROADMAP.md): completed V1 milestones and explicitly gated future stages.
- [Capability map](CAPABILITY_MAP.md): what is reused from CodexBar and what was learned from neighboring projects.
- [Backlog](BACKLOG.md): deferred ideas with entry conditions.
- [Release guide](RELEASING.md): direct-download and Mac App Store signing, packaging, and publication.
- [Product Hunt launch kit](product-hunt-launch.md): public listing copy, gallery brief, demo script, Maker Comment, and launch-day replies.
- [Demo capture guide](demo-capture.md): exact macOS recording steps for the public product GIF.
- [GitHub growth playbook](github-growth.md): repository, release, discussion, and directory-submission copy.
- [Project log](PROJECT_LOG.md): durable record of product, architecture, implementation, documentation, and release changes.

## Current Product

AgentMicro is a local-first macOS menu bar companion for observing multiple Codex Desktop and CLI tasks. It is derived from CodexBar but has a separate product boundary, application identity, release feed, and task-state model.

The menu shows the most recently changed tasks, with working tasks first. Each row contains a state block, task title, project, current-turn duration, and an optional fast-mode lightning badge. In the direct-download edition, a compact weekly Codex quota card sits below the task rows and shows consumed percentage, reset timing, pace variance, projected exhaustion, and quota markers. The menu bar icon mirrors the first six rows as a 2×3 grid of horizontal rounded rectangles. Slots follow task order left to right across the top and right to left across the bottom; thinking, unread, needs-input, and error blocks breathe while idle blocks remain static.

The five user-visible colors are:

| Color | State | Meaning |
| --- | --- | --- |
| White | Idle | The agent exists but has no active work. |
| Green | Unread | A new result is ready and has not been viewed. |
| Blue | Thinking | Codex is actively processing the task. |
| Orange | Needs input | Codex waits for approval, an answer, or an interactive browser step. |
| Red | Error | The current turn failed or hit a blocking error. |

Settings use a CodexBar-style sidebar with Guide, General, Task Display, and Updates pages. The Guide is opened automatically on first launch, explains all five colors, and includes a checked-by-default “Don’t show this guide on next launch” checkbox. All AgentMicro UI copy is available in the same 23 interface languages exposed by CodexBar.

AgentMicro reads known local Codex process and session metadata. Current-date directory discovery is supplemented by recently updated, unarchived rollout paths from Codex's local thread database, so resuming an old conversation is detected without scanning every historical directory. Optional Enhanced Status Detection can use macOS Accessibility, only after explicit opt-in, to recognize the uniquely selected Codex task and visible approval/error controls. Base mode never requires that permission, and the enhanced reader does not click or type. AgentMicro does not upload task titles, prompts, responses, source code, command output, or session files.

The direct-download edition uses bounded process correlation, AgentMicro's signed Sparkle feed, CodexBar's read-only
Codex CLI app-server fetcher, shared pace/threshold calculations, and the shared `CodexBarUI` usage-metric view for
the weekly quota card. AgentMicro does not read or store the Codex login.
The Mac App Store edition is sandboxed, obtains persistent read-only access only after the user selects the Codex data
folder, skips process-table and CLI launches, omits the quota card, and receives updates from the store. Both editions
use the same rollout state reducer.

Refresh is event-driven for known rollout, session-directory, unread-state, and thread-database changes. Non-overlapping
15-second active and 30-second idle safety scans recover missed events. Process candidates, rollout headers, menu
content, animation state, and optional Accessibility evidence are filtered, cached, or throttled so the menu bar app
does not continuously redo unchanged work. Known rollout writes use incremental reduction; only new-session directory
or thread-index events schedule a coalesced discovery scan.

Explicitly archived Codex threads are removed from the current task menu. Unknown archive metadata is tolerated for up to two hours, while orphaned guardian records are not presented as user tasks.

Direct releases publish a notarized drag-to-Applications DMG and retain the Ed25519-signed ZIP for Sparkle. The App
Store pipeline produces a separately provisioned and sandboxed signed installer package without Sparkle.

## Development

```bash
AGENTMICRO_BUILD_ONLY=1 swift test \
  --disable-automatic-resolution \
  --filter AgentMicro

make check
make test
./Scripts/package_agentmicro.sh debug
AGENTMICRO_APP_STORE=1 AGENTMICRO_SIGNING=adhoc ARCHES=arm64 \
  ./Scripts/package_agentmicro.sh debug
```

Every packaged app must contain the localization bundle, privacy manifest, layered Icon Composer assets, ICNS
fallback, version metadata, and a valid signature. Only the direct-download package contains Sparkle.

## Documentation Maintenance

Every completed change must update the documents affected by the decision:

- Product behavior or scope: `PRODUCT.md`, `V1_SPEC.md`, or `ROADMAP.md`.
- Architecture or implementation constraints: `CAPABILITY_MAP.md` or `V1_SPEC.md`.
- Deferred ideas: `BACKLOG.md`.
- Release process: `RELEASING.md`.
- Every material change: `PROJECT_LOG.md`.

Maintain these internal documents in English. The repository root `README.zh-CN.md` is the only Chinese document maintained for readers. Do not record speculative work as shipped behavior.
