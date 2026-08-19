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
- Local Codex session and process discovery, with bounded directory scanning plus database-indexed recovery of recently updated rollouts from old creation-date directories.
- Candidate-first process parsing and reusable append-safe rollout-header metadata caching; AgentMicro selects the
  Codex-only provider scope before session correlation while the shared scanner retains its multi-provider default.
- Launch at login and application-level language overrides.
- Sparkle framework integration and nested signing patterns.
- A channel-specific distribution seam: Developer ID packages keep Sparkle and bounded process correlation, while
  the Mac App Store target removes Sparkle, disables process-tool launches, persists a user-selected read-only Codex
  folder bookmark, and signs with sandbox entitlements from its distribution profile.
- A CodexBar-style settings sidebar and native macOS visual hierarchy.
- The CodexBar `UsageFetcher`, `UsageSnapshot.secondary`, `UsagePace`, and quota-warning thresholds for a throttled,
  read-only weekly Codex quota card in the direct-download menu.
- A new shared `CodexBarUI` library target containing the usage metric view and progress/pace/warning marker renderer;
  both the CodexBar weekly row and AgentMicro card import this target instead of maintaining duplicate UI logic.

AgentMicro-specific work:

- A separate five-state task model instead of CodexBar’s `active`/`idle` session state.
- Incremental Codex rollout reduction, current-turn timing, and explicit user-handoff detection.
- Desktop unread-thread synchronization and optional read-only Accessibility evidence for exact visible selection, approval controls, and blocking error dialogs.
- Tri-state Codex archive metadata that excludes archived threads before guardian recovery while bounding unknown state.
- A 310-point task menu and six-slot status icon whose snake-ordered animation covers running and attention states.
- A native header search interaction that immediately matches project/task metadata and asynchronously searches a
  bounded, transient cache of user/assistant text from already observed Codex rollouts. The AppKit field editor is
  retained during result/usage refreshes, defers queries while an input method has marked text, and applies an
  AgentMicro-specific relevance rank before normal task priority. Its transcript parser admits only user/assistant
  message roles and gates short conversation queries while leaving metadata search immediate.
- A direct-download-only `/bin/ps` sampler that totals correlated CLI root processes and descendants while the menu is
  open. Desktop CPU remains explicitly shared because neither CodexBar nor Codex exposes per-thread attribution.
- Event-driven refresh with non-overlapping safety polls, content-fingerprinted menu rebuilds, cached animation state,
  and throttled selective Accessibility label reads.
- A first-launch five-color guide.
- A separate bundle identity, version source, appcast, Ed25519 key, GitHub Release, and adaptive six-layer Icon Composer application icon.
- App Store privacy-manifest, provisioning-profile, installer-signing, validation, and upload automation without
  changing the direct-download release chain.

Except for the direct-download Codex weekly quota pipeline and shared metric UI, inherited provider implementations remain in the
repository baseline and are not connected to the AgentMicro product surface.

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
- A styled drag-to-Applications DMG assembled and notarized in GitHub Actions.

Limits:

- It focuses on historical management rather than a reliable live state machine.
- Tauri/React is not appropriate as a dependency of the native menu bar V1.
- Provider and proxy management is outside AgentMicro’s current scope.

Decision: treat history and resume as V1.2 references; do not include provider/proxy features in V1. Reuse the
DMG distribution pattern, but implement it with native macOS tools rather than adding cc-switch's `create-dmg`
dependency.

## token-monitor

Useful capabilities:

- Multi-tool token usage, cost, cache, and history analysis.
- Provider limits, balances, and account switching.
- Local history, export, Electron widgets, Node hub, Cloudflare Worker, and SSE synchronization.

Limits:

- Its active/waiting/missing status describes data-source presence, not task lifecycle.
- Electron should not become an AgentMicro V1 runtime dependency.
- Full usage history and multi-device support would obscure the focused task product.

Decision: use CodexBar's native Codex fetcher for the compact shipped weekly summary; consider token-monitor's deeper
history ideas in V2.5 and the Agent/Hub/SSE protocol in V3.

## State-Synchronization References

- **Codex Micro official documentation** defines green as a completed chat with an unread update, makes selection pulse in the existing status color, and offers recent, pinned, priority, and custom assignment modes.
- **freemicro's vendor-build research** confirms a selected-and-focused unread override to idle and documents the factory state precedence and lighting parameters. FreeMicro itself cannot observe Codex Desktop selection, so its own implementation falls back to a 180-second completion TTL; AgentMicro does not treat a timeout as read.
- **opendeck** observes only sessions it creates through `codex exec --json`; it does not solve unread synchronization for existing Desktop tasks.
- **abtop** models lifecycle but not unread/read state.

AgentMicro reads Codex Desktop’s locally persisted unread-thread ID set as the best available general Desktop completion source. Because this is not a public API, parsing is narrow and fail-safe: missing or malformed data never means “everything has been read.” Exact, explicit AgentMicro navigation is higher-confidence evidence for the viewed completion and overrides a stale upstream unread bit until newer activity arrives.

An optional Enhanced Status Detection setting adds a narrow local Accessibility reader. It only runs after explicit opt-in, while Codex is focused, and only accepts a unique task-title match. Paired visible approval/rejection controls may promote that task to needs-input, and visible blocking error dialogs may promote it to error. This is a best-effort supplement, not a runtime dependency or an upstream contract; the default reducer remains complete without Accessibility permission.

The complete evidence model is maintained in [Codex Micro Functional Model](CODEX_MICRO_REFERENCE.md).

## Recommended Composition

```text
Codex process + rollout
        ↓
CodexBar directory + local thread-index discovery
        ↓
abtop-informed state reducer
        ↓
AgentMicro task model
        ↓
native menu + Codex focus
```

Future stages may separately learn from cc-switch history/resume and token-monitor history/sync.

## Licensing

The referenced projects use MIT-family licensing. Reused source must retain copyright, license, and attribution notices. Third-party work must not be presented as original AgentMicro work.
