"""Fake-transport smoke tests for HybridindieBridgeAdapter mappings.

Run from repo root (stdlib only)::

    python -m unittest tests.test_hybridindie_adapter -v
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path
from typing import Any, Mapping, Optional

# Allow `python -m unittest` without installing a package.
_ROOT = Path(__file__).resolve().parents[1]
if str(_ROOT) not in sys.path:
    sys.path.insert(0, str(_ROOT))

from bridges.hybridindie.adapter import HybridindieBridgeAdapter
from bridges.hybridindie.mapping import ABSTRACT_TO_MCP, GODOT_MCP_DEFAULT_TOOLSETS_SEED
from tools.registry import CapabilityRegistry
from tools.schemas import (
    AnimationTreeInspectArgs,
    AttachScriptArgs,
    CreateSceneArgs,
    InspectSceneArgs,
    ObserveRuntimeArgs,
    PatchScriptArgs,
    PlaytestInputArgs,
    SaveSceneArgs,
    TilemapFillRectArgs,
    TilemapSetCellArgs,
    TilesetAddAtlasArgs,
    TilesetCreateArgs,
    ToolStatus,
    UndoArgs,
)


class FakeTransport:
    """Records MCP tool calls; returns a minimal success payload."""

    def __init__(self) -> None:
        self.calls: list[tuple[str, dict[str, Any]]] = []

    def call_tool(
        self,
        name: str,
        arguments: Optional[Mapping[str, Any]] = None,
    ) -> Any:
        args = dict(arguments or {})
        self.calls.append((name, args))
        return {"ok": True, "tool": name, "arguments": args}

    def last(self) -> tuple[str, dict[str, Any]]:
        assert self.calls, "expected at least one MCP call"
        return self.calls[-1]


class HybridindieAdapterMappingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.transport = FakeTransport()
        self.adapter = HybridindieBridgeAdapter(
            self.transport,
            runtime_probe_present=True,
            godot_version="4.7.2.stable.steam",
        )
        self.adapter.connect()

    def test_connect_applies_animation_tree_and_undo_caps(self) -> None:
        registry = CapabilityRegistry()
        self.adapter.apply_capabilities(registry)
        self.assertTrue(registry.is_capability_enabled("animation_tree"))
        self.assertTrue(registry.is_capability_enabled("agent_undo"))
        self.assertTrue(registry.is_capability_enabled("tilemap_editing"))
        self.assertTrue(registry.tool_available("animation_tree_inspect"))
        self.assertTrue(registry.tool_available("undo"))
        self.assertTrue(registry.tool_available("tilemap_set_cell"))
        self.assertIn("animation", GODOT_MCP_DEFAULT_TOOLSETS_SEED)
        self.assertIn("runtime", GODOT_MCP_DEFAULT_TOOLSETS_SEED)
        self.assertIn("tilemap", GODOT_MCP_DEFAULT_TOOLSETS_SEED)
        self.assertIn("resources_edit", GODOT_MCP_DEFAULT_TOOLSETS_SEED)
        self.assertIn("composite", GODOT_MCP_DEFAULT_TOOLSETS_SEED)
        self.assertTrue(registry.tool_available("create_scene"))
        self.assertTrue(registry.tool_available("save_scene"))
        self.assertTrue(registry.tool_available("attach_script"))

    def test_tileset_create_maps_shape(self) -> None:
        result = self.adapter.tileset_create(
            TilesetCreateArgs(
                tile_size=(16, 16),
                node_path="Ground",
                save_path="res://tilesets/ground.tres",
            )
        )
        self.assertTrue(result.ok, result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_tilemap_create_tileset")
        self.assertEqual(
            args,
            {
                "tile_size": [16, 16],
                "node_path": "Ground",
                "save_path": "res://tilesets/ground.tres",
            },
        )

    def test_tileset_add_atlas_maps_region_size(self) -> None:
        result = self.adapter.tileset_add_atlas(
            TilesetAddAtlasArgs(
                texture_path="res://assets/terrain.png",
                node_path="Ground",
                texture_region_size=(16, 16),
                source_id=0,
            )
        )
        self.assertTrue(result.ok, result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_tilemap_add_tileset_atlas_source")
        self.assertEqual(
            args,
            {
                "texture_path": "res://assets/terrain.png",
                "node_path": "Ground",
                "region_size": [16, 16],
                "source_id": 0,
            },
        )

    def test_tilemap_set_cell_maps_shape(self) -> None:
        result = self.adapter.tilemap_set_cell(
            TilemapSetCellArgs(
                node_path="Ground",
                coords=(3, 4),
                source_id=0,
                atlas_coords=(1, 2),
                layer=0,
            )
        )
        self.assertTrue(result.ok, result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_tilemap_set_cell")
        self.assertEqual(
            args,
            {
                "node_path": "Ground",
                "coords": [3, 4],
                "source_id": 0,
                "atlas_coords": [1, 2],
                "alternative_tile": 0,
                "layer": 0,
            },
        )

    def test_tilemap_fill_rect_maps_shape(self) -> None:
        result = self.adapter.tilemap_fill_rect(
            TilemapFillRectArgs(
                node_path="Ground",
                rect=(0, 10, 20, 2),
                source_id=0,
                atlas_coords=(0, 0),
            )
        )
        self.assertTrue(result.ok, result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_tilemap_fill_rect")
        self.assertEqual(
            args,
            {
                "node_path": "Ground",
                "rect": [0, 10, 20, 2],
                "source_id": 0,
                "atlas_coords": [0, 0],
                "alternative_tile": 0,
                "layer": 0,
            },
        )

    def test_inspect_scene_opens_then_gets_tree(self) -> None:
        result = self.adapter.inspect_scene(
            InspectSceneArgs(scene_path="res://scenes/main.tscn")
        )
        self.assertTrue(result.ok, result.error)
        self.assertEqual(
            [name for name, _ in self.transport.calls],
            ["godot_scene_edit_open_scene", "godot_inspection_get_scene_tree"],
        )
        open_name, open_args = self.transport.calls[0]
        self.assertEqual(open_name, "godot_scene_edit_open_scene")
        self.assertEqual(open_args, {"scene_path": "res://scenes/main.tscn"})
        tree_name, tree_args = self.transport.calls[1]
        self.assertEqual(tree_name, "godot_inspection_get_scene_tree")
        self.assertEqual(tree_args, {})
        self.assertEqual(
            result.evidence.get("mcp_tool"),
            "godot_inspection_get_scene_tree",
        )

    def test_patch_script_find_replace_shape(self) -> None:
        patch_body = {"find": "print(1)", "replace": "print(2)"}
        result = self.adapter.patch_script(
            PatchScriptArgs(
                script_path="res://scripts/player.gd",
                patch=json.dumps(patch_body),
                format="find_replace",
            )
        )
        self.assertTrue(result.ok, result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_scripts_patch")
        self.assertEqual(
            args,
            {
                "script_path": "res://scripts/player.gd",
                "find": "print(1)",
                "replace": "print(2)",
            },
        )
        self.assertEqual(ABSTRACT_TO_MCP["patch_script"].mcp_tools[0], "godot_scripts_patch")

    def test_animation_tree_inspect_uses_node_properties(self) -> None:
        result = self.adapter.animation_tree_inspect(
            AnimationTreeInspectArgs(node_path="Player/AnimTree")
        )
        self.assertTrue(result.ok, result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_inspection_get_node_properties")
        self.assertEqual(args, {"node_path": "Player/AnimTree"})

    def test_undo_maps_to_godot_undo_count(self) -> None:
        result = self.adapter.undo(UndoArgs(steps=2))
        self.assertTrue(result.ok, result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_undo")
        self.assertEqual(args, {"count": 2})

    def test_playtest_input_key_and_action_shapes(self) -> None:
        key_result = self.adapter.playtest_input(
            PlaytestInputArgs(kind="key", name="Space", pressed=True)
        )
        self.assertTrue(key_result.ok, key_result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_input_simulate_key")
        self.assertEqual(
            args,
            {
                "key": "Space",
                "pressed": True,
                "shift": False,
                "ctrl": False,
                "alt": False,
                "meta": False,
            },
        )

        action_result = self.adapter.playtest_input(
            PlaytestInputArgs(
                kind="action",
                name="ui_right",
                pressed=True,
                strength=0.5,
            )
        )
        self.assertTrue(action_result.ok, action_result.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_input_simulate_action")
        self.assertEqual(
            args,
            {"action": "ui_right", "pressed": True, "strength": 0.5},
        )

    def test_playtest_input_fails_without_probe(self) -> None:
        adapter = HybridindieBridgeAdapter(
            self.transport,
            runtime_probe_present=False,
        )
        adapter.connect()
        result = adapter.playtest_input(
            PlaytestInputArgs(kind="key", name="A", pressed=True)
        )
        self.assertEqual(result.status, ToolStatus.ERROR)
        self.assertIn("runtime_probe", result.error or "")
        self.assertEqual(result.data.get("required"), "runtime_probe")
        self.assertEqual(self.transport.calls, [])

    def test_create_save_attach_scene_shapes(self) -> None:
        created = self.adapter.create_scene(
            CreateSceneArgs(scene_path="res://scenes/player.tscn", root_type="CharacterBody2D")
        )
        self.assertTrue(created.ok, created.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_scene_edit_create_scene")
        self.assertEqual(
            args,
            {"scene_path": "res://scenes/player.tscn", "root_type": "CharacterBody2D"},
        )

        saved = self.adapter.save_scene(SaveSceneArgs())
        self.assertTrue(saved.ok, saved.error)
        self.assertEqual(self.transport.last()[0], "godot_scene_edit_save_scene")

        attached = self.adapter.attach_script(
            AttachScriptArgs(node_path=".", script_path="res://scripts/player.gd")
        )
        self.assertTrue(attached.ok, attached.error)
        name, args = self.transport.last()
        self.assertEqual(name, "godot_scene_edit_attach_script")
        self.assertEqual(
            args,
            {"node_path": ".", "script_path": "res://scripts/player.gd"},
        )

    def test_observe_runtime_errors_first_and_pending(self) -> None:
        class PendingTransport(FakeTransport):
            def call_tool(self, name, arguments=None):
                self.calls.append((name, dict(arguments or {})))
                if name == "godot_runtime_get_game_output":
                    return {"ready": False, "reason": "output_pending", "entries": []}
                return {"ok": True, "tool": name}

        transport = PendingTransport()
        adapter = HybridindieBridgeAdapter(
            transport, runtime_probe_present=True, godot_version="4.7.2.stable.steam"
        )
        adapter.connect()
        result = adapter.observe_runtime(ObserveRuntimeArgs(include_errors=True))
        self.assertEqual(result.status, ToolStatus.ERROR)
        self.assertEqual(result.data.get("code"), "OUTPUT_PENDING")

        class ReadyTransport(FakeTransport):
            def call_tool(self, name, arguments=None):
                self.calls.append((name, dict(arguments or {})))
                if name == "godot_runtime_get_game_output":
                    return {"ready": True, "entries": [], "connected": True, "playing": True}
                if name == "godot_runtime_read_property":
                    return {"value": 1, "property": arguments.get("property")}
                return {"ok": True}

        transport2 = ReadyTransport()
        adapter2 = HybridindieBridgeAdapter(
            transport2, runtime_probe_present=True, godot_version="4.7.2.stable.steam"
        )
        adapter2.connect()
        ok = adapter2.observe_runtime(
            ObserveRuntimeArgs(
                include_errors=True,
                node_path="Player",
                properties=("velocity", "is_on_floor"),
            )
        )
        self.assertTrue(ok.ok, ok.error)
        self.assertEqual(transport2.calls[0][0], "godot_runtime_get_game_output")
        self.assertIn("observe_order", ok.data)

    def test_missing_toolset_returns_structured_error(self) -> None:
        adapter = HybridindieBridgeAdapter(
            self.transport,
            enabled_toolsets=[],  # core+inspection only after ALWAYS_ON merge
            runtime_probe_present=True,
        )
        adapter.connect()
        result = adapter.patch_script(
            PatchScriptArgs(
                script_path="res://a.gd",
                patch=json.dumps({"find": "a", "replace": "b"}),
                format="find_replace",
            )
        )
        self.assertEqual(result.status, ToolStatus.ERROR)
        self.assertIn("toolset:scripts", result.error or "")
        self.assertEqual(self.transport.calls, [])


if __name__ == "__main__":
    unittest.main()
