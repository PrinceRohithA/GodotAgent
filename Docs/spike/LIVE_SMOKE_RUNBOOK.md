# LIVE SMOKE RUNBOOK — hybridindie Phase-0

Steam Godot **4.7.2.stable.steam** · project `smoke_project/` · bridge **hybridindie**
(`godot-editor-mcp` **2026.09.30**).

## Why bridge port 19080?

On this machine `127.0.0.1:9080` is already taken by **NahimicService**.
hybridindie's default `ws://127.0.0.1:9080` therefore cannot bind.
All configs here use:

```text
GODOT_MCP_BRIDGE_URL=ws://127.0.0.1:19080
```

Set the **same** value for the MCP server process and the Godot editor process
(addon reads `OS.get_environment("GODOT_MCP_BRIDGE_URL")`).

## Exact start order

### A. MCP server (headless / PowerShell)

```powershell
cd C:\Rohith\Projects\GodotAgent
powershell -File scripts\start_mcp_server.ps1
```

Leaves HTTP MCP at `http://127.0.0.1:9090/mcp` and bridge listener on `19080`.

Cursor stdio alternative: project `.cursor/mcp.json` (already seeded). After editing,
**restart Cursor MCP / reload window**. User-global file if preferred:

`%USERPROFILE%\.cursor\mcp.json`

### B. Godot editor GUI

```powershell
powershell -File scripts\start_smoke_godot.ps1
```

Forces `GODOT_MCP_BRIDGE_URL=ws://127.0.0.1:19080` onto the editor process
(ProcessStartInfo — do not open the project from Steam/Project Manager without that env).

**First-time / cold import only:**

1. Project manager → **Import** →  
   `C:\Rohith\Projects\GodotAgent\smoke_project\project.godot` → **Import & Edit**
2. Wait for `.godot/` scan
3. **Project → Project Settings → Plugins** → **Godot MCP** = Enabled
4. **Autoload** → `MCPRuntimeProbe` → `res://addons/godot_mcp/mcp_runtime_probe.gd`
5. MCP dock connected to `ws://127.0.0.1:19080`
6. Open `res://scenes/main.tscn`

### C. Probe attach (tests 9–11)

No Autoload UI re-confirm is required once file-seeded. Probe connects over the
editor debugger channel (`mcp_runtime_probe.gd` → `godot_mcp:ready`).

If live tools still return `required=runtime_probe` after play:

1. Fully **quit** the Godot editor (not just Stop)
2. Relaunch via `scripts\start_smoke_godot.ps1`
3. Re-run the harness

Root cause that blocked Phase-0: `MCPDebugger` only set `_session_active` on
`session.started`, which can miss after play/stop; `godot_mcp:ready` now also
marks the session active (local addon fix under `addons/godot_mcp/mcp_debugger.gd`).

### D. Run live smoke harness

```powershell
cd C:\Rohith\Projects\GodotAgent
py -3 scripts\live_smoke_hybridindie.py --http-only
```

Results: `Docs/spike/live_smoke_results.md`

### E. Fake-transport regression (no Godot needed)

```powershell
py -3 -m unittest tests.test_hybridindie_adapter -v
```

## Cursor MCP path (this machine)

| Location | Path |
|----------|------|
| Project (preferred) | `C:\Rohith\Projects\GodotAgent\.cursor\mcp.json` |
| User (optional copy) | `%USERPROFILE%\.cursor\mcp.json` |

Server command uses the full path to `godot-editor-mcp.exe` because the Store
Python Scripts directory is often **not** on `PATH`.

Env seeded:

- `GODOT_MCP_DEFAULT_TOOLSETS=inspection,scene_edit,scripts,input_map,animation,tilemap,runtime,input,editor,debugger,project,resources_edit,composite,spatial,profiling`
- `GODOT_MCP_BRIDGE_URL=ws://127.0.0.1:19080`
- `GODOT_MCP_GODOT_BIN` → Steam Godot binary
- `GODOT_MCP_PROJECT_DIR` → `smoke_project`

## Probe + toolsets

- Autoload already in `smoke_project/project.godot`: `MCPRuntimeProbe`
- Without probe: playtest input / game screenshot / live observe → `PRECONDITION_FAILED`
- Without toolset seed: Cursor may ignore `tools/list_changed` after `godot_enable_toolset`

## Cleanup after smoke

- Stop play in editor if still running.
- Ctrl+C the HTTP MCP server console.
- Optional: revert `player.gd` SPEED if patch test passed (`221.0` → `220.0`).
