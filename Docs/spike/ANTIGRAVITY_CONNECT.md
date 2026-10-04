# Connect Antigravity → hybridindie Godot MCP

## Status

- MCP HTTP: `http://127.0.0.1:9090/mcp`
- Bridge: `ws://127.0.0.1:19080`
- Seed toolsets via **server** (`scripts/start_mcp_server.ps1`), not Antigravity JSON
- Apply server patches after install: `scripts/patch_godot_mcp_server.ps1`

## Config

| File | Entry |
|------|--------|
| `%USERPROFILE%\.gemini\config\mcp_config.json` | `"godot": { "serverUrl": "http://127.0.0.1:9090/mcp" }` |
| `GodotAgent/.agents/mcp_config.json` | same (workspace) |

Uses **HTTP** against the already-running server so Antigravity does not spawn a second process fighting for port 19080.

## Keep backend up

```powershell
powershell -File scripts\patch_godot_mcp_server.ps1   # after pip reinstall
powershell -File scripts\start_mcp_server.ps1
powershell -File scripts\start_smoke_godot.ps1          # or open GodotAgentTest
```

Reload Antigravity MCP servers after config changes.

---

## Pasteable system constraints (keep in chat)

```text
You are connected to the godot MCP server. Follow this contract strictly:

AUTHORING
- NEVER host-Write/Edit *.tscn, *.scn, or project.godot.
- Scenes: godot_scene_edit_create_scene → create_node → attach_script → set_property → save_scene.
  Prefer instance_scene / extract_scene for prefabs.
- Scripts: godot_scripts_write / patch only. Always read returned {success, parse:{status,errors}}.
- Settings: godot_project_set_setting. InputMap: godot_input_map_* only.
- play_scene fails with raw_scene_or_settings_edit if those files change without MCP tools.

PLAYTEST LIFECYCLE (canonical)
1. play_scene → wait until probe_connected / scene_tree.connected
2. simulate input
3. godot_runtime_get_game_output until ready=true (errors first)
4. godot_runtime_read_property on gameplay nodes (position, velocity, is_on_floor, …)
5. screenshot LAST (optional)

VERIFICATION
- Never declare gameplay success from a screenshot alone.
- Use runtime state, diagnostics, and/or observable behavior.
- Recovery loop: introduce/detect bug → fix → re-run → verify properties/errors again.
```

---

## Mandatory platformer loop

1. Inspect assets with godot FS / inspection tools  
2. Author scenes only via `scene_edit_*`  
3. Scripts via `scripts_write` → use embedded `parse{}`  
4. InputMap via `input_map_*`  
5. Play → probe → input → **errors → properties → screenshot last**  
6. If parse or runtime errors: fix → re-run → verify (recovery)

### Never declare success from a screenshot alone

A gameplay task is not verified by visual appearance alone. Use runtime state, diagnostics, and/or observable game behavior.

---

## TileMapLayer recipe (collision platformer)

Use **sibling `TileMapLayer` nodes** (Ground / Decor / Foreground / Hazards) sharing one TileSet. Deprecated `TileMap` is read/compat only.

```text
INSPECT
  godot_tilemap_tileset_inspect / tileset_atlas_inspect

AUTHOR
  create_tileset → add_tileset_atlas_source → create_tile
  add_tileset_physics_layer → set_tile_collision (shape=full_rect)
  tilemap_layer_set_physics(collision_enabled=true)
  tilemap_fill_rect / tilemap_set_cells_batch

VERIFY
  get_tile_data → collision polygons present
  play → read is_on_floor (positive)
  clear_tile_collision or collision_enabled=false → player falls (negative)
  restore collision → lands again

LATER
  custom data → terrain (gated TERRAIN_NOT_CONFIGURED) → patterns → alts/anim
  P3: navigation / occlusion / scene tiles / kinematic+velocity
```

Never host-write `.tres` TileSets / `.tscn` when these MCP tools exist.

---

## Bulk / composite recipe (prefer over N× create/set)

Use semantic bulk tools — **not** a generic `batch_execute` of arbitrary MCP calls.

```text
SCENE BULK
  godot_composite_nodes_create_batch
    nodes: [{type, name, parent, properties}, ...]
    validate → commit → verify paths; fail-before-commit with index
  godot_composite_nodes_edit_batch
    operations: [{path, property, value}, ...]
    (or legacy edits: [{node_path, properties}])

SPRITEFRAMES
  godot_animation_create_sprite_frames
    texture + frame_size + animations{ idle:{row,frames,fps,loop} | run:{frames:[[x,y],...]} }
    optional save_path (.tres) + assign_to (AnimatedSprite2D)
    VERIFY: animation_names + per-anim frame counts

TILEMAP BULK (already available)
  tilemap_fill_rect / tilemap_set_cells_batch / patterns
```

Prefer these over looping `create_node` / `set_property` / `edit_node` for ≥10 peers.

---

## Spatial + runtime + debug (structured first)

Prefer structured world state over screenshots.

```text
OBSERVE PRIORITY
  1. diagnostics / game output
  2. runtime tree / node inspect / properties
  3. spatial_observe (local vs global transforms, pivot/center, AABB, world_corners)
  4. gameplay state (velocity, is_on_floor, animation)
  5. screenshot LAST (visual confirmation only)

SPATIAL
  godot_spatial_observe(scope=editor|runtime, root, depth, include=[transform,bounds,collision,runtime])
  Geometry is type-sourced (Sprite2D/Control/CollisionShape2D/CollisionPolygon2D/Polygon2D).
  Unsupported types → geometry.available=false (never invent bounds).

RUNTIME (read-only P0)
  godot_runtime_tree / godot_runtime_node_inspect / godot_runtime_read_property

DEBUG (session-centric)
  godot_debugger_status → session_id, breaked, debuggable
  godot_debugger_error → reason, file, line, message, stack (when broken)
  godot_debugger_force_break / continue_execution / step_*
  godot_debugger_set_breakpoint / remove / list / clear

BLACK-BOX playtest: input → game → observe
WHITE-BOX diagnose: inspect/runtime spatial → (P1) allowlisted write_property → observe
```

Never declare gameplay success from a screenshot alone.

---

## Quick probes

```text
Use the godot MCP server. Call godot_inspection_get_scene_tree and summarize the open scene hierarchy.
```

```text
Using godot tools only (no host file writes to .tscn): create_scene res://scenes/AntigravityMarker.tscn root Node2D, add a child Node2D named Marker, save_scene, then get_scene_tree.
```

```text
Write a tiny broken .gd via godot_scripts_write, confirm parse.status=error in the write result, fix it with write again, confirm parse.status=ok.
```

```text
Play the main scene, wait for probe_connected, simulate jump/move, read player global_position/velocity/is_on_floor, get_game_output (ready=true), then screenshot last. Do not claim success from the screenshot alone.
```
