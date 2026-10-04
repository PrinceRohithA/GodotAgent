"""Spatial observation tools (GodotAgent).

Structured SpatialObject snapshots for editor and running game. Gated under the
``spatial`` toolset. Screenshot is never required.
"""

from __future__ import annotations

import uuid
from typing import Any

from fastmcp import FastMCP

from mcp_server.bridge import Bridge
from mcp_server.categories import SPATIAL_TAG
from mcp_server.models.spatial import SpatialObserveResult
from mcp_server.safety import READ_ONLY, enforce_preconditions, require_active_scene
from mcp_server.tools._route import poll_ready, route

SPATIAL = {SPATIAL_TAG}


def register_spatial(mcp: FastMCP, bridge: Bridge) -> None:
    """Register spatial observation tools."""

    @mcp.tool(meta=READ_ONLY, tags=SPATIAL)
    @enforce_preconditions
    async def observe(
        scope: str = "editor",
        root: str = ".",
        depth: int = 3,
        include: list[str] | None = None,
        type_filter: list[str] | None = None,
        path_filter: str = "",
        screenshot: bool = False,
        timeout_ms: int = 5000,
    ) -> SpatialObserveResult:
        """Return a structured spatial snapshot of the editor scene or running game.

        ``scope`` is ``editor`` or ``runtime``. Geometry is type-sourced (Sprite2D,
        Control, CollisionShape2D, CollisionPolygon2D, Polygon2D); unsupported
        nodes report ``geometry.available=false`` — bounds are never invented.
        Local vs global transforms are always labeled. Screenshot is optional and
        not required for spatial reasoning.
        """
        params: dict[str, Any] = {
            "scope": scope,
            "root": root,
            "depth": depth,
            "include": include or ["transform", "bounds"],
            "type_filter": type_filter or [],
            "path_filter": path_filter,
            "screenshot": screenshot,
        }
        if scope == "editor":
            await require_active_scene(bridge)
            return SpatialObserveResult(**await route(bridge, "cmd_spatial_observe", params))
        # Runtime: poll until ready (request_id pattern).
        params["request_id"] = str(uuid.uuid4())
        result = await poll_ready(bridge, "cmd_spatial_observe", params, timeout_ms)
        return SpatialObserveResult(**result)
