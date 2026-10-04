#!/usr/bin/env python3
"""Live smoke for TileMapLayer-first TileSet/TileMap system (Phases 0–3).

Requires:
  - godot-editor-mcp HTTP on :9090 (scripts/start_mcp_server.ps1 with tilemap seeded)
  - GodotAgentTest open with MCP dock connected

Usage::

    py -3 scripts/live_smoke_tilemap.py --http-only
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Optional

_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from bridges.hybridindie.adapter import HybridindieBridgeAdapter
from tools.schemas import (
    AddTilesetCustomDataLayerArgs,
    AddTilesetNavigationLayerArgs,
    AddTilesetOcclusionLayerArgs,
    AddTilesetPhysicsLayerArgs,
    AddTilesetScenesCollectionSourceArgs,
    AddTilesetTerrainArgs,
    AddTilesetTerrainSetArgs,
    ClearTileCollisionArgs,
    EditNodeArgs,
    GetTileDataArgs,
    InspectSceneArgs,
    ObserveRuntimeArgs,
    RunGameArgs,
    SaveSceneArgs,
    SetTileCollisionArgs,
    SetTileConstantVelocityArgs,
    SetTileCustomDataArgs,
    SetTileNavigationArgs,
    SetTileOcclusionArgs,
    StopGameArgs,
    TilemapFillRectArgs,
    TilemapGetCellArgs,
    TilemapInspectArgs,
    TilemapLayerSetKinematicArgs,
    TilemapLayerSetNavigationArgs,
    TilemapLayerSetPhysicsArgs,
    TilemapSetCellArgs,
    TilemapSetCellsBatchArgs,
    TilemapSetTerrainArgs,
    TilesetAddAtlasArgs,
    TilesetAddPatternArgs,
    TilesetAtlasInspectArgs,
    TilesetCreateArgs,
    TilesetCreateTileArgs,
    TilesetInspectArgs,
)

RESULTS_PATH = _ROOT / "Docs" / "spike" / "live_smoke_tilemap_results.md"
DEFAULT_HTTP = "http://127.0.0.1:9090/mcp"
SCENE = "res://scenes/main.tscn"
LAYER_NAME = "SmokeTileLayer"
TERRAIN_TEX = "res://assets/pixel_adventure_1/Terrain/Terrain (16x16).png"
TILESET_SAVE = "res://tilesets/smoke_terrain.tres"


class HttpMcpTransport:
    """Minimal Streamable-HTTP MCP client for tools/call."""

    def __init__(self, url: str) -> None:
        self._url = url
        self._session: Optional[str] = None
        self._next_id = 1
        self._initialize()

    def _post(self, payload: Mapping[str, Any]) -> Any:
        data = json.dumps(payload).encode("utf-8")
        headers = {
            "Content-Type": "application/json",
            "Accept": "application/json, text/event-stream",
        }
        if self._session:
            headers["Mcp-Session-Id"] = self._session
        req = urllib.request.Request(self._url, data=data, headers=headers)
        with urllib.request.urlopen(req, timeout=90) as resp:
            sid = resp.headers.get("Mcp-Session-Id")
            if sid:
                self._session = sid
            body = resp.read().decode("utf-8", errors="replace")
        return self._parse_body(body)

    def _parse_body(self, body: str) -> Any:
        messages: list[Any] = []
        for line in body.splitlines():
            if line.startswith("data: "):
                try:
                    messages.append(json.loads(line[6:]))
                except json.JSONDecodeError:
                    continue
        if not messages:
            try:
                return json.loads(body)
            except json.JSONDecodeError:
                return {"isError": True, "error": body[:500]}
        for msg in reversed(messages):
            if isinstance(msg, Mapping) and ("result" in msg or "error" in msg):
                if "error" in msg:
                    return {"isError": True, "error": str(msg["error"])}
                return self._unwrap_result(msg["result"])
        return messages[-1]

    @staticmethod
    def _unwrap_result(result: Any) -> Any:
        if not isinstance(result, Mapping):
            return result
        if result.get("isError"):
            content = result.get("content") or []
            texts = []
            for block in content:
                if isinstance(block, Mapping) and block.get("text"):
                    texts.append(str(block["text"]))
            return {
                "isError": True,
                "error": "\n".join(texts) or str(result),
                "raw": dict(result),
            }
        structured = result.get("structuredContent")
        if structured is not None:
            return structured
        content = result.get("content") or []
        texts: list[str] = []
        for block in content:
            if isinstance(block, Mapping) and "text" in block:
                texts.append(str(block["text"]))
        if len(texts) == 1:
            try:
                return json.loads(texts[0])
            except json.JSONDecodeError:
                return {"text": texts[0]}
        if texts:
            return {"texts": texts}
        return dict(result)

    def _initialize(self) -> None:
        self._post(
            {
                "jsonrpc": "2.0",
                "id": self._alloc_id(),
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "live_smoke_tilemap", "version": "2.0"},
                },
            }
        )
        for cat in ("tilemap", "scene_edit", "inspection", "runtime", "debugging"):
            try:
                self.call_tool("godot_enable_toolset", {"category": cat})
            except Exception:
                pass

    def _alloc_id(self) -> int:
        i = self._next_id
        self._next_id += 1
        return i

    def call_tool(
        self,
        name: str,
        arguments: Optional[Mapping[str, Any]] = None,
    ) -> Any:
        return self._post(
            {
                "jsonrpc": "2.0",
                "id": self._alloc_id(),
                "method": "tools/call",
                "params": {"name": name, "arguments": dict(arguments or {})},
            }
        )


def _write_results(rows: list[tuple[str, str, str]], mode: str) -> None:
    RESULTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    passed = sum(1 for _, s, _ in rows if s == "pass")
    failed = sum(1 for _, s, _ in rows if s == "fail")
    blocked = sum(1 for _, s, _ in rows if s == "blocked")
    lines = [
        "# Live smoke — TileMap / TileSet tools (TileMapLayer-first)",
        "",
        f"**Generated:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}",
        f"**Transport:** `{mode}`",
        f"**Project:** GodotAgentTest",
        f"**Terrain:** `{TERRAIN_TEX}`",
        "",
        f"**Rollup:** pass={passed} fail={failed} blocked={blocked}",
        "",
        "| # | Step | Status | Detail |",
        "|---|------|--------|--------|",
    ]
    for i, (name, status, detail) in enumerate(rows, 1):
        safe = detail.replace("|", "\\|").replace("\n", " ")[:200]
        lines.append(f"| {i} | {name} | **{status}** | {safe} |")
    lines.append("")
    RESULTS_PATH.write_text("\n".join(lines), encoding="utf-8")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--http-url", default=DEFAULT_HTTP)
    parser.add_argument("--http-only", action="store_true")
    args = parser.parse_args()

    rows: list[tuple[str, str, str]] = []
    try:
        transport = HttpMcpTransport(args.http_url)
    except (urllib.error.URLError, OSError, TimeoutError) as exc:
        rows.append(("connect MCP", "blocked", str(exc)))
        _write_results(rows, f"http:{args.http_url}")
        print("LIVE TILEMAP SMOKE: blocked — MCP HTTP unreachable")
        print("  start: powershell -File scripts\\start_mcp_server.ps1")
        return 2

    adapter = HybridindieBridgeAdapter(
        transport,
        enabled_toolsets=[
            "inspection",
            "scene_edit",
            "tilemap",
            "project",
            "runtime",
            "debugging",
        ],
        runtime_probe_present=True,
        godot_version="4.7.2.stable.steam",
    )
    adapter.connect()

    def step(name: str, fn) -> Any:
        try:
            result = fn()
            if result.ok:
                rows.append((name, "pass", json.dumps(dict(result.data))[:160]))
            else:
                err = result.error or ""
                status = (
                    "blocked"
                    if "PRECONDITION" in err or "not connected" in err.lower()
                    else "fail"
                )
                rows.append((name, status, err[:200]))
            return result
        except Exception as exc:  # noqa: BLE001
            rows.append((name, "fail", f"{type(exc).__name__}: {exc}"))
            return None

    step(
        "Open main scene",
        lambda: adapter.inspect_scene(InspectSceneArgs(scene_path=SCENE)),
    )

    try:
        adapter.edit_node(
            EditNodeArgs(operation="delete", node_path=LAYER_NAME, params={})
        )
    except Exception:
        pass

    step(
        "Create TileMapLayer",
        lambda: adapter.edit_node(
            EditNodeArgs(
                operation="create",
                node_path=".",
                params={
                    "parent_path": ".",
                    "node_type": "TileMapLayer",
                    "node_name": LAYER_NAME,
                },
            )
        ),
    )
    layer_path = LAYER_NAME

    step(
        "tileset_create 16x16",
        lambda: adapter.tileset_create(
            TilesetCreateArgs(
                tile_size=(16, 16),
                node_path=layer_path,
                save_path=TILESET_SAVE,
            )
        ),
    )

    step(
        "tileset_add_atlas Terrain",
        lambda: adapter.tileset_add_atlas(
            TilesetAddAtlasArgs(
                texture_path=TERRAIN_TEX,
                node_path=layer_path,
                texture_region_size=(16, 16),
                source_id=0,
            )
        ),
    )

    for coords in ((0, 0), (1, 0), (2, 0), (0, 1)):
        c = coords

        def _make(c=c):
            return lambda: adapter.tileset_create_tile(
                TilesetCreateTileArgs(
                    atlas_coords=c,
                    source_id=0,
                    node_path=layer_path,
                )
            )

        step(f"tileset_create_tile {c}", _make())

    insp = step(
        "tileset_inspect",
        lambda: adapter.tileset_inspect(TilesetInspectArgs(node_path=layer_path)),
    )
    step(
        "tileset_atlas_inspect",
        lambda: adapter.tileset_atlas_inspect(
            TilesetAtlasInspectArgs(source_id=0, node_path=layer_path)
        ),
    )

    step(
        "add_tileset_physics_layer",
        lambda: adapter.add_tileset_physics_layer(
            AddTilesetPhysicsLayerArgs(node_path=layer_path, collision_layer=1, collision_mask=1)
        ),
    )

    step(
        "set_tile_collision full_rect",
        lambda: adapter.set_tile_collision(
            SetTileCollisionArgs(
                source_id=0,
                atlas_coords=(0, 0),
                node_path=layer_path,
                shape="full_rect",
            )
        ),
    )

    td = step(
        "get_tile_data VERIFY collision",
        lambda: adapter.get_tile_data(
            GetTileDataArgs(source_id=0, atlas_coords=(0, 0), node_path=layer_path)
        ),
    )
    if td and td.ok:
        physics = td.data.get("physics") or []
        polys = 0
        if physics:
            polys = len((physics[0] or {}).get("polygons") or [])
        rows.append(
            (
                "verify collision polygons present",
                "pass" if polys > 0 else "fail",
                f"polygons={polys}",
            )
        )

    step(
        "tilemap_layer_set_physics ON",
        lambda: adapter.tilemap_layer_set_physics(
            TilemapLayerSetPhysicsArgs(node_path=layer_path, collision_enabled=True)
        ),
    )

    step(
        "tilemap_fill_rect ground",
        lambda: adapter.tilemap_fill_rect(
            TilemapFillRectArgs(
                node_path=layer_path,
                rect=(0, 10, 24, 2),
                source_id=0,
                atlas_coords=(0, 0),
            )
        ),
    )

    step(
        "tilemap_set_cells_batch accents",
        lambda: adapter.tilemap_set_cells_batch(
            TilemapSetCellsBatchArgs(
                node_path=layer_path,
                cells=[
                    {"coords": [3, 9], "source_id": 0, "atlas_coords": [1, 0]},
                    {"coords": [4, 9], "source_id": 0, "atlas_coords": [2, 0]},
                ],
            )
        ),
    )

    step(
        "tilemap_get_cell verify",
        lambda: adapter.tilemap_get_cell(
            TilemapGetCellArgs(node_path=layer_path, coords=(0, 10), layer=0)
        ),
    )

    # Negative collision smoke (TileData level)
    step(
        "clear_tile_collision (negative prep)",
        lambda: adapter.clear_tile_collision(
            ClearTileCollisionArgs(source_id=0, atlas_coords=(0, 0), node_path=layer_path)
        ),
    )
    td_neg = step(
        "get_tile_data VERIFY no collision",
        lambda: adapter.get_tile_data(
            GetTileDataArgs(source_id=0, atlas_coords=(0, 0), node_path=layer_path)
        ),
    )
    if td_neg and td_neg.ok:
        physics = td_neg.data.get("physics") or []
        polys = len((physics[0] or {}).get("polygons") or []) if physics else 0
        rows.append(
            (
                "verify collision cleared",
                "pass" if polys == 0 else "fail",
                f"polygons={polys}",
            )
        )

    step(
        "set_tile_collision restore",
        lambda: adapter.set_tile_collision(
            SetTileCollisionArgs(
                source_id=0,
                atlas_coords=(0, 0),
                node_path=layer_path,
                shape="full_rect",
            )
        ),
    )

    # Phase 2
    step(
        "add_tileset_custom_data_layer damage",
        lambda: adapter.add_tileset_custom_data_layer(
            AddTilesetCustomDataLayerArgs(name="damage", type="int", node_path=layer_path)
        ),
    )
    step(
        "set_tile_custom_data damage=20",
        lambda: adapter.set_tile_custom_data(
            SetTileCustomDataArgs(
                source_id=0,
                atlas_coords=(0, 0),
                name="damage",
                value=20,
                node_path=layer_path,
            )
        ),
    )
    step(
        "add_tileset_terrain_set",
        lambda: adapter.add_tileset_terrain_set(
            AddTilesetTerrainSetArgs(node_path=layer_path, mode=0)
        ),
    )
    step(
        "add_tileset_terrain ground",
        lambda: adapter.add_tileset_terrain(
            AddTilesetTerrainArgs(terrain_set=0, name="ground", node_path=layer_path)
        ),
    )
    # Gate: paint before config on empty set index should fail — use bad set
    bad = adapter.tilemap_set_terrain(
        TilemapSetTerrainArgs(
            node_path=layer_path,
            cells=[[0, 10]],
            terrain_set=99,
            terrain=0,
        )
    )
    if not bad.ok and "TERRAIN_NOT_CONFIGURED" in (bad.error or ""):
        rows.append(("TERRAIN_NOT_CONFIGURED gate", "pass", bad.error or ""))
    else:
        rows.append(
            (
                "TERRAIN_NOT_CONFIGURED gate",
                "fail",
                f"ok={bad.ok} err={bad.error}",
            )
        )

    step(
        "tileset_add_pattern room",
        lambda: adapter.tileset_add_pattern(
            TilesetAddPatternArgs(
                node_path=layer_path,
                cells=[
                    {
                        "coords": [0, 0],
                        "source_id": 0,
                        "atlas_coords": [0, 0],
                    },
                    {
                        "coords": [1, 0],
                        "source_id": 0,
                        "atlas_coords": [0, 0],
                    },
                ],
            )
        ),
    )

    # Phase 3 tracks (authoring)
    step(
        "P3-A add_tileset_navigation_layer",
        lambda: adapter.add_tileset_navigation_layer(
            AddTilesetNavigationLayerArgs(node_path=layer_path)
        ),
    )
    step(
        "P3-A set_tile_navigation",
        lambda: adapter.set_tile_navigation(
            SetTileNavigationArgs(
                source_id=0, atlas_coords=(0, 0), node_path=layer_path, shape="full_rect"
            )
        ),
    )
    step(
        "P3-A tilemap_layer_set_navigation",
        lambda: adapter.tilemap_layer_set_navigation(
            TilemapLayerSetNavigationArgs(node_path=layer_path, navigation_enabled=True)
        ),
    )
    step(
        "P3-B add_tileset_occlusion_layer",
        lambda: adapter.add_tileset_occlusion_layer(
            AddTilesetOcclusionLayerArgs(node_path=layer_path)
        ),
    )
    step(
        "P3-B set_tile_occlusion",
        lambda: adapter.set_tile_occlusion(
            SetTileOcclusionArgs(
                source_id=0, atlas_coords=(0, 0), node_path=layer_path, shape="full_rect"
            )
        ),
    )
    step(
        "P3-C add_tileset_scenes_collection_source",
        lambda: adapter.add_tileset_scenes_collection_source(
            AddTilesetScenesCollectionSourceArgs(node_path=layer_path, source_id=1)
        ),
    )
    step(
        "P3-D set_tile_constant_velocity",
        lambda: adapter.set_tile_constant_velocity(
            SetTileConstantVelocityArgs(
                source_id=0,
                atlas_coords=(0, 0),
                node_path=layer_path,
                linear_velocity=(50.0, 0.0),
            )
        ),
    )
    step(
        "P3-D tilemap_layer_set_kinematic",
        lambda: adapter.tilemap_layer_set_kinematic(
            TilemapLayerSetKinematicArgs(node_path=layer_path, use_kinematic_bodies=True)
        ),
    )

    step(
        "tilemap_inspect layers",
        lambda: adapter.tilemap_inspect(
            TilemapInspectArgs(node_path=layer_path, include_used_cells=False)
        ),
    )

    # Persist MCP scene mutations so play_scene authoring audit passes.
    step(
        "save_scene before play",
        lambda: adapter.save_scene(SaveSceneArgs(scene_path=SCENE)),
    )

    # Optional playtest: collision ON lands / OFF falls (best-effort)
    try:
        play = adapter.run_game(RunGameArgs(scene_path=SCENE))
        if play.ok:
            rows.append(("play_scene", "pass", json.dumps(dict(play.data))[:120]))
            # Wait briefly via observe
            obs = adapter.observe_runtime(ObserveRuntimeArgs(include_errors=True))
            if obs.ok:
                rows.append(("observe_runtime after play", "pass", "ok"))
            # Toggle collision_enabled off then on via layer flag — property verify if player exists
            off = adapter.tilemap_layer_set_physics(
                TilemapLayerSetPhysicsArgs(node_path=layer_path, collision_enabled=False)
            )
            rows.append(
                (
                    "playtest collision_enabled=false",
                    "pass" if off.ok else "fail",
                    "toggled" if off.ok else (off.error or ""),
                )
            )
            on = adapter.tilemap_layer_set_physics(
                TilemapLayerSetPhysicsArgs(node_path=layer_path, collision_enabled=True)
            )
            rows.append(
                (
                    "playtest collision_enabled=true",
                    "pass" if on.ok else "fail",
                    "restored" if on.ok else (on.error or ""),
                )
            )
            stop = adapter.stop_game(StopGameArgs())
            rows.append(
                ("stop_game", "pass" if stop.ok else "fail", "ok" if stop.ok else (stop.error or ""))
            )
        else:
            rows.append(("play_scene", "blocked", play.error or "play unavailable"))
    except Exception as exc:  # noqa: BLE001
        rows.append(("playtest suite", "blocked", f"{type(exc).__name__}: {exc}"))

    if insp and insp.ok:
        sources = insp.data.get("sources") or []
        rows.append(
            (
                "verify tileset_inspect sources",
                "pass" if sources else "fail",
                f"count={len(sources)}",
            )
        )

    _write_results(rows, f"http:{args.http_url}")
    passed = sum(1 for _, s, _ in rows if s == "pass")
    failed = sum(1 for _, s, _ in rows if s == "fail")
    blocked = sum(1 for _, s, _ in rows if s == "blocked")
    print(f"LIVE TILEMAP SMOKE: pass={passed} fail={failed} blocked={blocked}")
    for name, status, detail in rows:
        print(f"  [{status:7}] {name} — {detail[:100]}")
    print(f"Wrote {RESULTS_PATH}")
    return 0 if failed == 0 and blocked == 0 else 1


if __name__ == "__main__":
    raise SystemExit(main())
