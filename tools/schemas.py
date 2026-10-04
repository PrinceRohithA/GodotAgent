"""Tool argument and result schemas (stdlib dataclasses).

Language target is GDScript-first. Paths use Godot ``res://`` form where relevant.
"""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import Enum
from typing import Any, Mapping, Optional, Sequence


class ToolStatus(str, Enum):
    OK = "ok"
    ERROR = "error"
    UNSUPPORTED = "unsupported"
    CANCELLED = "cancelled"


class ToolRisk(str, Enum):
    READ = "read"
    WRITE = "write"
    EXECUTE = "execute"
    DESTRUCTIVE = "destructive"


@dataclass(frozen=True)
class ToolResult:
    """Normalized result returned by every abstract tool call."""

    status: ToolStatus
    data: Mapping[str, Any] = field(default_factory=dict)
    error: Optional[str] = None
    # Evidence suitable for the verifier (Godot-sourced facts, not agent claims).
    evidence: Mapping[str, Any] = field(default_factory=dict)
    # Optional change record for mutations (feeds undo / change tracking).
    change: Optional[Mapping[str, Any]] = None

    @property
    def ok(self) -> bool:
        return self.status is ToolStatus.OK


# --- Inspection ---


@dataclass(frozen=True)
class InspectProjectArgs:
    include_autoload: bool = True
    include_input_map: bool = True


@dataclass(frozen=True)
class InspectSceneArgs:
    scene_path: str  # res://...


@dataclass(frozen=True)
class InspectNodeArgs:
    node_path: str  # scene-relative or absolute NodePath string
    include_properties: bool = True
    include_children: bool = False


# --- Mutation ---


@dataclass(frozen=True)
class SetPropertyArgs:
    node_path: str
    property_name: str
    value: Any


@dataclass(frozen=True)
class EditNodeArgs:
    """Create / delete / rename / duplicate / reparent a node."""

    operation: str  # create | delete | rename | duplicate | reparent
    node_path: str
    # Operation-specific fields (type, new_name, parent_path, etc.)
    params: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class CreateSceneArgs:
    """Create a new packed scene via editor tools (never raw .tscn text)."""

    scene_path: str  # res://.../*.tscn
    root_type: str = "Node2D"


@dataclass(frozen=True)
class SaveSceneArgs:
    """Save the currently edited scene."""

    scene_path: Optional[str] = None  # optional hint; editor saves active scene


@dataclass(frozen=True)
class AttachScriptArgs:
    """Attach a script resource to a node in the edited scene."""

    node_path: str
    script_path: str  # res://.../*.gd


@dataclass(frozen=True)
class PatchScriptArgs:
    script_path: str  # res://.../*.gd
    # Unified-diff style patch or replacement payload; adapter interprets format.
    patch: str
    format: str = "unified_diff"  # unified_diff | full_replace


@dataclass(frozen=True)
class ReadScriptArgs:
    script_path: str
    start_line: Optional[int] = None
    end_line: Optional[int] = None


# --- Project settings / InputMap ---


@dataclass(frozen=True)
class SettingsGetArgs:
    key: str  # e.g. "application/config/name" or "input/dash"
    section: str = "project"  # project | input_map


@dataclass(frozen=True)
class SettingsSetArgs:
    key: str
    value: Any
    section: str = "project"  # project | input_map


# --- Animation ---


@dataclass(frozen=True)
class AnimationInspectArgs:
    node_path: str  # AnimationPlayer path
    animation_name: Optional[str] = None


@dataclass(frozen=True)
class AnimationEditArgs:
    node_path: str
    operation: str  # create | delete | set_track | set_key | rename | ...
    params: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class AnimationTreeInspectArgs:
    node_path: str  # AnimationTree path


@dataclass(frozen=True)
class AnimationTreeEditArgs:
    node_path: str
    operation: str
    params: Mapping[str, Any] = field(default_factory=dict)


# --- Runtime / playtest ---


