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
