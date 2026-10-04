"""Typed results for spatial observation tools (GodotAgent)."""

from __future__ import annotations

from typing import Any

from pydantic import BaseModel, Field


class SpatialObserveResult(BaseModel):
    """Outcome of ``spatial_observe`` (editor or runtime)."""

    scope: str = "editor"
    root: str = ""
    depth: int = 0
    viewport: dict[str, Any] = Field(default_factory=dict)
    camera: dict[str, Any] = Field(default_factory=dict)
    objects: list[dict[str, Any]] = Field(default_factory=list)
    count: int = 0
    screenshot: Any = None
    ready: bool = True
    reason: str = ""
    screenshot_hint: str = ""
    error: str = ""
    request_id: str = ""
