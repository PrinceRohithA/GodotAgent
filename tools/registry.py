"""Capability registry — what the connected bridge actually supports.

The model must not assume unsupported capabilities (PRD §34).
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Mapping, MutableMapping, Optional, Set

from tools.schemas import ToolRisk


# Canonical capability flags reported by a bridge at connect time.
DEFAULT_CAPABILITIES: Mapping[str, bool] = {
    "scene_editing": False,
    "property_editing": False,
    "resource_editing": False,
    "script_editing": False,
    "animation_player": False,
    "animation_tree": False,
    "tilemap_editing": False,
    "spatial_observation": False,
    "runtime_debugger": False,
    "viewport_capture": False,
    "project_settings": False,
    "playtest": False,
    "documentation_search": False,
}


# Map abstract tool method names → required capability flag(s).
TOOL_CAPABILITY_REQUIREMENTS: Mapping[str, frozenset[str]] = {
    "inspect_project": frozenset({"project_settings"}),
    "inspect_scene": frozenset({"scene_editing"}),
    "inspect_node": frozenset({"scene_editing"}),
    "set_property": frozenset({"property_editing"}),
    "edit_node": frozenset({"scene_editing"}),
    "create_scene": frozenset({"scene_editing"}),
    "save_scene": frozenset({"scene_editing"}),
    "attach_script": frozenset({"scene_editing", "script_editing"}),
    "patch_script": frozenset({"script_editing"}),
    "read_script": frozenset({"script_editing"}),
    "settings_get": frozenset({"project_settings"}),
    "settings_set": frozenset({"project_settings"}),
    "animation_inspect": frozenset({"animation_player"}),
    "animation_edit": frozenset({"animation_player"}),
    "animation_tree_inspect": frozenset({"animation_tree"}),
    "animation_tree_edit": frozenset({"animation_tree"}),
    "create_sprite_frames": frozenset({"animation_player", "resource_editing"}),
    "nodes_create_batch": frozenset({"scene_editing"}),
    "nodes_edit_batch": frozenset({"scene_editing", "property_editing"}),
    "spatial_observe": frozenset({"spatial_observation"}),
    "observe": frozenset({"spatial_observation", "runtime_debugger"}),
    "runtime_tree": frozenset({"runtime_debugger"}),
    "runtime_node_inspect": frozenset({"runtime_debugger"}),
    "runtime_get_property": frozenset({"runtime_debugger"}),
    "runtime_set_property": frozenset({"runtime_debugger"}),
    "debug_status": frozenset({"runtime_debugger"}),
    "debug_control": frozenset({"runtime_debugger"}),
    "debug_breakpoint": frozenset({"runtime_debugger"}),
    "debug_stack": frozenset({"runtime_debugger"}),
    "debug_error": frozenset({"runtime_debugger"}),
    "debug_state": frozenset({"runtime_debugger"}),
    "debug_visuals": frozenset({"runtime_debugger"}),
    "debug_profiler": frozenset({"runtime_debugger"}),
    "tileset_create": frozenset({"tilemap_editing"}),
    "tileset_add_atlas": frozenset({"tilemap_editing"}),
    "tileset_create_tile": frozenset({"tilemap_editing"}),
    "tileset_inspect": frozenset({"tilemap_editing"}),
    "tileset_atlas_inspect": frozenset({"tilemap_editing"}),
    "get_tile_data": frozenset({"tilemap_editing"}),
    "add_tileset_physics_layer": frozenset({"tilemap_editing"}),
    "set_tile_collision": frozenset({"tilemap_editing"}),
    "clear_tile_collision": frozenset({"tilemap_editing"}),
    "tilemap_layer_set_physics": frozenset({"tilemap_editing"}),
    "tilemap_set_cells_batch": frozenset({"tilemap_editing"}),
    "add_tileset_custom_data_layer": frozenset({"tilemap_editing"}),
    "set_tile_custom_data": frozenset({"tilemap_editing"}),
    "add_tileset_terrain_set": frozenset({"tilemap_editing"}),
    "add_tileset_terrain": frozenset({"tilemap_editing"}),
    "set_tile_terrain": frozenset({"tilemap_editing"}),
    "tilemap_set_terrain": frozenset({"tilemap_editing"}),
    "tileset_add_pattern": frozenset({"tilemap_editing"}),
    "tilemap_set_pattern": frozenset({"tilemap_editing"}),
    "create_alternative_tile": frozenset({"tilemap_editing"}),
    "set_tile_animation": frozenset({"tilemap_editing"}),
    "add_tileset_navigation_layer": frozenset({"tilemap_editing"}),
    "set_tile_navigation": frozenset({"tilemap_editing"}),
    "tilemap_layer_set_navigation": frozenset({"tilemap_editing"}),
    "add_tileset_occlusion_layer": frozenset({"tilemap_editing"}),
    "set_tile_occlusion": frozenset({"tilemap_editing"}),
    "add_tileset_scenes_collection_source": frozenset({"tilemap_editing"}),
    "create_scene_tile": frozenset({"tilemap_editing"}),
    "set_tile_constant_velocity": frozenset({"tilemap_editing"}),
    "tilemap_layer_set_kinematic": frozenset({"tilemap_editing"}),
    "tilemap_inspect": frozenset({"tilemap_editing"}),
    "tilemap_get_cell": frozenset({"tilemap_editing"}),
    "tilemap_set_cell": frozenset({"tilemap_editing"}),
    "tilemap_fill_rect": frozenset({"tilemap_editing"}),
    "tilemap_clear": frozenset({"tilemap_editing"}),
    "run_game": frozenset({"playtest"}),
    "stop_game": frozenset({"playtest"}),
    "playtest_input": frozenset({"playtest"}),
    "playtest_wait": frozenset({"playtest"}),
    "observe_runtime": frozenset({"runtime_debugger"}),
    "capture_viewport": frozenset({"viewport_capture"}),
    "get_diagnostics": frozenset(),  # always available if bridge is connected
    "undo": frozenset(
        {"scene_editing", "property_editing", "script_editing", "tilemap_editing"}
    ),
}


TOOL_RISK_LEVELS: Mapping[str, ToolRisk] = {
    "inspect_project": ToolRisk.READ,
    "inspect_scene": ToolRisk.READ,
    "inspect_node": ToolRisk.READ,
    "set_property": ToolRisk.WRITE,
    "edit_node": ToolRisk.WRITE,
    "create_scene": ToolRisk.WRITE,
    "save_scene": ToolRisk.WRITE,
    "attach_script": ToolRisk.WRITE,
    "patch_script": ToolRisk.WRITE,
    "read_script": ToolRisk.READ,
    "settings_get": ToolRisk.READ,
    "settings_set": ToolRisk.WRITE,
    "animation_inspect": ToolRisk.READ,
    "animation_edit": ToolRisk.WRITE,
    "animation_tree_inspect": ToolRisk.READ,
    "animation_tree_edit": ToolRisk.WRITE,
    "create_sprite_frames": ToolRisk.WRITE,
    "nodes_create_batch": ToolRisk.WRITE,
    "nodes_edit_batch": ToolRisk.WRITE,
    "spatial_observe": ToolRisk.READ,
    "observe": ToolRisk.READ,
    "runtime_tree": ToolRisk.READ,
    "runtime_node_inspect": ToolRisk.READ,
    "runtime_get_property": ToolRisk.READ,
    "runtime_set_property": ToolRisk.WRITE,
    "debug_status": ToolRisk.READ,
    "debug_control": ToolRisk.EXECUTE,
    "debug_breakpoint": ToolRisk.WRITE,
    "debug_stack": ToolRisk.READ,
    "debug_error": ToolRisk.READ,
    "debug_state": ToolRisk.READ,
    "debug_visuals": ToolRisk.WRITE,
    "debug_profiler": ToolRisk.READ,
    "tileset_create": ToolRisk.WRITE,
    "tileset_add_atlas": ToolRisk.WRITE,
    "tileset_create_tile": ToolRisk.WRITE,
    "tileset_inspect": ToolRisk.READ,
    "tileset_atlas_inspect": ToolRisk.READ,
    "get_tile_data": ToolRisk.READ,
    "add_tileset_physics_layer": ToolRisk.WRITE,
    "set_tile_collision": ToolRisk.WRITE,
    "clear_tile_collision": ToolRisk.WRITE,
    "tilemap_layer_set_physics": ToolRisk.WRITE,
    "tilemap_set_cells_batch": ToolRisk.WRITE,
    "add_tileset_custom_data_layer": ToolRisk.WRITE,
    "set_tile_custom_data": ToolRisk.WRITE,
    "add_tileset_terrain_set": ToolRisk.WRITE,
    "add_tileset_terrain": ToolRisk.WRITE,
    "set_tile_terrain": ToolRisk.WRITE,
    "tilemap_set_terrain": ToolRisk.WRITE,
    "tileset_add_pattern": ToolRisk.WRITE,
    "tilemap_set_pattern": ToolRisk.WRITE,
    "create_alternative_tile": ToolRisk.WRITE,
    "set_tile_animation": ToolRisk.WRITE,
    "add_tileset_navigation_layer": ToolRisk.WRITE,
    "set_tile_navigation": ToolRisk.WRITE,
    "tilemap_layer_set_navigation": ToolRisk.WRITE,
    "add_tileset_occlusion_layer": ToolRisk.WRITE,
    "set_tile_occlusion": ToolRisk.WRITE,
    "add_tileset_scenes_collection_source": ToolRisk.WRITE,
    "create_scene_tile": ToolRisk.WRITE,
    "set_tile_constant_velocity": ToolRisk.WRITE,
    "tilemap_layer_set_kinematic": ToolRisk.WRITE,
    "tilemap_inspect": ToolRisk.READ,
    "tilemap_get_cell": ToolRisk.READ,
    "tilemap_set_cell": ToolRisk.WRITE,
    "tilemap_fill_rect": ToolRisk.WRITE,
    "tilemap_clear": ToolRisk.DESTRUCTIVE,
    "run_game": ToolRisk.EXECUTE,
    "stop_game": ToolRisk.EXECUTE,
    "playtest_input": ToolRisk.EXECUTE,
    "playtest_wait": ToolRisk.READ,
    "observe_runtime": ToolRisk.READ,
    "capture_viewport": ToolRisk.READ,
    "get_diagnostics": ToolRisk.READ,
    "undo": ToolRisk.WRITE,
}


@dataclass
class CapabilityRegistry:
    """Holds bridge-reported capabilities and answers availability queries."""

    godot_version: str = "unknown"
    capabilities: MutableMapping[str, bool] = field(
        default_factory=lambda: dict(DEFAULT_CAPABILITIES)
    )
    bridge_id: Optional[str] = None

    def update_from_bridge(
        self,
        *,
        godot_version: str,
        capabilities: Mapping[str, bool],
        bridge_id: Optional[str] = None,
    ) -> None:
        self.godot_version = godot_version
        if bridge_id is not None:
            self.bridge_id = bridge_id
        for key, value in capabilities.items():
            self.capabilities[key] = bool(value)

    def is_capability_enabled(self, name: str) -> bool:
        return bool(self.capabilities.get(name, False))

    def supported_tools(self) -> Set[str]:
        return {name for name in TOOL_CAPABILITY_REQUIREMENTS if self.tool_available(name)}

    def tool_available(self, tool_name: str) -> bool:
        required = TOOL_CAPABILITY_REQUIREMENTS.get(tool_name)
        if required is None:
            return False
        if not required:
            return True
        # undo: available if any of the listed mutation caps is on
        if tool_name == "undo":
            return any(self.is_capability_enabled(c) for c in required)
        return all(self.is_capability_enabled(c) for c in required)

    def risk_for(self, tool_name: str) -> Optional[ToolRisk]:
        return TOOL_RISK_LEVELS.get(tool_name)

    def as_dict(self) -> Mapping[str, object]:
        return {
            "godot_version": self.godot_version,
            "bridge_id": self.bridge_id,
            "capabilities": dict(self.capabilities),
            "supported_tools": sorted(self.supported_tools()),
        }
