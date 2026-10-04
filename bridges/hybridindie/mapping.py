"""AbstractGodotTools → hybridindie / godot-editor-mcp tool mapping.

Source of truth for V1 names/params: hybridindie docs for ``godot-editor-mcp``
``2026.09.30`` (193 tools) — especially
https://hybridindie.github.io/godot-mcp/reference-toolsets.html.md and
``docs/tool-contracts.md`` on hybridindie/godot-mcp.

This module is data only: the adapter interprets operation-specific rows and
builds MCP argument dicts. Agent Core never imports this file.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Mapping, Optional, Sequence


# Toolsets that must be seeded for Cursor (clients often ignore tools/list_changed).
# Include ``inspection`` explicitly: live 2026.09.30 servers may leave it disabled
# unless seeded (docs historically called it always-on with ``core``).
V1_DEFAULT_TOOLSETS: tuple[str, ...] = (
    "inspection",
    "scene_edit",
    "scripts",
    "input_map",
    "animation",
    "tilemap",
    "runtime",
    "input",
    "editor",
    "debugger",
    "project",
    "resources_edit",
    "composite",
)

# Treated as always available by the adapter once the server is up.
# Still seed ``inspection`` via GODOT_MCP_DEFAULT_TOOLSETS for Cursor honesty.
ALWAYS_ON_TOOLSETS: frozenset[str] = frozenset({"core", "inspection"})

# Env value recommended for Cursor mcp.json.
GODOT_MCP_DEFAULT_TOOLSETS_SEED: str = ",".join(V1_DEFAULT_TOOLSETS)

RUNTIME_PROBE_AUTOLOAD: str = "MCPRuntimeProbe"
RUNTIME_PROBE_SCRIPT: str = "res://addons/godot_mcp/mcp_runtime_probe.gd"


@dataclass(frozen=True)
class McpMapping:
    """One abstract method → one or more MCP tools."""

    abstract_method: str
    mcp_tools: tuple[str, ...]
    toolsets: frozenset[str]
    notes: str = ""
    requires_runtime_probe: bool = False
    requires_play_session: bool = False
    # When True, adapter may sleep locally (no dedicated MCP wait tool).
    local_only: bool = False


# Primary mapping table (operation variants listed as multiple mcp_tools).
ABSTRACT_TO_MCP: Mapping[str, McpMapping] = {
    "inspect_project": McpMapping(
        abstract_method="inspect_project",
        mcp_tools=("godot_inspection_get_project_info",),
        toolsets=frozenset({"inspection"}),
        notes="Always-on. Returns name, godot_version, main_scene, autoloads, input_actions.",
    ),
    "inspect_scene": McpMapping(
        abstract_method="inspect_scene",
        mcp_tools=(
            "godot_scene_edit_open_scene",
            "godot_inspection_get_scene_tree",
            "godot_inspection_get_active_scene",
        ),
        toolsets=frozenset({"inspection", "scene_edit"}),
        notes=(
            "get_scene_tree reads the *active* editor scene. If args.scene_path differs, "
            "adapter opens via godot_scene_edit_open_scene first (needs scene_edit). "
            "Params: max_depth=-1, lightweight=False."
        ),
    ),
    "inspect_node": McpMapping(
        abstract_method="inspect_node",
        mcp_tools=(
            "godot_inspection_get_node_properties",
            "godot_inspection_get_node_property_list",
            "godot_inspection_snapshot_subtree",
        ),
        toolsets=frozenset({"inspection"}),
        notes=(
            "Primary: get_node_properties(node_path). "
            "include_children → snapshot_subtree; built-in props need get_node_property."
        ),
    ),
    "set_property": McpMapping(
        abstract_method="set_property",
        mcp_tools=("godot_scene_edit_set_node_property",),
        toolsets=frozenset({"scene_edit"}),
        notes="Args: node_path, property, value. Mutating; supports dry_run.",
    ),
    "edit_node": McpMapping(
        abstract_method="edit_node",
        mcp_tools=(
            "godot_scene_edit_create_node",
            "godot_scene_edit_delete_node",
            "godot_scene_edit_rename_node",
            "godot_scene_edit_duplicate_node",
            "godot_scene_edit_move_node",
        ),
        toolsets=frozenset({"scene_edit"}),
        notes=(
            "operation create|delete|rename|duplicate|reparent → matching scene_edit tool. "
            "delete is destructive (confirm=True). reparent → move_node(new_parent_path)."
        ),
    ),
    "create_scene": McpMapping(
        abstract_method="create_scene",
        mcp_tools=("godot_scene_edit_create_scene",),
        toolsets=frozenset({"scene_edit"}),
        notes="Args: scene_path, root_type. Never host-write .tscn.",
    ),
    "save_scene": McpMapping(
        abstract_method="save_scene",
        mcp_tools=("godot_scene_edit_save_scene",),
        toolsets=frozenset({"scene_edit"}),
        notes="Saves the currently edited scene.",
    ),
    "attach_script": McpMapping(
        abstract_method="attach_script",
        mcp_tools=("godot_scene_edit_attach_script",),
        toolsets=frozenset({"scene_edit"}),
        notes="Args: node_path, script_path.",
    ),
    "patch_script": McpMapping(
        abstract_method="patch_script",
        mcp_tools=("godot_scripts_patch", "godot_scripts_write"),
        toolsets=frozenset({"scripts"}),
        notes=(
            "Native patch is find/replace: godot_scripts_patch(script_path, find, replace). "
            "format=full_replace → godot_scripts_write(content). "
            "format=find_replace → JSON patch {find, replace}. "
            "unified_diff is not native (structured error). GDScript-only; C# patch Phase-2-blocked."
        ),
    ),
    "read_script": McpMapping(
        abstract_method="read_script",
        mcp_tools=("godot_scripts_read",),
        toolsets=frozenset({"scripts"}),
        notes="Args: script_path. Optional line slice applied client-side after read.",
    ),
    "settings_get": McpMapping(
        abstract_method="settings_get",
        mcp_tools=(
            "godot_project_get_setting",
            "godot_input_map_get_action_events",
            "godot_inspection_get_project_info",
        ),
        toolsets=frozenset({"project", "input_map", "inspection"}),
        notes=(
            "section=project → godot_project_get_setting(name=key). "
            "section=input_map → godot_input_map_get_action_events(action=key)."
        ),
    ),
    "settings_set": McpMapping(
        abstract_method="settings_set",
        mcp_tools=(
            "godot_project_set_setting",
            "godot_input_map_add_action",
            "godot_input_map_add_event",
            "godot_input_map_remove_action",
        ),
        toolsets=frozenset({"project", "input_map"}),
        notes=(
            "section=project → set_setting(name, value). "
            "section=input_map → add_action / add_event / remove_action from value shape."
        ),
    ),
    "animation_inspect": McpMapping(
        abstract_method="animation_inspect",
        mcp_tools=("godot_animation_list_animations", "godot_animation_get"),
        toolsets=frozenset({"animation"}),
        notes=(
            "list_animations(node_path); if animation_name set → get(node_path, animation_name)."
        ),
    ),
    "animation_edit": McpMapping(
        abstract_method="animation_edit",
        mcp_tools=(
            "godot_animation_create",
            "godot_animation_add_track",
            "godot_animation_insert_keyframe",
        ),
        toolsets=frozenset({"animation"}),
        notes=(
            "create → create(node_path, name, length). "
            "add_track|set_track → add_track. set_key|insert_key → insert_keyframe."
        ),
    ),
    "animation_tree_inspect": McpMapping(
        abstract_method="animation_tree_inspect",
        mcp_tools=(
            "godot_inspection_get_node_properties",
            "godot_animation_list_animations",
        ),
        toolsets=frozenset({"inspection", "animation"}),
        notes=(
            "No dedicated AnimationTree dump tool. Primary: get_node_properties on the tree. "
            "Optional list_animations if an AnimationPlayer path is in params. "
            "hybridindie is the only V1 bridge with AnimationTree *authoring* ops."
        ),
    ),
    "animation_tree_edit": McpMapping(
        abstract_method="animation_tree_edit",
        mcp_tools=(
            "godot_animation_create_tree",
            "godot_animation_add_state_machine_state",
            "godot_animation_set_blend_tree_node",
        ),
        toolsets=frozenset({"animation"}),
        notes=(
            "create_tree(parent_path, name, anim_player?, root_type). "
            "add_state|add_state_machine_state → add_state_machine_state(tree_path, state_name). "
            "set_blend|set_blend_tree_node → set_blend_tree_node(tree_path, node_name, node_type). "
            "Requires AnimationNodeStateMachine or BlendTree root as documented."
        ),
    ),
    "run_game": McpMapping(
        abstract_method="run_game",
        mcp_tools=("godot_runtime_play_scene",),
        toolsets=frozenset({"runtime"}),
        notes=(
            "play_scene(scene_path?). No runtime probe required for play/stop. "
            "Headless alternative godot_runtime_run_and_capture may need GODOT_MCP_GODOT_BIN on Steam."
        ),
        requires_play_session=False,
        requires_runtime_probe=False,
    ),
    "stop_game": McpMapping(
        abstract_method="stop_game",
        mcp_tools=("godot_runtime_stop_scene",),
        toolsets=frozenset({"runtime"}),
        notes="stop_scene() — no params.",
    ),
    "playtest_input": McpMapping(
        abstract_method="playtest_input",
        mcp_tools=(
            "godot_input_simulate_action",
            "godot_input_simulate_key",
            "godot_input_simulate_mouse",
            "godot_input_play_sequence",
        ),
        toolsets=frozenset({"input"}),
        notes=(
            "kind=action → simulate_action(action, pressed, strength). "
            "kind=key → simulate_key(key, pressed, modifiers from extras). "
            "kind=mouse_* → simulate_mouse(x, y, button, …). "
            "REQUIRES runtime probe autoload + live play session."
        ),
        requires_runtime_probe=True,
        requires_play_session=True,
    ),
    "playtest_wait": McpMapping(
        abstract_method="playtest_wait",
        mcp_tools=(),
        toolsets=frozenset({"runtime"}),
        notes=(
            "No dedicated MCP wait tool. Adapter sleeps locally for args.seconds; "
            "optional until=playing|stopped polls godot_runtime_is_playing."
        ),
        local_only=True,
    ),
    "observe_runtime": McpMapping(
        abstract_method="observe_runtime",
        mcp_tools=(
            "godot_runtime_get_game_output",
            "godot_runtime_get_game_scene_tree",
            "godot_runtime_read_property",
            "godot_runtime_monitor_property",
        ),
        toolsets=frozenset({"runtime"}),
        notes=(
            "include_errors → get_game_output. node_path → scene tree and/or read_property. "
            "REQUIRES runtime probe + play session for live tree/property/output."
        ),
        requires_runtime_probe=True,
        requires_play_session=True,
    ),
    "capture_viewport": McpMapping(
        abstract_method="capture_viewport",
        mcp_tools=(
            "godot_runtime_capture_game_screenshot",
            "godot_editor_capture_screenshot",
        ),
        toolsets=frozenset({"runtime", "editor"}),
        notes=(
            "V1 game viewport → capture_game_screenshot (probe + play session). "
            "Editor UI only → editor_capture_screenshot (not game pixels)."
        ),
        requires_runtime_probe=True,
        requires_play_session=True,
    ),
    "get_diagnostics": McpMapping(
        abstract_method="get_diagnostics",
        mcp_tools=(
            "godot_debug_workflow",
            "godot_scripts_get_parse_errors",
            "godot_runtime_get_game_output",
            "godot_health_check",
        ),
        toolsets=frozenset({"core", "scripts", "runtime"}),
        notes=(
            "scope=all → debug_workflow (core). script → get_parse_errors. "
            "runtime → get_game_output (probe). editor → health_check."
        ),
    ),
    "undo": McpMapping(
        abstract_method="undo",
        mcp_tools=("godot_undo", "godot_list_history"),
        toolsets=frozenset({"core"}),
        notes=(
            "Always-on core: godot_undo(count=steps). Some batch/file ops report undoable:false — "
            "prefer UndoRedo-wrapped scene edits for acceptance test #12."
        ),
    ),
    # Tile tools live under the tilemap toolset; MCP names are godot_tilemap_* (not godot_tileset_*).
    "tileset_create": McpMapping(
        abstract_method="tileset_create",
        mcp_tools=("godot_tilemap_create_tileset",),
        toolsets=frozenset({"tilemap"}),
        notes="tile_size [w,h]; node_path and/or save_path required by bridge.",
    ),
    "tileset_add_atlas": McpMapping(
        abstract_method="tileset_add_atlas",
        mcp_tools=("godot_tilemap_add_tileset_atlas_source",),
        toolsets=frozenset({"tilemap"}),
        notes="texture_path + node_path XOR tileset_path; optional source_id / texture_region_size.",
    ),
    "tileset_create_tile": McpMapping(
        abstract_method="tileset_create_tile",
        mcp_tools=("godot_tilemap_create_tile",),
        toolsets=frozenset({"tilemap"}),
        notes="atlas_coords + source_id on node-backed or file-backed TileSet.",
    ),
    "tileset_inspect": McpMapping(
        abstract_method="tileset_inspect",
        mcp_tools=("godot_inspection_get_node_properties",),
        toolsets=frozenset({"inspection", "tilemap"}),
        notes=(
            "No dedicated tileset dump tool — inspect TileMapLayer tile_set via node properties "
            "when node_path is set."
        ),
    ),
    "tilemap_inspect": McpMapping(
        abstract_method="tilemap_inspect",
        mcp_tools=("godot_tilemap_layers", "godot_tilemap_get_used_cells"),
        toolsets=frozenset({"tilemap"}),
        notes="layers always; used cells only when include_used_cells=True (token control).",
    ),
    "tilemap_get_cell": McpMapping(
        abstract_method="tilemap_get_cell",
        mcp_tools=("godot_tilemap_get_cell",),
        toolsets=frozenset({"tilemap"}),
    ),
    "tilemap_set_cell": McpMapping(
        abstract_method="tilemap_set_cell",
        mcp_tools=("godot_tilemap_set_cell",),
        toolsets=frozenset({"tilemap"}),
    ),
    "tilemap_fill_rect": McpMapping(
        abstract_method="tilemap_fill_rect",
        mcp_tools=("godot_tilemap_fill_rect",),
        toolsets=frozenset({"tilemap"}),
        notes="rect=[x,y,w,h]; bridge caps fill at 16384 cells.",
    ),
    "tilemap_clear": McpMapping(
        abstract_method="tilemap_clear",
        mcp_tools=("godot_tilemap_clear",),
        toolsets=frozenset({"tilemap"}),
    ),
}


def mapping_for(abstract_method: str) -> Optional[McpMapping]:
    return ABSTRACT_TO_MCP.get(abstract_method)


def required_toolsets(abstract_method: str) -> frozenset[str]:
    row = ABSTRACT_TO_MCP.get(abstract_method)
    if row is None:
        return frozenset()
    # Always-on sets are never "missing" once the server is up.
    return frozenset(t for t in row.toolsets if t not in ALWAYS_ON_TOOLSETS)


def all_mapped_mcp_tools() -> Sequence[str]:
    names: list[str] = []
    seen: set[str] = set()
    for row in ABSTRACT_TO_MCP.values():
        for name in row.mcp_tools:
            if name not in seen:
                seen.add(name)
                names.append(name)
    return names
