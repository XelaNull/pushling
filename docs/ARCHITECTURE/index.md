<!-- GENERATED — do not hand-edit. Run: node scripts/generate-docs-index.mjs -->

# ARCHITECTURE Index

- [Pushling IPC Command and Action Catalog](ipc-command-catalog.md) — The 15 socket commands, their valid actions, parameters, and response shapes — the raw wire contract underneath the 9 pushling_* MCP tools.
- [Pushling IPC Wire Protocol](ipc-wire-protocol.md) — The NDJSON-over-Unix-socket transport contract between the Pushling daemon and its clients — framing, envelope, error vocabulary, and the implementation constraints both sides must honor.
- [MCP Session Lifecycle](mcp-session-lifecycle.md) — The handshake, single-session enforcement, idle gradient, and clean-vs-abrupt disconnect paths that govern one Claude session's presence in the creature.
- [MCP Tool Contract — the pushling_* Family](mcp-tool-contract.md) — The single merged authority for the 9 pushling_* embodiment tools — verbatim descriptions, parameters, stage gates, degraded-mode behavior, and how each maps onto the 15 socket commands.
- [Pending Events (Proprioception Ring Buffer)](pending-events.md) — The per-session ring buffer of events piggybacked on every IPC response so Claude stays aware of the world without polling.
- [Pushling System Architecture](system-architecture.md) — The four-process topology (daemon, MCP server, git hook, Claude Code hooks), the rendering target, and the on-disk state layout that everything else in the bundle assumes.
