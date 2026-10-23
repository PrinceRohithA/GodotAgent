#!/usr/bin/env python3
"""Phase-0 live smoke for hybridindie via bridges.hybridindie adapter.

Tries a real MCP transport (HTTP preferred, stdio spawn fallback). If the
editor/server are not ready, writes blocked statuses + a checklist into
Docs/spike/live_smoke_results.md and prints the remaining human steps.

Usage (from repo root)::

    py -3 scripts/live_smoke_hybridindie.py
    py -3 scripts/live_smoke_hybridindie.py --http-url http://127.0.0.1:9090/mcp
    py -3 scripts/live_smoke_hybridindie.py --checklist-only
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import socket
import sys
import threading
import time
import traceback
from dataclasses import dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable, Mapping, Optional

_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from bridges.hybridindie.adapter import HybridindieBridgeAdapter
from bridges.hybridindie.mapping import (
    GODOT_MCP_DEFAULT_TOOLSETS_SEED,
    RUNTIME_PROBE_AUTOLOAD,
    RUNTIME_PROBE_SCRIPT,
)
from tools.schemas import (
    AnimationEditArgs,
    AnimationInspectArgs,
    AnimationTreeEditArgs,
    AnimationTreeInspectArgs,
    CaptureViewportArgs,
    EditNodeArgs,
    GetDiagnosticsArgs,
    InspectNodeArgs,
    InspectSceneArgs,
    ObserveRuntimeArgs,
    PatchScriptArgs,
    PlaytestInputArgs,
    PlaytestWaitArgs,
    RunGameArgs,
    SettingsGetArgs,
    SettingsSetArgs,
    StopGameArgs,
    ToolResult,
    ToolStatus,
    UndoArgs,
)

RESULTS_PATH = _ROOT / "Docs" / "spike" / "live_smoke_results.md"
RUNBOOK_PATH = _ROOT / "Docs" / "spike" / "LIVE_SMOKE_RUNBOOK.md"
DEFAULT_HTTP_URL = "http://127.0.0.1:9090/mcp"
DEFAULT_BRIDGE_URL = "ws://127.0.0.1:19080"
STEAM_GODOT = (
    r"C:\Program Files (x86)\Steam\steamapps\common\Godot Engine"
    r"\godot.windows.opt.tools.64.exe"
)
MCP_EXE = Path(
    os.environ.get(
        "GODOT_MCP_EXE",
        str(
            Path(os.environ.get("LOCALAPPDATA", ""))
            / "Packages"
            / "PythonSoftwareFoundation.Python.3.12_qbz5n2kfra8p0"
            / "LocalCache"
            / "local-packages"
            / "Python312"
            / "Scripts"
            / "godot-editor-mcp.exe"
        ),
    )
)


@dataclass
class CaseResult:
    number: int
    name: str
    status: str  # pass | fail | blocked
    detail: str = ""
    evidence: Mapping[str, Any] = field(default_factory=dict)


def _port_open(host: str, port: int, timeout: float = 0.4) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except OSError:
        return False


def _soft_error_message(data: Any) -> Optional[str]:
    """Detect MCP soft-failures returned as plain text with isError=false."""
    texts: list[str] = []
    if isinstance(data, str):
        texts.append(data)
    elif isinstance(data, Mapping):
        for key in ("error", "message", "text"):
            val = data.get(key)
            if isinstance(val, str):
                texts.append(val)
        texts_list = data.get("texts")
        if isinstance(texts_list, list):
            texts.extend(str(t) for t in texts_list)
    joined = "\n".join(texts)
    lower = joined.lower()
    markers = (
        "is not enabled",
        "precondition_failed",
        "bridge_connected",
        "not connected",
        "required=runtime_probe",
        "required=toolset",
        "unknown tool",
        "tool not found",
    )
    if any(m in lower for m in markers):
        # Avoid false positive on health payloads that merely report the field.
        if "bridge_connected" in lower and "false" not in lower and "is not enabled" not in lower:
            return None
        if '"bridge_connected": false' in lower or "bridge_connected\":false" in lower.replace(" ", ""):
            return joined
        if "is not enabled" in lower or "precondition_failed" in lower or "required=" in lower:
            return joined
        if "not connected" in lower or "unknown tool" in lower or "tool not found" in lower:
            return joined
    return None


def _parse_tool_payload(result: Any) -> Any:
    """Normalize MCP CallToolResult / dict into adapter-friendly data."""
    if result is None:
        return {}
    if isinstance(result, Mapping):
        data: Any = dict(result)
        soft = _soft_error_message(data)
        if soft:
            data = dict(data)
            data["isError"] = True
            data.setdefault("error", soft)
        return data
    # mcp SDK CallToolResult
    is_error = bool(getattr(result, "isError", False))
    structured = getattr(result, "structuredContent", None)
    if structured is not None:
        data = structured
    else:
        content = getattr(result, "content", None) or []
        texts: list[str] = []
        for block in content:
            text = getattr(block, "text", None)
            if text is not None:
                texts.append(text)
            elif isinstance(block, Mapping) and "text" in block:
                texts.append(str(block["text"]))
        images: list[dict[str, Any]] = []
        for block in content:
            # MCP ImageContent (game screenshot) — treat as success payload.
            mime = getattr(block, "mimeType", None) or getattr(block, "mime_type", None)
            img_data = getattr(block, "data", None)
            btype = getattr(block, "type", None)
            if img_data is not None and (btype == "image" or mime):
                images.append(
                    {
                        "mime_type": mime or "image/png",
                        "data_chars": len(str(img_data)),
                        "ready": True,
                    }
                )
        if len(texts) == 1:
            try:
                data = json.loads(texts[0])
            except json.JSONDecodeError:
                data = {"text": texts[0]}
        elif texts:
            data = {"texts": texts}
        elif images:
            data = {"ready": True, "images": images}
        else:
            data = {"raw": repr(result)}
    soft = _soft_error_message(data)
    if is_error or soft:
        if isinstance(data, Mapping):
            out = dict(data)
            out["isError"] = True
            out.setdefault("error", soft or str(data.get("message") or data))
            return out
        return {"isError": True, "error": soft or str(data)}
    return data


class AsyncSessionTransport:
    """Sync McpTransport wrapping an async MCP ClientSession on a worker loop."""

    def __init__(self, session: Any, loop: asyncio.AbstractEventLoop) -> None:
        self._session = session
        self._loop = loop

    def call_tool(
        self,
        name: str,
        arguments: Optional[Mapping[str, Any]] = None,
    ) -> Any:
        async def _call() -> Any:
            result = await self._session.call_tool(name, dict(arguments or {}))
            return _parse_tool_payload(result)

        fut = asyncio.run_coroutine_threadsafe(_call(), self._loop)
        return fut.result(timeout=120)


class LiveMcpSession:
    """Owns a background asyncio loop + MCP client session."""

    def __init__(self) -> None:
        self._loop: asyncio.AbstractEventLoop | None = None
        self._thread: threading.Thread | None = None
        self._session: Any = None
        self._transport: AsyncSessionTransport | None = None
        self._ready = threading.Event()
        self._error: BaseException | None = None
        self._mode = ""
        self._stop = asyncio.Event() if False else None  # placeholder typed later

    @property
    def transport(self) -> AsyncSessionTransport:
        if self._transport is None:
            raise RuntimeError("MCP session not started")
        return self._transport

    @property
    def mode(self) -> str:
        return self._mode

    def start_http(self, url: str) -> None:
        self._mode = f"http:{url}"
        self._start(lambda: self._run_http(url))

    def start_stdio(self, exe: Path, env: Mapping[str, str]) -> None:
        self._mode = f"stdio:{exe}"
        self._start(lambda: self._run_stdio(exe, env))

    def _start(self, runner: Callable[[], Any]) -> None:
        self._ready.clear()
        self._error = None

        def thread_main() -> None:
            loop = asyncio.new_event_loop()
            asyncio.set_event_loop(loop)
            self._loop = loop
            try:
                loop.run_until_complete(runner())
            except BaseException as exc:  # noqa: BLE001 — surface to parent
                self._error = exc
                self._ready.set()
            finally:
                try:
                    loop.run_until_complete(loop.shutdown_asyncgens())
                except Exception:
                    pass
                loop.close()

        self._thread = threading.Thread(target=thread_main, name="live-mcp", daemon=True)
        self._thread.start()
        if not self._ready.wait(timeout=45):
            raise TimeoutError(f"MCP session failed to become ready ({self._mode})")
        if self._error is not None:
            raise RuntimeError(f"MCP session failed ({self._mode}): {self._error}") from self._error

    async def _run_http(self, url: str) -> None:
        from mcp import ClientSession
        from mcp.client.streamable_http import streamable_http_client

        stop = asyncio.Event()
        self._stop = stop
        async with streamable_http_client(url) as streams:
            read, write = streams[0], streams[1]
            async with ClientSession(read, write) as session:
                await session.initialize()
                assert self._loop is not None
                self._session = session
                self._transport = AsyncSessionTransport(session, self._loop)
                self._ready.set()
                await stop.wait()

    async def _run_stdio(self, exe: Path, env: Mapping[str, str]) -> None:
        from mcp import ClientSession
        from mcp.client.stdio import StdioServerParameters, stdio_client

        stop = asyncio.Event()
        self._stop = stop
        merged = {**os.environ, **dict(env)}
        params = StdioServerParameters(command=str(exe), args=[], env=merged)
        async with stdio_client(params) as streams:
            read, write = streams[0], streams[1]
            async with ClientSession(read, write) as session:
                await session.initialize()
                assert self._loop is not None
                self._session = session
                self._transport = AsyncSessionTransport(session, self._loop)
                self._ready.set()
                await stop.wait()

    def close(self) -> None:
        if self._loop and self._stop is not None:
            self._loop.call_soon_threadsafe(self._stop.set)
        if self._thread:
            self._thread.join(timeout=10)


def _classify(result: ToolResult) -> tuple[str, str]:
    if result.ok:
        return "pass", ""
    err = result.error or ""
    code = ""
    if isinstance(result.data, Mapping):
        code = str(result.data.get("code") or "")
    blob = f"{code} {err}".upper()
    if any(
        x in blob
        for x in (
            "BRIDGE_DISCONNECTED",
            "PRECONDITION_FAILED",
            "NOT_CONNECTED",
            "RUNTIME_PROBE",
            "BRIDGE_CONNECTED",
            "CONNECTION",
            "TIMEOUT",
        )
    ):
        # Probe/toolset gates are failures of readiness → blocked for smoke.
        if "PRECONDITION_FAILED" in blob or "RUNTIME_PROBE" in blob:
            return "blocked", err
        if "BRIDGE" in blob or "NOT_CONNECTED" in blob or "CONNECTION" in blob:
            return "blocked", err
    if result.status is ToolStatus.UNSUPPORTED:
        return "fail", err
    return "fail", err


def _manual_checklist() -> list[str]:
    return [
        "1. Start MCP server: `powershell -File scripts/start_mcp_server.ps1`",
        "   (HTTP http://127.0.0.1:9090/mcp, bridge ws://127.0.0.1:19080 - not 9080; Nahimic owns 9080)",
        "2. Open Godot with bridge env: `powershell -File scripts/start_smoke_godot.ps1`",
        "3. If first open: run install_smoke_mcp_addon.ps1, then import `mcp_smoke_project`",
        "4. Project -> Project Settings -> Plugins -> enable Godot MCP (file-seeded; confirm Enabled)",
        "5. Confirm Autoload MCPRuntimeProbe -> res://addons/godot_mcp/mcp_runtime_probe.gd",
        "6. MCP dock should show connected / bridge_connected",
        "7. Optional Cursor: reload MCP from project .cursor/mcp.json (or user %USERPROFILE%\\.cursor\\mcp.json)",
        "8. Re-run: `py -3 scripts/live_smoke_hybridindie.py`",
    ]


def build_cases(adapter: HybridindieBridgeAdapter) -> list[tuple[int, str, Callable[[], ToolResult]]]:
    scene = "res://scenes/main.tscn"
    player = "Player"  # edited-scene relative (inspection / scene_edit)
    # Runtime probe paths are absolute from the playing game tree.
    runtime_player = "/root/Main/Player"
    anim = "Player/AnimationPlayer"
    return [
        (
            1,
            "Inspect current scene hierarchy",
            lambda: adapter.inspect_scene(InspectSceneArgs(scene_path=scene)),
        ),
        (
            2,
            "Inspect node properties",
            lambda: adapter.inspect_node(
                InspectNodeArgs(node_path=player, include_properties=True)
            ),
        ),
        (
            3,
            "Create / reparent node",
            lambda: adapter.edit_node(
                EditNodeArgs(
                    operation="create",
                    node_path=".",
                    params={
                        "parent_path": ".",
                        "node_type": "Node2D",
                        "node_name": "SmokeMarker",
                    },
                )
            ),
        ),
        (
            4,
            "Patch GDScript",
            lambda: adapter.patch_script(
                PatchScriptArgs(
                    script_path="res://scripts/player.gd",
                    patch=json.dumps(
                        {
                            "find": "const SPEED := 220.0",
                            "replace": "const SPEED := 221.0",
                        }
                    ),
                    format="find_replace",
                )
            ),
        ),
        (
            5,
            "Change InputMap",
            lambda: adapter.settings_set(
                SettingsSetArgs(section="input_map", key="smoke_ping", value={})
            ),
        ),
        (
            6,
            "Inspect / change AnimationPlayer",
            lambda: (
                adapter.animation_inspect(AnimationInspectArgs(node_path=anim))
                if False
                else _compose(
                    adapter.animation_inspect(AnimationInspectArgs(node_path=anim)),
                    adapter.animation_edit(
                        AnimationEditArgs(
                            node_path=anim,
                            operation="create",
                            params={"name": "smoke_idle", "length": 0.3},
                        )
                    ),
                )
            ),
        ),
        (
            7,
            "Inspect / change AnimationTree",
            lambda: _compose(
                adapter.animation_tree_edit(
                    AnimationTreeEditArgs(
                        node_path=".",
                        operation="create_tree",
                        params={
                            "parent_path": ".",
                            "name": "SmokeAnimTree",
                            "anim_player": anim,
                            "root_type": "AnimationNodeStateMachine",
                        },
                    )
                ),
                adapter.animation_tree_inspect(
                    AnimationTreeInspectArgs(node_path="SmokeAnimTree")
                ),
            ),
        ),
        (
            8,
            "Run game",
            lambda: _compose(
                # Fresh play avoids stale debugger sessions blocking probe attach.
                adapter.stop_game(StopGameArgs()),
                adapter.playtest_wait(PlaytestWaitArgs(seconds=0.4, until="stopped")),
                adapter.run_game(RunGameArgs(scene_path=scene, debug=True)),
                adapter.playtest_wait(PlaytestWaitArgs(seconds=2.0, until="playing")),
            ),
        ),
        (
            9,
            "Send keyboard input",
            lambda: _compose(
                _wait_for_runtime_probe(adapter, timeout_s=15.0),
                adapter.playtest_input(
                    PlaytestInputArgs(kind="key", name="D", pressed=True)
                ),
            ),
        ),
        (
            10,
            "Capture game viewport",
            lambda: adapter.capture_viewport(
                CaptureViewportArgs(destination="res://.smoke_capture.png")
            ),
        ),
        (
            11,
            "Retrieve runtime errors / state",
            lambda: adapter.observe_runtime(
                ObserveRuntimeArgs(
                    node_path=runtime_player,
                    properties=("position",),
                    include_errors=True,
                )
            ),
        ),
        (
            12,
            "Undo a mutation",
            lambda: _compose(
                # Undo must run in the editor (not during play). Leave play mode
                # first, then create a fresh undoable scene edit and revert it.
                adapter.stop_game(StopGameArgs()),
                adapter.playtest_wait(PlaytestWaitArgs(seconds=0.4, until="stopped")),
                adapter.edit_node(
                    EditNodeArgs(
                        operation="create",
                        node_path=".",
                        params={
                            "parent_path": ".",
                            "node_type": "Node",
                            "node_name": "SmokeUndoMarker",
                        },
                    )
                ),
                adapter.undo(UndoArgs(steps=1)),
            ),
        ),
    ]


def _compose(*results: ToolResult) -> ToolResult:
    """Return first failure, else last success (keeps evidence of final step)."""
    last_ok: ToolResult | None = None
    for r in results:
        if not r.ok:
            return r
        last_ok = r
    assert last_ok is not None
    return last_ok


def _wait_for_runtime_probe(
    adapter: HybridindieBridgeAdapter,
    *,
    timeout_s: float = 15.0,
) -> ToolResult:
    """Poll get_game_scene_tree until connected=true (probe attached) or timeout.

    Soft MCP replies can be ``ok`` with ``connected: false``; do not treat those
    as probe-ready. Prefer the raw tree tool over observe_runtime for the gate.
    """
    deadline = time.monotonic() + timeout_s
    last_raw: Any = None
    while time.monotonic() < deadline:
        try:
            last_raw = adapter._call("godot_runtime_get_game_scene_tree", {})  # noqa: SLF001
        except Exception as exc:  # noqa: BLE001
            last_raw = {"isError": True, "error": str(exc)}
        data = last_raw if isinstance(last_raw, Mapping) else {"value": last_raw}
        if isinstance(data, Mapping) and data.get("connected") is True:
            return ToolResult(
                status=ToolStatus.OK,
                data=dict(data),
                evidence={"mcp_tool": "godot_runtime_get_game_scene_tree", "probe": "connected"},
            )
        soft = _soft_error_message(data)
        blob = soft or str(data)
        lower = blob.lower()
        # Keep polling while play is up but probe has not attached yet.
        if data.get("playing") and data.get("connected") is False:
            time.sleep(0.35)
            continue
        if "runtime_probe" in lower or "precondition_failed" in lower or "not connected" in lower:
            time.sleep(0.35)
            continue
        if data.get("isError") or soft:
            return ToolResult(
                status=ToolStatus.ERROR,
                error=soft or str(data.get("error") or data),
                data={"code": "PRECONDITION_FAILED", "required": "runtime_probe", "raw": dict(data)},
            )
        time.sleep(0.35)
    return ToolResult(
        status=ToolStatus.ERROR,
        error="PRECONDITION_FAILED: required=runtime_probe (timeout waiting for probe)",
        data={
            "code": "PRECONDITION_FAILED",
            "required": "runtime_probe",
            "last": last_raw if isinstance(last_raw, Mapping) else {"value": last_raw},
        },
    )


def run_cases(adapter: HybridindieBridgeAdapter) -> list[CaseResult]:
    out: list[CaseResult] = []
    for number, name, fn in build_cases(adapter):
        try:
            result = fn()
            status, detail = _classify(result)
            out.append(
                CaseResult(
                    number=number,
                    name=name,
                    status=status,
                    detail=detail or ("" if result.ok else str(result.error)),
                    evidence=dict(result.evidence or {}),
                )
            )
        except Exception as exc:  # noqa: BLE001
            out.append(
                CaseResult(
                    number=number,
                    name=name,
                    status="fail",
                    detail=f"{type(exc).__name__}: {exc}",
                )
            )
        # Best-effort stop after runtime cases to leave editor idle.
        if number == 11:
            try:
                adapter.stop_game(StopGameArgs())
            except Exception:
                pass
    return out


def write_results(
    *,
    mode: str,
    cases: list[CaseResult],
    blocked_reason: str = "",
    checklist: Optional[list[str]] = None,
) -> None:
    now = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M:%S UTC")
    lines = [
        "# Live smoke results — hybridindie / Godot 4.7.2.steam",
        "",
        f"**Generated:** {now}",
        f"**Transport mode:** `{mode}`",
        f"**Bridge URL:** `{os.environ.get('GODOT_MCP_BRIDGE_URL', DEFAULT_BRIDGE_URL)}`",
        f"**Toolset seed:** `{GODOT_MCP_DEFAULT_TOOLSETS_SEED}`",
        f"**Runtime probe:** `{RUNTIME_PROBE_AUTOLOAD}` → `{RUNTIME_PROBE_SCRIPT}`",
        f"**Steam Godot:** `{STEAM_GODOT}`",
        "",
        "This is a **Phase-0 live smoke**, not a permanent bridge winner declaration.",
        "",
    ]
    if blocked_reason:
        lines += [
            "## Blocker",
            "",
            blocked_reason,
            "",
        ]
    lines += [
        "## 12 acceptance tests",
        "",
        "| # | Test | Status | Detail |",
        "|---|------|--------|--------|",
    ]
    for c in cases:
        detail = (c.detail or "").replace("|", "\\|").replace("\n", " ")
        if len(detail) > 160:
            detail = detail[:157] + "..."
        lines.append(f"| {c.number} | {c.name} | **{c.status}** | {detail} |")

    counts = {k: sum(1 for c in cases if c.status == k) for k in ("pass", "fail", "blocked")}
    lines += [
        "",
        f"**Rollup:** pass={counts['pass']} fail={counts['fail']} blocked={counts['blocked']}",
        "",
        "## Probe attach notes (tests 9–11)",
        "",
        "Autoload was already correct in `project.godot`. The live blocker was the",
        "addon debugger gate: `MCPDebugger.is_connected_to_probe()` required",
        "`_session_active` from `EditorDebuggerSession.started`, which can be missed",
        "after play/stop cycles even when the game probe already sent `godot_mcp:ready`.",
        "Fix: treat `godot_mcp:ready` (and already-active sessions in `_setup_session`)",
        "as proof the session is live — see `mcp_smoke_project/addons/godot_mcp/mcp_debugger.gd`.",
        "",
        "Harness also waits on `godot_runtime_get_game_scene_tree` → `connected: true`",
        "(not a soft `observe_runtime` ok), uses absolute `/root/Main/Player` for live",
        "property reads, and `start_smoke_godot.ps1` forces `GODOT_MCP_BRIDGE_URL`.",
        "",
        "**Human step:** none required when editor is already open via",
        "`scripts/start_smoke_godot.ps1` with plugin Enabled + Autoload present.",
        "If probe still never attaches after many play/stop cycles: fully quit the",
        "editor and relaunch that script (session-cap recovery).",
        "",
    ]
    if checklist:
        lines += ["## Remaining manual checklist", ""]
        lines += [f"- {item}" for item in checklist]
        lines += ["", f"See also `{RUNBOOK_PATH.relative_to(_ROOT).as_posix()}`."]
        lines += [""]
    RESULTS_PATH.parent.mkdir(parents=True, exist_ok=True)
    RESULTS_PATH.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_runbook() -> None:
    text = f"""# LIVE SMOKE RUNBOOK — hybridindie Phase-0

