"""hybridindie / godot-editor-mcp bridge adapter.

Maps ``AbstractGodotTools`` onto documented ``godot_*`` MCP tools via an
injectable transport. No live Godot / MCP server is required for unit tests.
"""

from __future__ import annotations

import json
import time
from typing import Any, Iterable, Mapping, Optional, Protocol, runtime_checkable

from bridges.base import BridgeInfo
from bridges.hybridindie import mapping as mcp_map
from tools.registry import CapabilityRegistry
from tools.schemas import (
    AnimationEditArgs,
    AnimationInspectArgs,
    AnimationTreeEditArgs,
    AnimationTreeInspectArgs,
    AttachScriptArgs,
    CaptureViewportArgs,
    CreateSceneArgs,
    EditNodeArgs,
    GetDiagnosticsArgs,
    InspectNodeArgs,
    InspectProjectArgs,
    InspectSceneArgs,
    ObserveRuntimeArgs,
    PatchScriptArgs,
    PlaytestInputArgs,
    PlaytestWaitArgs,
    ReadScriptArgs,
    RunGameArgs,
    SaveSceneArgs,
    SetPropertyArgs,
    SettingsGetArgs,
    SettingsSetArgs,
    StopGameArgs,
    TilemapClearArgs,
    TilemapFillRectArgs,
    TilemapGetCellArgs,
    TilemapInspectArgs,
    TilemapSetCellArgs,
    TilesetAddAtlasArgs,
    TilesetCreateArgs,
    TilesetCreateTileArgs,
    TilesetInspectArgs,
    ToolResult,
    ToolStatus,
    UndoArgs,
)


@runtime_checkable
class McpTransport(Protocol):
    """Minimal MCP tools/call surface. Real clients wrap stdio/HTTP later."""

    def call_tool(
        self,
        name: str,
        arguments: Optional[Mapping[str, Any]] = None,
    ) -> Any:
        ...


# Static V1 capability report (docs-grounded for hybridindie 2026.09.30).
EXPECTED_CAPABILITIES: Mapping[str, bool] = {
    "scene_editing": True,
    "property_editing": True,
    "resource_editing": True,
    "script_editing": True,
    "animation_player": True,
    "animation_tree": True,  # hybridindie-only among V1 bridges
    "runtime_debugger": True,
    "viewport_capture": True,
    "project_settings": True,
    "playtest": True,
    "documentation_search": False,
    "agent_undo": True,  # godot_undo always-on core
    "tilemap_editing": True,
}


