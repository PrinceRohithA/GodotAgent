# Bridge Spike Comparison: godot-ai vs hybridindie

**Inputs:** `compat_matrix_godot_ai.md`, `compat_matrix_hybridindie.md` (docs-only, 2026-10-03)  
**Target editor:** Steam Godot `4.7.2.stable.steam`  
**Architecture lock:** Agent Core stays **bridge-agnostic**; concrete MCP wiring lives under `bridges/`. Docs alone do **not** pick a permanent winner.

**Score key:** `pass` | `partial` | `fail` | `unknown` · `*` = docs-pass with hard operational preconditions

---

## 1. Side-by-side (12 V1 acceptance tests)

| # | Acceptance test | godot-ai | hybridindie |
|---|-----------------|----------|-------------|
| 1 | Inspect scene hierarchy | **pass** | **pass** |
| 2 | Inspect node properties | **pass** | **pass** |
| 3 | Create / reparent node | **pass** | **pass** |
| 4 | Patch GDScript | **pass** | **pass** |
| 5 | Change InputMap | **pass** | **pass** |
| 6 | Inspect / modify AnimationPlayer | **pass** | **pass** |
| 7 | Inspect / modify AnimationTree | **fail** | **pass** |
| 8 | Run game | **pass** | **pass** |
| 9 | Send keyboard input | **pass** | **pass\*** |
| 10 | Capture game viewport | **pass** | **pass\*** |
| 11 | Retrieve runtime errors / state | **pass** | **pass\*** |
| 12 | Undo a mutation | **partial** | **pass** |

