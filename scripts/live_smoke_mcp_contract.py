"""Live smoke for Antigravity MCP contract fixes (parse / runtime / authoring).

Requires: patched godot-editor-mcp on :9090, Godot editor with addon connected.

    py -3 scripts/live_smoke_mcp_contract.py --http-url http://127.0.0.1:9090/mcp
"""

from __future__ import annotations

import argparse
import asyncio
import json
import sys
import time
from pathlib import Path
from typing import Any

_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

RESULTS_PATH = _ROOT / "Docs" / "spike" / "live_smoke_mcp_contract_results.md"

try:
    from mcp import ClientSession
    from mcp.client.streamable_http import streamable_http_client
except ImportError:  # pragma: no cover
    ClientSession = None  # type: ignore
    streamable_http_client = None  # type: ignore


def _is_tool_error(payload: Any) -> bool:
    if not isinstance(payload, dict):
        return False
    text = str(payload.get("text") or payload.get("error") or "")
    return (
        "BRIDGE_DISCONNECTED" in text
        or "ToolError" in text
        or "PRECONDITION_FAILED" in text
        or payload.get("ok") is False
    )


async def _call(session: Any, name: str, arguments: dict[str, Any] | None = None) -> Any:
    result = await session.call_tool(name, arguments or {})
    is_error = bool(getattr(result, "isError", False) or getattr(result, "is_error", False))
    structured = getattr(result, "structured_content", None) or getattr(
        result, "structuredContent", None
    )
    if structured:
        data = structured
        if is_error and isinstance(data, dict):
            data = dict(data)
            data["_is_error"] = True
        return data
    texts = []
    for block in getattr(result, "content", []) or []:
        text = getattr(block, "text", None)
        if text:
            texts.append(text)
    if not texts:
        return {"raw": str(result), "_is_error": is_error}
    joined = "\n".join(texts)
    # ToolError surfaces as plain text — treat as failure.
    if is_error or "BRIDGE_DISCONNECTED" in joined or joined.startswith("Error"):
        return {"text": joined, "_is_error": True}
    try:
        data = json.loads(texts[0])
        if is_error and isinstance(data, dict):
            data = dict(data)
            data["_is_error"] = True
        return data
    except json.JSONDecodeError:
        return {"text": joined, "_is_error": is_error}


def _row(name: str, status: str, detail: str) -> tuple[str, str, str]:
    return name, status, detail