Steam Godot **4.7.2.stable.steam** · project `mcp_smoke_project/` · bridge **hybridindie**
(`godot-editor-mcp` **2026.09.30**).

## Why bridge port 19080?

On this machine `127.0.0.1:9080` is already taken by **NahimicService**.
hybridindie's default `ws://127.0.0.1:9080` therefore cannot bind.
All configs here use:

```text
GODOT_MCP_BRIDGE_URL=ws://127.0.0.1:19080
```

Set the **same** value for the MCP server process and the Godot editor process
(addon reads `OS.get_environment("GODOT_MCP_BRIDGE_URL")`).

## Exact start order

### A. MCP server (headless / PowerShell)

```powershell
cd C:\\Rohith\\Projects\\GodotAgent
powershell -File scripts\\start_mcp_server.ps1
```

Leaves HTTP MCP at `http://127.0.0.1:9090/mcp` and bridge listener on `19080`.

Cursor stdio alternative: project `.cursor/mcp.json` (already seeded). After editing,
**restart Cursor MCP / reload window**. User-global file if preferred:

`%USERPROFILE%\\.cursor\\mcp.json`

### B. Godot editor GUI

```powershell
powershell -File scripts\\start_smoke_godot.ps1
```

Forces `GODOT_MCP_BRIDGE_URL=ws://127.0.0.1:19080` onto the editor process
(ProcessStartInfo — do not open the project from Steam/Project Manager without that env).

