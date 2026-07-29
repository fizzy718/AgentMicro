# AgentMicro Backlog

Backlog items are not commitments. Each item includes an entry condition so speculative ideas cannot silently become scope.

## Status

- `candidate`: worth exploring after its entry condition is met.
- `deferred`: intentionally outside the current release.
- `blocked`: requires an upstream or infrastructure change.

## Task Observation

| ID | Status | Idea | Entry condition |
| --- | --- | --- | --- |
| AM-101 | candidate | Add stable upstream event transport | Codex publishes a supported task event API. |
| AM-102 | candidate | Improve Desktop window/viewed correlation | A stable, non-private local signal is available. |
| AM-103 | deferred | Show subagents as independent rows | Ownership and user value are defined without duplication. |
| AM-104 | candidate | Add task-state diagnostic export | Export can redact titles, paths, prompts, and payloads by default. |
| AM-105 | candidate | Reduce the remaining brief UI synchronization gap | Reproducible fixtures identify a safe local source of truth. |

## Attention and Notifications

| ID | Status | Idea | Entry condition |
| --- | --- | --- | --- |
| AM-201 | candidate | Notify on needs-input, error, or unread | State false-positive rate is accepted in real use. |
| AM-202 | candidate | Quiet hours and per-state switches | AM-201 ships with stable identity and deduplication. |
| AM-203 | deferred | Sound themes | Accessibility value is demonstrated. |

## History and Recovery

| ID | Status | Idea | Entry condition |
| --- | --- | --- | --- |
| AM-301 | candidate | Local task metadata history | A bounded schema avoids transcript retention. |
| AM-302 | candidate | Search recent task metadata | AM-301 ships with retention controls. |
| AM-303 | blocked | Reliable cross-version resume | Codex provides stable resume/deep-link behavior. |

## Task Management

| ID | Status | Idea | Entry condition |
| --- | --- | --- | --- |
| AM-401 | blocked | Start, stop, retry, or continue tasks | Codex provides a supported control API. |
| AM-402 | blocked | Approve from AgentMicro | Explicit authentication, scope, and audit semantics exist. |

## Usage and Accounts

| ID | Status | Idea | Entry condition |
| --- | --- | --- | --- |
| AM-501 | deferred | Optional Codex quota view | Task observation remains the primary product and the source is stable. |
| AM-502 | deferred | Multiple Codex accounts | Codex account identity is safely observable. |

## Multi-device

| ID | Status | Idea | Entry condition |
| --- | --- | --- | --- |
| AM-601 | blocked | Encrypted task-state synchronization | Trust, key management, and metadata-minimization designs are approved. |
| AM-602 | deferred | Mobile companion | AM-601 exists and the desktop product is stable. |

## Other Agents

| ID | Status | Idea | Entry condition |
| --- | --- | --- | --- |
| AM-701 | deferred | Claude or other agent providers | Codex-only V1 is stable and each provider has an honest state contract. |
| AM-702 | deferred | Provider plugin API | At least two implementations prove a common contract. |

## Distribution

| ID | Status | Idea | Entry condition |
| --- | --- | --- | --- |
| AM-704 | candidate | Homebrew Cask | Signed releases and update continuity are established. |

## New Item Template

```markdown
| AM-NNN | candidate | Short user-facing capability | Observable entry condition |
```
