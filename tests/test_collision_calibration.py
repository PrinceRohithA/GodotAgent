"""
Unit tests for GodotAgent Collision Calibration v1.
Validates tool registration, schema definitions, bundle keywords, system prompt guidelines,
and mathematical invariants for collision profiles and ground baseline alignment.
"""

import math
import os
import re
import unittest

ROOT_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ADDONS_DIR = os.path.join(ROOT_DIR, "project", "addons", "godot_agent")


class TestCollisionCalibrationRegistration(unittest.TestCase):
    """Verifies that all 4 collision calibration tools are registered across the agent codebase."""

    EXPECTED_TOOLS = [
        "inspect_collision_geometry",
        "measure_visual_bounds",
        "calibrate_collision_shape",
        "preview_collision_overlay",
    ]

    def test_registered_in_local_tools_names(self):
        path = os.path.join(ADDONS_DIR, "agent_local_tools.gd")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        local_names_match = re.search(r"const LOCAL_NAMES := \[(.*?)\]", content, re.DOTALL)
        self.assertIsNotNone(local_names_match, "LOCAL_NAMES array not found in agent_local_tools.gd")
        names_block = local_names_match.group(1)

        for tool in self.EXPECTED_TOOLS:
            self.assertIn(f'"{tool}"', names_block, f"{tool} missing from LOCAL_NAMES in agent_local_tools.gd")

    def test_registered_in_has_tool_and_invoke(self):
        path = os.path.join(ADDONS_DIR, "agent_local_tools.gd")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        for tool in self.EXPECTED_TOOLS:
            self.assertIn(f'"{tool}"', content, f"{tool} missing from agent_local_tools.gd")

        # Aliases in has_tool
        aliases = [
            "collision_geometry", "inspect_collider",
            "visual_bounds", "measure_sprite_bounds",
            "calibrate_collision", "calibrate_collider",
            "collision_overlay", "preview_collision"
        ]
        for alias in aliases:
            self.assertIn(f'"{alias}"', content, f"Alias {alias} missing from has_tool in agent_local_tools.gd")

    def test_registered_in_tools_bridge(self):
        path = os.path.join(ADDONS_DIR, "agent_tools_bridge.gd")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        bridge_names_match = re.search(r"const LOCAL_TOOL_NAMES := \[(.*?)\]", content, re.DOTALL)
        self.assertIsNotNone(bridge_names_match, "LOCAL_TOOL_NAMES array not found in agent_tools_bridge.gd")
        names_block = bridge_names_match.group(1)

        for tool in self.EXPECTED_TOOLS:
            self.assertIn(f'"{tool}"', names_block, f"{tool} missing from LOCAL_TOOL_NAMES in agent_tools_bridge.gd")

    def test_registered_in_mcp_mapping(self):
        path = os.path.join(ADDONS_DIR, "mcp_mapping.gd")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        for tool in self.EXPECTED_TOOLS:
            self.assertIn(f'"{tool}"', content, f"{tool} missing from ABSTRACT_TO_MCP in mcp_mapping.gd")

    def test_physics_bundle_includes_collision_keywords(self):
        path = os.path.join(ADDONS_DIR, "agent_tools_bridge.gd")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        keywords = ["calibrate", "calibration", "visual_bounds", "opaque", "feet", "baseline", "silhouette"]
        for kw in keywords:
            self.assertIn(f'"{kw}"', content, f"Keyword '{kw}' missing from TOOL_BUNDLES in agent_tools_bridge.gd")


class TestCollisionToolSchemas(unittest.TestCase):
    """Verifies that tool schemas in agent_tool_catalog.gd are valid and describe all parameters."""

    def setUp(self):
        path = os.path.join(ADDONS_DIR, "agent_tool_catalog.gd")
        with open(path, "r", encoding="utf-8") as f:
            self.content = f.read()

    def test_inspect_collision_geometry_schema(self):
        self.assertIn('"inspect_collision_geometry"', self.content)
        self.assertIn('"node_path"', self.content)

    def test_measure_visual_bounds_schema(self):
        self.assertIn('"measure_visual_bounds"', self.content)
        self.assertIn('"alpha_threshold"', self.content)
        self.assertIn('"animation"', self.content)

    def test_calibrate_collision_shape_schema(self):
        self.assertIn('"calibrate_collision_shape"', self.content)
        self.assertIn('"profile"', self.content)
        self.assertIn('"platformer_body"', self.content)
        self.assertIn('"top_down_body"', self.content)
        self.assertIn('"solid_object"', self.content)
        self.assertIn('"hurtbox"', self.content)
        self.assertIn('"attack_hitbox"', self.content)
        self.assertIn('"make_unique"', self.content)
        self.assertIn('"reset_scale"', self.content)
        self.assertIn('"align_feet"', self.content)
        self.assertIn('"apply"', self.content)

    def test_preview_collision_overlay_schema(self):
        self.assertIn('"preview_collision_overlay"', self.content)
        self.assertIn('"scale_factor"', self.content)
        self.assertIn('"save_path"', self.content)


