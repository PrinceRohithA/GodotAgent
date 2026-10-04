# Compatibility Matrix: hi-godot/godot-ai vs GodotAgent V1 Acceptance Tests

**Subject:** [hi-godot/godot-ai](https://github.com/hi-godot/godot-ai) (MCP + Godot editor plugin)  
**Against:** V1 acceptance tests from `Docs/godot_ai_agent_v1_prd.md` (§53 / abstract tool loop)  
**User editor:** Steam Godot `4.7.2.stable.steam` (not modified for this spike)  
**Evidence date:** 2026-10-03  
**Method:** Live upstream docs only (README, `docs/TOOLS.md`, `docs/tool-taxonomy.md`, `docs/implementation-plan.md`, `docs/plugin-architecture.md`, `docs/client-configuration.md`, `plugin/addons/godot_ai/clients/cursor.gd`). No local install, no adapter code, no hybridindie evaluation.

**Score legend:** `pass` | `partial` | `fail` | `unknown`

---

## Summary table

| # | V1 acceptance test | Score | Primary godot-ai surface |
|---|--------------------|-------|--------------------------|
| 1 | Inspect current scene hierarchy | **pass** | `scene_get_hierarchy` / `godot://scene/hierarchy` |
| 2 | Inspect node properties | **pass** | `node_get_properties` / `godot://node/{path}/properties` |
| 3 | Create / reparent node | **pass** | `node_create` + `node_manage(op="reparent")` |
| 4 | Patch GDScript | **pass** | `script_patch` (GDScript validated + diagnostics) |
| 5 | Change InputMap | **pass** | `input_map_manage` + `godot://input_map` |
| 6 | Inspect / modify AnimationPlayer | **pass** | `animation_create` + `animation_manage` |
| 7 | Inspect / modify AnimationTree | **fail** | Not shipped (`animation_tree.*` follow-up) |
| 8 | Run game | **pass** | `project_run` + `project_manage(op="stop")` |
| 9 | Send keyboard input | **pass** | `game_manage(op="input_key"\|"input_action"\|…)` |
| 10 | Capture game viewport | **pass** | `editor_screenshot` (`game` target) |
| 11 | Retrieve runtime errors / state | **pass** | `logs_read` + `game_manage` + `editor_state.game_status` |
| 12 | Undo a mutation | **partial** | UndoRedo on writes; no agent MCP `undo` op |

**Tally:** 10 pass · 1 partial · 1 fail · 0 unknown

---

## Per-test evidence

### 1. Inspect current scene hierarchy — **pass**

| Field | Detail |
|-------|--------|
| Tools | Always-loaded `scene_get_hierarchy` (depth / offset / limit). Resource: `godot://scene/hierarchy` (first 100 nodes; paginate via tool). |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md) — core tools + MCP Resources |
| Notes | README quick-start example: *"Show me the current scene hierarchy."* |

### 2. Inspect node properties — **pass**

| Field | Detail |
|-------|--------|
| Tools | Always-loaded `node_get_properties`. Resource: `godot://node/{path}/properties`. Related: `node_find`, `resource_manage(op="inspect")` for assigned Resources. |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md) |

### 3. Create / reparent node — **pass**

| Field | Detail |
|-------|--------|
| Tools | Deferred verb `node_create`. Rollup `node_manage` ops: `reparent`, `move`, `rename`, `delete`, `duplicate`, groups. Plugin batch cmds include `create_node` / `set_property`. |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md) domain rollups |

### 4. Patch GDScript — **pass**

