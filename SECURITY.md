# Security policy

## Supported versions

Before the first signed release, only the latest commit on `main` is supported.
After releases begin, the latest published version and `main` receive security
fixes.

## Reporting a vulnerability

Please use GitHub's private vulnerability reporting for this repository:

<https://github.com/fizzy718/AgentMicro/security/advisories/new>

Do not disclose a vulnerability in a public issue until a fix is available.
Include the affected version, impact, reproduction steps, and any suggested
mitigation. Do not include real Codex prompts, source code, credentials, or
unredacted session files.

## Security boundaries

AgentMicro reads bounded local Codex process and session metadata to derive task
state. It does not intentionally upload task data, read the Keychain, or request
Full Disk Access. The optional updater is expected to accept only
Developer ID-signed, Apple-notarized releases whose archives pass the dedicated
AgentMicro Ed25519 signature check.

Reports that show a violation of those boundaries are treated as security
issues.

