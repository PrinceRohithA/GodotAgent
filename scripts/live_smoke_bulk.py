#!/usr/bin/env python3
"""Live smoke for bulk / composite authoring tools.

Requires:
  - godot-editor-mcp HTTP on :9090 (scripts/start_mcp_server.ps1; composite+animation seeded)
  - Patches applied (scripts/patch_godot_mcp_server.ps1)
  - mcp_smoke_project open with MCP dock connected (materialized by install_smoke_mcp_addon.ps1)

Usage::

    py -3 scripts/live_smoke_bulk.py --http-only
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
    CreateSpriteFramesArgs,
    EditNodeArgs,
    InspectSceneArgs,
    NodesCreateBatchArgs,
    NodesEditBatchArgs,
    SaveSceneArgs,
)

RESULTS_PATH = _ROOT / "Docs" / "spike" / "live_smoke_bulk_results.md"
DEFAULT_HTTP = "http://127.0.0.1:9090/mcp"
SCENE = "res://scenes/main.tscn"
IDLE_TEX = "res://assets/pixel_adventure_1/Main Characters/Mask Dude/Idle (32x32).png"
FRAMES_SAVE = "res://animations/smoke_player_frames.tres"
LEVEL = "BulkLevel"
SPRITE_PARENT = "BulkSpriteHost"


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
                "id": self._next_id,
                "method": "initialize",
                "params": {
                    "protocolVersion": "2024-11-05",
                    "capabilities": {},
                    "clientInfo": {"name": "live_smoke_bulk", "version": "1.0"},
                },
            }
        )
        self._next_id += 1
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})
        for cat in ("composite", "animation", "scene_edit", "inspection"):
            try:
                self.call_tool("godot_enable_toolset", {"category": cat})
            except Exception:
                pass

    def call_tool(
        self,
        name: str,
        arguments: Optional[Mapping[str, Any]] = None,
    ) -> Any:
        req_id = self._next_id
        self._next_id += 1
        return self._post(
            {
                "jsonrpc": "2.0",
                "id": req_id,
                "method": "tools/call",
                "params": {"name": name, "arguments": dict(arguments or {})},
            }
        )

def _ok(result: Any, label: str) -> None:
    if not getattr(result, "ok", False):
        raise AssertionError(f"{label} failed: {getattr(result, 'error', result)}")


def run_smoke(url: str) -> list[str]:
    lines: list[str] = []
    transport = HttpMcpTransport(url)
    adapter = HybridindieBridgeAdapter(transport, runtime_probe_present=True)
    adapter.connect()

    def step(name: str, fn) -> Any:
        result = fn()
        _ok(result, name)
        lines.append(f"- PASS `{name}`")
        return result

    step(
        "open_scene",
        lambda: adapter.inspect_scene(InspectSceneArgs(scene_path=SCENE)),
    )

    # Ensure parent Level node exists (create if missing).
    tree = adapter.inspect_scene(InspectSceneArgs(scene_path=SCENE))
    _ok(tree, "inspect_for_level")
    tree_text = json.dumps(tree.data)
    if LEVEL not in tree_text:
        step(
            "create_level",
            lambda: adapter.edit_node(
                EditNodeArgs(
                    node_path=".",
                    operation="create",
                    params={"parent_path": ".", "node_type": "Node2D", "node_name": LEVEL},
                )
            ),
        )

    platforms = []
    for i in range(1, 11):
        platforms.append(
            {
                "type": "StaticBody2D" if i % 2 else "AnimatableBody2D",
                "name": f"Platform{i:02d}",
                "parent": LEVEL,
                "properties": {"position": [80 * i, 200 + (i % 3) * 40]},
            }
        )

    created = step(
        "nodes_create_batch_10",
        lambda: adapter.nodes_create_batch(NodesCreateBatchArgs(nodes=platforms)),
    )
    created_n = int(created.data.get("created", 0) or 0)
    if created_n < 10:
        raise AssertionError(f"expected created>=10, got {created_n}: {created.data}")
    lines.append(f"  - created={created_n} changes={len(created.data.get('changes', []))}")

    # SpriteFrames: idle (row) + run (explicit cells) from Idle strip.
    frames = step(
        "create_sprite_frames",
        lambda: adapter.create_sprite_frames(
            CreateSpriteFramesArgs(
                texture=IDLE_TEX,
                frame_size=(32, 32),
                animations={
                    "idle": {"row": 0, "frames": 6, "fps": 8, "loop": True},
                    "run": {
                        "frames": [[6, 0], [7, 0], [8, 0], [9, 0]],
                        "fps": 12,
                        "loop": True,
                    },
                },
                save_path=FRAMES_SAVE,
            )
        ),
    )
    anims = frames.data.get("animations") or []
    names = frames.data.get("animation_names") or []
    if "idle" not in names or "run" not in names:
        raise AssertionError(f"missing anim names: {names}")
    by_name = {a.get("name"): a for a in anims if isinstance(a, Mapping)}
    if int(by_name.get("idle", {}).get("frames", 0)) != 6:
        raise AssertionError(f"idle frame count: {by_name.get('idle')}")
    if int(by_name.get("run", {}).get("frames", 0)) != 4:
        raise AssertionError(f"run frame count: {by_name.get('run')}")
    lines.append(f"  - animations={names} frame_counts ok; save={FRAMES_SAVE}")

    ops = [
        {
            "path": f"{LEVEL}/Platform{i:02d}",
            "property": "position",
            "value": [80 * i + 10, 220],
        }
        for i in range(1, 11)
    ]
    edited = step(
        "nodes_edit_batch_10",
        lambda: adapter.nodes_edit_batch(NodesEditBatchArgs(operations=ops)),
    )
    modified = int(edited.data.get("modified", 0) or 0)
    if modified < 1:
        raise AssertionError(f"expected modified>=1: {edited.data}")
    lines.append(f"  - modified={modified}")

    step("save_scene", lambda: adapter.save_scene(SaveSceneArgs()))
    verify = step(
        "verify_tree",
        lambda: adapter.inspect_scene(InspectSceneArgs(scene_path=SCENE)),
    )
    vtext = json.dumps(verify.data)
    missing = [f"Platform{i:02d}" for i in range(1, 11) if f"Platform{i:02d}" not in vtext]
    if missing:
        raise AssertionError(f"platforms missing after save: {missing}")
    lines.append("- PASS verify platforms present in scene tree")
    return lines


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--http-only", action="store_true")
    parser.add_argument("--url", default=DEFAULT_HTTP)
    args = parser.parse_args()
    started = datetime.now(timezone.utc).isoformat()
    try:
        lines = run_smoke(args.url)
        status = "GREEN"
        body = "\n".join(lines)
        code = 0
    except Exception as exc:  # noqa: BLE001 — smoke harness
        status = "RED"
        body = f"- FAIL `{type(exc).__name__}`: {exc}"
        code = 1
    report = "\n".join(
        [
            f"# Live smoke bulk - {status}",
            "",
            f"**UTC:** {started}",
            f"**Project:** GodotAgentTest",
            f"**URL:** {args.url}",
            "",
            body,
            "",
        ]
    )
    RESULTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESULTS_PATH.write_text(report, encoding="utf-8")
    print(report)
    return code


if __name__ == "__main__":
    sys.exit(main())
