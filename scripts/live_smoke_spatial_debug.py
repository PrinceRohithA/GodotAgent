#!/usr/bin/env python3
"""Live smoke for spatial observation + runtime/debug (demanding path).

Requires MCP HTTP :9090, patches applied, GodotAgentTest connected.
"""

from __future__ import annotations

import argparse
import json
import math
import sys
import urllib.request
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Mapping, Optional

_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from bridges.hybridindie.adapter import HybridindieBridgeAdapter
from tools.schemas import (
    DebugControlArgs,
    DebugErrorArgs,
    DebugStatusArgs,
    EditNodeArgs,
    InspectSceneArgs,
    NodesCreateBatchArgs,
    RuntimeNodeInspectArgs,
    RuntimeTreeArgs,
    SaveSceneArgs,
    SpatialObserveArgs,
    StopGameArgs,
)

RESULTS_PATH = _ROOT / "Docs" / "spike" / "live_smoke_spatial_debug_results.md"
DEFAULT_HTTP = "http://127.0.0.1:9090/mcp"
SCENE = "res://scenes/main.tscn"
HOST = "SpatialSmoke"


class HttpMcpTransport:
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
            return {"isError": True, "error": str(result)}
        structured = result.get("structuredContent")
        if structured is not None:
            return structured
        content = result.get("content") or []
        texts = [
            str(b.get("text", ""))
            for b in content
            if isinstance(b, Mapping) and "text" in b
        ]
        if len(texts) == 1:
            try:
                return json.loads(texts[0])
            except json.JSONDecodeError:
                return {"text": texts[0]}
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
                    "clientInfo": {"name": "live_smoke_spatial_debug", "version": "1.0"},
                },
            }
        )
        self._next_id += 1
        self._post({"jsonrpc": "2.0", "method": "notifications/initialized"})
        for cat in ("spatial", "runtime", "debugger", "scene_edit", "inspection", "composite"):
            try:
                self.call_tool("godot_enable_toolset", {"category": cat})
            except Exception:
                pass

    def call_tool(self, name: str, arguments: Optional[Mapping[str, Any]] = None) -> Any:
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