class HybridindieBridgeAdapter:
    """BridgeAdapter implementation for hybridindie godot-editor-mcp."""

    BRIDGE_ID = "hybridindie"
    DISPLAY_NAME = "hybridindie/godot-mcp (godot-editor-mcp)"

    def __init__(
        self,
        transport: McpTransport,
        *,
        enabled_toolsets: Optional[Iterable[str]] = None,
        runtime_probe_present: bool = False,
        godot_version: str = "4.7.2.stable.steam",
        poll_interval_s: float = 0.05,
    ) -> None:
        self._transport = transport
        self._connected = False
        self._info: BridgeInfo | None = None
        self._godot_version = godot_version
        self._runtime_probe_present = bool(runtime_probe_present)
        self._poll_interval_s = poll_interval_s
        seeded = set(mcp_map.ALWAYS_ON_TOOLSETS)
        if enabled_toolsets is None:
            seeded.update(mcp_map.V1_DEFAULT_TOOLSETS)
        else:
            seeded.update(enabled_toolsets)
        self._enabled_toolsets: set[str] = seeded

    # --- lifecycle ---------------------------------------------------------

    def connect(self) -> BridgeInfo:
        """Record connected state; populate capabilities from the static V1 list.

        A future transport may call ``godot_health_check`` / ``godot_get_server_info``
        here; V1 stays offline-friendly for fake-transport tests.
        """
        self._connected = True
        self._info = BridgeInfo(
            bridge_id=self.BRIDGE_ID,
            display_name=self.DISPLAY_NAME,
            godot_version=self._godot_version,
            capabilities=dict(EXPECTED_CAPABILITIES),
        )
        return self._info

    def disconnect(self) -> None:
        self._connected = False

    def bridge_info(self) -> BridgeInfo:
        if self._info is None:
            return BridgeInfo(
                bridge_id=self.BRIDGE_ID,
                display_name=self.DISPLAY_NAME,
                godot_version=self._godot_version,
                capabilities=dict(EXPECTED_CAPABILITIES),
            )
        return self._info

    def apply_capabilities(self, registry: CapabilityRegistry) -> CapabilityRegistry:
        info = self.bridge_info()
        registry.update_from_bridge(
            godot_version=info.godot_version,
            capabilities=info.capabilities,
            bridge_id=info.bridge_id,
        )
        return registry

    def set_runtime_probe_present(self, present: bool) -> None:
        self._runtime_probe_present = bool(present)

    def enable_toolset_local(self, toolset: str) -> None:
        """Record a toolset as enabled (mirrors GODOT_MCP_DEFAULT_TOOLSETS / enable_toolset)."""
        self._enabled_toolsets.add(toolset)

    @property
    def enabled_toolsets(self) -> frozenset[str]:
        return frozenset(self._enabled_toolsets)

    @staticmethod
    def expected_capability_template() -> Mapping[str, bool]:
        return dict(EXPECTED_CAPABILITIES)

    # --- AbstractGodotTools ------------------------------------------------

    def inspect_project(self, args: InspectProjectArgs) -> ToolResult:
        gate = self._preflight("inspect_project")
        if gate is not None:
            return gate
        raw = self._call("godot_inspection_get_project_info", {})
        data = self._as_mapping(raw)
        if not args.include_autoload and "autoloads" in data:
            data = {k: v for k, v in data.items() if k != "autoloads"}
        if not args.include_input_map and "input_actions" in data:
            data = {k: v for k, v in data.items() if k != "input_actions"}
        return self._ok(data, evidence={"mcp_tool": "godot_inspection_get_project_info"})

    def inspect_scene(self, args: InspectSceneArgs) -> ToolResult:
        gate = self._preflight("inspect_scene")
        if gate is not None:
            return gate
        # Open target scene when scene_edit is available and path is set.
        if args.scene_path and "scene_edit" in self._enabled_toolsets:
            open_raw = self._call(
                "godot_scene_edit_open_scene",
                {"scene_path": args.scene_path},
            )
            open_err = self._mcp_error_result(open_raw, "godot_scene_edit_open_scene")
            if open_err is not None:
                return open_err
        raw = self._call("godot_inspection_get_scene_tree", {})
        err = self._mcp_error_result(raw, "godot_inspection_get_scene_tree")
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={
                "mcp_tool": "godot_inspection_get_scene_tree",
                "scene_path": args.scene_path,
            },
        )

    def inspect_node(self, args: InspectNodeArgs) -> ToolResult:
        gate = self._preflight("inspect_node")
        if gate is not None:
            return gate
        if args.include_children:
            raw = self._call(
                "godot_inspection_snapshot_subtree",
                {"node_path": args.node_path},
            )
            tool_name = "godot_inspection_snapshot_subtree"
        else:
            raw = self._call(
                "godot_inspection_get_node_properties",
                {"node_path": args.node_path},
            )
            tool_name = "godot_inspection_get_node_properties"
        err = self._mcp_error_result(raw, tool_name)
        if err is not None:
            return err
        data = self._as_mapping(raw)
        if not args.include_properties and "properties" in data:
            data = {k: v for k, v in data.items() if k != "properties"}
        return self._ok(data, evidence={"mcp_tool": tool_name})

    def set_property(self, args: SetPropertyArgs) -> ToolResult:
        gate = self._preflight("set_property")
        if gate is not None:
            return gate
        payload = {
            "node_path": args.node_path,
            "property": args.property_name,
            "value": args.value,
        }
        raw = self._call("godot_scene_edit_set_node_property", payload)
        err = self._mcp_error_result(raw, "godot_scene_edit_set_node_property")
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": "godot_scene_edit_set_node_property"},
            change=payload,
        )

    def edit_node(self, args: EditNodeArgs) -> ToolResult:
        gate = self._preflight("edit_node")
        if gate is not None:
            return gate
        op = (args.operation or "").strip().lower()
        params = dict(args.params)
        if op == "create":
            payload = {
                "parent_path": params.get("parent_path", args.node_path or "."),
                "node_type": params.get("node_type") or params.get("type"),
                "node_name": params.get("node_name") or params.get("name"),
            }
            if not payload["node_type"] or not payload["node_name"]:
                return self._error(
                    "edit_node create requires params.node_type and params.node_name",
                    code="PARAM_ERROR",
                )
            tool = "godot_scene_edit_create_node"
        elif op == "delete":
            payload = {"node_path": args.node_path, "confirm": True}
            tool = "godot_scene_edit_delete_node"
        elif op == "rename":
            new_name = params.get("new_name") or params.get("name")
            if not new_name:
                return self._error(
                    "edit_node rename requires params.new_name",
                    code="PARAM_ERROR",
                )
            payload = {"node_path": args.node_path, "new_name": new_name}
            tool = "godot_scene_edit_rename_node"
        elif op == "duplicate":
            payload = {"node_path": args.node_path}
            tool = "godot_scene_edit_duplicate_node"
        elif op == "reparent":
            new_parent = params.get("new_parent_path") or params.get("parent_path")
            if not new_parent:
                return self._error(
                    "edit_node reparent requires params.new_parent_path",
                    code="PARAM_ERROR",
                )
            payload = {
                "node_path": args.node_path,
                "new_parent_path": new_parent,
                "index": params.get("index", -1),
            }
            tool = "godot_scene_edit_move_node"
        else:
            return self._error(
                f"unsupported edit_node operation: {args.operation!r}",
                code="PARAM_ERROR",
            )
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool, "operation": op},
            change={"operation": op, **payload},
        )

    def create_scene(self, args: CreateSceneArgs) -> ToolResult:
        gate = self._preflight("create_scene")
        if gate is not None:
            return gate
        payload = {
            "scene_path": args.scene_path,
            "root_type": args.root_type,
        }
        raw = self._call("godot_scene_edit_create_scene", payload)
        err = self._mcp_error_result(raw, "godot_scene_edit_create_scene")
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": "godot_scene_edit_create_scene"},
            change=payload,
        )

    def save_scene(self, args: SaveSceneArgs) -> ToolResult:
        gate = self._preflight("save_scene")
        if gate is not None:
            return gate
        raw = self._call("godot_scene_edit_save_scene", {})
        err = self._mcp_error_result(raw, "godot_scene_edit_save_scene")
        if err is not None:
            return err
        data = self._as_mapping(raw)
        if args.scene_path:
            data = dict(data)
            data["requested_scene_path"] = args.scene_path
        return self._ok(
            data,
            evidence={"mcp_tool": "godot_scene_edit_save_scene"},
            change={"scene_path": args.scene_path},
        )

    def attach_script(self, args: AttachScriptArgs) -> ToolResult:
        gate = self._preflight("attach_script")
        if gate is not None:
            return gate
        payload = {
            "node_path": args.node_path,
            "script_path": args.script_path,
        }
        raw = self._call("godot_scene_edit_attach_script", payload)
        err = self._mcp_error_result(raw, "godot_scene_edit_attach_script")
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": "godot_scene_edit_attach_script"},
            change=payload,
        )

    def patch_script(self, args: PatchScriptArgs) -> ToolResult:
        gate = self._preflight("patch_script")
        if gate is not None:
            return gate
        fmt = (args.format or "unified_diff").strip().lower()
        if fmt == "full_replace":
            payload = {"script_path": args.script_path, "content": args.patch}
            tool = "godot_scripts_write"
        elif fmt in {"find_replace", "find/replace", "anchor"}:
            try:
                body = json.loads(args.patch) if isinstance(args.patch, str) else args.patch
            except json.JSONDecodeError:
                return self._error(
                    "patch_script find_replace format expects JSON "
                    '{"find": "...", "replace": "..."}',
                    code="PARAM_ERROR",
                )
            if not isinstance(body, Mapping) or "find" not in body or "replace" not in body:
                return self._error(
                    "patch_script find_replace requires find and replace keys",
                    code="PARAM_ERROR",
                )
            payload = {
                "script_path": args.script_path,
                "find": body["find"],
                "replace": body["replace"],
            }
            tool = "godot_scripts_patch"
        elif fmt == "unified_diff":
            # hybridindie has no unified-diff apply tool — refuse clearly.
            return ToolResult(
                status=ToolStatus.UNSUPPORTED,
                error=(
                    "hybridindie godot_scripts_patch uses find/replace, not unified_diff. "
                    'Use format="find_replace" with JSON {"find","replace"}, '
                    'or format="full_replace".'
                ),
                data={"code": "UNSUPPORTED_FORMAT", "format": fmt},
            )
        else:
            return self._error(
                f"unknown patch_script format: {args.format!r}",
                code="PARAM_ERROR",
            )
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool, "format": fmt},
            change={"script_path": args.script_path, "format": fmt},
        )

    def read_script(self, args: ReadScriptArgs) -> ToolResult:
        gate = self._preflight("read_script")
        if gate is not None:
            return gate
        raw = self._call("godot_scripts_read", {"script_path": args.script_path})
        err = self._mcp_error_result(raw, "godot_scripts_read")
        if err is not None:
            return err
        data = self._as_mapping(raw)
        content = data.get("content")
        if isinstance(content, str) and (
            args.start_line is not None or args.end_line is not None
        ):
            lines = content.splitlines(keepends=True)
            start = max((args.start_line or 1) - 1, 0)
            end = args.end_line if args.end_line is not None else len(lines)
            data = dict(data)
            data["content"] = "".join(lines[start:end])
            data["start_line"] = start + 1
            data["end_line"] = start + data["content"].count("\n") + (
                0 if data["content"].endswith("\n") else 1
            )
        return self._ok(data, evidence={"mcp_tool": "godot_scripts_read"})

    def settings_get(self, args: SettingsGetArgs) -> ToolResult:
        gate = self._preflight("settings_get")
        if gate is not None:
            return gate
        section = (args.section or "project").strip().lower()
        if section == "project":
            if "project" not in self._enabled_toolsets:
                return self._missing_toolset("settings_get", "project")
            tool = "godot_project_get_setting"
            payload: dict[str, Any] = {"name": args.key}
        elif section == "input_map":
            if "input_map" not in self._enabled_toolsets:
                return self._missing_toolset("settings_get", "input_map")
            tool = "godot_input_map_get_action_events"
            payload = {"action": args.key}
        else:
            return self._error(
                f"unknown settings section: {args.section!r}",
                code="PARAM_ERROR",
            )
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(self._as_mapping(raw), evidence={"mcp_tool": tool})

    def settings_set(self, args: SettingsSetArgs) -> ToolResult:
        gate = self._preflight("settings_set")
        if gate is not None:
            return gate
        section = (args.section or "project").strip().lower()
        if section == "project":
            if "project" not in self._enabled_toolsets:
                return self._missing_toolset("settings_set", "project")
            tool = "godot_project_set_setting"
            payload: dict[str, Any] = {"name": args.key, "value": args.value}
        elif section == "input_map":
            if "input_map" not in self._enabled_toolsets:
                return self._missing_toolset("settings_set", "input_map")
            value = args.value
            if value is None or value == "remove":
                tool = "godot_input_map_remove_action"
                payload = {"name": args.key, "confirm": True}
            elif isinstance(value, Mapping) and "event_type" in value:
                tool = "godot_input_map_add_event"
                payload = {"action": args.key, **dict(value)}
            else:
                tool = "godot_input_map_add_action"
                payload = {"name": args.key}
                if isinstance(value, Mapping) and "deadzone" in value:
                    payload["deadzone"] = value["deadzone"]
                elif isinstance(value, (int, float)):
                    payload["deadzone"] = float(value)
        else:
            return self._error(
                f"unknown settings section: {args.section!r}",
                code="PARAM_ERROR",
            )
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool},
            change={"section": section, "key": args.key},
        )

    def animation_inspect(self, args: AnimationInspectArgs) -> ToolResult:
        gate = self._preflight("animation_inspect")
        if gate is not None:
            return gate
        if args.animation_name:
            tool = "godot_animation_get"
            payload: dict[str, Any] = {
                "node_path": args.node_path,
                "animation_name": args.animation_name,
            }
        else:
            tool = "godot_animation_list_animations"
            payload = {"node_path": args.node_path}
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(self._as_mapping(raw), evidence={"mcp_tool": tool})

    def animation_edit(self, args: AnimationEditArgs) -> ToolResult:
        gate = self._preflight("animation_edit")
        if gate is not None:
            return gate
        op = (args.operation or "").strip().lower()
        params = dict(args.params)
        if op == "create":
            name = params.get("name") or params.get("animation_name")
            if not name:
                return self._error(
                    "animation_edit create requires params.name",
                    code="PARAM_ERROR",
                )
            tool = "godot_animation_create"
            payload: dict[str, Any] = {
                "node_path": args.node_path,
                "name": name,
                "length": params.get("length", 1.0),
            }
        elif op in {"add_track", "set_track"}:
            tool = "godot_animation_add_track"
            payload = {
                "node_path": args.node_path,
                "animation": params.get("animation") or params.get("animation_name"),
                "track_path": params.get("track_path"),
                "track_type": params.get("track_type", "value"),
            }
        elif op in {"set_key", "insert_key", "insert_keyframe"}:
            tool = "godot_animation_insert_keyframe"
            payload = {
                "node_path": args.node_path,
                "animation": params.get("animation") or params.get("animation_name"),
                "track": params.get("track"),
                "time": params.get("time"),
                "value": params.get("value"),
                "easing": params.get("easing", 1.0),
            }
        else:
            return self._error(
                f"unsupported animation_edit operation: {args.operation!r}",
                code="PARAM_ERROR",
            )
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool, "operation": op},
            change={"operation": op, **payload},
        )

    def animation_tree_inspect(self, args: AnimationTreeInspectArgs) -> ToolResult:
        gate = self._preflight("animation_tree_inspect")
        if gate is not None:
            return gate
        # No dedicated tree-dump MCP tool; node properties are the inspect surface.
        raw = self._call(
            "godot_inspection_get_node_properties",
            {"node_path": args.node_path},
        )
        err = self._mcp_error_result(raw, "godot_inspection_get_node_properties")
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={
                "mcp_tool": "godot_inspection_get_node_properties",
                "note": "AnimationTree authoring uses animation toolset create_tree / state / blend ops",
            },
        )

    def animation_tree_edit(self, args: AnimationTreeEditArgs) -> ToolResult:
        gate = self._preflight("animation_tree_edit")
        if gate is not None:
            return gate
        op = (args.operation or "").strip().lower()
        params = dict(args.params)
        if op in {"create", "create_tree"}:
            tool = "godot_animation_create_tree"
            payload: dict[str, Any] = {
                "parent_path": params.get("parent_path", args.node_path),
                "name": params.get("name", "AnimationTree"),
                "root_type": params.get("root_type", "AnimationNodeStateMachine"),
            }
            if "anim_player" in params:
                payload["anim_player"] = params["anim_player"]
        elif op in {"add_state", "add_state_machine_state"}:
            tool = "godot_animation_add_state_machine_state"
            payload = {
                "tree_path": args.node_path,
                "state_name": params.get("state_name") or params.get("name"),
            }
            if "animation" in params:
                payload["animation"] = params["animation"]
        elif op in {"set_blend", "set_blend_tree_node", "add_blend_node"}:
            tool = "godot_animation_set_blend_tree_node"
            payload = {
                "tree_path": args.node_path,
                "node_name": params.get("node_name") or params.get("name"),
                "node_type": params.get("node_type"),
            }
        else:
            return self._error(
                f"unsupported animation_tree_edit operation: {args.operation!r}",
                code="PARAM_ERROR",
            )
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool, "operation": op},
            change={"operation": op, **payload},
        )

    def run_game(self, args: RunGameArgs) -> ToolResult:
        gate = self._preflight("run_game")
        if gate is not None:
            return gate
        payload: dict[str, Any] = {}
        if args.scene_path:
            payload["scene_path"] = args.scene_path
        raw = self._call("godot_runtime_play_scene", payload)
        err = self._mcp_error_result(raw, "godot_runtime_play_scene")
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": "godot_runtime_play_scene", "debug": args.debug},
        )

    def stop_game(self, args: StopGameArgs) -> ToolResult:
        gate = self._preflight("stop_game")
        if gate is not None:
            return gate
        raw = self._call("godot_runtime_stop_scene", {})
        err = self._mcp_error_result(raw, "godot_runtime_stop_scene")
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": "godot_runtime_stop_scene", "force": args.force},
        )

    def playtest_input(self, args: PlaytestInputArgs) -> ToolResult:
        gate = self._preflight("playtest_input")
        if gate is not None:
            return gate
        kind = (args.kind or "").strip().lower()
        extras = dict(args.extras)
        if kind == "action":
            tool = "godot_input_simulate_action"
            payload: dict[str, Any] = {
                "action": args.name,
                "pressed": args.pressed,
                "strength": args.strength,
            }
        elif kind == "key":
            tool = "godot_input_simulate_key"
            payload = {
                "key": args.name,
                "pressed": args.pressed,
                "shift": bool(extras.get("shift", False)),
                "ctrl": bool(extras.get("ctrl", False)),
                "alt": bool(extras.get("alt", False)),
                "meta": bool(extras.get("meta", False)),
            }
        elif kind in {"mouse_button", "mouse_motion", "mouse"}:
            tool = "godot_input_simulate_mouse"
            payload = {
                "x": extras.get("x", 0),
                "y": extras.get("y", 0),
                "button": extras.get("button", args.name if kind == "mouse_button" else ""),
                "pressed": args.pressed,
                "relative_x": extras.get("relative_x", 0),
                "relative_y": extras.get("relative_y", 0),
            }
        else:
            return self._error(
                f"unsupported playtest_input kind: {args.kind!r}",
                code="PARAM_ERROR",
            )
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool, "kind": kind},
        )

    def playtest_wait(self, args: PlaytestWaitArgs) -> ToolResult:
        gate = self._preflight("playtest_wait", skip_probe=True)
        if gate is not None:
            return gate
        # No MCP wait tool — local sleep; optional poll of is_playing.
        seconds = max(float(args.seconds), 0.0)
        until = (args.until or "").strip().lower() if args.until else ""
        deadline = time.monotonic() + seconds
        playing_snapshots: list[Any] = []
        if until in {"playing", "stopped", "not_playing"} and "runtime" in self._enabled_toolsets:
            while True:
                raw = self._call("godot_runtime_is_playing", {})
                data = self._as_mapping(raw)
                playing_snapshots.append(data)
                playing = bool(data.get("playing"))
                if until == "playing" and playing:
                    break
                if until in {"stopped", "not_playing"} and not playing:
                    break
                if time.monotonic() >= deadline:
                    break
                time.sleep(self._poll_interval_s)
        else:
            time.sleep(seconds)
        return self._ok(
            {
                "waited_seconds": seconds,
                "until": args.until,
                "snapshots": playing_snapshots,
            },
            evidence={"mcp_tool": None, "local_wait": True},
        )

    def observe_runtime(self, args: ObserveRuntimeArgs) -> ToolResult:
        """Structured playtest observe: errors → properties/tree (screenshot is separate)."""
        gate = self._preflight("observe_runtime")
        if gate is not None:
            return gate
        combined: dict[str, Any] = {
            "observe_order": ["errors", "properties_or_tree", "screenshot_last"],
            "note": (
                "Never declare gameplay success from a screenshot alone. "
                "Call capture_viewport only after reviewing errors + properties."
            ),
        }
        tools_used: list[str] = []
        # Always fetch errors first when requested (canonical playtest lifecycle).
        if args.include_errors:
            raw = self._call("godot_runtime_get_game_output", {"since_seq": 0})
            err = self._mcp_error_result(raw, "godot_runtime_get_game_output")
            if err is not None:
                return err
            out = self._as_mapping(raw)
            combined["output"] = out
            if out.get("ready") is False:
                return self._error(
                    "runtime output not ready (output_pending) — poll observe_runtime again",
                    code="OUTPUT_PENDING",
                )
            tools_used.append("godot_runtime_get_game_output")
        if args.node_path and args.properties:
            props: dict[str, Any] = {}
            for prop in args.properties:
                raw = self._call(
                    "godot_runtime_read_property",
                    {"node_path": args.node_path, "property": prop},
                )
                err = self._mcp_error_result(raw, "godot_runtime_read_property")
                if err is not None:
                    return err
                props[prop] = self._as_mapping(raw)
            combined["properties"] = props
            tools_used.append("godot_runtime_read_property")
        elif args.node_path:
            raw = self._call("godot_runtime_get_game_scene_tree", {})
            err = self._mcp_error_result(raw, "godot_runtime_get_game_scene_tree")
            if err is not None:
                return err
            combined["scene_tree"] = self._as_mapping(raw)
            tools_used.append("godot_runtime_get_game_scene_tree")
        if "output" not in combined and "properties" not in combined and "scene_tree" not in combined:
            raw = self._call("godot_runtime_get_game_scene_tree", {})
            err = self._mcp_error_result(raw, "godot_runtime_get_game_scene_tree")
            if err is not None:
                return err
            combined["scene_tree"] = self._as_mapping(raw)
            tools_used.append("godot_runtime_get_game_scene_tree")
        return self._ok(combined, evidence={"mcp_tools": tools_used})

    def capture_viewport(self, args: CaptureViewportArgs) -> ToolResult:
        gate = self._preflight("capture_viewport")
        if gate is not None:
            return gate
        # V1 acceptance wants game viewport, not editor UI.
        payload: dict[str, Any] = {}
        raw = self._call("godot_runtime_capture_game_screenshot", payload)
        err = self._mcp_error_result(raw, "godot_runtime_capture_game_screenshot")
        if err is not None:
            return err
        data = self._as_mapping(raw) if isinstance(raw, Mapping) else {"image": raw}
        if args.destination:
            data = dict(data)
            data["destination"] = args.destination
        return self._ok(
            data,
            evidence={
                "mcp_tool": "godot_runtime_capture_game_screenshot",
                "include_ui": args.include_ui,
            },
        )

    def get_diagnostics(self, args: GetDiagnosticsArgs) -> ToolResult:
        gate = self._preflight("get_diagnostics", skip_probe=True)
        if gate is not None:
            return gate
        scope = (args.scope or "all").strip().lower()
        if scope == "script":
            if "scripts" not in self._enabled_toolsets:
                return self._missing_toolset("get_diagnostics", "scripts")
            if not args.path_filter:
                return self._error(
                    "get_diagnostics scope=script requires path_filter",
                    code="PARAM_ERROR",
                )
            tool = "godot_scripts_get_parse_errors"
            payload: dict[str, Any] = {"script_path": args.path_filter}
        elif scope == "runtime":
            probe = self._require_probe("get_diagnostics")
            if probe is not None:
                return probe
            if "runtime" not in self._enabled_toolsets:
                return self._missing_toolset("get_diagnostics", "runtime")
            tool = "godot_runtime_get_game_output"
            payload = {"since_seq": 0}
        elif scope == "editor":
            tool = "godot_health_check"
            payload = {}
        else:
            tool = "godot_debug_workflow"
            payload = {}
            if args.path_filter:
                payload["scene"] = args.path_filter
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(self._as_mapping(raw), evidence={"mcp_tool": tool, "scope": scope})

    def undo(self, args: UndoArgs) -> ToolResult:
        gate = self._preflight("undo")
        if gate is not None:
            return gate
        count = max(int(args.steps), 1)
        raw = self._call("godot_undo", {"count": count})
        err = self._mcp_error_result(raw, "godot_undo")
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": "godot_undo", "steps": count},
            change={"undone_requested": count},
        )

    # --- TileSet / TileMap -------------------------------------------------

    def tileset_create(self, args: TilesetCreateArgs) -> ToolResult:
        gate = self._preflight("tileset_create")
        if gate is not None:
            return gate
        if not args.node_path and not args.save_path:
            return self._error(
                "tileset_create requires node_path and/or save_path",
                code="PARAM_ERROR",
            )
        tile_size = list(args.tile_size) if args.tile_size else [16, 16]
        if len(tile_size) != 2:
            return self._error("tile_size must be [w, h]", code="PARAM_ERROR")
        payload: dict[str, Any] = {"tile_size": [int(tile_size[0]), int(tile_size[1])]}
        if args.node_path:
            payload["node_path"] = args.node_path
        if args.save_path:
            payload["save_path"] = args.save_path
        tool = "godot_tilemap_create_tileset"
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool},
            change={"type": "tileset", "operation": "create", **payload},
        )

    def tileset_add_atlas(self, args: TilesetAddAtlasArgs) -> ToolResult:
        gate = self._preflight("tileset_add_atlas")
        if gate is not None:
            return gate
        if bool(args.node_path) == bool(args.tileset_path):
            return self._error(
                "tileset_add_atlas requires exactly one of node_path or tileset_path",
                code="PARAM_ERROR",
            )
        if not args.texture_path:
            return self._error("tileset_add_atlas requires texture_path", code="PARAM_ERROR")
        payload: dict[str, Any] = {"texture_path": args.texture_path}
        if args.node_path:
            payload["node_path"] = args.node_path
        if args.tileset_path:
            payload["tileset_path"] = args.tileset_path
        # Bridge param is region_size (TileSetAtlasSource.texture_region_size).
        if args.texture_region_size is not None:
            trs = list(args.texture_region_size)
            if len(trs) != 2:
                return self._error("texture_region_size must be [w, h]", code="PARAM_ERROR")
            payload["region_size"] = [int(trs[0]), int(trs[1])]
        else:
            payload["region_size"] = [16, 16]
        if args.source_id is not None:
            payload["source_id"] = int(args.source_id)
        tool = "godot_tilemap_add_tileset_atlas_source"
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool},
            change={"type": "tileset", "operation": "add_atlas", **payload},
        )

    def tileset_create_tile(self, args: TilesetCreateTileArgs) -> ToolResult:
        gate = self._preflight("tileset_create_tile")
        if gate is not None:
            return gate
        if bool(args.node_path) == bool(args.tileset_path):
            return self._error(
                "tileset_create_tile requires exactly one of node_path or tileset_path",
                code="PARAM_ERROR",
            )
        coords = list(args.atlas_coords)
        if len(coords) != 2:
            return self._error("atlas_coords must be [x, y]", code="PARAM_ERROR")
        payload: dict[str, Any] = {
            "atlas_coords": [int(coords[0]), int(coords[1])],
            "source_id": int(args.source_id),
        }
        if args.node_path:
            payload["node_path"] = args.node_path
        if args.tileset_path:
            payload["tileset_path"] = args.tileset_path
        # Bridge param is size (atlas cells), default [1,1].
        if args.size_in_atlas is not None:
            size = list(args.size_in_atlas)
            if len(size) != 2:
                return self._error("size_in_atlas must be [w, h]", code="PARAM_ERROR")
            payload["size"] = [int(size[0]), int(size[1])]
        else:
            payload["size"] = [1, 1]
        tool = "godot_tilemap_create_tile"
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool},
            change={"type": "tileset", "operation": "create_tile", **payload},
        )

    def tileset_inspect(self, args: TilesetInspectArgs) -> ToolResult:
        gate = self._preflight(
            "tileset_inspect",
            required_toolsets=["inspection"],
        )
        if gate is not None:
            return gate
        if not args.node_path:
            return self._error(
                "tileset_inspect V1 requires node_path (TileMapLayer/TileMap); "
                "no dedicated tileset dump MCP tool",
                code="PARAM_ERROR",
            )
        tool = "godot_inspection_get_node_properties"
        raw = self._call(tool, {"node_path": args.node_path})
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool, "node_path": args.node_path},
        )

    def tilemap_inspect(self, args: TilemapInspectArgs) -> ToolResult:
        gate = self._preflight("tilemap_inspect")
        if gate is not None:
            return gate
        layers_raw = self._call("godot_tilemap_layers", {"node_path": args.node_path})
        err = self._mcp_error_result(layers_raw, "godot_tilemap_layers")
        if err is not None:
            return err
        data: dict[str, Any] = {"layers": self._as_mapping(layers_raw)}
        evidence: dict[str, Any] = {"mcp_tool": "godot_tilemap_layers"}
        if args.include_used_cells:
            used_raw = self._call(
                "godot_tilemap_get_used_cells",
                {"node_path": args.node_path, "layer": int(args.layer)},
            )
            err2 = self._mcp_error_result(used_raw, "godot_tilemap_get_used_cells")
            if err2 is not None:
                return err2
            used = self._as_mapping(used_raw)
            data["used_cells"] = used
            data["used_count"] = used.get("count", len(used.get("cells", []) or []))
            evidence["mcp_tool"] = "godot_tilemap_get_used_cells"
        else:
            # Lightweight count via used_cells without dumping into evidence-heavy paths
            # when callers only need layer metadata — skip second call.
            data["used_cells_included"] = False
        return self._ok(data, evidence=evidence)

    def tilemap_get_cell(self, args: TilemapGetCellArgs) -> ToolResult:
        gate = self._preflight("tilemap_get_cell")
        if gate is not None:
            return gate
        coords = list(args.coords)
        if len(coords) != 2:
            return self._error("coords must be [x, y]", code="PARAM_ERROR")
        tool = "godot_tilemap_get_cell"
        payload = {
            "node_path": args.node_path,
            "coords": [int(coords[0]), int(coords[1])],
            "layer": int(args.layer),
        }
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(self._as_mapping(raw), evidence={"mcp_tool": tool})

    def tilemap_set_cell(self, args: TilemapSetCellArgs) -> ToolResult:
        gate = self._preflight("tilemap_set_cell")
        if gate is not None:
            return gate
        coords = list(args.coords)
        atlas = list(args.atlas_coords) if args.atlas_coords else [0, 0]
        if len(coords) != 2 or len(atlas) != 2:
            return self._error("coords and atlas_coords must be [x, y]", code="PARAM_ERROR")
        tool = "godot_tilemap_set_cell"
        payload = {
            "node_path": args.node_path,
            "coords": [int(coords[0]), int(coords[1])],
            "source_id": int(args.source_id),
            "atlas_coords": [int(atlas[0]), int(atlas[1])],
            "alternative_tile": int(args.alternative_tile),
            "layer": int(args.layer),
        }
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool},
            change={"type": "tilemap", "operation": "set_cell", **payload},
        )

    def tilemap_fill_rect(self, args: TilemapFillRectArgs) -> ToolResult:
        gate = self._preflight("tilemap_fill_rect")
        if gate is not None:
            return gate
        rect = list(args.rect)
        atlas = list(args.atlas_coords) if args.atlas_coords else [0, 0]
        if len(rect) != 4:
            return self._error("rect must be [x, y, w, h]", code="PARAM_ERROR")
        if len(atlas) != 2:
            return self._error("atlas_coords must be [x, y]", code="PARAM_ERROR")
        tool = "godot_tilemap_fill_rect"
        payload = {
            "node_path": args.node_path,
            "rect": [int(rect[0]), int(rect[1]), int(rect[2]), int(rect[3])],
            "source_id": int(args.source_id),
            "atlas_coords": [int(atlas[0]), int(atlas[1])],
            "alternative_tile": int(args.alternative_tile),
            "layer": int(args.layer),
        }
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool},
            change={"type": "tilemap", "operation": "fill_rect", **payload},
        )

    def tilemap_clear(self, args: TilemapClearArgs) -> ToolResult:
        gate = self._preflight("tilemap_clear")
        if gate is not None:
            return gate
        tool = "godot_tilemap_clear"
        payload = {"node_path": args.node_path, "layer": int(args.layer)}
        raw = self._call(tool, payload)
        err = self._mcp_error_result(raw, tool)
        if err is not None:
            return err
        return self._ok(
            self._as_mapping(raw),
            evidence={"mcp_tool": tool},
            change={"type": "tilemap", "operation": "clear", **payload},
        )

    # --- internals ---------------------------------------------------------

    def _call(self, name: str, arguments: Mapping[str, Any]) -> Any:
        return self._transport.call_tool(name, dict(arguments))

    def _preflight(
        self,
        abstract_method: str,
        *,
        skip_probe: bool = False,
        required_toolsets: Optional[Iterable[str]] = None,
    ) -> Optional[ToolResult]:
        if not self._connected:
            return ToolResult(
                status=ToolStatus.ERROR,
                error="BRIDGE_DISCONNECTED: HybridindieBridgeAdapter is not connected",
                data={"code": "BRIDGE_DISCONNECTED"},
            )
        row = mcp_map.mapping_for(abstract_method)
        if row is None:
            return ToolResult(
                status=ToolStatus.UNSUPPORTED,
                error=f"no hybridindie mapping for {abstract_method}",
                data={"code": "UNMAPPED"},
            )

        # Methods that branch on section/scope check toolsets inside the method.
        defer_toolset_check = abstract_method in {
            "settings_get",
            "settings_set",
            "get_diagnostics",
            "playtest_wait",
            "inspect_scene",
            "animation_tree_inspect",
        }
        if required_toolsets is not None:
            check = [
                t
                for t in required_toolsets
                if t not in mcp_map.ALWAYS_ON_TOOLSETS
            ]
        elif defer_toolset_check:
            check = []
        else:
            check = list(mcp_map.required_toolsets(abstract_method))

        for toolset in check:
            if toolset not in self._enabled_toolsets:
                return self._missing_toolset(abstract_method, toolset)

        if row.requires_runtime_probe and not skip_probe:
            probe_err = self._require_probe(abstract_method)
            if probe_err is not None:
                return probe_err
        return None

    def _require_probe(self, abstract_method: str) -> Optional[ToolResult]:
        if self._runtime_probe_present:
            return None
        return ToolResult(
            status=ToolStatus.ERROR,
            error=(
                "PRECONDITION_FAILED: required=runtime_probe "
                f"(autoload {mcp_map.RUNTIME_PROBE_AUTOLOAD} → {mcp_map.RUNTIME_PROBE_SCRIPT}). "
                f"Cannot run {abstract_method} without the runtime probe and a play session."
            ),
            data={
                "code": "PRECONDITION_FAILED",
                "required": "runtime_probe",
                "autoload": mcp_map.RUNTIME_PROBE_AUTOLOAD,
                "script": mcp_map.RUNTIME_PROBE_SCRIPT,
                "abstract_method": abstract_method,
            },
        )

    def _missing_toolset(self, abstract_method: str, toolset: str) -> ToolResult:
        return ToolResult(
            status=ToolStatus.ERROR,
            error=(
                f"PRECONDITION_FAILED: required=toolset:{toolset} for {abstract_method}. "
                f"Seed GODOT_MCP_DEFAULT_TOOLSETS={mcp_map.GODOT_MCP_DEFAULT_TOOLSETS_SEED!r} "
                "or call godot_enable_toolset (clients may ignore tools/list_changed)."
            ),
            data={
                "code": "PRECONDITION_FAILED",
                "required": f"toolset:{toolset}",
                "abstract_method": abstract_method,
                "enabled_toolsets": sorted(self._enabled_toolsets),
            },
        )

    def _mcp_error_result(self, raw: Any, tool_name: str) -> Optional[ToolResult]:
        if isinstance(raw, Mapping):
            if raw.get("isError") or raw.get("is_error"):
                return ToolResult(
                    status=ToolStatus.ERROR,
                    error=str(raw.get("error") or raw.get("message") or raw),
                    data={"mcp_tool": tool_name, "raw": dict(raw)},
                )
            err = raw.get("error")
            if isinstance(err, str) and err:
                # Structured MCP/addon errors often look like "PRECONDITION_FAILED: …"
                code = err.split(":", 1)[0].strip() if ":" in err else "MCP_ERROR"
                return ToolResult(
                    status=ToolStatus.ERROR,
                    error=err,
                    data={"code": code, "mcp_tool": tool_name, "raw": dict(raw)},
                )
        return None

    @staticmethod
    def _as_mapping(raw: Any) -> dict[str, Any]:
        if isinstance(raw, Mapping):
            return dict(raw)
        return {"value": raw}

    @staticmethod
    def _ok(
        data: Mapping[str, Any],
        *,
        evidence: Optional[Mapping[str, Any]] = None,
        change: Optional[Mapping[str, Any]] = None,
    ) -> ToolResult:
        return ToolResult(
            status=ToolStatus.OK,
            data=dict(data),
            evidence=dict(evidence or {}),
            change=dict(change) if change is not None else None,
        )

    @staticmethod
    def _error(message: str, *, code: str) -> ToolResult:
        return ToolResult(
            status=ToolStatus.ERROR,
            error=message,
            data={"code": code},
        )