| Bridge | pass | partial | fail | unknown |
|--------|------|---------|------|---------|
| [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai) | 10 | 1 | 1 | 0 |
| [hybridindie/godot-mcp](https://github.com/hybridindie/godot-mcp) (`2026.09.30`) | 12\* | 0 | 0 | 0 |

\*hybridindie 9–11 require runtime probe + play session; mutation/runtime toolsets off by default until seeded.

---

## 2. Where each wins / fails

### hybridindie wins

| Area | Why |
|------|-----|
| **AnimationTree (#7)** | Documented `create_tree` / state-machine / blend-tree ops. godot-ai marks `animation_tree.*` unshipped. |
| **Agent undo (#12)** | Always-on `godot_undo` / `godot_redo` / `godot_list_history`. godot-ai: UndoRedo on writes + batch rollback, **no** MCP undo op. |
| **Breadth vs PRD surface** | Docs claim full 12-test coverage in one tool family. |

### godot-ai wins

| Area | Why |
|------|-----|
| **Cursor friction** | Dock **Configure → Cursor** writes authenticated stdio into `~/.cursor/mcp.json`. hybridindie: no Cursor-specific page; inferred `mcp.json`. |
| **Playtest triad (#9–11)** | Shipped `game_manage` / `editor_screenshot(game)` / `logs_read` via `_mcp_game_helper` — no separate “enable N toolsets + add probe autoload” checklist in docs. |
| **Auth story** | Documented V4 capability rotation + HMAC WS; hybridindie is simpler loopback WS (`9080`) with server-side safety classes. |

### Shared / neither

- Both version-OK for **4.7.2** on paper; Steam launcher / binary-discovery quirks **unverified**.
- Both are GDScript-strong; C# patch/parse incomplete (godot-ai text-only; hybridindie Phase-2-blocked).
- Neither exposes PRD abstract names 1:1 — adapters still map `animation_tree_*`, `playtest_*`, etc.
- Scores are **documentation-grounded**, not live-verified.

---

## 3. Spike recommendation (first live instrument)

**Do not lock a permanent bridge from this spike.** Keep Agent Core on abstract tools; put adapters under `bridges/<name>/`.

**Instrument first for a 48h Cursor smoke on Steam 4.7.2:** **hybridindie/godot-mcp** (`godot-editor-mcp`).

Why (smoke order, not lifetime choice):

1. Only docs-passing path for **AnimationTree** — the hard godot-ai fail against V1 acceptance.  
2. Only docs-passing path for **agent-callable undo** — closes the godot-ai partial.  
3. One smoke can exercise the **full 12-test matrix**; toolset seed + probe are known setup steps, not missing APIs. If hybridindie fails live, fall back to godot-ai for the 10/12 surface without changing Agent Core.

Secondary (if hybridindie blocks on Cursor tool-list / Steam probe within ~8h): pivot the remaining window to **godot-ai** for playtest + Cursor attach validation.

---

## 4. First live-test gotchas (hybridindie + Cursor + Steam 4.7.2)

1. **Pre-seed toolsets** — Default surface is `core` + `inspection` only. Set `GODOT_MCP_DEFAULT_TOOLSETS` before Cursor starts (e.g. `scene_edit,scripts,input_map,animation,runtime,input,editor,debugger`). Do not rely on `godot_enable_toolset` alone; some MCP clients ignore `tools/list_changed`.
2. **Runtime probe autoload** — Add `res://addons/godot_mcp/mcp_runtime_probe.gd` (e.g. `MCPRuntimeProbe`). Without it, tests **9–11** fail with `PRECONDITION_FAILED: required=runtime_probe` (or disconnected reads). `play_scene`/`stop_scene` alone are not enough.
3. **Play session required** — Probe tools need an editor play session; start play before input / game screenshot / live tree-property-output checks.
4. **Cursor MCP shape** — No official Cursor snippet; use stdio `godot-editor-mcp` + env toolset seed. Confirm `tools/list` shows gated ops after Cursor restart.
5. **Project-local addon only** — Enable `addons/godot_mcp/`; do not modify the Steam Godot install. Bridge expects `ws://127.0.0.1:9080`.
6. **Steam binary discovery** — Headless `run_and_capture` / export may need `GODOT_MCP_GODOT_BIN` if auto-discover misses Steam’s path. Prefer editor play path for the first smoke.
7. **Undo honesty** — Prefer UndoRedo-wrapped scene edits for test #12; some batch/file ops report `undoable: false`.
8. **GDScript-first fixture** — Avoid C# for the 48h window (patch/parse refused until Phase 2).

---

## 5. Abstract-tool mapping notes (esp. AnimationTree, undo)

| PRD abstract | godot-ai | hybridindie | Adapter note |
|--------------|----------|-------------|--------------|
| `scene_inspect` / `node_inspect` | `scene_get_hierarchy`, `node_get_properties` | `godot_inspection_get_scene_tree`, `get_node_properties` | Both cover; naming differs |
| `node_edit` / create-reparent | `node_create`, `node_manage` | `godot_scene_edit_*` | hybridindie needs `scene_edit` toolset |
| `script_patch` | `script_patch` (+ diagnostics) | `godot_scripts_patch` | Both GDScript-OK |
| Input Map | `input_map_manage` | `godot_input_map_*` | Both cover |
| `animation_*` (Player) | `animation_manage` / `animation_create` | `godot_animation_*` | Both cover |
| **`animation_tree_inspect` / `animation_tree_edit`** | **Missing** (follow-up) | `create_tree`, `add_state_machine_state`, `set_blend_tree_node`, get/list | **hybridindie only** for V1 tree accept; capability flag must be per-bridge |
| `runtime_control` | `project_run` / `project_manage(stop)` | `godot_runtime_play_scene` / `stop_scene` | Both cover |
| `playtest_input` | `game_manage(input_*)` | `godot_input_simulate_*` | hybridindie: probe + `input` toolset |
| `viewport_capture` | `editor_screenshot(target=game)` | `godot_runtime_capture_game_screenshot` | hybridindie: probe |
| `runtime_errors` / inspect | `logs_read`, `game_manage`, doorbells | `get_game_output`, tree/property, `debugger_*` | hybridindie: probe for live path |
| **Agent undo** | Editor UndoRedo + batch failure rollback; **no MCP undo** | **`godot_undo` / `godot_redo` / `godot_list_history`** | Expose abstract `undo` only when bridge reports it; godot-ai adapter → unsupported / human Ctrl+Z |
| Docs / web search | Outside both MCPs | Outside both MCPs | Client/LLM side |

**Capability registry implication:** treat `animation_tree` and `agent_undo` as bridge-reported flags — true for hybridindie (docs), false / partial for godot-ai — never hardcode into Agent Core.

---

## Verdict (actionable)

| Decision | Choice |
|----------|--------|
| Permanent bridge | **None** (docs-only; Core stays agnostic) |
| First 48h live smoke | **hybridindie** |
| Fallback if blocked early | **godot-ai** (Cursor attach + 10/12 playtest) |
| Adapter placement | `bridges/hybridindie/` first, `bridges/godot_ai/` ready as second |
