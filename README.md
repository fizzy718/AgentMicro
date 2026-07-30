<div align="center">

<img src="docs/agentmicro-logo-macos27-light.png" width="128" height="128" alt="AgentMicro logo">

# AgentMicro

### Live Codex task status, in your macOS menu bar

[![CI](https://github.com/fizzy718/AgentMicro/actions/workflows/ci.yml/badge.svg)](https://github.com/fizzy718/AgentMicro/actions/workflows/ci.yml)
[![macOS 14+](https://img.shields.io/badge/macOS-14%2B-0a0a0c?style=flat-square)](https://github.com/fizzy718/AgentMicro)
[![Swift 6.2+](https://img.shields.io/badge/Swift-6.2%2B-f05138?style=flat-square)](https://swift.org)
[![License: MIT](https://img.shields.io/badge/license-MIT-6e5aff?style=flat-square)](LICENSE)

[简体中文](README.zh-CN.md)

</div>

AgentMicro is a small, local-first macOS menu bar companion for people running several Codex tasks at once. It shows which tasks are working, waiting for you, finished with unread results, idle, or in error—and lets you return to a Codex Desktop task with one click.

AgentMicro is an independent, community-maintained project built on the excellent [CodexBar](https://github.com/steipete/CodexBar) codebase. It is not affiliated with or endorsed by OpenAI or the CodexBar maintainers.

## Screenshot

<p align="center">
  <img src="docs/screenshots/agentmicro-menu.png" width="420" alt="AgentMicro menu showing live Codex tasks, status colors, projects, durations, and fast mode">
</p>

How to read the menu:

- Running tasks stay at the top; the header shows the active count.
- The rounded block on the left uses the five task-state colors described below.
- The value on the right is the current turn duration, not the age of the task.
- A lightning bolt means that Codex fast mode is enabled for that task.

## Why AgentMicro?

- **See the queue without opening Codex.** Running tasks stay at the top, followed by the most recently changed tasks.
- **Understand state at a glance.** The six-tile menu bar icon mirrors the first six tasks and animates while work is in progress.
- **Return quickly.** Click a Codex Desktop task to open the matching conversation.
- **Keep task data local.** AgentMicro reads known local Codex process and session metadata; it does not upload prompts, responses, source code, command output, or task state.

## Task states

AgentMicro uses five visible states:

| Indicator | State | Meaning |
| --- | --- | --- |
| ⬜ | Idle | The task exists but has no current activity. |
| 🟩 | Unread | A new result is ready and has not been viewed. |
| 🟦 | Thinking | Codex is actively processing the task. |
| 🟧 | Needs input | Codex asks you to approve, answer, or complete an interactive step such as browser input. |
| 🟥 | Error | The current turn failed or hit a blocking error. |

Insufficient evidence is represented internally as `unknown`, but displayed as idle rather than introducing a misleading sixth color.

## Features

- Observes local Codex Desktop and Codex CLI tasks.
- Updates from filesystem events with a short fallback polling interval.
- Synchronizes completed Desktop-task unread state with Codex's local state, while explicit AgentMicro navigation immediately closes the viewed result.
- Offers optional Enhanced Status Detection for direct Codex selection and visible approval/error controls; it is off by default and Accessibility permission is never required for base mode.
- Keeps explicit user handoffs orange until the user resumes the task.
- Sorts working tasks first, then by the most recent state change.
- Shows project name, task title, and the current turn duration down to the second.
- Shows a lightning badge when the task uses Codex fast mode.
- Displays 1–20 recent tasks, configurable in Settings.
- Offers task-title, project-only, and combined display modes.
- Uses paged settings with a first-launch guide to all five state colors.
- Supports launch at login and recently completed task retention.
- Follows the macOS language by default, with 23 selectable interface languages.
- Uses an adaptive six-layer application icon with Default, Dark, Clear, and Tinted system appearances.
- Supports an independent Sparkle update feed for signed releases.

## Install

### Requirements

- macOS 14 Sonoma or later
- Codex Desktop or Codex CLI with local sessions

Download the latest signed and notarized build from
[GitHub Releases](https://github.com/fizzy718/AgentMicro/releases/latest). Prefer
the DMG when it is listed: open it, drag `AgentMicro.app` onto the Applications
folder, then launch AgentMicro from `/Applications`. Older releases that provide
only a ZIP can be unzipped and moved to `/Applications` manually. Release builds
check the AgentMicro Sparkle feed for updates automatically; you can also check
manually in Settings.

### Build from source

Building requires Xcode with Swift 6.2 or later:

```bash
git clone https://github.com/fizzy718/AgentMicro.git
cd AgentMicro
make agentmicro-package
open AgentMicro.app
```

For the development loop:

```bash
make agentmicro-start
make agentmicro-stop
```

The local development bundle is ad-hoc signed. Automatic updates are intentionally unavailable in development builds; release builds use a dedicated AgentMicro feed, Developer ID signing, Apple notarization, and an Ed25519 update signature.

## Privacy

AgentMicro is local-first and read-only:

- It reads only known Codex process and local session locations.
- It does not require Full Disk Access.
- It does not read the Keychain.
- It does not send task titles, prompts, responses, source code, command output, or session files to a server.
- The optional software updater requests only the AgentMicro update feed.
- Task titles can still be sensitive on a shared screen; Settings includes a project-only display mode.

## Current scope

AgentMicro V1 focuses on observing and returning to Codex tasks. It does not approve actions, stop or continue tasks, edit Codex state, monitor token quotas, or upload task history.

The repository still contains provider implementations and tests inherited from
the CodexBar baseline. They are not connected to the AgentMicro menu or exposed
as AgentMicro features; V1 is intentionally Codex-only.

Codex does not currently expose a stable public event API for observing every Desktop task transition. AgentMicro therefore derives lifecycle state from bounded local metadata and rollout events, and synchronizes completed Desktop-task unread state from Codex's local unread-thread state. Successfully opening the exact task through AgentMicro is stronger, task-specific view evidence and immediately changes that completion from green to white; newer completion activity can make it green again. Optional Enhanced Status Detection can also recognize a uniquely selected task and visible approval/error controls in the focused Codex window. It is disabled by default, only requests Accessibility permission after explicit opt-in, and never clicks or types. CLI read state still uses AgentMicro's local record. The project prefers an honest idle state over an unsupported guess, but brief differences from the Codex UI may still occur while local files settle.

## Development

The AgentMicro-specific entry point lives in `Sources/AgentMicro`; reusable local-session discovery remains in `Sources/CodexBarCore`.

```bash
# Focused AgentMicro tests
AGENTMICRO_BUILD_ONLY=1 swift test \
  --disable-automatic-resolution \
  --filter AgentMicro

# Repository checks
make check
make test
```

Product decisions and implementation constraints are documented in the
[AgentMicro product docs](docs/agentmicro/README.md). Release signing and
Sparkle setup are documented in the
[AgentMicro release guide](docs/agentmicro/RELEASING.md).
The evidence-backed model of the original hardware and ChatGPT integration lives in the
[Codex Micro functional model](docs/agentmicro/CODEX_MICRO_REFERENCE.md).

## Contributing

Issues, focused pull requests, translations, reproducible state-sync reports, and documentation improvements are welcome. Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a change and [SECURITY.md](SECURITY.md) before reporting a vulnerability.

Never attach real Codex prompts, source code, credentials, or unredacted rollout files to a public issue.

## Community

Join the AgentMicro community to discuss usage, state detection, translations, and development:

- [Telegram discussion group](https://t.me/+844ZOEqapkI5OTBh)
- WeChat group: scan the QR code below.

<p align="center">
  <img src="docs/community/agentmicro-wechat-group.jpg" width="360" alt="QR code for the AgentMicro WeChat community group">
</p>

This invitation QR code is valid through August 5, 2026. WeChat periodically refreshes group invitation codes, so this image may be replaced after it expires.

## Upstream and credits

AgentMicro is derived from [steipete/CodexBar](https://github.com/steipete/CodexBar), created by Peter Steinberger and distributed under the MIT License. It reuses portions of CodexBar's macOS application foundation, local session discovery, localization conventions, and Sparkle integration while developing a separate Codex task-observation product.

The original CodexBar copyright and MIT notice are preserved in [LICENSE](LICENSE). Additional attribution is recorded in [NOTICE.md](NOTICE.md).

## License

MIT. See [LICENSE](LICENSE).
