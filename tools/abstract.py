"""Protocol defining abstract Godot capabilities.

Agent Core and planners call only this interface. Concrete bridges implement it
via ``bridges.base.BridgeAdapter`` — Agent Core must never import a specific
bridge package.
"""

from __future__ import annotations

from typing import Protocol, runtime_checkable

from tools.schemas import (
    AnimationEditArgs,
    AnimationInspectArgs,
    AnimationTreeEditArgs,
    AnimationTreeInspectArgs,
    AttachScriptArgs,
    CaptureViewportArgs,
    CreateSceneArgs,
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
    SaveSceneArgs,
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


@runtime_checkable
class AbstractGodotTools(Protocol):
    """Semantic Godot tools (GDScript-first). No raw engine API surface."""

    # --- Inspection ---

    def inspect_project(self, args: InspectProjectArgs) -> ToolResult: ...

    def inspect_scene(self, args: InspectSceneArgs) -> ToolResult: ...

    def inspect_node(self, args: InspectNodeArgs) -> ToolResult: ...

    # --- Editing ---

    def set_property(self, args: SetPropertyArgs) -> ToolResult: ...

    def edit_node(self, args: EditNodeArgs) -> ToolResult: ...

    def create_scene(self, args: CreateSceneArgs) -> ToolResult: ...

    def save_scene(self, args: SaveSceneArgs) -> ToolResult: ...

    def attach_script(self, args: AttachScriptArgs) -> ToolResult: ...

    def patch_script(self, args: PatchScriptArgs) -> ToolResult: ...

    def read_script(self, args: ReadScriptArgs) -> ToolResult: ...

    # --- Settings / InputMap ---

    def settings_get(self, args: SettingsGetArgs) -> ToolResult: ...

    def settings_set(self, args: SettingsSetArgs) -> ToolResult: ...

    # --- AnimationPlayer ---

    def animation_inspect(self, args: AnimationInspectArgs) -> ToolResult: ...

    def animation_edit(self, args: AnimationEditArgs) -> ToolResult: ...

    # --- AnimationTree ---

    def animation_tree_inspect(self, args: AnimationTreeInspectArgs) -> ToolResult: ...

    def animation_tree_edit(self, args: AnimationTreeEditArgs) -> ToolResult: ...

    # --- TileSet / TileMap (TileMapLayer-first) ---

    def tileset_create(self, args: TilesetCreateArgs) -> ToolResult: ...

    def tileset_add_atlas(self, args: TilesetAddAtlasArgs) -> ToolResult: ...

    def tileset_create_tile(self, args: TilesetCreateTileArgs) -> ToolResult: ...

    def tileset_inspect(self, args: TilesetInspectArgs) -> ToolResult: ...

    def tilemap_inspect(self, args: TilemapInspectArgs) -> ToolResult: ...

    def tilemap_get_cell(self, args: TilemapGetCellArgs) -> ToolResult: ...

    def tilemap_set_cell(self, args: TilemapSetCellArgs) -> ToolResult: ...

    def tilemap_fill_rect(self, args: TilemapFillRectArgs) -> ToolResult: ...

    def tilemap_clear(self, args: TilemapClearArgs) -> ToolResult: ...

    # --- Runtime / playtest ---

    def run_game(self, args: RunGameArgs) -> ToolResult: ...

    def stop_game(self, args: StopGameArgs) -> ToolResult: ...

    def playtest_input(self, args: PlaytestInputArgs) -> ToolResult: ...

    def playtest_wait(self, args: PlaytestWaitArgs) -> ToolResult: ...

    def observe_runtime(self, args: ObserveRuntimeArgs) -> ToolResult: ...

    def capture_viewport(self, args: CaptureViewportArgs) -> ToolResult: ...

    def get_diagnostics(self, args: GetDiagnosticsArgs) -> ToolResult: ...

    def undo(self, args: UndoArgs) -> ToolResult: ...
