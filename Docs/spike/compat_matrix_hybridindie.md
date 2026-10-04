# Compatibility Matrix: hybridindie/godot-mcp vs V1 Acceptance Tests

**Subject:** [hybridindie/godot-mcp](https://github.com/hybridindie/godot-mcp) / PyPI [`godot-editor-mcp`](https://pypi.org/project/godot-editor-mcp/)  
**Evaluated version (docs):** `2026.09.30` — **193 tools**, 29 categories (`core` + 28 gated toolsets)  
**User editor (not modified):** Godot `4.7.2.stable.steam`  
**Evidence basis:** public docs only (no clone, no live bridge run, no Godot install changes)  
**Primary sources:**
- Docs site / LLM dump: https://hybridindie.github.io/godot-mcp/ · [llms-full.txt](https://hybridindie.github.io/godot-mcp/llms-full.txt)
- Tool reference: https://hybridindie.github.io/godot-mcp/reference-toolsets.html.md
- PyPI README (same content as GitHub README for this release): https://pypi.org/project/godot-editor-mcp/2026.9.30/
- Clients / gating: https://hybridindie.github.io/godot-mcp/getting-started-clients.html.md
- Changelog (C# Phase 1): https://hybridindie.github.io/godot-mcp/changelog.html.md

**Out of scope:** hi-godot/godot-ai · agent core · Python adapters

**Score key:** `pass` = documented tools cover the acceptance intent · `partial` = covers part of intent or hard operational preconditions beyond enable-toolset · `fail` = no matching capability · `unknown` = docs insufficient / environment-specific without a live check

---

## Summary table (12 V1 acceptance tests)

| # | Acceptance test | Score | Primary tools / ops | Evidence |
|---|-----------------|-------|---------------------|----------|
| 1 | Inspect current scene hierarchy | **pass** | `godot_inspection_get_scene_tree`, `godot_inspection_get_active_scene`, `godot_inspection_snapshot_subtree` | [toolsets](https://hybridindie.github.io/godot-mcp/reference-toolsets.html.md) · `inspection` always on |
| 2 | Inspect node properties | **pass** | `godot_inspection_get_node_properties`, `godot_inspection_get_node_property`, `godot_inspection_get_node_property_list` | same |
| 3 | Create / reparent node | **pass** | `godot_scene_edit_create_node`, `godot_scene_edit_move_node` (reparent), `godot_scene_edit_rename_node` | gated `scene_edit` · [README “Scene Edit”](https://pypi.org/project/godot-editor-mcp/2026.9.30/) |
| 4 | Patch GDScript | **pass** | `godot_scripts_patch`, also `godot_scripts_read` / `write` / `get_parse_errors` | gated `scripts` · described as “Read/write/patch **GDScript**” |
| 5 | Change InputMap | **pass** | `godot_input_map_add_action`, `godot_input_map_add_event`, `godot_input_map_get_action_events`, `godot_input_map_remove_action`, `godot_input_map_clear_action_events` | gated `input_map`, min Godot **4.4+** (OK for 4.7.2) |
| 6 | Inspect / modify AnimationPlayer | **pass** | `godot_animation_list_animations`, `godot_animation_get`, `godot_animation_create`, `godot_animation_add_track`, `godot_animation_insert_keyframe` | gated `animation` |
| 7 | Inspect / modify AnimationTree | **pass** | `godot_animation_create_tree`, `godot_animation_add_state_machine_state`, `godot_animation_set_blend_tree_node`, plus get/list | same toolset claims AnimationPlayers **and** AnimationTrees |
| 8 | Run game | **pass** | `godot_runtime_play_scene` / `stop_scene` / `is_playing`; alt headless `godot_runtime_run_and_capture` | gated `runtime` · play path uses editor; headless needs discoverable Godot binary |
| 9 | Send keyboard input | **pass*** | `godot_input_simulate_key` (+ `simulate_action` / `simulate_mouse` / `play_sequence`) | gated `input` · **requires runtime probe autoload** + live play session |
| 10 | Capture game viewport | **pass*** | `godot_runtime_capture_game_screenshot` (game viewport PNG; probe in-process grab). Editor UI: `godot_editor_capture_screenshot` (not V1 game viewport) | gated `runtime` / `editor` · game capture is probe-based |
| 11 | Retrieve runtime errors / state | **pass*** | Errors/output: `godot_runtime_get_game_output`; state: `godot_runtime_get_game_scene_tree`, `godot_runtime_read_property`, `godot_runtime_monitor_property`; parse: `godot_scripts_get_parse_errors`; deeper: `debugger` toolset | probe required for live tree/properties/output path; play_session for live tools |
| 12 | Undo a mutation | **pass** | Always-on `godot_undo` / `godot_redo` / `godot_list_history` (EditorUndoRedoManager) | [core toolset](https://hybridindie.github.io/godot-mcp/reference-toolsets.html.md) · honesty: some ops report `undoable: false` |

\*Operational preconditions (probe / play session / toolset enable) are documented; capability itself is present. Not scored `partial` unless noted in “Caveats” below.

### Score rollup

| pass | partial | fail | unknown |
|------|---------|------|---------|
| 12 | 0 | 0 | 0 |

**Caveats that could become `partial` after a live Steam smoke (not scored here):**
- Headless `run_and_capture` / export may need `GODOT_MCP_GODOT_BIN` if Steam’s Godot path is not auto-discovered — docs say auto-discover; Steam layout **unverified**.
- AnimationTree depth beyond create / state-machine state / blend-tree node set is not further itemized in the public tool list (still covers PRD “basic state-machine/blend”).
- Batch / file-only mutations may set `undoable: false` — undo acceptance still met for normal UndoRedo-wrapped edits.

---

## Cross-cutting notes (required)

### Safety classes

Every tool is classified; safety lives in the Python server (`mcp_server/safety.py`), not the addon.

| Class | Meaning | Extra params | Examples relevant to V1 |
|-------|---------|--------------|-------------------------|
| `read_only` | No project change | — | `godot_inspection_*`, `godot_scripts_read`, `godot_runtime_capture_game_screenshot` |
| `mutating` | Reversible editor change | `dry_run` | `godot_scene_edit_create_node`, `godot_scripts_patch`, `godot_undo` |
| `destructive` | May be irreversible | `dry_run` **and** `confirm=True` | `godot_scene_edit_delete_node`, `godot_input_map_remove_action` |
| `runtime` | Controls execution | varies | `godot_runtime_play_scene`, `godot_input_simulate_key`, `godot_export_project` |

Source: [PyPI README — Safety Classes](https://pypi.org/project/godot-editor-mcp/2026.9.30/) · [reference-safety-classes](https://hybridindie.github.io/godot-mcp/reference-safety-classes.html.md)

Mutation results also carry honesty fields: `persisted`, `undoable`, `aborted_at`, `rescan_pending`.

### Gated toolsets

- **Always on:** `core`, `inspection`
- **Off by default (27):** includes all V1 mutation/runtime surfaces: `scene_edit`, `scripts`, `animation`, `input_map`, `runtime`, `input`, `editor`, `debugger`, …
- Enable: `godot_enable_toolset("<category>")` or seed via `GODOT_MCP_DEFAULT_TOOLSETS` (comma list or `all`)

V1-relevant enable set (minimum practical):  
`scene_edit,scripts,input_map,animation,runtime,input,editor,debugger`  
(optional: `testing`, `profiling`, `project`)

### Runtime probe

Autoload: `res://addons/godot_mcp/mcp_runtime_probe.gd` (e.g. name `MCPRuntimeProbe`).

| Capability | Needs probe? |
|------------|--------------|
| `play_scene` / `stop_scene` | No |
| `run_and_capture` (headless) | No |
| `get_game_scene_tree`, property monitor/read, UI find | **Yes** |
| `input_simulate_key` / mouse / action / record | **Yes** |
| Game screenshot (`capture_game_screenshot`) | **Yes** (in-process grab) |

Without probe: `PRECONDITION_FAILED: required=runtime_probe` (or `connected: false` + hint for some reads).

### Version gating

| Toolset | Min Godot | User `4.7.2.stable.steam` |
|---------|-----------|---------------------------|
| Platform minimum | **4.4** (recommended / validated **4.7**) | Compatible per docs |
| `scene_edit`, `input_map`, `tilemap`, `scene_3d` | 4.4+ | Should enable |

Steam-specific binary discovery for headless ops: **not documented as Steam-aware** → treat as live-verify item, not a version gate fail.

### Cursor MCP setup

Docs explicitly cover OpenCode, Claude Code/Desktop, OpenWebUI, Docker/HTTP. **No Cursor-specific `mcp.json` snippet** in getting-started-clients; Cursor is named as a supported stdio MCP host in the project blurb.

Practical Cursor stdio shape (inferred from standard MCP + docs “Other clients”):

```json
{
  "mcpServers": {
    "godot": {
      "command": "godot-editor-mcp",
      "env": {
        "GODOT_MCP_DEFAULT_TOOLSETS": "scene_edit,scripts,input_map,animation,runtime,input,editor,debugger"
      }
    }
  }
}
```

**Important client caveat:** `enable_toolset` emits `notifications/tools/list_changed`, but some clients ignore it (docs cite Claude Code / OpenCode bugs). **Pre-seed `GODOT_MCP_DEFAULT_TOOLSETS`** so Cursor’s first `tools/list` already includes V1 surfaces.

Addon path (project-local, does not modify Steam Godot install): enable plugin `addons/godot_mcp/` → bridge dials out to `ws://127.0.0.1:9080`.

### GDScript vs C# limits

| Operation | GDScript (`.gd`) | C# (`.cs`) |
|-----------|------------------|------------|
| list / read / write | Yes | Phase 1: yes (`language=gd\|cs`); write carries validate-via-build hint |
| parse (`get_parse_errors`) | Yes | **Refused until Phase 2 (#560)** |
| patch (`godot_scripts_patch`) | Yes | **Refused until Phase 2 (#560)** |

Capability flags on `godot_get_server_info().bridge.backend`: `{csharp_supported, csharp_project, csharp_build}`.  
**V1 test #4 (Patch GDScript): pass.** C#-heavy projects are a **gap** for patch/parse parity.

### Gaps vs PRD abstract tools

PRD (`Docs/godot_ai_agent_v1_prd.md`) defines semantic tools (`node_inspect`, `script_patch`, `animation_edit`, `animation_tree_edit`, `playtest_input`, `viewport_capture`, `runtime_errors`, …). hybridindie exposes a **large, Godot-shaped, gated** surface (`godot_<toolset>_<op>`), not those abstract names.

| PRD abstract (examples) | Closest hybridindie mapping |
|-------------------------|-----------------------------|
| `node_inspect` / `scene_inspect` | `godot_inspection_get_scene_tree` / `get_node_properties` |
| `script_patch` | `godot_scripts_patch` |
| `animation_inspect` / `animation_edit` | `godot_animation_get` / `create` / `add_track` / `insert_keyframe` |
| `animation_tree_inspect` / `animation_tree_edit` | `godot_animation_get` + `create_tree` / `add_state_machine_state` / `set_blend_tree_node` |
| `settings` / Input Map | `godot_input_map_*` (+ `godot_project_get/set_setting`) |
| `runtime_control` | `godot_runtime_play_scene` / `stop_scene` / `run_and_capture` |
| `playtest_input` | `godot_input_simulate_key` / `simulate_action` |
| `viewport_capture` | `godot_runtime_capture_game_screenshot` |
| `runtime_errors` / `runtime_inspect` | `godot_runtime_get_game_output` + tree/property tools + `debugger_*` |
| (undo) | `godot_undo` |
| Godot docs / web search (PRD goal 16) | **Not in this MCP** |

Implication: capability coverage for the 12 acceptance tests is strong; a **thin semantic adapter / skill layer** (out of scope here) would still be needed to match the PRD tool vocabulary and hide gating/probe ceremony.

---

## Top 3 gaps

1. **Gating + Cursor tool-list refresh** — Mutation/runtime tools are off by default; clients that ignore `tools/list_changed` won’t see them after `godot_enable_toolset`. Mitigate with `GODOT_MCP_DEFAULT_TOOLSETS` (docs-recommended). Cursor has no first-class setup page.
2. **Runtime probe is mandatory for the playtest triad (tests 9–11)** — Keyboard input, game viewport capture, and live tree/property/output inspection require adding `mcp_runtime_probe.gd` as a project autoload and an editor play session. Not zero-config after “install MCP.”
3. **PRD semantic surface / C# patch** — No 1:1 PRD abstract tools (adapter still required for GodotAgent V1 shape). Additionally, **C# `patch`/`parse` are Phase-2-blocked** while GDScript is complete — a limit if V1 projects mix C#.

---

## Quick verdict

Against the **12 V1 acceptance tests**, hybridindie/godot-mcp (`godot-editor-mcp` **2026.09.30**) is a **strong capability match (12/12 pass on docs)** for Godot **4.7.x**, including Steam 4.7.2 as a version target. Remaining risk is **integration ceremony** (toolset seed for Cursor, probe autoload, optional Steam binary discovery for headless), not missing tool ops for those twelve tests.
