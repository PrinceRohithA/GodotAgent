"""hi-godot / godot-ai bridge adapter — STUB ONLY.

Do not import MCP clients or clone the upstream repo here.
A future implementation maps each ``AbstractGodotTools`` method to the
godot-ai MCP tool surface and normalizes results into ``ToolResult``.
"""

from __future__ import annotations

from typing import Mapping, NoReturn

from bridges.base import BridgeInfo
from tools.registry import CapabilityRegistry
from tools.schemas import (
    AnimationEditArgs,
    AnimationInspectArgs,
    AnimationTreeEditArgs,
    AnimationTreeInspectArgs,
    CaptureViewportArgs,
    EditNodeArgs,
    GetDiagnosticsArgs,
    InspectNodeArgs,
    InspectProjectArgs,
    InspectSceneArgs,
    ObserveRuntimeArgs,
    PatchScriptArgs,
    PlaytestInputArgs,
    PlaytestWaitArgs,
    ReadScriptArgs,
    RunGameArgs,
    SetPropertyArgs,
    SettingsGetArgs,
    SettingsSetArgs,
    StopGameArgs,
    TilemapClearArgs,
    TilemapFillRectArgs,
    TilemapGetCellArgs,
    TilemapInspectArgs,
    TilemapSetCellArgs,
    TilesetAddAtlasArgs,
    TilesetCreateArgs,
    TilesetCreateTileArgs,
    TilesetInspectArgs,
    ToolResult,
    UndoArgs,
)


