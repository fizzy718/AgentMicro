# AgentMicro Product Documentation

This directory is the product and engineering source of truth for AgentMicro. The public overview lives in the repository [README](../../README.md).

## Documents

- [Product definition](PRODUCT.md): audience, problem, principles, privacy, and V1 success criteria.
- [V1 specification](V1_SPEC.md): supported task model, state reduction, menu behavior, settings, and acceptance criteria.
- [Codex Micro functional model](CODEX_MICRO_REFERENCE.md): official behavior, observed implementation details, evidence levels, and AgentMicro implications.
- [Roadmap](ROADMAP.md): completed V1 milestones and explicitly gated future stages.
- [Capability map](CAPABILITY_MAP.md): what is reused from CodexBar and what was learned from neighboring projects.
- [Backlog](BACKLOG.md): deferred ideas with entry conditions.
- [Release guide](RELEASING.md): signing, notarization, GitHub Releases, appcast, and Sparkle.
- [Project log](PROJECT_LOG.md): durable record of product, architecture, implementation, documentation, and release changes.

## Current Product

AgentMicro is a local-first macOS menu bar companion for observing multiple Codex Desktop and CLI tasks. It is derived from CodexBar but has a separate product boundary, application identity, release feed, and task-state model.

The menu shows the most recently changed tasks, with working tasks first. Each row contains a state block, task title, project, current-turn duration, and an optional fast-mode lightning badge. The menu bar icon mirrors the first six rows as a 2×3 grid of horizontal rounded rectangles and breathes while work is active.

The five user-visible colors are:

| Color | State | Meaning |
| --- | --- | --- |
| White | Idle | The agent exists but has no active work. |
| Green | Unread | A new result is ready and has not been viewed. |
| Blue | Thinking | Codex is actively processing the task. |
| Orange | Needs input | Codex waits for approval, an answer, or an interactive browser step. |
| Red | Error | The current turn failed or hit a blocking error. |

Settings use a CodexBar-style sidebar with Guide, General, Task Display, and Updates pages. The Guide is opened automatically on first launch, explains all five colors, and includes a checked-by-default “Don’t show this guide on next launch” checkbox. All AgentMicro UI copy is available in the same 23 interface languages exposed by CodexBar.

AgentMicro reads known local Codex process and session metadata. Optional Enhanced Status Detection can use macOS Accessibility, only after explicit opt-in, to recognize the uniquely selected Codex task and visible approval/error controls. Base mode never requires that permission, and the enhanced reader does not click or type. AgentMicro does not upload task titles, prompts, responses, source code, command output, or session files. Software updates use AgentMicro’s own signed Sparkle feed.

Signed releases publish a notarized drag-to-Applications DMG for first installation and retain the Ed25519-signed ZIP as the Sparkle update artifact.

## Development

```bash
AGENTMICRO_BUILD_ONLY=1 swift test \
  --disable-automatic-resolution \
  --filter AgentMicro

make check
make test
./Scripts/package_agentmicro.sh debug
```

The packaged app must contain the AgentMicro localization bundle, layered Icon Composer asset catalog, ICNS compatibility fallback, Sparkle framework, version metadata, and a valid code signature.

## Documentation Maintenance

Every completed change must update the documents affected by the decision:

- Product behavior or scope: `PRODUCT.md`, `V1_SPEC.md`, or `ROADMAP.md`.
- Architecture or implementation constraints: `CAPABILITY_MAP.md` or `V1_SPEC.md`.
- Deferred ideas: `BACKLOG.md`.
- Release process: `RELEASING.md`.
- Every material change: `PROJECT_LOG.md`.

Maintain these internal documents in English. The repository root `README.zh-CN.md` is the only Chinese document maintained for readers. Do not record speculative work as shipped behavior.