def _find_obj(objects: list, name_part: str) -> dict:
    for o in objects:
        if isinstance(o, Mapping) and name_part in str(o.get("path", "")):
            return dict(o)
    raise AssertionError(f"object containing {name_part!r} not found")


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

    step("open_scene", lambda: adapter.inspect_scene(InspectSceneArgs(scene_path=SCENE)))

    # Rebuild host so re-runs are idempotent.
    tree = adapter.inspect_scene(InspectSceneArgs(scene_path=SCENE))
    if HOST in json.dumps(tree.data):
        adapter.edit_node(
            EditNodeArgs(node_path=HOST, operation="delete", params={})
        )
        lines.append("- PASS `delete_stale_host`")
    step(
        "create_host",
        lambda: adapter.edit_node(
            EditNodeArgs(
                node_path=".",
                operation="create",
                params={"parent_path": ".", "node_type": "Node2D", "node_name": HOST},
            )
        ),
    )

    # Polygon2D fixtures for geometry source table tests A/B/D + nesting.
    nodes = [
        {
            "type": "Polygon2D",
            "name": "AxisAligned",
            "parent": HOST,
            "properties": {
                "position": [200, 200],
                "polygon": [[-50, -10], [50, -10], [50, 10], [-50, 10]],
            },
        },
        {
            "type": "Polygon2D",
            "name": "Rotated90",
            "parent": HOST,
            "properties": {
                "position": [400, 200],
                "rotation": math.pi / 2,
                "polygon": [[-50, -10], [50, -10], [50, 10], [-50, 10]],
            },
        },
        {
            "type": "Polygon2D",
            "name": "Scaled",
            "parent": HOST,
            "properties": {
                "position": [600, 200],
                "scale": [2, 1],
                "polygon": [[-50, -10], [50, -10], [50, 10], [-50, 10]],
            },
        },
        {
            "type": "Node2D",
            "name": "NestParent",
            "parent": HOST,
            "properties": {"position": [100, 400], "rotation": 0.3},
        },
    ]
    step("create_fixtures", lambda: adapter.nodes_create_batch(NodesCreateBatchArgs(nodes=nodes)))
    step(
        "create_nested_child",
        lambda: adapter.nodes_create_batch(
            NodesCreateBatchArgs(
                nodes=[
                    {
                        "type": "Polygon2D",
                        "name": "NestChild",
                        "parent": f"{HOST}/NestParent",
                        "properties": {
                            "position": [40, 0],
                            "polygon": [[-20, -20], [20, -20], [20, 20], [-20, 20]],
                        },
                    }
                ]
            )
        ),
    )

    spat = step(
        "editor_spatial_observe",
        lambda: adapter.spatial_observe(
            SpatialObserveArgs(
                scope="editor",
                root=HOST,
                depth=4,
                include=("transform", "bounds", "collision"),
            )
        ),
    )
    objects = spat.data.get("objects") or []
    aa = _find_obj(objects, "AxisAligned")
    rot = _find_obj(objects, "Rotated90")
    scaled = _find_obj(objects, "Scaled")
    nested = _find_obj(objects, "NestChild")
    if not aa.get("geometry", {}).get("available"):
        raise AssertionError(f"AxisAligned geometry unavailable: {aa.get('geometry')}")
    ga = aa["geometry"]["global_aabb"]
    if abs(float(ga["width"]) - 100) > 2 or abs(float(ga["height"]) - 20) > 2:
        raise AssertionError(f"Test A AABB unexpected: {ga}")
    gr = rot["geometry"]["global_aabb"]
    if abs(float(gr["width"]) - 20) > 2 or abs(float(gr["height"]) - 100) > 2:
        raise AssertionError(f"Test B AABB unexpected: {gr}")
    gs = scaled["geometry"]["global_aabb"]
    if abs(float(gs["width"]) - 200) > 2:
        raise AssertionError(f"Test D AABB unexpected: {gs}")
    # Nested: global != local position
    lt = nested.get("transform", {}).get("local", {}).get("position")
    gt = nested.get("transform", {}).get("global", {}).get("position")
    if lt == gt:
        raise AssertionError(f"nested local==global unexpectedly: {lt} {gt}")
    lines.append("  - AABB A/B/D + nested local/global OK")

    # Unsupported type should report unavailable geometry
    unsupported = [o for o in objects if o.get("type") == "Node2D"]
    if unsupported and unsupported[0].get("geometry", {}).get("available") is True:
        raise AssertionError("Node2D must not invent geometry")
    lines.append("  - unsupported Node2D geometry unavailable OK")

    step("save_scene", lambda: adapter.save_scene(SaveSceneArgs()))

    # Runtime path
    from tools.schemas import RunGameArgs

    play = step("run_game", lambda: adapter.run_game(RunGameArgs(scene_path=SCENE)))
    lines.append(f"  - play probe={play.data.get('probe_connected')}")

    import time

    time.sleep(1.5)
    rt = step("runtime_tree", lambda: adapter.runtime_tree(RuntimeTreeArgs(depth=8)))
    if not rt.data.get("tree") and not rt.data.get("ready", True):
        raise AssertionError(f"runtime tree empty: {rt.data}")

    rs = step(
        "runtime_spatial",
        lambda: adapter.spatial_observe(
            SpatialObserveArgs(scope="runtime", root="/root", depth=6, include=("transform", "bounds"))
        ),
    )
    if not (rs.data.get("objects") or rs.data.get("ready") is False):
        # pending then retry once
        time.sleep(0.5)
        rs = step(
            "runtime_spatial_retry",
            lambda: adapter.spatial_observe(
                SpatialObserveArgs(
                    scope="runtime", root="/root", depth=6, include=("transform", "bounds")
                )
            ),
        )

    # Debug status / force break / error / continue
    st = step("debug_status", lambda: adapter.debug_status(DebugStatusArgs()))
    lines.append(f"  - session_id={st.data.get('session_id')} breaked={st.data.get('breaked')}")
    br = step("force_break", lambda: adapter.debug_control(DebugControlArgs(operation="break")))
    time.sleep(0.4)
    st2 = step("debug_status_after_break", lambda: adapter.debug_status(DebugStatusArgs()))
    de = step("debug_error", lambda: adapter.debug_error(DebugErrorArgs()))
    lines.append(
        f"  - breaked={st2.data.get('breaked')} reason={de.data.get('reason')} "
        f"stack_frames={len(de.data.get('stack') or [])}"
    )
    if st2.data.get("breaked"):
        step("continue", lambda: adapter.debug_control(DebugControlArgs(operation="continue")))
    step("stop_game", lambda: adapter.stop_game(StopGameArgs()))
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
    except Exception as exc:  # noqa: BLE001
        status = "RED"
        body = f"- FAIL `{type(exc).__name__}`: {exc}"
        code = 1
    report = "\n".join(
        [
            f"# Live smoke spatial/debug - {status}",
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
