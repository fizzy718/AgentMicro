# GitHub Growth Playbook

This is the public-distribution checklist for AgentMicro. Keep every claim within
the current V1 boundary: AgentMicro observes local Codex task state and opens
the matching Desktop task; it does not control tasks, approve actions, or upload
task data.

## Repository positioning

Use this repository description:

> A local-first macOS menu bar app for monitoring multiple Codex tasks in real time.

Apply these GitHub topics:

`openai-codex`, `codex`, `macos`, `menu-bar`, `developer-tools`, `swiftui`,
`ai-agent`, `agent-monitoring`, `productivity`, `local-first`, `open-source`.

Keep Discussions enabled. Send questions, feature ideas, task-state reports, and
release feedback there; reserve Issues for reproducible bugs and well-scoped
implementation work.

## Release-note template

Start each release with a user-facing result, then provide exact changes and
upgrade guidance. Do not use the commit log as the opening paragraph.

```md
## [Version] — [user-facing outcome]

AgentMicro can now [plain-language benefit for concurrent Codex users].

### Highlights

- [What changed and who benefits]
- [What changed and who benefits]

### Install or update

Download the signed and notarized DMG below, move AgentMicro to Applications,
then launch it. Existing release builds can also update from Settings.

### Feedback

Tell us what you observe in [GitHub Discussions](https://github.com/fizzy718/AgentMicro/discussions).
For reproducible state mismatches, use the task-state issue form and omit prompts,
source code, credentials, and real task names.
```

## Directory-submission pitch

Use this short description for relevant macOS menu-bar, OpenAI Codex, AI coding
tool, developer-productivity, SwiftUI, and local-first open-source directories.

> **AgentMicro** — A local-first macOS menu-bar companion that shows the live
> status of parallel Codex Desktop and CLI tasks. See thinking, unread results,
> input requests, errors, and idle tasks at a glance, then return to the matching
> Codex Desktop conversation in one click. No prompts, code, or task history leave
> your Mac.

Before submitting, check the directory's contribution rules, choose one relevant
category, and make a small focused pull request. Do not submit to directories
whose scope would imply that AgentMicro controls agents or works outside macOS.

### Qualified targets

These are the two current, high-fit targets. Submit one focused pull request to
each after the next signed release and final demo asset are public.

| Directory | Placement | Proposed entry |
| --- | --- | --- |
| [`phmullins/awesome-macos`](https://github.com/phmullins/awesome-macos) | `Menubar Applications` | `* [AgentMicro](https://github.com/fizzy718/AgentMicro) - Local-first macOS menu bar companion for monitoring multiple Codex tasks in real time.` |
| [`RoggeOhta/awesome-codex-cli`](https://github.com/RoggeOhta/awesome-codex-cli) | `GUI & Desktop Apps` | `- [AgentMicro](https://github.com/fizzy718/AgentMicro) — Local-first macOS menu bar companion for live status across parallel Codex Desktop and CLI tasks; jump back to the matching Desktop conversation in one click. ![GitHub stars](https://img.shields.io/github/stars/fizzy718/AgentMicro?style=flat-square)` |

Do not submit AgentMicro to workflow, plugin, or generic agent lists merely
because it reads Codex state. Its product promise is observation, not task
orchestration or control.

## Demo asset requirement

The repository should eventually have a 8–15 second, silent, final-release GIF:

1. Show two or more generic Codex tasks running.
2. Open AgentMicro to show working, unread, and input-needed states.
3. Click a task and land in its exact Codex Desktop conversation.
4. End on the local-first / read-only setting.

Record from a dedicated demo profile with fictitious project and task names.
Never replace this with an animated static screenshot or capture real task data.