**First-time / cold import only:**

1. Project manager → **Import** →  
   `C:\\Rohith\\Projects\\GodotAgent\\mcp_smoke_project\\project.godot` → **Import & Edit**
2. Wait for `.godot/` scan
3. **Project → Project Settings → Plugins** → **Godot MCP** = Enabled
4. **Autoload** → `MCPRuntimeProbe` → `res://addons/godot_mcp/mcp_runtime_probe.gd`
5. MCP dock connected to `ws://127.0.0.1:19080`
6. Open `res://scenes/main.tscn`

### C. Probe attach (tests 9–11)

No Autoload UI re-confirm is required once file-seeded. Probe connects over the
editor debugger channel (`mcp_runtime_probe.gd` → `godot_mcp:ready`).

If live tools still return `required=runtime_probe` after play:

1. Fully **quit** the Godot editor (not just Stop)
2. Relaunch via `scripts\\start_smoke_godot.ps1`
3. Re-run the harness

Root cause that blocked Phase-0: `MCPDebugger` only set `_session_active` on
`session.started`, which can miss after play/stop; `godot_mcp:ready` now also
marks the session active (local addon fix under `addons/godot_mcp/mcp_debugger.gd`).

### D. Run live smoke harness

```powershell
cd C:\\Rohith\\Projects\\GodotAgent
py -3 scripts\\live_smoke_hybridindie.py --http-only
```

