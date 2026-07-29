# AgentMicro Capability Map

## Conclusion

Four local projects informed AgentMicro at different layers:

| Project | Stack | Strongest capability | Role in AgentMicro |
| --- | --- | --- | --- |
| AgentMicro / CodexBar | Swift, AppKit, SwiftUI | Native menu bar and macOS integration | V1 application foundation |
| abtop | Rust, ratatui | Live task state and process correlation | State-reducer reference |
| cc-switch | Tauri, Rust, React | Session recovery and provider management | Future history/resume reference |
| token-monitor | Electron, Node.js | Usage, limits, history, and multi-device sync | Future data/sync reference |

These projects are references, not automatically enabled AgentMicro providers.

## AgentMicro / CodexBar

Capabilities reused or adapted:

- macOS menu bar lifecycle, native menu presentation, and window activation.
- Local Codex session and process discovery.
- Launch at login and application-level language overrides.
- Sparkle framework integration and nested signing patterns.
- A CodexBar-style settings sidebar and native macOS visual hierarchy.

AgentMicro-specific work:

- A separate five-state task model instead of CodexBar’s `active`/`idle` session state.
- Incremental Codex rollout reduction, current-turn timing, and explicit user-handoff detection.
- Desktop unread-thread synchronization.
- A 310-point task menu and six-slot animated status icon.
- A first-launch five-color guide.
- A separate bundle identity, version source, appcast, Ed25519 key, GitHub Release, and adaptive six-layer Icon Composer application icon.

The inherited provider implementations remain in the repository baseline but are not connected to the AgentMicro product surface.

## abtop

Useful capabilities:

- Codex CLI/Desktop task discovery.
- Incremental rollout semantics and tool-call/output pairing.
- Thinking, executing, waiting, rate-limited, done, and unknown lifecycle ideas.
- Current action, model, token, process, terminal, and host information.

Limits:

- Heuristic local state is not an authoritative Codex Desktop API.
- Waiting does not reliably mean approval is required.
- It has no Desktop unread/read model.
- A Rust sidecar would complicate the V1 package and signature.

Decision: port the reducer ideas and fixture strategy, but do not add abtop as a runtime dependency.

## cc-switch

Useful capabilities:

- Codex title, state database, session index, and archived-session parsing.
- Session search, grouping, details, deletion, and resume commands.
- Terminal launchers and multi-provider management.

Limits:

- It focuses on historical management rather than a reliable live state machine.
- Tauri/React is not appropriate as a dependency of the native menu bar V1.
- Provider and proxy management is outside AgentMicro’s current scope.

Decision: treat history and resume as V1.2 references; do not include provider/proxy features in V1.

## token-monitor

Useful capabilities:

- Multi-tool token usage, cost, cache, and history analysis.
- Provider limits, balances, and account switching.
- Local history, export, Electron widgets, Node hub, Cloudflare Worker, and SSE synchronization.

Limits:

- Its active/waiting/missing status describes data-source presence, not task lifecycle.
- Electron should not become an AgentMicro V1 runtime dependency.
- Usage and multi-device support would obscure the focused task product.

Decision: consider usage in V2.5 and the Agent/Hub/SSE protocol in V3.

## State-Synchronization References

- **freemicro** has no viewed-thread signal and lets completed state expire after a default 180-second TTL. AgentMicro does not treat a timeout as read.
- **opendeck** observes only sessions it creates through `codex exec --json`; it does not solve unread synchronization for existing Desktop tasks.
- **abtop** models lifecycle but not unread/read state.

AgentMicro reads Codex Desktop’s locally persisted unread-thread ID set as the best available Desktop completion source. Because this is not a public API, parsing is narrow and fail-safe: missing or malformed data never means “everything has been read.”

## Recommended Composition

```text
Codex process + rollout
        ↓
CodexBar discovery
        ↓
abtop-informed state reducer
        ↓
AgentMicro task model
        ↓
native menu + Codex focus
```

Future stages may separately learn from cc-switch history/resume and token-monitor usage/sync.

## Licensing

The referenced projects use MIT-family licensing. Reused source must retain copyright, license, and attribution notices. Third-party work must not be presented as original AgentMicro work.
