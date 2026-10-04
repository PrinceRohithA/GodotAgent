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