Results: `Docs/spike/live_smoke_results.md`

### E. Fake-transport regression (no Godot needed)

```powershell
py -3 -m unittest tests.test_hybridindie_adapter -v
```

## Cursor MCP path (this machine)

| Location | Path |
|----------|------|
| Project (preferred) | `C:\\Rohith\\Projects\\GodotAgent\\.cursor\\mcp.json` |
| User (optional copy) | `%USERPROFILE%\\.cursor\\mcp.json` |

Server command uses the full path to `godot-editor-mcp.exe` because the Store
Python Scripts directory is often **not** on `PATH`.

Env seeded:

- `GODOT_MCP_DEFAULT_TOOLSETS={GODOT_MCP_DEFAULT_TOOLSETS_SEED}`
- `GODOT_MCP_BRIDGE_URL=ws://127.0.0.1:19080`
- `GODOT_MCP_GODOT_BIN` → Steam Godot binary
- `GODOT_MCP_PROJECT_DIR` → `mcp_smoke_project`

## Probe + toolsets

- Autoload already in `mcp_smoke_project/project.godot`: `{RUNTIME_PROBE_AUTOLOAD}`
- Without probe: playtest input / game screenshot / live observe → `PRECONDITION_FAILED`
- Without toolset seed: Cursor may ignore `tools/list_changed` after `godot_enable_toolset`

