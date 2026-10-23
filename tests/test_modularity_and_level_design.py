"""Unit tests for Professional Modularity, Custom Resources, Level Design Protocol, and Visual Verification Mandate."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class ModularityAndLevelDesignTests(unittest.TestCase):
    def setUp(self):
        self.server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")

    def test_component_modularity_and_custom_resources_prompt(self):
        # Asserts Section 10.9 exists with explicit rules
        self.assertIn("### 10.9 Professional Modularity, Scene Composition, and Custom Resources", self.server_src)
        self.assertIn("Scene Composition over Deep Inheritance", self.server_src)
        self.assertIn("MovementComponent", self.server_src)
        self.assertIn("HealthComponent", self.server_src)
        self.assertIn("HitboxComponent", self.server_src)
        self.assertIn("HurtboxComponent", self.server_src)
        self.assertIn("StateMachine", self.server_src)
        self.assertIn("Call Down, Signal Up", self.server_src)
        self.assertIn("Data-Driven Architecture via Custom Resources", self.server_src)
        self.assertIn("class_name CharacterStats", self.server_src)
        self.assertIn("res://scripts/components/", self.server_src)
        self.assertIn("res://resources/", self.server_src)

    def test_level_design_and_environment_placement_protocol(self):
        # Asserts Section 10.10 exists with structured rules
        self.assertIn("### 10.10 Professional 2D Level Design & Environment Placement Protocol", self.server_src)
        self.assertIn("Functional `TileMapLayer` Separation", self.server_src)
        self.assertIn("Background_Decor", self.server_src)
        self.assertIn("Ground_Base", self.server_src)
        self.assertIn("Foreground_Overhangs", self.server_src)
        self.assertIn("Parallax2D", self.server_src)
        self.assertIn("repeat_size", self.server_src)
        self.assertIn("scroll_scale", self.server_src)
        self.assertIn("Camera Framing & Level Boundaries", self.server_src)
        self.assertIn("limit_left", self.server_src)
        self.assertIn("limit_right", self.server_src)
        self.assertIn("drag_horizontal_enabled", self.server_src)

    def test_visual_inspection_and_placement_verification_mandate(self):
        # Asserts Level 6 in Section 6 is an active mandate
        self.assertIn("### Level 6 — Visual inspection & Environment Verification", self.server_src)
        self.assertIn("Visual inspection is **MANDATORY** for any task involving level design, prop/entity placement", self.server_src)
        self.assertIn("capture_viewport", self.server_src)
        self.assertIn("visual hierarchy and readability", self.server_src)
        self.assertIn("ground contact and alignment", self.server_src)
        self.assertIn("camera framing", self.server_src)

    def test_animation_reset_track_and_advance_expressions(self):
        # Asserts Animation systems include RESET track and advance expressions
        self.assertIn("Mandatory RESET Animation Track", self.server_src)
        self.assertIn("Advance Expressions vs Manual Bools", self.server_src)
        self.assertIn("Constant-Driven Travel", self.server_src)
        self.assertIn("Pre-Flight Animation Checklist", self.server_src)
        self.assertIn("AnimationTree.active == true", self.server_src)

    def test_step_4_workflow_incorporates_modularity_and_visual_verification(self):
        # Asserts Step 4 in Section 4 includes modularity and visual check
        self.assertIn("Bulk Hierarchy Construction & Component Modularity", self.server_src)
        self.assertIn("Visual & Viewport Verification (Mandatory)", self.server_src)


if __name__ == "__main__":
    unittest.main()