class GodotAiBridgeAdapter:
    """Stub: raises until real MCP mapping is implemented."""

    BRIDGE_ID = "godot_ai"

    def __init__(self) -> None:
        self._info: BridgeInfo | None = None

    def connect(self) -> BridgeInfo:
        # TODO: open MCP session to godot-ai and query capability report
        raise NotImplementedError(
            "GodotAiBridgeAdapter.connect: MCP wiring not implemented "
            "(do not clone hi-godot/godot-ai in Agent Core)"
        )

    def disconnect(self) -> None:
        raise NotImplementedError("GodotAiBridgeAdapter.disconnect: not implemented")

    def bridge_info(self) -> BridgeInfo:
        if self._info is None:
            raise NotImplementedError("GodotAiBridgeAdapter: not connected")
        return self._info

    def apply_capabilities(self, registry: CapabilityRegistry) -> CapabilityRegistry:
        info = self.bridge_info()
        registry.update_from_bridge(
            godot_version=info.godot_version,
            capabilities=info.capabilities,
            bridge_id=info.bridge_id,
        )
        return registry

    # --- AbstractGodotTools (all stubs) ---

    def inspect_project(self, args: InspectProjectArgs) -> ToolResult:
        return self._todo("inspect_project", args)

    def inspect_scene(self, args: InspectSceneArgs) -> ToolResult:
        return self._todo("inspect_scene", args)

    def inspect_node(self, args: InspectNodeArgs) -> ToolResult:
        return self._todo("inspect_node", args)

    def set_property(self, args: SetPropertyArgs) -> ToolResult:
        return self._todo("set_property", args)

    def edit_node(self, args: EditNodeArgs) -> ToolResult:
        return self._todo("edit_node", args)

    def create_scene(self, args: object) -> ToolResult:
        return self._todo("create_scene", args)

    def save_scene(self, args: object) -> ToolResult:
        return self._todo("save_scene", args)

    def attach_script(self, args: object) -> ToolResult:
        return self._todo("attach_script", args)

    def patch_script(self, args: PatchScriptArgs) -> ToolResult:
        return self._todo("patch_script", args)

    def read_script(self, args: ReadScriptArgs) -> ToolResult:
        return self._todo("read_script", args)

    def settings_get(self, args: SettingsGetArgs) -> ToolResult:
        return self._todo("settings_get", args)

    def settings_set(self, args: SettingsSetArgs) -> ToolResult:
        return self._todo("settings_set", args)

    def animation_inspect(self, args: AnimationInspectArgs) -> ToolResult:
        return self._todo("animation_inspect", args)

    def animation_edit(self, args: AnimationEditArgs) -> ToolResult:
        return self._todo("animation_edit", args)

    def animation_tree_inspect(self, args: AnimationTreeInspectArgs) -> ToolResult:
        return self._todo("animation_tree_inspect", args)

    def animation_tree_edit(self, args: AnimationTreeEditArgs) -> ToolResult:
        return self._todo("animation_tree_edit", args)

    def run_game(self, args: RunGameArgs) -> ToolResult:
        return self._todo("run_game", args)

    def stop_game(self, args: StopGameArgs) -> ToolResult:
        return self._todo("stop_game", args)

    def playtest_input(self, args: PlaytestInputArgs) -> ToolResult:
        return self._todo("playtest_input", args)

    def playtest_wait(self, args: PlaytestWaitArgs) -> ToolResult:
        return self._todo("playtest_wait", args)

    def observe_runtime(self, args: ObserveRuntimeArgs) -> ToolResult:
        return self._todo("observe_runtime", args)

    def capture_viewport(self, args: CaptureViewportArgs) -> ToolResult:
        return self._todo("capture_viewport", args)

    def get_diagnostics(self, args: GetDiagnosticsArgs) -> ToolResult:
        return self._todo("get_diagnostics", args)

    def undo(self, args: UndoArgs) -> ToolResult:
        return self._todo("undo", args)

    def tileset_create(self, args: TilesetCreateArgs) -> ToolResult:
        return self._todo("tileset_create", args)

    def tileset_add_atlas(self, args: TilesetAddAtlasArgs) -> ToolResult:
        return self._todo("tileset_add_atlas", args)

    def tileset_create_tile(self, args: TilesetCreateTileArgs) -> ToolResult:
        return self._todo("tileset_create_tile", args)

    def tileset_inspect(self, args: TilesetInspectArgs) -> ToolResult:
        return self._todo("tileset_inspect", args)

    def tileset_atlas_inspect(self, args: object) -> ToolResult:
        return self._todo("tileset_atlas_inspect", args)

    def get_tile_data(self, args: object) -> ToolResult:
        return self._todo("get_tile_data", args)

    def add_tileset_physics_layer(self, args: object) -> ToolResult:
        return self._todo("add_tileset_physics_layer", args)

    def set_tile_collision(self, args: object) -> ToolResult:
        return self._todo("set_tile_collision", args)

    def clear_tile_collision(self, args: object) -> ToolResult:
        return self._todo("clear_tile_collision", args)

    def tilemap_layer_set_physics(self, args: object) -> ToolResult:
        return self._todo("tilemap_layer_set_physics", args)

    def tilemap_set_cells_batch(self, args: object) -> ToolResult:
        return self._todo("tilemap_set_cells_batch", args)

    def add_tileset_custom_data_layer(self, args: object) -> ToolResult:
        return self._todo("add_tileset_custom_data_layer", args)

    def set_tile_custom_data(self, args: object) -> ToolResult:
        return self._todo("set_tile_custom_data", args)

    def add_tileset_terrain_set(self, args: object) -> ToolResult:
        return self._todo("add_tileset_terrain_set", args)

    def add_tileset_terrain(self, args: object) -> ToolResult:
        return self._todo("add_tileset_terrain", args)

    def set_tile_terrain(self, args: object) -> ToolResult:
        return self._todo("set_tile_terrain", args)

    def tilemap_set_terrain(self, args: object) -> ToolResult:
        return self._todo("tilemap_set_terrain", args)

    def tileset_add_pattern(self, args: object) -> ToolResult:
        return self._todo("tileset_add_pattern", args)

    def tilemap_set_pattern(self, args: object) -> ToolResult:
        return self._todo("tilemap_set_pattern", args)

    def create_alternative_tile(self, args: object) -> ToolResult:
        return self._todo("create_alternative_tile", args)

    def set_tile_animation(self, args: object) -> ToolResult:
        return self._todo("set_tile_animation", args)

    def add_tileset_navigation_layer(self, args: object) -> ToolResult:
        return self._todo("add_tileset_navigation_layer", args)

    def set_tile_navigation(self, args: object) -> ToolResult:
        return self._todo("set_tile_navigation", args)

    def tilemap_layer_set_navigation(self, args: object) -> ToolResult:
        return self._todo("tilemap_layer_set_navigation", args)

    def add_tileset_occlusion_layer(self, args: object) -> ToolResult:
        return self._todo("add_tileset_occlusion_layer", args)

    def set_tile_occlusion(self, args: object) -> ToolResult:
        return self._todo("set_tile_occlusion", args)

    def add_tileset_scenes_collection_source(self, args: object) -> ToolResult:
        return self._todo("add_tileset_scenes_collection_source", args)

    def create_scene_tile(self, args: object) -> ToolResult:
        return self._todo("create_scene_tile", args)

    def set_tile_constant_velocity(self, args: object) -> ToolResult:
        return self._todo("set_tile_constant_velocity", args)

    def tilemap_layer_set_kinematic(self, args: object) -> ToolResult:
        return self._todo("tilemap_layer_set_kinematic", args)

    def tilemap_inspect(self, args: TilemapInspectArgs) -> ToolResult:
        return self._todo("tilemap_inspect", args)

    def tilemap_get_cell(self, args: TilemapGetCellArgs) -> ToolResult:
        return self._todo("tilemap_get_cell", args)

    def tilemap_set_cell(self, args: TilemapSetCellArgs) -> ToolResult:
        return self._todo("tilemap_set_cell", args)

    def tilemap_fill_rect(self, args: TilemapFillRectArgs) -> ToolResult:
        return self._todo("tilemap_fill_rect", args)

    def tilemap_clear(self, args: TilemapClearArgs) -> ToolResult:
        return self._todo("tilemap_clear", args)

    def create_sprite_frames(self, args: object) -> ToolResult:
        return self._todo("create_sprite_frames", args)

    def nodes_create_batch(self, args: object) -> ToolResult:
        return self._todo("nodes_create_batch", args)

    def nodes_edit_batch(self, args: object) -> ToolResult:
        return self._todo("nodes_edit_batch", args)

    def spatial_observe(self, args: object) -> ToolResult:
        return self._todo("spatial_observe", args)

    def observe(self, args: object) -> ToolResult:
        return self._todo("observe", args)

    def runtime_tree(self, args: object) -> ToolResult:
        return self._todo("runtime_tree", args)

    def runtime_node_inspect(self, args: object) -> ToolResult:
        return self._todo("runtime_node_inspect", args)

    def runtime_get_property(self, args: object) -> ToolResult:
        return self._todo("runtime_get_property", args)

    def runtime_set_property(self, args: object) -> ToolResult:
        return self._todo("runtime_set_property", args)

    def debug_status(self, args: object) -> ToolResult:
        return self._todo("debug_status", args)

    def debug_control(self, args: object) -> ToolResult:
        return self._todo("debug_control", args)

    def debug_breakpoint(self, args: object) -> ToolResult:
        return self._todo("debug_breakpoint", args)

    def debug_stack(self, args: object) -> ToolResult:
        return self._todo("debug_stack", args)

    def debug_error(self, args: object) -> ToolResult:
        return self._todo("debug_error", args)

    def debug_state(self, args: object) -> ToolResult:
        return self._todo("debug_state", args)

    def debug_visuals(self, args: object) -> ToolResult:
        return self._todo("debug_visuals", args)

    def debug_profiler(self, args: object) -> ToolResult:
        return self._todo("debug_profiler", args)

    def _todo(self, tool_name: str, args: object) -> NoReturn:
        # Mapping table placeholder for future MCP tool names:
        # inspect_project  -> <godot-ai MCP tool>
        # patch_script     -> <godot-ai MCP tool>
        # run_game         -> <godot-ai MCP tool>
        # ...
        raise NotImplementedError(
            f"GodotAiBridgeAdapter.{tool_name}: map to godot-ai MCP call "
            f"(args={type(args).__name__})"
        )

    @staticmethod
    def expected_capability_template() -> Mapping[str, bool]:
        """Document what a full godot-ai mapping should report when ready."""
        return {
            "scene_editing": True,
            "property_editing": True,
            "resource_editing": True,
            "script_editing": True,
            "animation_player": True,
            "animation_tree": True,
            "runtime_debugger": True,
            "viewport_capture": True,
            "project_settings": True,
            "playtest": True,
            "documentation_search": False,
            "tilemap_editing": False,  # godot-ai AnimationTree-style: not a V1 guarantee
        }
