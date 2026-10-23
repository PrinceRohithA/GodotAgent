# Live smoke results — hybridindie / Godot 4.7.2.steam

**Generated:** 2026-10-13 10:46:01 UTC
**Transport mode:** `http:http://127.0.0.1:9090/mcp`
**Bridge URL:** `ws://127.0.0.1:19080`
**Toolset seed:** `inspection,scene_edit,scripts,input_map,animation,tilemap,runtime,input,editor,debugger,project,resources_edit,composite,spatial,profiling`
**Runtime probe:** `MCPRuntimeProbe` → `res://addons/godot_mcp/mcp_runtime_probe.gd`
**Steam Godot:** `C:\Program Files (x86)\Steam\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`

This is a **Phase-0 live smoke**, not a permanent bridge winner declaration.

## 12 acceptance tests

| # | Test | Status | Detail |
|---|------|--------|--------|
| 1 | Inspect current scene hierarchy | **pass** |  |
| 2 | Inspect node properties | **pass** |  |
| 3 | Create / reparent node | **pass** |  |
| 4 | Patch GDScript | **pass** |  |
| 5 | Change InputMap | **pass** |  |
| 6 | Inspect / change AnimationPlayer | **pass** |  |
| 7 | Inspect / change AnimationTree | **pass** |  |
| 8 | Run game | **blocked** | PRECONDITION_FAILED: raw_scene_or_settings_edit: disk changes to scene/settings files without MCP authoring ops: res://scenes/main.tscn, res://project.godot.... |
| 9 | Send keyboard input | **blocked** | PRECONDITION_FAILED: required=runtime_probe (timeout waiting for probe) |
| 10 | Capture game viewport | **blocked** | PRECONDITION_FAILED: No play session. Run play_scene first. [required=play_session] |
| 11 | Retrieve runtime errors / state | **blocked** | PRECONDITION_FAILED: No play session. Run play_scene first. [required=play_session] |
| 12 | Undo a mutation | **pass** |  |

**Rollup:** pass=8 fail=0 blocked=4

## Probe attach notes (tests 9–11)

Autoload was already correct in `project.godot`. The live blocker was the
addon debugger gate: `MCPDebugger.is_connected_to_probe()` required
`_session_active` from `EditorDebuggerSession.started`, which can be missed
after play/stop cycles even when the game probe already sent `godot_mcp:ready`.
Fix: treat `godot_mcp:ready` (and already-active sessions in `_setup_session`)
as proof the session is live — see `smoke_project/addons/godot_mcp/mcp_debugger.gd`.

Harness also waits on `godot_runtime_get_game_scene_tree` → `connected: true`
(not a soft `observe_runtime` ok), uses absolute `/root/Main/Player` for live
property reads, and `start_smoke_godot.ps1` forces `GODOT_MCP_BRIDGE_URL`.

**Human step:** none required when editor is already open via
`scripts/start_smoke_godot.ps1` with plugin Enabled + Autoload present.
If probe still never attaches after many play/stop cycles: fully quit the
editor and relaunch that script (session-cap recovery).