## Cleanup after smoke

- Stop play in editor if still running.
- Ctrl+C the HTTP MCP server console.
- Optional: revert `player.gd` SPEED if patch test passed (`221.0` → `220.0`).
"""
    RUNBOOK_PATH.parent.mkdir(parents=True, exist_ok=True)
    RUNBOOK_PATH.write_text(text, encoding="utf-8")


def try_connect(args: argparse.Namespace) -> tuple[Optional[LiveMcpSession], str, str]:
    """Return (session|None, mode, blocker)."""
    env = {
        "GODOT_MCP_DEFAULT_TOOLSETS": GODOT_MCP_DEFAULT_TOOLSETS_SEED,
        "GODOT_MCP_BRIDGE_URL": os.environ.get("GODOT_MCP_BRIDGE_URL", DEFAULT_BRIDGE_URL),
        "GODOT_MCP_GODOT_BIN": os.environ.get("GODOT_MCP_GODOT_BIN", STEAM_GODOT),
        "GODOT_MCP_PROJECT_DIR": str(_ROOT / "mcp_smoke_project"),
        "GODOT_MCP_LOG_LEVEL": "INFO",
    }
    os.environ.setdefault("GODOT_MCP_BRIDGE_URL", DEFAULT_BRIDGE_URL)

    if args.checklist_only:
        return None, "checklist-only", "Harness invoked with --checklist-only."

    # Prefer HTTP if port is up.
    http_url = args.http_url
    if _port_open("127.0.0.1", 9090) or args.force_http:
        session = LiveMcpSession()
        try:
            session.start_http(http_url)
            return session, session.mode, ""
        except Exception as exc:  # noqa: BLE001
            session.close()
            http_err = f"HTTP MCP connect failed ({http_url}): {exc}"
    else:
        http_err = "HTTP MCP not listening on 127.0.0.1:9090."

    if args.http_only:
        return None, "http-unavailable", http_err

    if not MCP_EXE.is_file():
        return (
            None,
            "no-server",
            f"{http_err} Stdio fallback missing exe: {MCP_EXE}",
        )

    session = LiveMcpSession()
    try:
        session.start_stdio(MCP_EXE, env)
        return session, session.mode, ""
    except Exception as exc:  # noqa: BLE001
        session.close()
        return (
            None,
            "connect-failed",
            f"{http_err} Stdio spawn failed: {exc}",
        )


def health_bridge_connected(transport: AsyncSessionTransport) -> tuple[bool, Any]:
    try:
        raw = transport.call_tool("godot_health_check", {})
    except Exception as exc:  # noqa: BLE001
        return False, {"error": str(exc)}
    data = raw if isinstance(raw, Mapping) else {"value": raw}
    # Do not treat mere presence of the key as connected.
    if isinstance(data, Mapping) and "bridge_connected" in data:
        return bool(data.get("bridge_connected")), data
    if isinstance(data, Mapping) and isinstance(data.get("bridge"), Mapping):
        return bool(data["bridge"].get("connected")), data
    return bool(isinstance(data, Mapping) and data.get("connected")), data


def ensure_v1_toolsets(transport: AsyncSessionTransport) -> list[str]:
    """Best-effort enable V1 toolsets (seed may have missed inspection)."""
    enabled: list[str] = []
    for category in GODOT_MCP_DEFAULT_TOOLSETS_SEED.split(","):
        category = category.strip()
        if not category:
            continue
        try:
            raw = transport.call_tool("godot_enable_toolset", {"category": category})
            if isinstance(raw, Mapping) and not raw.get("isError"):
                enabled.append(category)
        except Exception:
            continue
    return enabled


def main() -> int:
    # Avoid Windows cp1252 crashes on console arrows / en-dashes.
    try:
        sys.stdout.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
        sys.stderr.reconfigure(encoding="utf-8", errors="replace")  # type: ignore[attr-defined]
    except Exception:
        pass

    parser = argparse.ArgumentParser(description="hybridindie Phase-0 live smoke")
    parser.add_argument("--http-url", default=DEFAULT_HTTP_URL)
    parser.add_argument("--http-only", action="store_true")
    parser.add_argument("--force-http", action="store_true")
    parser.add_argument("--checklist-only", action="store_true")
    args = parser.parse_args()

    write_runbook()
    checklist = _manual_checklist()

    acceptance_names = [
        "Inspect current scene hierarchy",
        "Inspect node properties",
        "Create / reparent node",
        "Patch GDScript",
        "Change InputMap",
        "Inspect / change AnimationPlayer",
        "Inspect / change AnimationTree",
        "Run game",
        "Send keyboard input",
        "Capture game viewport",
        "Retrieve runtime errors / state",
        "Undo a mutation",
    ]

    session, mode, blocker = try_connect(args)
    if session is None:
        blocked_cases = [
            CaseResult(
                i + 1,
                acceptance_names[i],
                "blocked",
                blocker or "MCP/editor not ready",
            )
            for i in range(12)
        ]
        write_results(
            mode=mode,
            cases=blocked_cases,
            blocked_reason=blocker or "Environment not ready for live MCP calls.",
            checklist=checklist,
        )
        print("LIVE SMOKE: blocked — environment not ready")
        print(blocker)
        print("")
        print("Checklist:")
        for item in checklist:
            print(" ", item)
        print(f"\nWrote {RESULTS_PATH}")
        print(f"Wrote {RUNBOOK_PATH}")
        return 2

    try:
        enabled = ensure_v1_toolsets(session.transport)
        connected, health = health_bridge_connected(session.transport)
        adapter = HybridindieBridgeAdapter(
            session.transport,
            runtime_probe_present=True,  # file-seeded; live failures still surface from MCP
            godot_version="4.7.2.stable.steam",
        )
        adapter.connect()
        for ts in enabled:
            adapter.enable_toolset_local(ts)

        if not connected:
            detail = (
                "godot_health_check bridge_connected=false. "
                "Open mcp_smoke_project via scripts/start_smoke_godot.ps1 "
                f"(bridge {DEFAULT_BRIDGE_URL}). Health={health!r}"
            )
            cases = [
                CaseResult(i + 1, acceptance_names[i], "blocked", detail)
                for i in range(12)
            ]
            write_results(
                mode=mode,
                cases=cases,
                blocked_reason=detail,
                checklist=checklist,
            )
            print("LIVE SMOKE: blocked — Godot editor addon not connected")
            print(detail)
            for item in checklist:
                print(" ", item)
            return 3

        cases = run_cases(adapter)
        write_results(mode=mode, cases=cases, checklist=None)
        fails = sum(1 for c in cases if c.status == "fail")
        blocks = sum(1 for c in cases if c.status == "blocked")
        passes = sum(1 for c in cases if c.status == "pass")
        print(f"LIVE SMOKE: pass={passes} fail={fails} blocked={blocks} mode={mode}")
        for c in cases:
            print(f"  [{c.status:7}] #{c.number} {c.name}" + (f" — {c.detail}" if c.detail else ""))
        print(f"Wrote {RESULTS_PATH}")
        return 0 if fails == 0 and blocks == 0 else 1
    except Exception:
        traceback.print_exc()
        write_results(
            mode=mode,
            cases=[
                CaseResult(i + 1, f"test-{i+1}", "fail", "harness exception")
                for i in range(12)
            ],
            blocked_reason="Harness exception; see console traceback.",
            checklist=checklist,
        )
        return 4
    finally:
        session.close()


if __name__ == "__main__":
    raise SystemExit(main())
