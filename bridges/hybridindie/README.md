# hybridindie bridge (godot-editor-mcp)

Adapter that maps GodotAgent `AbstractGodotTools` → documented
[`hybridindie/godot-mcp`](https://github.com/hybridindie/godot-mcp) /
PyPI [`godot-editor-mcp`](https://pypi.org/project/godot-editor-mcp/) tool names.

**This package does not start Godot or the MCP server.** Wire a real MCP
transport later; unit tests inject a fake `call_tool` transport.

| File | Role |
|------|------|
| `mapping.py` | Abstract method → MCP tool name(s), toolsets, probe/undo notes |
| `adapter.py` | `HybridindieBridgeAdapter` + `McpTransport` protocol |
| `upstream_patches/` | Local patches for auto-parse, runtime ready poll, authoring protocol — apply via `scripts/patch_godot_mcp_server.ps1` |

Docs baseline: **godot-editor-mcp 2026.09.30** (193 tools), evaluated for Steam
Godot **4.7.2.stable.steam**.

## Cursor setup gotchas

### 1. Pre-seed `GODOT_MCP_DEFAULT_TOOLSETS`

Only `core` + `inspection` are on by default. Mutation/runtime surfaces need a
seed, because some MCP clients (including patterns Cursor may share) **ignore**
`notifications/tools/list_changed` after `godot_enable_toolset`.

Recommended Cursor `mcp.json` stdio shape (inferred — no official Cursor snippet
in upstream client docs):

```json
{
  "mcpServers": {
    "godot": {
      "command": "godot-editor-mcp",
      "env": {
        "GODOT_MCP_DEFAULT_TOOLSETS": "inspection,scene_edit,scripts,input_map,animation,tilemap,runtime,input,editor,debugger,project,resources_edit,composite"
      }
    }
  }
}
```

### Tilemap toolset (TileMapLayer-first)

Seed includes `tilemap`. Abstract tools map to `godot_tilemap_*` (not
`godot_tileset_*`). Prefer **TileMapLayer** siblings sharing one TileSet;
deprecated `TileMap` is read/compat only for paint/get/clear.

Full stack (apply `upstream_patches/tools|models/tilemap.py` via
`scripts/patch_godot_mcp_server.ps1`):

- **INSPECT/VERIFY:** `tileset_inspect`, `tileset_atlas_inspect`, `get_tile_data`
- **Phase 1:** physics layer, `set_tile_collision` (`full_rect` → centered
  polygon), `layer_set_physics`, `set_cells_batch`
- **Phase 2:** custom data → terrain (`TERRAIN_NOT_CONFIGURED` gate) → patterns → alts/anim
- **P3:** navigation, occlusion, scenes collection source, constant velocity + kinematic

Capability flag: `tilemap_editing`. Live smoke: `scripts/live_smoke_tilemap.py`.

### Bulk / composite authoring

Seed already includes `composite` + `animation`. Prefer semantic bulk tools over
N× `create_node` / `set_property`:

| Abstract | MCP |
|----------|-----|
| `nodes_create_batch` | `godot_composite_nodes_create_batch` |
| `nodes_edit_batch` | `godot_composite_nodes_edit_batch` |
| `create_sprite_frames` | `godot_animation_create_sprite_frames` |

Apply `upstream_patches/tools|models/{composite,animation}.py` via
`scripts/patch_godot_mcp_server.ps1`. Live smoke: `scripts/live_smoke_bulk.py`.

### Spatial / runtime / debug

Seed includes `spatial`, `debugger`, `profiling`. Abstract tools:

| Abstract | MCP |
|----------|-----|
| `spatial_observe` | `godot_spatial_observe` |
| `runtime_tree` / `runtime_node_inspect` | `godot_runtime_tree` / `godot_runtime_node_inspect` |
| `runtime_get_property` | `godot_runtime_read_property` |
| `observe` | abstract composition (no mega MCP tool) |
| `debug_status` / `debug_error` | `godot_debugger_status` / `godot_debugger_error` |
| `debug_control` / `debug_breakpoint` / `debug_stack` | existing `godot_debugger_*` |

Capability: `spatial_observation`. Live smoke: `scripts/live_smoke_spatial_debug.py`.

Same seed string is exported as `bridges.hybridindie.mapping.GODOT_MCP_DEFAULT_TOOLSETS_SEED`.

After changing env, **restart Cursor** and confirm `tools/list` includes gated
ops (e.g. `godot_scripts_patch`, `godot_runtime_play_scene`).

### 2. Runtime probe (playtest triad)

Keyboard/mouse injection, game viewport capture, and live game tree/property/output
require the probe autoload:

- Script: `res://addons/godot_mcp/mcp_runtime_probe.gd`
- Suggested name: `MCPRuntimeProbe`

Without it, MCP returns `PRECONDITION_FAILED: required=runtime_probe`. The adapter
mirrors that as a structured `ToolResult` when `runtime_probe_present=False`.

Also start an **editor play session** (`godot_runtime_play_scene`) before
`playtest_input` / game screenshot / live observe. `play_scene` / `stop_scene`
themselves do **not** need the probe.

### 3. Godot 4.7.2 Steam

- Enable the project-local addon `addons/godot_mcp/` only — **do not** modify the
  Steam Godot install.
- Bridge dials out to `ws://127.0.0.1:9080`.
- Prefer editor play for the first smoke. Headless `run_and_capture` / export may
  need `GODOT_MCP_GODOT_BIN` if auto-discover misses Steam’s binary path.
- GDScript-first: C# `patch` / `parse` are Phase-2-blocked upstream.

### 4. Undo honesty

`godot_undo` is always-on (`core`). Prefer UndoRedo-wrapped scene edits for
acceptance undo; some batch/file ops report `undoable: false`.

**Local patch:** `smoke_project/addons/godot_mcp/command_router.gd` must
`clear_history` after raw `UndoRedo.undo()`/`redo()`. Without that, Godot logs
`ERROR: Inconsistent redo history` and can block saves. Reload the plugin after
pulling that fix; if you already hit the error, fully quit and relaunch Godot.

### 5. AnimationTree

hybridindie is the V1 path with AnimationTree authoring
(`create_tree`, `add_state_machine_state`, `set_blend_tree_node`). Capability
flag `animation_tree` is set `True` in this adapter’s static expected caps.

## Fake-transport test

From the repo root (stdlib `unittest`, no Godot/MCP install):

```bash
# Windows (py launcher) or Unix:
py -3 -m unittest tests.test_hybridindie_adapter -v
# python -m unittest tests.test_hybridindie_adapter -v
```

## Wiring a real transport later

Implement `McpTransport.call_tool(name, arguments) -> Any` over MCP stdio/HTTP,
then:

```python
adapter = HybridindieBridgeAdapter(transport, runtime_probe_present=True)
adapter.connect()
adapter.apply_capabilities(registry)
```
