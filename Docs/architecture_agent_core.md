# Agent Core Architecture

**Status:** Scaffold / V1 foundation  
**Runtime:** Independent Python process  
**Language target:** GDScript-first

## Pluggable-bridge rule (locked)

`agent_core/` **must not** import or know about a specific Godot bridge
(e.g. `hi-godot/godot-ai`, `hybridindie/godot-mcp`, or any future backend).

The core only depends on:

- `tools.AbstractGodotTools` — semantic capabilities
- `tools.CapabilityRegistry` — what the connected bridge reports
- local planner / verifier / memory / budgets / state

Concrete bridges live under `bridges/` and implement `bridges.base.BridgeAdapter`,
which extends the abstract tool protocol and adds `connect` / `disconnect` /
capability reporting.

```text
agent_core ──► tools.AbstractGodotTools
                      ▲
                      │ implements
             bridges.*.adapter (MCP / plugin / …)
                      │
                   Godot 4.x
```

Host wiring (outside Agent Core) picks one adapter at startup and injects it
into `AgentExecutor`. Swapping bridges does not change planner, verifier, or
loop code.

## Loop (no LangGraph)

Thin custom loop in `agent_core.executor.AgentExecutor`:

```text
Plan → Observe → Reason → ToolSequence → Verify → Iterate
```

Stop conditions: success (verified), needs user, cancel hook, or budget exhaustion.

## Verification uses Godot evidence

Verification is first-class (`agent_core.verifier.Verifier`).

- A successful **mutation** tool result is **not** proof of task success.
- The verifier re-inspects via abstract tools (`inspect_node`, `read_script`,
  `get_diagnostics`, `observe_runtime`, …) and evaluates criteria against
  **Godot-sourced** `ToolResult.data` / `ToolResult.evidence`.
- Gameplay tasks should include runtime/playtest criteria when the bridge
  supports `playtest` / `runtime_debugger`.

## Adapter plug-in recipe

1. Implement `BridgeAdapter` in `bridges/<name>/adapter.py`.
2. Map each abstract method to backend calls; normalize into `ToolResult`.
3. On `connect()`, return `BridgeInfo` with `godot_version` + capability flags.
4. Call `adapter.apply_capabilities(registry)`.
5. Construct `AgentExecutor(tools=adapter, capabilities=registry, …)`.

`bridges.hybridindie` maps abstract tools (including TileSet/TileMap) onto
`godot-editor-mcp`. `bridges.godot_ai` remains a stub until wired.

## TileMap / TileSet (V1)

Abstract tools (TileMapLayer-first):

- `tileset_create`, `tileset_add_atlas`, `tileset_create_tile`, `tileset_inspect`
- `tilemap_inspect`, `tilemap_get_cell`, `tilemap_set_cell`, `tilemap_fill_rect`, `tilemap_clear`

Capability: `tilemap_editing`. Hybridindie MCP names are all under the
`tilemap` toolset (`godot_tilemap_*`). Out of V1: terrain peering, physics
polygons, navigation, animated atlases, pattern stamps.