@dataclass(frozen=True)
class RunGameArgs:
    scene_path: Optional[str] = None  # None = main/current scene
    debug: bool = True


@dataclass(frozen=True)
class StopGameArgs:
    force: bool = False


@dataclass(frozen=True)
class PlaytestInputArgs:
    """Send gameplay input (action press/release, key, mouse, etc.)."""

    kind: str  # action | key | mouse_button | mouse_motion
    name: str  # action name or key name
    pressed: bool = True
    strength: float = 1.0
    extras: Mapping[str, Any] = field(default_factory=dict)


@dataclass(frozen=True)
class PlaytestWaitArgs:
    seconds: float = 0.5
    # Optional condition hint for the bridge (e.g. wait until frame N).
    until: Optional[str] = None


@dataclass(frozen=True)
class ObserveRuntimeArgs:
    node_path: Optional[str] = None
    properties: Sequence[str] = field(default_factory=tuple)
    include_errors: bool = True


@dataclass(frozen=True)
class CaptureViewportArgs:
    # Where to write or how to return the image (adapter-defined).
    destination: Optional[str] = None
    include_ui: bool = True


@dataclass(frozen=True)
class GetDiagnosticsArgs:
    scope: str = "all"  # all | editor | runtime | script
    path_filter: Optional[str] = None


@dataclass(frozen=True)
class UndoArgs:
    steps: int = 1


# --- TileSet / TileMap (Godot 4 TileMapLayer-first) ---


@dataclass(frozen=True)
class TilesetCreateArgs:
    """Create a TileSet; optionally assign to a TileMapLayer/TileMap and/or save .tres."""

    tile_size: Sequence[int] = field(default_factory=lambda: (16, 16))
    node_path: Optional[str] = None
    save_path: Optional[str] = None  # e.g. res://tilesets/terrain.tres


@dataclass(frozen=True)
class TilesetAddAtlasArgs:
    """Add a TileSetAtlasSource from a texture."""

    texture_path: str  # res://...png
    node_path: Optional[str] = None
    tileset_path: Optional[str] = None
    texture_region_size: Optional[Sequence[int]] = None  # defaults to tile_size
    source_id: Optional[int] = None


@dataclass(frozen=True)
class TilesetCreateTileArgs:
    """Create a tile in an atlas source at atlas_coords."""

    atlas_coords: Sequence[int]  # [x, y]
    source_id: int = 0
    node_path: Optional[str] = None
    tileset_path: Optional[str] = None
    size_in_atlas: Optional[Sequence[int]] = None  # [w, h] in atlas cells


@dataclass(frozen=True)
class TilesetInspectArgs:
    """Summarize TileSet sources / tile_size for a node or .tres path."""

    node_path: Optional[str] = None
    tileset_path: Optional[str] = None


@dataclass(frozen=True)
class TilemapInspectArgs:
    """Inspect TileMapLayer/TileMap layers; optionally include used cells."""

    node_path: str
    layer: int = 0
    include_used_cells: bool = False


@dataclass(frozen=True)
class TilemapGetCellArgs:
    node_path: str
    coords: Sequence[int]  # [x, y]
    layer: int = 0


@dataclass(frozen=True)
class TilemapSetCellArgs:
    node_path: str
    coords: Sequence[int]  # [x, y]
    source_id: int
    atlas_coords: Sequence[int] = field(default_factory=lambda: (0, 0))
    alternative_tile: int = 0
    layer: int = 0


@dataclass(frozen=True)
class TilemapFillRectArgs:
    """Fill rect [x, y, w, h] with one tile (bridge fill cap applies)."""

    node_path: str
    rect: Sequence[int]  # [x, y, w, h]
    source_id: int
    atlas_coords: Sequence[int] = field(default_factory=lambda: (0, 0))
    alternative_tile: int = 0
    layer: int = 0


@dataclass(frozen=True)
class TilemapClearArgs:
    node_path: str
    layer: int = 0
