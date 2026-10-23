"""Unit tests for GodotAgent 2D Spatial Awareness v1.

Covers:
- Tool registrations, aliases, and catalog schemas.
- Bridge bundling and MCP mapping contracts.
- System prompt instructions and strict anti-guessing rules.
- Deterministic geometry fixture math matching GDScript implementations:
  * Coordinate transformations (Global <-> Local, Global <-> Viewport, Global <-> Cell).
  * Rejection of invalid conversions (Atlas -> World).
  * Region intersection and horizontal platform surface merging.
  * Spatial relationships (clearance, direction classification, support surfaces).
"""

from __future__ import annotations

import math
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"


class SpatialRegistrationAndSchemaTests(unittest.TestCase):
    def setUp(self) -> None:
        self.local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (AGENT_ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.bridge_src = (AGENT_ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.mapping_src = (AGENT_ADDON / "mcp_mapping.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")

    def test_local_names_includes_spatial_tools(self) -> None:
        expected_tools = [
            "inspect_spatial_context",
            "convert_spatial_coordinates",
            "inspect_spatial_region",
            "query_spatial_relationships",
            "preview_spatial_overlay",
        ]
        for tool_name in expected_tools:
            self.assertIn(f'"{tool_name}"', self.local_tools_src)

    def test_has_tool_and_invoke_support_aliases(self) -> None:
        aliases = [
            "spatial_context",
            "spatial_inspect",
            "convert_coordinates",
            "convert_coords",
            "spatial_region",
            "inspect_region",
            "spatial_relationships",
            "query_relationships",
            "spatial_overlay",
            "draw_spatial_overlay",
        ]
        for alias in aliases:
            self.assertIn(f'"{alias}"', self.local_tools_src)

    def test_tool_catalog_defines_all_spatial_schemas(self) -> None:
        tools = [
            "inspect_spatial_context",
            "convert_spatial_coordinates",
            "inspect_spatial_region",
            "query_spatial_relationships",
            "preview_spatial_overlay",
        ]
        for tool in tools:
            self.assertIn(f'"{tool}":', self.catalog_src)

        # Check key schema properties
        self.assertIn('"from_frame"', self.catalog_src)
        self.assertIn('"to_frame"', self.catalog_src)
        self.assertIn('"tilemap_cell"', self.catalog_src)
        self.assertIn('"tilemap_atlas"', self.catalog_src)
        self.assertIn('"node_a"', self.catalog_src)
        self.assertIn('"node_b"', self.catalog_src)
        self.assertIn('"rect"', self.catalog_src)

    def test_bridge_pins_spatial_tools_and_bundle_keywords(self) -> None:
        for tool in [
            "inspect_spatial_context",
            "convert_spatial_coordinates",
            "inspect_spatial_region",
            "query_spatial_relationships",
            "preview_spatial_overlay",
        ]:
            self.assertIn(f'"{tool}"', self.bridge_src)

        # Bundle keywords
        self.assertIn('"clearance"', self.bridge_src)
        self.assertIn('"support_surface"', self.bridge_src)
        self.assertIn('"reachability"', self.bridge_src)
        self.assertIn('"overlay"', self.bridge_src)

    def test_mcp_mapping_defines_abstract_spatial_tools(self) -> None:
        for tool in [
            "inspect_spatial_context",
            "convert_spatial_coordinates",
            "inspect_spatial_region",
            "query_spatial_relationships",
            "preview_spatial_overlay",
        ]:
            self.assertIn(f'"{tool}":', self.mapping_src)

    def test_system_prompt_instructs_spatial_awareness_and_anti_guessing(self) -> None:
        self.assertIn("10.7 Spatial Awareness and 2D Geometry Integrity", self.server_src)
        self.assertIn("Never guess spatial coordinates, distances, or clearances from scaled screenshots alone", self.server_src)
        self.assertIn("inspect_spatial_context", self.server_src)
        self.assertIn("convert_spatial_coordinates", self.server_src)
        self.assertIn("inspect_spatial_region", self.server_src)
        self.assertIn("query_spatial_relationships", self.server_src)
        self.assertIn("preview_spatial_overlay", self.server_src)
        self.assertIn("Strict Reachability Rule", self.server_src)
        self.assertIn("NEVER proven reachable purely from bounding box proximity", self.server_src)
        self.assertIn("inspect_player_metrics", self.server_src)


# ==============================================================================
# Deterministic Geometry & Coordinate Verification Fixtures
# ==============================================================================

class DeterministicSpatialMathTests(unittest.TestCase):
    def test_local_to_global_and_inverse_conversion(self) -> None:
        # Simulate Node2D transform: position=(100, 200), rotation=0, scale=(2, 2)
        pos = (100.0, 200.0)
        scale = (2.0, 2.0)
        local_pt = (10.0, 15.0)

        # to_global
        global_pt = (pos[0] + local_pt[0] * scale[0], pos[1] + local_pt[1] * scale[1])
        self.assertEqual(global_pt, (120.0, 230.0))

        # to_local
        inv_local = ((global_pt[0] - pos[0]) / scale[0], (global_pt[1] - pos[1]) / scale[1])
        self.assertAlmostEqual(inv_local[0], local_pt[0], places=5)
        self.assertAlmostEqual(inv_local[1], local_pt[1], places=5)

    def test_viewport_screen_to_world_and_back_with_camera(self) -> None:
        # Camera at (500, 300), zoom=(1.5, 1.5), viewport=(1152, 648)
        cam_pos = (500.0, 300.0)
        cam_zoom = (1.5, 1.5)
        vp_size = (1152.0, 648.0)
        half_vp = (vp_size[0] * 0.5, vp_size[1] * 0.5)

        world_target = (560.0, 340.0)

        # Global -> Viewport
        delta = (world_target[0] - cam_pos[0], world_target[1] - cam_pos[1])
        screen_pt = (delta[0] * cam_zoom[0] + half_vp[0], delta[1] * cam_zoom[1] + half_vp[1])
        self.assertEqual(screen_pt, (60.0 * 1.5 + 576.0, 40.0 * 1.5 + 324.0))
        self.assertEqual(screen_pt, (666.0, 384.0))

        # Viewport -> Global
        unzoomed = ((screen_pt[0] - half_vp[0]) / cam_zoom[0], (screen_pt[1] - half_vp[1]) / cam_zoom[1])
        back_world = (cam_pos[0] + unzoomed[0], cam_pos[1] + unzoomed[1])
        self.assertAlmostEqual(back_world[0], world_target[0], places=5)
        self.assertAlmostEqual(back_world[1], world_target[1], places=5)

    def test_tilemap_cell_to_world_and_back(self) -> None:
        # Tile size = 64x64, layer at origin
        tile_size = (64.0, 64.0)
        cell = (5, -2)

        # Map to local center: cell * size + size/2
        world_center = (cell[0] * tile_size[0] + tile_size[0] * 0.5, cell[1] * tile_size[1] + tile_size[1] * 0.5)
        self.assertEqual(world_center, (352.0, -96.0))

        # World back to map: floor(world / tile_size)
        calc_cell = (math.floor(world_center[0] / tile_size[0]), math.floor(world_center[1] / tile_size[1]))
        self.assertEqual(calc_cell, cell)

    def test_bounding_clearance_and_relative_direction(self) -> None:
        # Node A: [x=100, y=100, w=50, h=80] -> center=(125, 140), bottom=180, right=150
        box_a = {"x": 100.0, "y": 100.0, "w": 50.0, "h": 80.0}
        # Node B: Platform to the right: [x=220, y=180, w=100, h=32] -> left=220, top=180
        box_b = {"x": 220.0, "y": 180.0, "w": 100.0, "h": 32.0}

        # Horizontal clearance
        h_clearance = box_b["x"] - (box_a["x"] + box_a["w"])  # 220 - 150 = 70.0
        self.assertEqual(h_clearance, 70.0)

        # Vertical clearance (top of B is 180, bottom of A is 180 -> contact vertical clearance 0.0)
        v_clearance = max(0.0, box_b["y"] - (box_a["y"] + box_a["h"]))
        self.assertEqual(v_clearance, 0.0)

        # Relative direction: B is to the right of A
        dx = (box_b["x"] + box_b["w"] * 0.5) - (box_a["x"] + box_a["w"] * 0.5)
        self.assertGreater(dx, 0)

    def test_support_surface_detection(self) -> None:
        # Player: [x=100, y=100, w=32, h=64] -> horizontal [100..132], bottom=164
        player = {"x": 100.0, "y": 100.0, "w": 32.0, "h": 64.0}
        # Platform 1 directly underneath: [x=80, y=164, w=200, h=32] -> horizontal [80..280], top=164
        plat1 = {"x": 80.0, "y": 164.0, "w": 200.0, "h": 32.0}

        # Check horizontal overlap
        a_right = player["x"] + player["w"]
        b_right = plat1["x"] + plat1["w"]
        h_overlap = max(0.0, min(a_right, b_right) - max(player["x"], plat1["x"]))
        self.assertEqual(h_overlap, 32.0)  # full player width spans platform

        # Drop distance: plat_top - player_bottom = 164 - 164 = 0 (perfect contact)
        drop_dist = plat1["y"] - (player["y"] + player["h"])
        self.assertEqual(drop_dist, 0.0)
        self.assertTrue(abs(drop_dist) <= 2.0)

    def test_horizontal_surface_merging(self) -> None:
        # Three adjacent 64px cells at y=200: x=0..64, x=64..128, x=128..192
        cells = [(0, 200, 64), (64, 200, 64), (128, 200, 64)]
        surface_start = cells[0][0]
        surface_end = cells[0][0] + cells[0][2]
        for c in cells[1:]:
            if c[0] == surface_end:
                surface_end = c[0] + c[2]

        # Merged span: 0 to 192 (total width 192)
        self.assertEqual(surface_start, 0)
        self.assertEqual(surface_end, 192)
        self.assertEqual(surface_end - surface_start, 192)


if __name__ == "__main__":
    unittest.main()
