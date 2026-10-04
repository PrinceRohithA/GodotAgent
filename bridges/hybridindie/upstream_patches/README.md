# Upstream patches for `godot-editor-mcp==2026.9.30`

Local GodotAgent contract fixes applied onto the installed `mcp_server` package:

| File | Change |
|------|--------|
| `tools/scripts.py` + `models/scripts.py` | Auto-parse after write/patch; `success` + `parse{}`; 10s scan wait; hard fail on stale scan / missing `GODOT_BIN` |
| `tools/runtime_session.py` + `models/runtime_session.py` | `probe_connected` on play; poll `get_game_output` until `ready` |
| `tools/tilemap.py` + `models/tilemap.py` | TileMapLayer-first system: inspect, physics/collision, batch, custom data, terrain, patterns, nav/occlusion/scenes/kinematic |
| `tools/composite.py` + `models/composite.py` | `nodes_create_batch` (heterogeneous) + `nodes_edit_batch` (operations[]) |
| `tools/animation.py` + `models/animation.py` | `create_sprite_frames` (row / explicit cells, save/assign) |
| `tools/spatial.py` + `models/spatial.py` + `categories`/`toolsets`/`server` | `godot_spatial_observe` toolset |
| `tools/runtime_inspect.py` + models | `runtime_tree`, `node_inspect`, allowlisted `write_property` |
| `tools/debugger.py` + models | `status`, `error`, `list_breakpoints`, `visuals`, `get_break_state` |
| `toolset_protocol.py` | Authoring enforcement; advertise `create_scene`, `project`, `input_map` |
| `safety.py` | Stronger `GODOT_BIN` error with Steam path hint |

Apply:

```powershell
powershell -File scripts\patch_godot_mcp_server.ps1
```

Re-apply after reinstalling the package.