| Field | Detail |
|-------|--------|
| Tools | `script_patch`, `script_create`, `script_attach`; `script_manage(op="read"\|"find_symbols"\|"detach")`. |
| Docs | [docs/TOOLS.md § C# support](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md#c-support); [README](https://github.com/hi-godot/godot-ai/blob/main/README.md) |
| Notes | `.gd` parse-validated with per-write `diagnostics`. C# is text-only (see platform notes). |

### 5. Change InputMap — **pass**

| Field | Detail |
|-------|--------|
| Tools | `input_map_manage` ops: `list`, `add_action`, `ensure_action`, `remove_action`, `bind_event`, `ensure_binding`. Resource: `godot://input_map`. |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md); taxonomy `input_map.*` in [docs/tool-taxonomy.md](https://github.com/hi-godot/godot-ai/blob/main/docs/tool-taxonomy.md) |

### 6. Inspect / modify AnimationPlayer — **pass**

| Field | Detail |
|-------|--------|
| Tools | `animation_create`; `animation_manage` ops: `player_create`, `list`, `get`, `add_property_track`, `add_method_track`, `set_autoplay`, `play`, `stop`, `create_simple`, `validate`, presets (`preset_fade` / `slide` / `shake` / `pulse`), `delete`. |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md); shipped status in [docs/tool-taxonomy.md](https://github.com/hi-godot/godot-ai/blob/main/docs/tool-taxonomy.md) |
| Known gaps vs PRD polish | Bezier/audio tracks and some nested material-path coercion still follow-ups — not required for basic inspect/modify. |

### 7. Inspect / modify AnimationTree — **fail**

| Field | Detail |
|-------|--------|
| Tools | None on published MCP surface. |
| Docs | Explicitly unshipped: [docs/tool-taxonomy.md](https://github.com/hi-godot/godot-ai/blob/main/docs/tool-taxonomy.md) (*"`animation_tree.*` … tracked as follow-ups"*); [docs/implementation-plan.md](https://github.com/hi-godot/godot-ai/blob/main/docs/implementation-plan.md) (`[ ] animation_tree.*` — state-machine / blend-tree authoring). |
| PRD impact | Blocks V1 acceptance items “Inspect AnimationTree” / “Modify a basic state-machine/blend configuration” and the dash-transition failure-loop example (`animation_tree_inspect` / `animation_tree_edit`). |
| Workaround quality | Generic `node_get_properties` / `node_set_property` on an AnimationTree node is not a semantic tree/graph API — scored **fail**, not partial. |

### 8. Run game — **pass**

| Field | Detail |
|-------|--------|
| Tools | `project_run` (play + wait for helper liveness / `game_status`); `project_manage(op="stop")`; `editor_state` exposes play / `game_status`. |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md) (`project_run`, `game_status` contract) |
| Notes | Depends on `_mcp_game_helper` autoload for `status="live"`; headless/custom main loops may report `no_helper`. |

### 9. Send keyboard input — **pass**

| Field | Detail |
|-------|--------|
| Tools | `game_manage`: `input_key`, `input_action`, `input_sequence`, `input_mouse`, `input_gamepad`, `input_state`. |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md); runtime domain history [PR #470](https://github.com/hi-godot/godot-ai/pull/470) |
| Notes | Action-based / sequence paths are focus-independent; prefer `input_sequence` when frame timing matters. |

### 10. Capture game viewport — **pass**

| Field | Detail |
|-------|--------|
| Tools | `editor_screenshot` with target `game` (also `viewport`, `viewport_2d`, `cinematic`). Optional Vision Routing replaces image with text description. |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md); [docs/vision-routing.md](https://github.com/hi-godot/godot-ai/blob/main/docs/vision-routing.md) |
| Notes | Aligns with PRD §32 (game viewport prioritized). Capture readiness gated by `game_capture_ready` / helper liveness. |

### 11. Retrieve runtime errors / state — **pass**

| Field | Detail |
|-------|--------|
| Tools | `logs_read` (`plugin` / `game` / `editor` / `all`, `include_details`, cursors, run ids); `game_manage` (`get_scene_tree`, `get_node_info`, `get_ui_elements`, `debug_status`, suspend/resume/next_frame); `editor_state` / `project_run` `game_status` + `recent_errors`; doorbell fields `new_errors_since_last_call`. |
| Docs | [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md) |
| Notes | Boot-time parse/load errors may need `source="editor"` (not game log). C# compiler output is **not** on this channel. |

### 12. Undo a mutation — **partial**

| Field | Detail |
|-------|--------|
| What exists | Scene mutations are required to commit via `EditorUndoRedoManager` (`undoable: true` response contract). `batch_execute` rolls back successful subcommands on first error when `undo=True` (default). User can Ctrl+Z in the editor. |
| What is missing | No published MCP op such as `editor_undo` / `editor_redo` on `editor_manage` (ops are `state`, `selection_*`, `monitors_get`, `quit`, `logs_clear`, `game_eval` only). Filesystem move/rename/remove explicitly **do not** participate in editor undo. |
| Docs | Undo contract: [docs/plugin-architecture.md](https://github.com/hi-godot/godot-ai/blob/main/docs/plugin-architecture.md); batch rollback: [docs/tool-surface.md](https://github.com/hi-godot/godot-ai/blob/main/docs/tool-surface.md); op list: [docs/TOOLS.md](https://github.com/hi-godot/godot-ai/blob/main/docs/TOOLS.md) |
| Score rationale | Recoverability for scene edits exists for humans and failed batches, but the agent cannot deliberately undo a prior successful mutation via tools — below PRD §40 / acceptance “safely recoverable” agent loop. |

---

## Platform / integration notes

### Auth model

```text
MCP client
  → godot-ai attach (stdio)
  → Python server (authenticated HTTP, ~port 8000)
  → Godot editor plugin (authenticated WebSocket, ~port 9500, loopback-only)
```

- V4: independent rotating **capabilities** on both hops; no unauthenticated fallback.  
- Bare `http://127.0.0.1:8000/mcp` **cannot** authenticate or follow capability rotation.  
- WebSocket: mutual HMAC handshake; Godot **&lt; 4.7 fail closed**.  
- Trust: same-user / loopback; Windows does **not** claim isolation from other local accounts.  
- Sources: [README](https://github.com/hi-godot/godot-ai/blob/main/README.md), [docs/plugin-architecture.md § Security Model](https://github.com/hi-godot/godot-ai/blob/main/docs/plugin-architecture.md).

### Godot version requirement

| Requirement | Evidence | User Steam build |
|-------------|----------|------------------|
| Godot **4.7+** (4.x line) for Godot AI v4 | README Requirements; WS handshake fail-closed below 4.7 | **4.7.2.stable.steam** → version-compatible on paper |

Steam / Flatpak caveats in upstream docs are primarily **Linux** pressure-vessel / capability-directory issues. This spike does not runtime-verify Steam Windows packaging; treat Steam-specific launcher quirks as **unknown until smoke-tested**, not as a version mismatch.

### MCP client setup for Cursor

1. Install release add-on at `addons/godot_ai/` (not a raw main-tree overlay).  
2. Enable **Project → Project Settings → Plugins → Godot AI**.  
3. Install [`uv`](https://docs.astral.sh/uv/) so `uvx` is available.  
4. In Godot AI dock: **Cursor → Configure** (or **Configure all**), then restart Cursor if needed.  
5. Dock writes authenticated **stdio** `godot-ai attach` into `$USERPROFILE/.cursor/mcp.json` (`mcpServers` map; `type: "stdio"`). Descriptor: [`clients/cursor.gd`](https://github.com/hi-godot/godot-ai/blob/main/plugin/addons/godot_ai/clients/cursor.gd).  
6. Prefer dock-generated argv (version pin, ports, domain exclusions, telemetry flags). Manual shape (illustrative):

```json
{
  "mcpServers": {
    "godot-ai": {
      "type": "stdio",
      "command": "/absolute/path/to/uvx",
      "args": [
        "--link-mode", "copy",
        "--from", "godot-ai==VERSION",
        "godot-ai", "attach",
        "--port", "8000",
        "--ws-port", "9500"
      ]
    }
  }
}
```

Sources: [README](https://github.com/hi-godot/godot-ai/blob/main/README.md), [docs/client-configuration.md](https://github.com/hi-godot/godot-ai/blob/main/docs/client-configuration.md).

### GDScript vs C# limits

| Language | Contract |
|----------|----------|
| **GDScript** | Full: write, parse-validate, hot-reload, attach, outline, diagnostics on write / logs. |
| **C#** | **Text-only** (#908): `script_create` / `script_patch` write `.cs`; `find_symbols` line-scan outline; **no** .NET build; **no** compiler errors on MCP surface; `reloaded: false`; attach needs .NET-enabled editor. Build via editor Build panel or `dotnet build`. |

### Gaps vs PRD abstract tools

| PRD abstract tool / capability | godot-ai mapping | Gap |
|-------------------------------|------------------|-----|
| `scene_inspect` / `node_inspect` / `property_inspect` | `scene_get_hierarchy`, `node_get_properties`, resources | Covered |
| `node_edit` / `property_set` / `scene_instance` | `node_*`, `node_manage`, `scene_*`, `resource_manage` | Covered (naming differs) |
| `script_patch` | `script_patch` | Covered (GDScript); C# incomplete vs PRD “detect parse errors” |
| `settings_inspect` / Input Map | `project_manage(settings_*)`, `input_map_manage` | Covered |
| `animation_inspect` / `animation_edit` | `animation_manage` / `animation_create` | AnimationPlayer covered |
| `animation_tree_inspect` / `animation_tree_edit` | — | **Missing** |
| `runtime_control` / `playtest_*` | `project_run` / `stop`, `game_manage`, screenshot | Covered |
| `runtime_errors` | `logs_read` + doorbells | Covered for GDScript/engine; not C# build |
| Agent-triggered undo / rollback | Editor UndoRedo + `batch_execute` failure rollback | **No deliberate undo tool** |
| `docs_search` / `web_search` | Outside godot-ai (client/LLM side) | Expected — not an editor MCP gap |
| Capability registry (`animation_tree: true`, …) | Tool domains / excluded domains in dock | Shape differs; AnimationTree must be treated false |
| Autonomy / permission UX (PRD §41) | Not evaluated as MCP tool surface | Product gap if building GodotAgent shell |

---

## Top 3 gaps

1. **AnimationTree authoring absent** — blocks V1 animation acceptance and the PRD’s canonical verify/fix loop for locomotion / dash transitions.  
2. **No agent-callable undo** — mutations are editor-undoable and batches can roll back on error, but the agent cannot issue undo after a “successful but wrong” change.  
3. **C# is text-only** — fine for GDScript-first V1; any C# project loses compile/reload/diagnostics parity that the PRD assumes for script iteration.

---

## Out of scope (this deliverable)

- hybridindie evaluation  
- GodotAgent agent core / Python adapters  
- Modifying the Steam Godot install  
- Live smoke against a running editor (scores are **documentation-grounded**, not runtime-verified)
