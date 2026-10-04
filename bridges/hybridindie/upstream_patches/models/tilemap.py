"""Typed results for tilemap tools (issue #45) + GodotAgent TileMapLayer system."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field

from mcp_server.models.persistence import PersistenceReport


class TileCellResult(PersistenceReport):
    node_path: str
    coords: list[int]
    source_id: int
    layer: int = 0
    dry_run: bool = False
    deprecated_tilemap: bool | None = None
    migration_hint: str | None = None


class TileFillResult(PersistenceReport):
    node_path: str
    rect: list[int]
    cells: int = 0
    layer: int = 0
    dry_run: bool = False
    deprecated_tilemap: bool | None = None
    migration_hint: str | None = None


class TileBatchResult(PersistenceReport):
    node_path: str
    cells: int = 0
    layer: int = 0
    dry_run: bool = False


class TileGetResult(BaseModel):
    node_path: str
    coords: list[int]
    source_id: int = -1
    atlas_coords: list[int] = Field(default_factory=lambda: [-1, -1])
    alternative_tile: int = -1
    empty: bool = True
    deprecated_tilemap: bool | None = None
    migration_hint: str | None = None


class TileCellSnapshot(BaseModel):
    """One painted cell in a used-cells snapshot (issue #219 P3)."""

    coords: list[int]
    source_id: int = -1
    atlas_coords: list[int] = Field(default_factory=lambda: [-1, -1])
    alternative_tile: int = -1


class TileUsedCellsResult(BaseModel):
    node_path: str
    layer: int = 0
    count: int = 0
    cells: list[TileCellSnapshot] = Field(default_factory=list)
    deprecated_tilemap: bool | None = None
    migration_hint: str | None = None


class TileClearResult(PersistenceReport):
    node_path: str
    layer: int | None = None
    cleared: int = 0
    dry_run: bool = False
    deprecated_tilemap: bool | None = None
    migration_hint: str | None = None


class TileLayerInfo(BaseModel):
    index: int
    name: str
    enabled: bool = True
    collision_enabled: bool | None = None
    navigation_enabled: bool | None = None
    use_kinematic_bodies: bool | None = None


class TileLayersResult(BaseModel):
    node_path: str
    node_type: str
    layers: list[TileLayerInfo] = Field(default_factory=list)
    deprecated_tilemap: bool | None = None
    migration_hint: str | None = None


class TileSetResult(PersistenceReport):
    node_path: str = ""
    tileset_path: str = ""
    tile_size: list[int] = Field(default_factory=lambda: [16, 16])
    created: bool = True
    dry_run: bool = False
    deprecated_tilemap: bool | None = None
    migration_hint: str | None = None


class TileSetSourceResult(PersistenceReport):
    node_path: str = ""
    tileset_path: str = ""
    source_id: int = -1
    texture_path: str = ""
    region_size: list[int] = Field(default_factory=lambda: [16, 16])
    dry_run: bool = False
    deprecated_tilemap: bool | None = None
    type: str | None = None


class TileCreateResult(PersistenceReport):
    node_path: str = ""
    tileset_path: str = ""
    source_id: int = -1
    atlas_coords: list[int] = Field(default_factory=lambda: [0, 0])
    size: list[int] = Field(default_factory=lambda: [1, 1])
    dry_run: bool = False


class TileSetInspectResult(BaseModel):
    node_path: str = ""
    tileset_path: str = ""
    tile_size: list[int] = Field(default_factory=lambda: [16, 16])
    sources: list[dict[str, Any]] = Field(default_factory=list)
    physics_layers: list[dict[str, Any]] = Field(default_factory=list)
    custom_data_layers: list[dict[str, Any]] = Field(default_factory=list)
    terrain_sets: list[dict[str, Any]] = Field(default_factory=list)
    navigation_layers: list[dict[str, Any]] = Field(default_factory=list)
    occlusion_layers: list[dict[str, Any]] = Field(default_factory=list)
    patterns_count: int = 0
    deprecated_tilemap: bool | None = None


class TileSetAtlasInspectResult(BaseModel):
    node_path: str = ""
    tileset_path: str = ""
    source_id: int = 0
    texture_path: str = ""
    texture_size: list[int] = Field(default_factory=lambda: [0, 0])
    texture_region_size: list[int] = Field(default_factory=lambda: [16, 16])
    margins: list[int] = Field(default_factory=lambda: [0, 0])
    separation: list[int] = Field(default_factory=lambda: [0, 0])
    atlas_grid: list[int] = Field(default_factory=lambda: [0, 0])
    tiles_count: int = 0
    tiles: list[dict[str, Any]] = Field(default_factory=list)


class TileDataResult(BaseModel):
    node_path: str = ""
    tileset_path: str = ""
    source_id: int = 0
    atlas_coords: list[int] = Field(default_factory=lambda: [0, 0])
    alternative_tile: int = 0
    physics: list[dict[str, Any]] = Field(default_factory=list)
    custom_data: dict[str, Any] = Field(default_factory=dict)
    terrain_set: int = -1
    terrain: int = -1
    terrain_peering: list[dict[str, Any]] = Field(default_factory=list)
    navigation: list[dict[str, Any]] = Field(default_factory=list)
    occlusion: list[dict[str, Any]] = Field(default_factory=list)
    flip_h: bool = False
    flip_v: bool = False
    transpose: bool = False


class TilePhysicsLayerResult(PersistenceReport):
    node_path: str = ""
    tileset_path: str = ""
    physics_layer: int = 0
    collision_layer: int = 1
    collision_mask: int = 1
    physics_layers_count: int = 0
    dry_run: bool = False


class TileCollisionResult(PersistenceReport):
    node_path: str = ""
    tileset_path: str = ""
    source_id: int = 0
    atlas_coords: list[int] = Field(default_factory=lambda: [0, 0])
    alternative_tile: int = 0
    physics_layer: int = 0
    shape: str = "full_rect"
    points: list[list[float]] = Field(default_factory=list)
    one_way: bool = False
    one_way_margin: float = 1.0
    polygons_count: int = 0
    cleared: bool | None = None
    dry_run: bool = False


class TileLayerFlagResult(PersistenceReport):
    node_path: str
    collision_enabled: bool | None = None
    navigation_enabled: bool | None = None
    use_kinematic_bodies: bool | None = None
    dry_run: bool = False


class TileGenericResult(PersistenceReport):
    """Flexible result for Phase 2/3 mutating tile tools."""

    node_path: str = ""
    tileset_path: str = ""
    dry_run: bool = False
    # Common optional fields (extras allowed via model_config if needed)
    source_id: int | None = None
    atlas_coords: list[int] | None = None
    alternative_tile: int | None = None
    physics_layer: int | None = None
    navigation_layer: int | None = None
    occlusion_layer: int | None = None
    terrain_set: int | None = None
    terrain: int | None = None
    mode: str | int | None = None
    name: str | None = None
    value: Any = None
    layer_index: int | None = None
    type: int | str | None = None
    pattern_index: int | None = None
    cells: int | None = None
    patterns_count: int | None = None
    frames_count: int | None = None
    columns: int | None = None
    speed: float | None = None
    scene_tile_id: int | None = None
    scene_path: str | None = None
    linear_velocity: list[float] | None = None
    angular_velocity: float | None = None
    position: list[int] | None = None
    points: list[list[float]] | None = None
    outline_points: list[list[float]] | None = None
    polygons_count: int | None = None