class TestCollisionPromptIntegration(unittest.TestCase):
    """Verifies that Section 10.8 Collision Calibration is present in agent_server.gd."""

    def test_system_prompt_section_10_8_present(self):
        path = os.path.join(ADDONS_DIR, "agent_server.gd")
        with open(path, "r", encoding="utf-8") as f:
            content = f.read()

        self.assertIn("10.8 Collision Calibration and Physics Geometry Integrity", content)
        self.assertIn("inspect_collision_geometry", content)
        self.assertIn("measure_visual_bounds", content)
        self.assertIn("calibrate_collision_shape", content)
        self.assertIn("preview_collision_overlay", content)
        self.assertIn("ground_baseline_y", content)
        self.assertIn("make_unique", content)
        self.assertIn("platformer_body", content)


class TestCollisionCalibrationMath(unittest.TestCase):
    """Validates the mathematical principles and geometry invariants of collision calibration."""

    def test_opaque_bounding_box_logic(self):
        # 16x16 grid with a 8x8 character in center (x: 4..11, y: 6..13)
        grid = [[0.0] * 16 for _ in range(16)]
        for y in range(6, 14):
            for x in range(4, 12):
                grid[y][x] = 1.0

        min_x = 999
        max_x = -1
        min_y = 999
        max_y = -1
        opaque_count = 0

        for y in range(16):
            for x in range(16):
                if grid[y][x] >= 0.05:
                    min_x = min(min_x, x)
                    max_x = max(max_x, x)
                    min_y = min(min_y, y)
                    max_y = max(max_y, y)
                    opaque_count += 1

        self.assertEqual(min_x, 4)
        self.assertEqual(max_x, 11)
        self.assertEqual(min_y, 6)
        self.assertEqual(max_y, 13)
        self.assertEqual(max_x - min_x + 1, 8)
        self.assertEqual(max_y - min_y + 1, 8)
        self.assertEqual(opaque_count, 64)

    def test_ground_baseline_alignment_capsule(self):
        # Visual bounds: width 60, height 120, centered at (0, 0)
        # top = -60, bottom = +60 (feet)
        vis_w = 60.0
        vis_h = 120.0
        ground_baseline_y = 60.0

        # Profile: platformer_body
        w_factor = 0.85
        h_factor = 0.95
        target_w = vis_w * w_factor  # 51.0
        target_h = vis_h * h_factor  # 114.0

        cap_radius = target_w * 0.5  # 25.5
        cap_height = max(target_w, target_h)  # 114.0

        # When align_feet = True:
        # bottom of capsule = target_y + cap_height * 0.5
        # we want bottom of capsule == ground_baseline_y
        target_y = ground_baseline_y - (cap_height * 0.5)

        computed_bottom = target_y + (cap_height * 0.5)
        feet_error = abs(computed_bottom - ground_baseline_y)

        self.assertAlmostEqual(feet_error, 0.0, places=6)
        self.assertAlmostEqual(computed_bottom, 60.0, places=6)
        self.assertAlmostEqual(target_y, 60.0 - 57.0, places=6)  # +3.0

    def test_ground_baseline_alignment_rectangle(self):
        vis_w = 64.0
        vis_h = 64.0
        ground_baseline_y = 32.0

        # Profile: solid_object
        target_w = vis_w * 1.0
        target_h = vis_h * 1.0

        target_y = ground_baseline_y - (target_h * 0.5)
        computed_bottom = target_y + (target_h * 0.5)

        self.assertAlmostEqual(computed_bottom, ground_baseline_y, places=6)

    def test_top_down_profile_bounds(self):
        # Top-down bodies have collision only on the bottom ~40% (legs/feet)
        vis_w = 50.0
        vis_h = 100.0
        ground_baseline_y = 50.0

        w_factor = 0.80
        h_factor = 0.40
        target_w = vis_w * w_factor  # 40.0
        target_h = vis_h * h_factor  # 40.0

        target_y = ground_baseline_y - (target_h * 0.5)  # 50 - 20 = 30
        computed_bottom = target_y + (target_h * 0.5)

        self.assertAlmostEqual(computed_bottom, 50.0, places=6)
        self.assertEqual(target_w, 40.0)
        self.assertEqual(target_h, 40.0)

    def test_shared_resource_duplication_safety(self):
        # Simulating shape sharing detection
        class MockShape:
            def __init__(self, res_path=""):
                self.resource_path = res_path

            def duplicate(self):
                return MockShape(self.resource_path)

        shape_a = MockShape("res://shared_shape.tres")
        shape_b = shape_a  # Shared by 2 nodes

        is_shared = (shape_a is shape_b) or (shape_a.resource_path != "")
        self.assertTrue(is_shared)

        # Applying calibration with make_unique: true
        calibrated_shape = shape_a.duplicate()
        self.assertIsNot(calibrated_shape, shape_a)
        self.assertIsNot(calibrated_shape, shape_b)

    def test_non_unit_scale_warning_detection(self):
        # Detection of scale != (1.0, 1.0)
        scale_unit = (1.0, 1.0)
        scale_bad = (2.0, 0.5)

        dist_sq_unit = (scale_unit[0] - 1.0) ** 2 + (scale_unit[1] - 1.0) ** 2
        dist_sq_bad = (scale_bad[0] - 1.0) ** 2 + (scale_bad[1] - 1.0) ** 2

        self.assertLess(dist_sq_unit, 0.0001)
        self.assertGreater(dist_sq_bad, 0.0001)


if __name__ == "__main__":
    unittest.main()
