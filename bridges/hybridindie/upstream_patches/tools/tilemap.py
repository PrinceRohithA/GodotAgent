"""TileMap tools (issue #45) + GodotAgent TileMapLayer-first system.

TileMapLayer is preferred for all new work. Deprecated TileMap remains
read/compat for paint/get/clear. New gameplay ops (physics, batch, terrain,
patterns, nav/occlusion/scenes/kinematic) require TileMapLayer.
"""

from __future__ import annotations

from typing import Any

from fastmcp import FastMCP

from mcp_server.bridge import Bridge
from mcp_server.categories import TILEMAP_TAG
from mcp_server.constraints import (
    TileAlternative,
    TileLayer,
    TileLayerOpt,
    TileSourceId,
    TileSourceIdOpt,
)
from mcp_server.models.tilemap import (
    TileBatchResult,
    TileCellResult,
    TileClearResult,
    TileCollisionResult,
    TileCreateResult,
    TileDataResult,
    TileFillResult,
    TileGenericResult,
    TileGetResult,
    TileLayerFlagResult,
    TileLayersResult,
    TilePhysicsLayerResult,
    TileSetAtlasInspectResult,
    TileSetInspectResult,
    TileSetResult,
    TileSetSourceResult,
    TileUsedCellsResult,
)
from mcp_server.safety import (
    MUTATING,
    READ_ONLY,
    PreconditionError,
    enforce_preconditions,
    require_node_exists,
)
from mcp_server.tools._persistence import node_probe
from mcp_server.tools._route import route, run_or_preview

TILEMAP = {TILEMAP_TAG}


def _require_single_tileset_target(node_path: str, tileset_path: str) -> None:
    if node_path and tileset_path:
        raise PreconditionError(
            "Pass only one of 'node_path' or 'tileset_path', not both.",
            required="single_tileset_target",
        )
    if not node_path and not tileset_path:
        raise PreconditionError(
            "Provide 'node_path' (a TileMapLayer preferred) or 'tileset_path' (a .tres).",
            required="node_path_or_tileset_path",
        )


def _tileset_target_params(node_path: str, tileset_path: str) -> dict[str, Any]:
    return {"node_path": node_path or "", "tileset_path": tileset_path or ""}


