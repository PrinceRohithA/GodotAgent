"""Tests for GodotAgent TileMap Development Toolkit & Specialist Workflow Protocol."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class TileMapToolkitTests(unittest.TestCase):
    def setUp(self):
        self.local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.mapping_src = (ADDON / "mcp_mapping.gd").read_text(encoding="utf-8")
        self.server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")

    def test_atlas_intelligence_tools_in_local_tools(self):
        # Verify tool registration in LOCAL_NAMES
        self.assertIn('"analyze_atlas_geometry"', self.local_src)
        self.assertIn('"preview_labelled_atlas"', self.local_src)
        self.assertIn('"inspect_tile_crop"', self.local_src)
        self.assertIn('"catalog_atlas_tiles"', self.local_src)
        self.assertIn('"validate_atlas_coords"', self.local_src)

        # Verify implementation methods
        self.assertIn("func _analyze_atlas_geometry", self.local_src)
        self.assertIn("func _preview_labelled_atlas", self.local_src)
        self.assertIn("func _inspect_tile_crop", self.local_src)
        self.assertIn("func _catalog_atlas_tiles", self.local_src)
        self.assertIn("func _validate_atlas_coords", self.local_src)

        # Verify in-memory glyph renderer and alpha analyzer
        self.assertIn("GLYPH_3X5", self.local_src)
        self.assertIn("func _draw_text_3x5", self.local_src)
        self.assertIn("func _analyze_tile_region", self.local_src)
        self.assertIn('"ground_top"', self.local_src)
        self.assertIn('"interior_fill"', self.local_src)
        self.assertIn('"left_edge"', self.local_src)
        self.assertIn('"right_edge"', self.local_src)
        self.assertIn('"corner_top_left"', self.local_src)
        self.assertIn('"corner_top_right"', self.local_src)

    def test_level_and_player_metric_tools_in_local_tools(self):
        # Verify tool registration in LOCAL_NAMES
        self.assertIn('"inspect_player_metrics"', self.local_src)
        self.assertIn('"inspect_tilemap_layer"', self.local_src)
        self.assertIn('"paint_tilemap_cells"', self.local_src)
        self.assertIn('"paint_tilemap_rect"', self.local_src)

        # Verify implementation methods
        self.assertIn("func _inspect_player_metrics", self.local_src)
        self.assertIn("func _inspect_tilemap_layer", self.local_src)
        self.assertIn("func _paint_tilemap_cells", self.local_src)
        self.assertIn("func _paint_tilemap_rect", self.local_src)
        self.assertIn("func _find_first_child_of_type", self.local_src)

        # Verify jump and gap calculation logic
        self.assertIn("max_jump_height", self.local_src)
        self.assertIn("air_time", self.local_src)
        self.assertIn("max_horizontal_jump", self.local_src)
        self.assertIn("safe_platform_elevation", self.local_src)
        self.assertIn("safe_horizontal_gap", self.local_src)
        self.assertIn("invalid_cells", self.local_src)

    def test_catalog_declarations_and_schemas(self):
        # Verify catalog declarations for all 9 new tools
        self.assertIn('"analyze_atlas_geometry":', self.catalog_src)
        self.assertIn('"preview_labelled_atlas":', self.catalog_src)
        self.assertIn('"inspect_tile_crop":', self.catalog_src)
        self.assertIn('"catalog_atlas_tiles":', self.catalog_src)
        self.assertIn('"validate_atlas_coords":', self.catalog_src)
        self.assertIn('"inspect_player_metrics":', self.catalog_src)
        self.assertIn('"inspect_tilemap_layer":', self.catalog_src)
        self.assertIn('"paint_tilemap_cells":', self.catalog_src)
        self.assertIn('"paint_tilemap_rect":', self.catalog_src)

        # Check parameter schemas
        self.assertIn('"character_path":', self.catalog_src)
        self.assertIn('"tile_dimension":', self.catalog_src)
        self.assertIn('"atlas_coords":', self.catalog_src)
        self.assertIn('"max_dimension":', self.catalog_src)

    def test_bridge_and_mcp_mapping(self):
        # Verify bridge LOCAL_TOOL_NAMES includes all 9 new tools
        self.assertIn('"analyze_atlas_geometry"', self.bridge_src)
        self.assertIn('"preview_labelled_atlas"', self.bridge_src)
        self.assertIn('"inspect_tile_crop"', self.bridge_src)
        self.assertIn('"catalog_atlas_tiles"', self.bridge_src)
        self.assertIn('"validate_atlas_coords"', self.bridge_src)
        self.assertIn('"inspect_player_metrics"', self.bridge_src)
        self.assertIn('"inspect_tilemap_layer"', self.bridge_src)
        self.assertIn('"paint_tilemap_cells"', self.bridge_src)
        self.assertIn('"paint_tilemap_rect"', self.bridge_src)

        # Verify bridge bundle keywords and aliases
        self.assertIn('"preview_coordinate_labelled_atlas", "inspect_atlas_geometry":', self.bridge_src)
        self.assertIn('"generate_tile_catalog":', self.bridge_src)
        self.assertIn('"measure_player_metrics":', self.bridge_src)
        self.assertIn('"tilemap_layer_inspect":', self.bridge_src)
        self.assertIn('"metrics", "player_metrics", "jump", "layer"', self.bridge_src)

        # Verify mcp_mapping.gd
        self.assertIn('"analyze_atlas_geometry":', self.mapping_src)
        self.assertIn('"preview_labelled_atlas":', self.mapping_src)
        self.assertIn('"inspect_tile_crop":', self.mapping_src)
        self.assertIn('"catalog_atlas_tiles":', self.mapping_src)
        self.assertIn('"validate_atlas_coords":', self.mapping_src)
        self.assertIn('"inspect_player_metrics":', self.mapping_src)
        self.assertIn('"inspect_tilemap_layer":', self.mapping_src)
        self.assertIn('"paint_tilemap_cells":', self.mapping_src)
        self.assertIn('"paint_tilemap_rect":', self.mapping_src)

    def test_server_system_prompt_workflow_and_tilemap_protocol(self):
        # 1. Section 4 Workflow: The Two Loops and 7-Step Implementation Cycle
        self.assertIn("The Two Agent Loops", self.server_src)
        self.assertIn("The Task Loop (Orchestrator)", self.server_src)
        self.assertIn("The Implementation Loop (System Prompt)", self.server_src)
        self.assertIn("The Autonomous Implementation Cycle: Plan → Act → Observe → Validate → Update → Decide → Continue", self.server_src)
        self.assertIn("Plan Once, Up Front", self.server_src)

        # 2. Dedicated TileMap Protocol Tag
        self.assertIn("<tilemap_protocol>", self.server_src)
        self.assertIn("</tilemap_protocol>", self.server_src)
        self.assertIn("GODOTAGENT — PROFESSIONAL TILEMAP AND LEVEL CONSTRUCTION PROTOCOL", self.server_src)

        # 3. All 12 Protocol Sections Present
        self.assertIn("### 1. MISSION", self.server_src)
        self.assertIn("### 2. MANDATORY INITIAL PLAN", self.server_src)
        self.assertIn("### 3. MANDATORY PLAN → ACT → OBSERVE → VALIDATE → UPDATE → DECIDE → CONTINUE CYCLE", self.server_src)
        self.assertIn("### 4. TOOL DISCOVERY AND USAGE", self.server_src)
        self.assertIn("### 5. TILESET DISCOVERY AND ATLAS ANALYSIS", self.server_src)
        self.assertIn("### 6. TILESET CONFIGURATION", self.server_src)
        self.assertIn("### 7. CHOOSE THE RIGHT REPRESENTATION — DO NOT OVER-ENGINEER REUSE", self.server_src)
        self.assertIn("### 8. PROFESSIONAL LEVEL LAYOUT", self.server_src)
        self.assertIn("### 9. COLLISION AND GAMEPLAY INTEGRATION", self.server_src)
        self.assertIn("### 10. CONTROLLED MUTATION AND PRESERVATION", self.server_src)
        self.assertIn("### 11. MILESTONE VALIDATION", self.server_src)
        self.assertIn("### 12. COMPLETION REQUIREMENTS & FINAL OPERATING PRINCIPLE", self.server_src)

        # 4. Critical Rules
        self.assertIn("coordinate-labelled tile preview", self.server_src)
        self.assertIn("preview_labelled_atlas", self.server_src)
        self.assertIn("analyze_atlas_geometry", self.server_src)
        self.assertIn("inspect_player_metrics", self.server_src)
        self.assertIn("Do not infer tile size solely by dividing image dimensions", self.server_src)
        self.assertIn("Infer categories from actual artwork", self.server_src)
        self.assertIn("do not fabricate an autotiling setup", self.server_src)
        self.assertIn("Reusability is a design decision, not an absolute rule", self.server_src)
        self.assertIn("Concrete Painting Tool Payloads", self.server_src)
        self.assertIn('"node_path": "World/Environment/Ground_Base"', self.server_src)
        self.assertIn('"atlas_coords": [1, 1]', self.server_src)
        self.assertIn('"coords": [0, 9]', self.server_src)


if __name__ == "__main__":
    unittest.main()
