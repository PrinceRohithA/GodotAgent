"""Unit tests for Runtime Action auto-resolution and Automatic Atlas Tile Generation."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"
MCP_ADDON = ROOT / "project" / "addons" / "godot_mcp"


class RuntimeActionAndAtlasAutogenTests(unittest.TestCase):
    def setUp(self):
        self.local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8") + "\n" + (AGENT_ADDON / "tools" / "agent_tilemap_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (AGENT_ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.bridge_src = (AGENT_ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.mapping_src = (AGENT_ADDON / "mcp_mapping.gd").read_text(encoding="utf-8")
        self.mcp_probe_src = (MCP_ADDON / "mcp_runtime_probe.gd").read_text(encoding="utf-8")
        self.mcp_tileset_src = (MCP_ADDON / "handlers" / "tileset.gd").read_text(encoding="utf-8")

    def test_runtime_action_auto_resolution_in_local_tools(self):
        # Verifies helper _ensure_input_action_registered exists and handles ProjectSettings / InputMap
        self.assertIn("func _ensure_input_action_registered", self.local_tools_src)
        self.assertIn("InputMap.load_from_project_settings()", self.local_tools_src)
        self.assertIn('setting_key := "input/" + action', self.local_tools_src)
        self.assertIn("ProjectSettings.has_setting(setting_key)", self.local_tools_src)
        self.assertIn('cf.load("res://project.godot")', self.local_tools_src)
        self.assertIn("func _get_action_binding_strings", self.local_tools_src)
        self.assertIn("KEY_D", self.local_tools_src)
        self.assertIn("KEY_SPACE", self.local_tools_src)

    def test_test_runtime_action_invokes_registration(self):
        # Verifies _test_runtime_action uses _ensure_input_action_registered and returns bindings
        self.assertIn("var reg := _ensure_input_action_registered(action, auto_create)", self.local_tools_src)
        self.assertIn('"action_source": reg.get("source"', self.local_tools_src)
        self.assertIn('"action_bindings": reg.get("bindings"', self.local_tools_src)

    def test_mcp_runtime_probe_action_injection(self):
        # Verifies runtime probe auto-loads from ProjectSettings instead of dropping unknown action
        self.assertIn('if ProjectSettings.has_setting("input/" + str(action)):', self.mcp_probe_src)
        self.assertIn("InputMap.load_from_project_settings()", self.mcp_probe_src)
        self.assertIn("InputMap.add_action(action)", self.mcp_probe_src)

    def test_auto_generate_atlas_tiles_in_local_tools(self):
        # Verifies tool registered in LOCAL_NAMES, has_tool, invoke
        self.assertIn('"auto_generate_atlas_tiles"', self.local_tools_src)
        self.assertIn('"setup_tilemap_atlas", "tileset_auto_create_tiles", "create_atlas_tiles"', self.local_tools_src)
        self.assertIn("func _auto_generate_atlas_tiles", self.local_tools_src)

    def test_auto_generate_atlas_tiles_functionality(self):
        # Verifies full automated pipeline: grid slicing, empty filtering, collision application
        self.assertIn("var auto_col := bool(args.get(\"auto_collision\"", self.local_tools_src)
        self.assertIn("var filter_empty := bool(args.get(\"filter_empty\"", self.local_tools_src)
        self.assertIn("source.create_tile(coords, Vector2i.ONE)", self.local_tools_src)
        self.assertIn("td.set_collision_polygon_points(phys_layer, 0, poly)", self.local_tools_src)
        self.assertIn('"tiles_created": created_coords.size()', self.local_tools_src)

    def test_mcp_tileset_atlas_source_auto_generation(self):
        # Verifies godot_mcp tileset handler auto-generates tiles by default
        self.assertIn("func _auto_generate_tiles_for_source", self.mcp_tileset_src)
        self.assertIn("func _is_region_transparent", self.mcp_tileset_src)
        self.assertIn('var auto_create := bool(params.get("auto_create_tiles", true))', self.mcp_tileset_src)
        self.assertIn("handlers[\"cmd_auto_generate_tiles\"] = _cmd_auto_generate_tiles", self.mcp_tileset_src)

    def test_mcp_create_tile_supports_auto_generation(self):
        # Verifies _cmd_create_tile supports auto_generate flag and omitted coords
        self.assertIn('bool(params.get("auto_generate", false)) or not params.has("atlas_coords")', self.mcp_tileset_src)
        self.assertIn('var gen_res := _auto_generate_tiles_for_source', self.mcp_tileset_src)

    def test_catalog_and_bridge_schemas(self):
        # Tool catalog schemas
        self.assertIn('"auto_generate_atlas_tiles":', self.catalog_src)
        self.assertIn('"auto_create": {"type": "boolean"', self.catalog_src)
        self.assertIn('"auto_collision": {"type": "boolean"', self.catalog_src)

        # Bridge tool names and keywords
        self.assertIn('"auto_generate_atlas_tiles"', self.bridge_src)
        self.assertIn('"auto_generate_atlas_tiles"', self.bridge_src)
        self.assertIn('"auto_generate_atlas_tiles": {"mcp_tools":', self.mapping_src)

    def test_server_prompt_mandates_automatic_atlas_generation(self):
        # System prompt instructs auto_generate_atlas_tiles and prohibits creating tiles one by one
        self.assertIn("NEVER create atlas tiles one by one with `create_tile`", self.server_src)
        self.assertIn("auto_generate_atlas_tiles(node_path=\"TileMapLayer\"", self.server_src)
        self.assertIn("auto_generate_atlas_tiles(texture_path, tile_size, auto_collision=true)", self.server_src)


if __name__ == "__main__":
    unittest.main()
