# Contributing to AgentMicro

Thank you for helping improve AgentMicro. Focused issues and pull requests are
welcome.

## Before opening an issue

- Search existing issues first.
- Confirm the behavior on the latest `main` build when practical.
- Describe the Codex surface involved: Desktop or CLI.
- Include macOS and AgentMicro versions.
- Provide a minimal event sequence and expected versus actual state.
- Redact task titles, usernames, local paths, prompts, source code, command
  output, credentials, and session identifiers.

Do not upload real rollout files. Build the smallest synthetic fixture that
reproduces the behavior instead.

## Pull requests

1. Keep a change focused on one behavior or maintenance goal.
2. Add or update tests for state, lifecycle, sorting, settings, or localization
   changes.
3. Update the relevant files under `docs/agentmicro` when product behavior or
   scope changes.
4. Do not add a dependency or new tool without discussing it in an issue first.
5. Preserve the local-first, read-only V1 privacy boundary.

Run before opening a pull request:

```bash
make check
make test
```

For a quicker AgentMicro-focused loop:

```bash
AGENTMICRO_BUILD_ONLY=1 swift test \
  --disable-automatic-resolution \
  --filter AgentMicro
```

Commit messages use Conventional Commits:

```text
fix(agentmicro): keep active tasks above unread results
feat(agentmicro): add a localized task-state label
docs(agentmicro): clarify local session privacy
```

## Translations

The English localization is the key source. Every locale must contain the same
key set, and user-facing state language should preserve the five public task
semantics. Run `make check` after editing localization files.

## Upstream changes

AgentMicro is derived from CodexBar. Keep upstream attribution intact, avoid
presenting inherited work as AgentMicro-original, and mention relevant CodexBar
issues or commits when porting an upstream fix.

