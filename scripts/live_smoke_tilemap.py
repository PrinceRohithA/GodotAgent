#!/usr/bin/env python3
"""Live smoke for abstract TileSet/TileMap tools via hybridindie adapter.

Requires:
  - godot-editor-mcp HTTP on :9090 (scripts/start_mcp_server.ps1 with tilemap seeded)
  - GodotAgentTest open with MCP dock connected (scripts/start_godot.ps1)

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
    EditNodeArgs,
    InspectSceneArgs,
    TilemapFillRectArgs,
    TilemapGetCellArgs,
    TilemapInspectArgs,
    TilemapSetCellArgs,
    TilesetAddAtlasArgs,
    TilesetCreateArgs,
    TilesetCreateTileArgs,
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
        with urllib.request.urlopen(req, timeout=60) as resp:
            sid = resp.headers.get("Mcp-Session-Id")
            if sid:
                self._session = sid
            body = resp.read().decode("utf-8", errors="replace")
        return self._parse_body(body)

    def _parse_body(self, body: str) -> Any:
        # Prefer last JSON-RPC response from SSE stream.
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
        # Prefer messages with id/result/error
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
            # content text often holds the error
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
                    "clientInfo": {"name": "live_smoke_tilemap", "version": "1.0"},
                },
            }
        )
        # Enable tilemap toolset (seed may already have it after server restart).
        self.call_tool("godot_enable_toolset", {"category": "tilemap"})
        self.call_tool("godot_enable_toolset", {"category": "scene_edit"})
        self.call_tool("godot_enable_toolset", {"category": "inspection"})

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
        "# Live smoke — TileMap / TileSet tools",
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
        print(f"  start: powershell -File scripts\\start_mcp_server.ps1")
        return 2

    adapter = HybridindieBridgeAdapter(
        transport,
        enabled_toolsets=[
            "inspection",
            "scene_edit",
            "tilemap",
            "project",
        ],
        runtime_probe_present=False,
        godot_version="4.7.2.stable.steam",
    )
    adapter.connect()

    def step(name: str, fn) -> None:
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
        except Exception as exc:  # noqa: BLE001
            rows.append((name, "fail", f"{type(exc).__name__}: {exc}"))

    step(
        "Open main scene",
        lambda: adapter.inspect_scene(InspectSceneArgs(scene_path=SCENE)),
    )

    # Remove prior smoke layer if present (ignore failure).
    try:
        adapter.edit_node(
            EditNodeArgs(
                operation="delete",
                node_path=LAYER_NAME,
                params={},
            )
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

    # Create a few atlas tiles so paint has valid cells
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
        "tilemap_get_cell verify",
        lambda: adapter.tilemap_get_cell(
            TilemapGetCellArgs(node_path=layer_path, coords=(0, 10), layer=0)
        ),
    )

    step(
        "tilemap_set_cell accent",
        lambda: adapter.tilemap_set_cell(
            TilemapSetCellArgs(
                node_path=layer_path,
                coords=(5, 9),
                source_id=0,
                atlas_coords=(1, 0),
            )
        ),
    )

    step(
        "tilemap_inspect layers",
        lambda: adapter.tilemap_inspect(
            TilemapInspectArgs(node_path=layer_path, include_used_cells=False)
        ),
    )

    # Verify get_cell is not empty
    verify = adapter.tilemap_get_cell(
        TilemapGetCellArgs(node_path=layer_path, coords=(0, 10))
    )
    if verify.ok and verify.data.get("empty") is True:
        rows.append(("verify painted cell non-empty", "fail", str(verify.data)))
    elif verify.ok:
        rows.append(
            (
                "verify painted cell non-empty",
                "pass",
                f"source_id={verify.data.get('source_id')}",
            )
        )
    else:
        rows.append(("verify painted cell non-empty", "fail", verify.error or ""))

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