def register_tilemap(mcp: FastMCP, bridge: Bridge) -> None:
    """Register the tilemap tools."""

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_set_cell(
        node_path: str,
        coords: list[int],
        source_id: TileSourceId = -1,
        atlas_coords: list[int] | None = None,
        alternative_tile: TileAlternative = 0,
        layer: TileLayer = 0,
        dry_run: bool = False,
    ) -> TileCellResult:
        """Set the tile at grid ``coords``. Prefer TileMapLayer; deprecated TileMap
        still works (compat). ``source_id=-1`` erases.
        """
        await require_node_exists(bridge, node_path)
        params = {
            "node_path": node_path,
            "coords": coords,
            "source_id": source_id,
            "atlas_coords": atlas_coords if atlas_coords is not None else [0, 0],
            "alternative_tile": alternative_tile,
            "layer": layer,
        }
        preview = {
            "node_path": node_path,
            "coords": coords,
            "source_id": source_id,
            "layer": layer,
        }
        return await run_or_preview(
            dry_run,
            TileCellResult,
            preview,
            bridge,
            "cmd_tilemap_set_cell",
            params,
            persistence_probe=node_probe(node_path),
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_fill_rect(
        node_path: str,
        rect: list[int],
        source_id: TileSourceId = -1,
        atlas_coords: list[int] | None = None,
        alternative_tile: TileAlternative = 0,
        layer: TileLayer = 0,
        dry_run: bool = False,
    ) -> TileFillResult:
        """Fill ``rect`` ``[x, y, w, h]`` with one tile in a single undoable action."""
        await require_node_exists(bridge, node_path)
        cells = max(0, rect[2]) * max(0, rect[3]) if len(rect) == 4 else 0
        params = {
            "node_path": node_path,
            "rect": rect,
            "source_id": source_id,
            "atlas_coords": atlas_coords if atlas_coords is not None else [0, 0],
            "alternative_tile": alternative_tile,
            "layer": layer,
        }
        preview = {
            "node_path": node_path,
            "rect": rect,
            "cells": cells,
            "layer": layer,
        }
        return await run_or_preview(
            dry_run,
            TileFillResult,
            preview,
            bridge,
            "cmd_tilemap_fill_rect",
            params,
            persistence_probe=node_probe(node_path),
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_set_cells_batch(
        node_path: str,
        cells: list[dict[str, Any]],
        layer: TileLayer = 0,
        dry_run: bool = False,
    ) -> TileBatchResult:
        """Paint many cells in one MCP call (TileMapLayer only). Each cell:
        ``{coords:[x,y], source_id, atlas_coords:[x,y], alternative_tile}``.
        """
        await require_node_exists(bridge, node_path)
        params = {"node_path": node_path, "cells": cells, "layer": layer}
        preview = {"node_path": node_path, "cells": len(cells), "layer": layer}
        return await run_or_preview(
            dry_run,
            TileBatchResult,
            preview,
            bridge,
            "cmd_tilemap_set_cells_batch",
            params,
            persistence_probe=node_probe(node_path),
        )

    @mcp.tool(meta=READ_ONLY, tags=TILEMAP)
    async def tilemap_get_cell(
        node_path: str, coords: list[int], layer: TileLayer = 0
    ) -> TileGetResult:
        """Read the tile at grid ``coords``."""
        params = {"node_path": node_path, "coords": coords, "layer": layer}
        return TileGetResult(**await route(bridge, "cmd_tilemap_get_cell", params))

    @mcp.tool(meta=READ_ONLY, tags=TILEMAP)
    async def tilemap_get_used_cells(node_path: str, layer: TileLayer = 0) -> TileUsedCellsResult:
        """Snapshot every painted cell on the layer."""
        params = {"node_path": node_path, "layer": layer}
        return TileUsedCellsResult(**await route(bridge, "cmd_tilemap_get_used_cells", params))

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_clear(
        node_path: str, layer: TileLayerOpt = None, dry_run: bool = False
    ) -> TileClearResult:
        """Clear a layer's cells (undoable)."""
        await require_node_exists(bridge, node_path)
        params = {"node_path": node_path, "layer": layer}
        preview = {"node_path": node_path, "layer": layer}
        return await run_or_preview(
            dry_run,
            TileClearResult,
            preview,
            bridge,
            "cmd_tilemap_clear",
            params,
            persistence_probe=node_probe(node_path),
        )

    @mcp.tool(meta=READ_ONLY, tags=TILEMAP)
    async def tilemap_layers(node_path: str) -> TileLayersResult:
        """List layers; TileMapLayer reports collision/navigation/kinematic flags."""
        params = {"node_path": node_path}
        return TileLayersResult(**await route(bridge, "cmd_tilemap_layers", params))

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def create_tileset(
        node_path: str = "",
        save_path: str = "",
        tile_size: list[int] | None = None,
        dry_run: bool = False,
    ) -> TileSetResult:
        """Create a TileSet; assign to TileMapLayer and/or save ``.tres``."""
        size = tile_size if tile_size is not None else [16, 16]
        if not node_path and not save_path:
            raise PreconditionError(
                "Provide 'node_path' to assign the TileSet and/or 'save_path' to save it.",
                required="node_path_or_save_path",
            )
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {"node_path": node_path, "save_path": save_path, "tile_size": size}
        preview = {"node_path": node_path, "tileset_path": save_path, "tile_size": size}
        return await run_or_preview(
            dry_run,
            TileSetResult,
            preview,
            bridge,
            "cmd_create_tileset",
            params,
            persistence_probe=node_probe(node_path) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def add_tileset_atlas_source(
        texture_path: str,
        region_size: list[int],
        node_path: str = "",
        tileset_path: str = "",
        source_id: TileSourceIdOpt = None,
        margins: list[int] | None = None,
        separation: list[int] | None = None,
        dry_run: bool = False,
    ) -> TileSetSourceResult:
        """Add a TileSetAtlasSource from an imported Texture2D."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "texture_path": texture_path,
            "region_size": region_size,
            "source_id": source_id,
            "margins": margins if margins is not None else [0, 0],
            "separation": separation if separation is not None else [0, 0],
        }
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id if source_id is not None else -1,
            "texture_path": texture_path,
            "region_size": region_size,
        }
        return await run_or_preview(
            dry_run,
            TileSetSourceResult,
            preview,
            bridge,
            "cmd_add_tileset_atlas_source",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def create_tile(
        source_id: TileSourceId,
        atlas_coords: list[int],
        node_path: str = "",
        tileset_path: str = "",
        size: list[int] | None = None,
        dry_run: bool = False,
    ) -> TileCreateResult:
        """Create a tile at ``atlas_coords`` in an atlas source."""
        tile_size = size if size is not None else [1, 1]
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "size": tile_size,
        }
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "size": tile_size,
        }
        return await run_or_preview(
            dry_run,
            TileCreateResult,
            preview,
            bridge,
            "cmd_create_tile",
            params,
            persistence_probe=(
                node_probe(node_path, ["tile_set"], source_id=source_id) if node_path else True
            ),
        )

    # --- INSPECT / VERIFY -------------------------------------------------

    @mcp.tool(meta=READ_ONLY, tags=TILEMAP)
    async def tileset_inspect(node_path: str = "", tileset_path: str = "") -> TileSetInspectResult:
        """Inspect TileSet sources, physics/custom/terrain/nav/occlusion layers, patterns."""
        _require_single_tileset_target(node_path, tileset_path)
        params = _tileset_target_params(node_path, tileset_path)
        return TileSetInspectResult(**await route(bridge, "cmd_tileset_inspect", params))

    @mcp.tool(meta=READ_ONLY, tags=TILEMAP)
    async def tileset_atlas_inspect(
        source_id: TileSourceId = 0,
        node_path: str = "",
        tileset_path: str = "",
    ) -> TileSetAtlasInspectResult:
        """Inspect an atlas source: texture, grid, tiles, alternatives, animation."""
        _require_single_tileset_target(node_path, tileset_path)
        params = {**_tileset_target_params(node_path, tileset_path), "source_id": source_id}
        return TileSetAtlasInspectResult(
            **await route(bridge, "cmd_tileset_atlas_inspect", params)
        )

    @mcp.tool(meta=READ_ONLY, tags=TILEMAP)
    async def get_tile_data(
        source_id: TileSourceId,
        atlas_coords: list[int],
        alternative_tile: TileAlternative = 0,
        node_path: str = "",
        tileset_path: str = "",
    ) -> TileDataResult:
        """Required VERIFY primitive: collision polygons, custom data, terrain, nav, occlusion."""
        _require_single_tileset_target(node_path, tileset_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile": alternative_tile,
        }
        return TileDataResult(**await route(bridge, "cmd_get_tile_data", params))

    # --- Phase 1 physics --------------------------------------------------

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def add_tileset_physics_layer(
        node_path: str = "",
        tileset_path: str = "",
        collision_layer: int = 1,
        collision_mask: int = 1,
        dry_run: bool = False,
    ) -> TilePhysicsLayerResult:
        """Add a TileSet physics layer (enables TileData collision polygons)."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "collision_layer": collision_layer,
            "collision_mask": collision_mask,
        }
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "physics_layer": -1,
            "collision_layer": collision_layer,
            "collision_mask": collision_mask,
        }
        return await run_or_preview(
            dry_run,
            TilePhysicsLayerResult,
            preview,
            bridge,
            "cmd_add_tileset_physics_layer",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def set_tile_collision(
        source_id: TileSourceId,
        atlas_coords: list[int],
        node_path: str = "",
        tileset_path: str = "",
        alternative_tile: TileAlternative = 0,
        physics_layer: int = 0,
        shape: str = "full_rect",
        points: list[list[float]] | None = None,
        one_way: bool = False,
        one_way_margin: float = 1.0,
        dry_run: bool = False,
    ) -> TileCollisionResult:
        """Set TileData collision. ``shape=full_rect`` generates a centered polygon from
        tile_size; or pass explicit ``points`` as ``[[x,y],...]``.
        """
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params: dict[str, Any] = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile": alternative_tile,
            "physics_layer": physics_layer,
            "shape": shape,
            "one_way": one_way,
            "one_way_margin": one_way_margin,
        }
        if points is not None:
            params["points"] = points
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "physics_layer": physics_layer,
            "shape": shape,
            "points": points or [],
            "one_way": one_way,
            "one_way_margin": one_way_margin,
        }
        return await run_or_preview(
            dry_run,
            TileCollisionResult,
            preview,
            bridge,
            "cmd_set_tile_collision",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def clear_tile_collision(
        source_id: TileSourceId,
        atlas_coords: list[int],
        node_path: str = "",
        tileset_path: str = "",
        alternative_tile: TileAlternative = 0,
        physics_layer: int = 0,
        dry_run: bool = False,
    ) -> TileCollisionResult:
        """Remove collision polygons from a tile (for negative collision tests)."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile": alternative_tile,
            "physics_layer": physics_layer,
        }
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "physics_layer": physics_layer,
            "cleared": True,
            "polygons_count": 0,
        }
        return await run_or_preview(
            dry_run,
            TileCollisionResult,
            preview,
            bridge,
            "cmd_clear_tile_collision",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_layer_set_physics(
        node_path: str,
        collision_enabled: bool = True,
        dry_run: bool = False,
    ) -> TileLayerFlagResult:
        """Set TileMapLayer.collision_enabled (TileMapLayer only)."""
        await require_node_exists(bridge, node_path)
        params = {"node_path": node_path, "collision_enabled": collision_enabled}
        preview = {"node_path": node_path, "collision_enabled": collision_enabled}
        return await run_or_preview(
            dry_run,
            TileLayerFlagResult,
            preview,
            bridge,
            "cmd_tilemap_layer_set_physics",
            params,
            persistence_probe=node_probe(node_path),
        )

    # --- Phase 2 ----------------------------------------------------------

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def add_tileset_custom_data_layer(
        name: str,
        type: str = "int",
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Add a named custom-data layer (gameplay metadata foundation)."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {**_tileset_target_params(node_path, tileset_path), "name": name, "type": type}
        preview = {"node_path": node_path, "tileset_path": tileset_path, "name": name, "type": type}
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_add_tileset_custom_data_layer",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def set_tile_custom_data(
        source_id: TileSourceId,
        atlas_coords: list[int],
        name: str,
        value: Any,
        alternative_tile: TileAlternative = 0,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Set per-tile custom data (e.g. damage, surface, type)."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile": alternative_tile,
            "name": name,
            "value": value,
        }
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "name": name,
            "value": value,
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_set_tile_custom_data",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def add_tileset_terrain_set(
        mode: int = 0,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Add a terrain set (prerequisite before terrain paint)."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {**_tileset_target_params(node_path, tileset_path), "mode": mode}
        preview = {"node_path": node_path, "tileset_path": tileset_path, "mode": mode}
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_add_tileset_terrain_set",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def add_tileset_terrain(
        terrain_set: int = 0,
        name: str = "",
        color: list[float] | None = None,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Add a terrain to a terrain set. Fails with TERRAIN_NOT_CONFIGURED if set missing."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params: dict[str, Any] = {
            **_tileset_target_params(node_path, tileset_path),
            "terrain_set": terrain_set,
            "name": name,
        }
        if color is not None:
            params["color"] = color
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "terrain_set": terrain_set,
            "name": name,
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_add_tileset_terrain",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def set_tile_terrain(
        source_id: TileSourceId,
        atlas_coords: list[int],
        terrain_set: int = 0,
        terrain: int = 0,
        peering_bits: list[dict[str, int]] | None = None,
        alternative_tile: TileAlternative = 0,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Assign terrain + optional peering bits on TileData."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile": alternative_tile,
            "terrain_set": terrain_set,
            "terrain": terrain,
            "peering_bits": peering_bits or [],
        }
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "terrain_set": terrain_set,
            "terrain": terrain,
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_set_tile_terrain",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_set_terrain(
        node_path: str,
        cells: list[Any],
        terrain_set: int = 0,
        terrain: int = 0,
        mode: str = "connect",
        ignore_empty_terrains: bool = True,
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Paint terrain via set_cells_terrain_connect/path. Requires configured terrain."""
        await require_node_exists(bridge, node_path)
        params = {
            "node_path": node_path,
            "cells": cells,
            "terrain_set": terrain_set,
            "terrain": terrain,
            "mode": mode,
            "ignore_empty_terrains": ignore_empty_terrains,
        }
        preview = {
            "node_path": node_path,
            "terrain_set": terrain_set,
            "terrain": terrain,
            "mode": mode,
            "cells": len(cells),
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_tilemap_set_terrain",
            params,
            persistence_probe=node_probe(node_path),
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tileset_add_pattern(
        cells: list[dict[str, Any]],
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Store a TileMapPattern on the TileSet for later stamping."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {**_tileset_target_params(node_path, tileset_path), "cells": cells}
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "cells": len(cells),
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_tileset_add_pattern",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_set_pattern(
        node_path: str,
        pattern_index: int,
        position: list[int] | None = None,
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Stamp a TileSet pattern onto a TileMapLayer."""
        await require_node_exists(bridge, node_path)
        pos = position if position is not None else [0, 0]
        params = {"node_path": node_path, "pattern_index": pattern_index, "position": pos}
        preview = {"node_path": node_path, "pattern_index": pattern_index, "position": pos}
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_tilemap_set_pattern",
            params,
            persistence_probe=node_probe(node_path),
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def create_alternative_tile(
        source_id: TileSourceId,
        atlas_coords: list[int],
        node_path: str = "",
        tileset_path: str = "",
        alternative_tile_id: int = -1,
        flip_h: bool | None = None,
        flip_v: bool | None = None,
        transpose: bool | None = None,
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Create an alternative tile (optional flip/transpose flags)."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params: dict[str, Any] = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile_id": alternative_tile_id,
        }
        if flip_h is not None:
            params["flip_h"] = flip_h
        if flip_v is not None:
            params["flip_v"] = flip_v
        if transpose is not None:
            params["transpose"] = transpose
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_create_alternative_tile",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def set_tile_animation(
        source_id: TileSourceId,
        atlas_coords: list[int],
        frames_count: int = 1,
        columns: int = 0,
        speed: float = 1.0,
        mode: int = 0,
        frame_duration: float | None = None,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """Configure atlas tile animation frames/speed/mode."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params: dict[str, Any] = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "frames_count": frames_count,
            "columns": columns,
            "speed": speed,
            "mode": mode,
        }
        if frame_duration is not None:
            params["frame_duration"] = frame_duration
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "frames_count": frames_count,
            "columns": columns,
            "speed": speed,
            "mode": mode,
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_set_tile_animation",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    # --- Phase 3 tracks ---------------------------------------------------

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def add_tileset_navigation_layer(
        layers: int = 1,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """P3-A: add a TileSet navigation layer."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {**_tileset_target_params(node_path, tileset_path), "layers": layers}
        preview = {"node_path": node_path, "tileset_path": tileset_path}
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_add_tileset_navigation_layer",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def set_tile_navigation(
        source_id: TileSourceId,
        atlas_coords: list[int],
        navigation_layer: int = 0,
        shape: str = "full_rect",
        points: list[list[float]] | None = None,
        alternative_tile: TileAlternative = 0,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """P3-A: set TileData navigation polygon (full_rect or points)."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params: dict[str, Any] = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile": alternative_tile,
            "navigation_layer": navigation_layer,
            "shape": shape,
        }
        if points is not None:
            params["points"] = points
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "navigation_layer": navigation_layer,
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_set_tile_navigation",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_layer_set_navigation(
        node_path: str,
        navigation_enabled: bool = True,
        dry_run: bool = False,
    ) -> TileLayerFlagResult:
        """P3-A: set TileMapLayer.navigation_enabled."""
        await require_node_exists(bridge, node_path)
        params = {"node_path": node_path, "navigation_enabled": navigation_enabled}
        preview = {"node_path": node_path, "navigation_enabled": navigation_enabled}
        return await run_or_preview(
            dry_run,
            TileLayerFlagResult,
            preview,
            bridge,
            "cmd_tilemap_layer_set_navigation",
            params,
            persistence_probe=node_probe(node_path),
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def add_tileset_occlusion_layer(
        light_mask: int = 1,
        sdf_collision: bool = False,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """P3-B: add a TileSet occlusion layer."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "light_mask": light_mask,
            "sdf_collision": sdf_collision,
        }
        preview = {"node_path": node_path, "tileset_path": tileset_path}
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_add_tileset_occlusion_layer",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def set_tile_occlusion(
        source_id: TileSourceId,
        atlas_coords: list[int],
        occlusion_layer: int = 0,
        shape: str = "full_rect",
        points: list[list[float]] | None = None,
        alternative_tile: TileAlternative = 0,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """P3-B: set TileData occluder polygon."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params: dict[str, Any] = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile": alternative_tile,
            "occlusion_layer": occlusion_layer,
            "shape": shape,
        }
        if points is not None:
            params["points"] = points
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "occlusion_layer": occlusion_layer,
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_set_tile_occlusion",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def add_tileset_scenes_collection_source(
        node_path: str = "",
        tileset_path: str = "",
        source_id: TileSourceIdOpt = None,
        dry_run: bool = False,
    ) -> TileSetSourceResult:
        """P3-C: add a TileSetScenesCollectionSource."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {**_tileset_target_params(node_path, tileset_path), "source_id": source_id}
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id if source_id is not None else -1,
            "texture_path": "",
            "region_size": [0, 0],
            "type": "TileSetScenesCollectionSource",
        }
        return await run_or_preview(
            dry_run,
            TileSetSourceResult,
            preview,
            bridge,
            "cmd_add_tileset_scenes_collection_source",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def create_scene_tile(
        source_id: TileSourceId,
        scene_path: str,
        scene_tile_id: int = -1,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """P3-C: create a scene tile in a scenes collection source."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "scene_path": scene_path,
            "scene_tile_id": scene_tile_id,
        }
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "scene_path": scene_path,
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_create_scene_tile",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def set_tile_constant_velocity(
        source_id: TileSourceId,
        atlas_coords: list[int],
        linear_velocity: list[float] | None = None,
        angular_velocity: float | None = None,
        physics_layer: int = 0,
        alternative_tile: TileAlternative = 0,
        node_path: str = "",
        tileset_path: str = "",
        dry_run: bool = False,
    ) -> TileGenericResult:
        """P3-D: conveyor-style constant linear/angular velocity on TileData."""
        _require_single_tileset_target(node_path, tileset_path)
        if node_path:
            await require_node_exists(bridge, node_path)
        params: dict[str, Any] = {
            **_tileset_target_params(node_path, tileset_path),
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "alternative_tile": alternative_tile,
            "physics_layer": physics_layer,
            "linear_velocity": linear_velocity if linear_velocity is not None else [0, 0],
        }
        if angular_velocity is not None:
            params["angular_velocity"] = angular_velocity
        preview = {
            "node_path": node_path,
            "tileset_path": tileset_path,
            "source_id": source_id,
            "atlas_coords": atlas_coords,
            "physics_layer": physics_layer,
            "linear_velocity": linear_velocity if linear_velocity is not None else [0, 0],
        }
        return await run_or_preview(
            dry_run,
            TileGenericResult,
            preview,
            bridge,
            "cmd_set_tile_constant_velocity",
            params,
            persistence_probe=node_probe(node_path, ["tile_set"]) if node_path else True,
        )

    @mcp.tool(meta=MUTATING, tags=TILEMAP)
    @enforce_preconditions
    async def tilemap_layer_set_kinematic(
        node_path: str,
        use_kinematic_bodies: bool = True,
        dry_run: bool = False,
    ) -> TileLayerFlagResult:
        """P3-D: set TileMapLayer.use_kinematic_bodies for moving platforms."""
        await require_node_exists(bridge, node_path)
        params = {"node_path": node_path, "use_kinematic_bodies": use_kinematic_bodies}
        preview = {"node_path": node_path, "use_kinematic_bodies": use_kinematic_bodies}
        return await run_or_preview(
            dry_run,
            TileLayerFlagResult,
            preview,
            bridge,
            "cmd_tilemap_layer_set_kinematic",
            params,
            persistence_probe=node_probe(node_path),
        )
