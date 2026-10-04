# Upstream patches for `godot-editor-mcp==2026.9.30`

Local GodotAgent contract fixes applied onto the installed `mcp_server` package:

| File | Change |
|------|--------|
| `tools/scripts.py` + `models/scripts.py` | Auto-parse after write/patch; `success` + `parse{}`; 10s scan wait; hard fail on stale scan / missing `GODOT_BIN` |
| `tools/runtime_session.py` + `models/runtime_session.py` | `probe_connected` on play; poll `get_game_output` until `ready` |
| `toolset_protocol.py` | Authoring enforcement; advertise `create_scene`, `project`, `input_map` |
| `safety.py` | Stronger `GODOT_BIN` error with Steam path hint |

Apply:

```powershell
powershell -File scripts\patch_godot_mcp_server.ps1
```

Re-apply after reinstalling the package.
