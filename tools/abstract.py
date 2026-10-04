"""Protocol defining abstract Godot capabilities.

Agent Core and planners call only this interface. Concrete bridges implement it
via ``bridges.base.BridgeAdapter`` — Agent Core must never import a specific
bridge package.
"""

from __future__ import annotations

from typing import Protocol, runtime_checkable

from tools.schemas import (
    AddTilesetCustomDataLayerArgs,
    AddTilesetNavigationLayerArgs,
    AddTilesetOcclusionLayerArgs,
    AddTilesetPhysicsLayerArgs,
    AddTilesetScenesCollectionSourceArgs,
    AddTilesetTerrainArgs,
    AddTilesetTerrainSetArgs,
    AnimationEditArgs,
    AnimationInspectArgs,
    AnimationTreeEditArgs,
    AnimationTreeInspectArgs,
    AttachScriptArgs,
    CaptureViewportArgs,
    ClearTileCollisionArgs,
    CreateAlternativeTileArgs,
    CreateSceneArgs,
    CreateSceneTileArgs,
    CreateSpriteFramesArgs,
    DebugBreakpointArgs,
    DebugControlArgs,
    DebugErrorArgs,
    DebugProfilerArgs,
    DebugStackArgs,
    DebugStateArgs,
    DebugStatusArgs,
    DebugVisualsArgs,
    EditNodeArgs,
    NodesCreateBatchArgs,
    NodesEditBatchArgs,
    ObserveArgs,
    RuntimeGetPropertyArgs,
    RuntimeNodeInspectArgs,
    RuntimeSetPropertyArgs,
    RuntimeTreeArgs,
    SpatialObserveArgs,
    GetDiagnosticsArgs,
    GetTileDataArgs,
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
    SetTileAnimationArgs,
    SetTileCollisionArgs,
    SetTileConstantVelocityArgs,
    SetTileCustomDataArgs,
    SetTileNavigationArgs,
    SetTileOcclusionArgs,
    SetTileTerrainArgs,
    SettingsGetArgs,
    SettingsSetArgs,
    StopGameArgs,
    TilemapClearArgs,
    TilemapFillRectArgs,
    TilemapGetCellArgs,
    TilemapInspectArgs,
    TilemapLayerSetKinematicArgs,
    TilemapLayerSetNavigationArgs,
    TilemapLayerSetPhysicsArgs,
    TilemapSetCellArgs,
    TilemapSetCellsBatchArgs,
    TilemapSetPatternArgs,
    TilemapSetTerrainArgs,
    TilesetAddAtlasArgs,
    TilesetAddPatternArgs,
    TilesetAtlasInspectArgs,
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

    def create_sprite_frames(self, args: CreateSpriteFramesArgs) -> ToolResult: ...

    # --- Bulk / composite authoring ---

    def nodes_create_batch(self, args: NodesCreateBatchArgs) -> ToolResult: ...

    def nodes_edit_batch(self, args: NodesEditBatchArgs) -> ToolResult: ...

    # --- Spatial / unified observe ---

    def spatial_observe(self, args: SpatialObserveArgs) -> ToolResult: ...

    def observe(self, args: ObserveArgs) -> ToolResult: ...

    def runtime_tree(self, args: RuntimeTreeArgs) -> ToolResult: ...

    def runtime_node_inspect(self, args: RuntimeNodeInspectArgs) -> ToolResult: ...

    def runtime_get_property(self, args: RuntimeGetPropertyArgs) -> ToolResult: ...

    def runtime_set_property(self, args: RuntimeSetPropertyArgs) -> ToolResult: ...

    # --- Debugger ---

    def debug_status(self, args: DebugStatusArgs) -> ToolResult: ...

    def debug_control(self, args: DebugControlArgs) -> ToolResult: ...

    def debug_breakpoint(self, args: DebugBreakpointArgs) -> ToolResult: ...

    def debug_stack(self, args: DebugStackArgs) -> ToolResult: ...

    def debug_error(self, args: DebugErrorArgs) -> ToolResult: ...

    def debug_state(self, args: DebugStateArgs) -> ToolResult: ...

    def debug_visuals(self, args: DebugVisualsArgs) -> ToolResult: ...

    def debug_profiler(self, args: DebugProfilerArgs) -> ToolResult: ...

    # --- TileSet / TileMap (TileMapLayer-first) ---

    def tileset_create(self, args: TilesetCreateArgs) -> ToolResult: ...

    def tileset_add_atlas(self, args: TilesetAddAtlasArgs) -> ToolResult: ...

    def tileset_create_tile(self, args: TilesetCreateTileArgs) -> ToolResult: ...

    def tileset_inspect(self, args: TilesetInspectArgs) -> ToolResult: ...

    def tileset_atlas_inspect(self, args: TilesetAtlasInspectArgs) -> ToolResult: ...

    def get_tile_data(self, args: GetTileDataArgs) -> ToolResult: ...

    def add_tileset_physics_layer(self, args: AddTilesetPhysicsLayerArgs) -> ToolResult: ...

    def set_tile_collision(self, args: SetTileCollisionArgs) -> ToolResult: ...

    def clear_tile_collision(self, args: ClearTileCollisionArgs) -> ToolResult: ...

    def tilemap_layer_set_physics(self, args: TilemapLayerSetPhysicsArgs) -> ToolResult: ...

    def tilemap_set_cells_batch(self, args: TilemapSetCellsBatchArgs) -> ToolResult: ...

    def add_tileset_custom_data_layer(self, args: AddTilesetCustomDataLayerArgs) -> ToolResult: ...

    def set_tile_custom_data(self, args: SetTileCustomDataArgs) -> ToolResult: ...

    def add_tileset_terrain_set(self, args: AddTilesetTerrainSetArgs) -> ToolResult: ...

    def add_tileset_terrain(self, args: AddTilesetTerrainArgs) -> ToolResult: ...

    def set_tile_terrain(self, args: SetTileTerrainArgs) -> ToolResult: ...

    def tilemap_set_terrain(self, args: TilemapSetTerrainArgs) -> ToolResult: ...

    def tileset_add_pattern(self, args: TilesetAddPatternArgs) -> ToolResult: ...

    def tilemap_set_pattern(self, args: TilemapSetPatternArgs) -> ToolResult: ...

    def create_alternative_tile(self, args: CreateAlternativeTileArgs) -> ToolResult: ...

    def set_tile_animation(self, args: SetTileAnimationArgs) -> ToolResult: ...

    def add_tileset_navigation_layer(self, args: AddTilesetNavigationLayerArgs) -> ToolResult: ...

    def set_tile_navigation(self, args: SetTileNavigationArgs) -> ToolResult: ...

    def tilemap_layer_set_navigation(self, args: TilemapLayerSetNavigationArgs) -> ToolResult: ...

    def add_tileset_occlusion_layer(self, args: AddTilesetOcclusionLayerArgs) -> ToolResult: ...

    def set_tile_occlusion(self, args: SetTileOcclusionArgs) -> ToolResult: ...

    def add_tileset_scenes_collection_source(
        self, args: AddTilesetScenesCollectionSourceArgs
    ) -> ToolResult: ...

    def create_scene_tile(self, args: CreateSceneTileArgs) -> ToolResult: ...

    def set_tile_constant_velocity(self, args: SetTileConstantVelocityArgs) -> ToolResult: ...

    def tilemap_layer_set_kinematic(self, args: TilemapLayerSetKinematicArgs) -> ToolResult: ...

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