async def run(http_url: str) -> list[tuple[str, str, str]]:
    rows: list[tuple[str, str, str]] = []
    if ClientSession is None or streamable_http_client is None:
        return [_row("imports", "fail", "mcp client not installed")]

    async with streamable_http_client(http_url) as streams:
        read, write = streams[0], streams[1]
        async with ClientSession(read, write) as session:
            await session.initialize()

            # 1) Parse contract — bad write
            bad = await _call(
                session,
                "godot_scripts_write",
                {
                    "script_path": "res://scripts/_contract_bad.gd",
                    "content": "extends Node\nfunc _ready()\n\tprint('missing colon')\n",
                },
            )
            parse = (bad or {}).get("parse") or {}
            if (bad or {}).get("success") is False and parse.get("status") == "error":
                rows.append(_row("parse_bad_write", "pass", json.dumps(parse)[:200]))
            else:
                rows.append(_row("parse_bad_write", "fail", json.dumps(bad)[:300]))

            # 2) Parse contract — good write
            good = await _call(
                session,
                "godot_scripts_write",
                {
                    "script_path": "res://scripts/_contract_good.gd",
                    "content": "extends Node\nfunc _ready() -> void:\n\tprint('ok')\n",
                },
            )
            parse_ok = (good or {}).get("parse") or {}
            if (good or {}).get("success") is True and parse_ok.get("status") == "ok":
                rows.append(_row("parse_good_write", "pass", "parse.status=ok"))
            else:
                rows.append(_row("parse_good_write", "fail", json.dumps(good)[:300]))

            # 3) MCP create_scene (authoring path)
            scene_path = "res://scenes/_contract_marker.tscn"
            created = await _call(
                session,
                "godot_scene_edit_create_scene",
                {"scene_path": scene_path, "root_type": "Node2D"},
            )
            if _is_tool_error(created):
                rows.append(_row("create_scene_mcp", "fail", json.dumps(created)[:300]))
            elif (created or {}).get("created") or (created or {}).get("scene_path"):
                rows.append(_row("create_scene_mcp", "pass", str(created)[:200]))
            else:
                rows.append(_row("create_scene_mcp", "fail", json.dumps(created)[:300]))

            # 4) Play + probe + output ready
            play = await _call(session, "godot_runtime_play_scene", {})
            if _is_tool_error(play):
                rows.append(_row("probe_connected", "fail", json.dumps(play)[:300]))
                rows.append(_row("output_ready", "fail", "skipped — play failed"))
                rows.append(_row("stale_output_clear", "fail", "skipped — play failed"))
                rows.append(_row("authoring_mcp_play", "fail", "skipped — play failed"))
                return rows

            probe = bool((play or {}).get("probe_connected"))
            deadline = time.monotonic() + 8.0
            while not probe and time.monotonic() < deadline:
                tree = await _call(session, "godot_runtime_get_game_scene_tree", {})
                if _is_tool_error(tree):
                    break
                probe = bool((tree or {}).get("connected"))
                await asyncio.sleep(0.2)
            rows.append(
                _row("probe_connected", "pass" if probe else "fail", f"play={play}")
            )

            out = await _call(session, "godot_runtime_get_game_output", {"since_seq": 0})
            if _is_tool_error(out) or (out or {}).get("ready") is False:
                rows.append(_row("output_ready", "fail", json.dumps(out)[:300]))
            else:
                rows.append(
                    _row(
                        "output_ready",
                        "pass",
                        f"entries={len((out or {}).get('entries', []))}",
                    )
                )

            # 5) Stale-state: stop, play again, output should be ready
            await _call(session, "godot_runtime_stop_scene", {})
            await asyncio.sleep(0.5)
            play2 = await _call(session, "godot_runtime_play_scene", {})
            out2 = await _call(session, "godot_runtime_get_game_output", {"since_seq": 0})
            if _is_tool_error(play2) or _is_tool_error(out2) or (out2 or {}).get("ready") is False:
                rows.append(
                    _row(
                        "stale_output_clear",
                        "fail",
                        json.dumps({"play2": play2, "out2": out2})[:300],
                    )
                )
            else:
                rows.append(
                    _row(
                        "stale_output_clear",
                        "pass",
                        f"play2_probe={(play2 or {}).get('probe_connected')} "
                        f"entries={len((out2 or {}).get('entries', []))}",
                    )
                )
            await _call(session, "godot_runtime_stop_scene", {})

            # 6) MCP save + play still allowed after MCP authoring touch
            await _call(session, "godot_scene_edit_open_scene", {"scene_path": scene_path})
            saved = await _call(session, "godot_scene_edit_save_scene", {})
            play3 = await _call(session, "godot_runtime_play_scene", {"scene_path": scene_path})
            text = json.dumps(play3)[:300]
            if _is_tool_error(play3) or "raw_scene_or_settings_edit" in text:
                rows.append(_row("authoring_mcp_play", "fail", text))
            else:
                rows.append(_row("authoring_mcp_play", "pass", f"saved={saved} play={play3}"))
            await _call(session, "godot_runtime_stop_scene", {})

    return rows


def write_results(rows: list[tuple[str, str, str]], mode: str) -> None:
    lines = [
        "# Live smoke — MCP Antigravity contract",
        "",
        f"**Mode:** `{mode}`",
        "",
        "| Test | Status | Detail |",
        "|---|---|---|",
    ]
    for name, status, detail in rows:
        safe = detail.replace("|", "\\|").replace("\n", " ")
        lines.append(f"| {name} | **{status}** | {safe} |")
    pass_n = sum(1 for _, s, _ in rows if s == "pass")
    lines += ["", f"**Rollup:** pass={pass_n} total={len(rows)}", ""]
    RESULTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESULTS_PATH.write_text("\n".join(lines), encoding="utf-8")
    print(RESULTS_PATH.read_text(encoding="utf-8"))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--http-url", default="http://127.0.0.1:9090/mcp")
    args = parser.parse_args()
    rows = asyncio.run(run(args.http_url))
    write_results(rows, f"http:{args.http_url}")
    return 0 if all(s == "pass" for _, s, _ in rows) else 1


if __name__ == "__main__":
    raise SystemExit(main())
