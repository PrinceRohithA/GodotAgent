"""Unit tests for Scene Instancing, Playtime Collision Debug Toggle, TileMap-First Mandate, and Level Designer Skill/Agent."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"


class SceneInstancingAndLevelDesignerTests(unittest.TestCase):
    def setUp(self):
        self.local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (AGENT_ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.bridge_src = (AGENT_ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.mapping_src = (AGENT_ADDON / "mcp_mapping.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.skills_src = (AGENT_ADDON / "agent_skills.gd").read_text(encoding="utf-8")
        self.skill_file = AGENT_ADDON / "skills" / "builtin" / "level_designer.md"

    def test_local_tools_registers_instance_scene(self):
        self.assertIn('"instance_scene"', self.local_tools_src)
        self.assertIn('"instantiate_scene"', self.local_tools_src)
        self.assertIn('"add_instance"', self.local_tools_src)
        self.assertIn("func _instance_scene", self.local_tools_src)

    def test_local_tools_instance_scene_implementation_contracts(self):
        self.assertIn("missing_scene_path", self.local_tools_src)
        self.assertIn("invalid_scene_extension", self.local_tools_src)
        self.assertIn("PackedScene.GEN_EDIT_STATE_INSTANCE", self.local_tools_src)
        self.assertIn("inst.owner = root", self.local_tools_src)
        self.assertIn('"is_instance": true', self.local_tools_src)

    def test_hierarchy_creation_supports_scene_instancing(self):
        # Asserts _build_node_recursive handles instance_scene / scene_path
        self.assertIn('spec.get("instance_scene"', self.local_tools_src)
        self.assertIn('packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)', self.local_tools_src)
        self.assertIn('if not is_instanced:\n\t\t_set_owner_recursive(n, scene_root)', self.local_tools_src)
        self.assertIn('"is_instance": is_instanced', self.local_tools_src)

    def test_polygon_and_collision_polygon_coercion_and_validation(self):
        self.assertIn("TYPE_PACKED_VECTOR2_ARRAY", self.local_tools_src)
        self.assertIn('prop in ["polygon", "points", "uv", "uvs"]', self.local_tools_src)
        self.assertIn("PackedVector2Array()", self.local_tools_src)
        self.assertIn("Polygon2D at '%s' has NO polygon points assigned.", self.local_tools_src)
        self.assertIn("CollisionPolygon2D at '%s' has NO polygon points assigned.", self.local_tools_src)

    def test_toggle_debug_collisions_tool(self):
        self.assertIn('"toggle_debug_collisions"', self.local_tools_src)
        self.assertIn('"toggle_collision_debug"', self.local_tools_src)
        self.assertIn("func _toggle_debug_collisions", self.local_tools_src)
        self.assertIn('debug/shapes/collision/visible', self.local_tools_src)
        self.assertIn('ProjectSettings.save()', self.local_tools_src)
        self.assertIn('debug_collisions_hint', self.local_tools_src)

    def test_invoke_level_designer_tool(self):
        self.assertIn('"invoke_level_designer"', self.local_tools_src)
        self.assertIn('"delegate_level_design"', self.local_tools_src)
        self.assertIn("func _invoke_level_designer", self.local_tools_src)
        self.assertIn("TileMapLayer", self.local_tools_src)
        self.assertIn("available_entity_scenes", self.local_tools_src)
        self.assertIn("TILEMAP-FIRST MANDATE", self.local_tools_src)
        self.assertIn("SCENE REUSE MANDATE", self.local_tools_src)

    def test_tool_catalog_defines_schemas(self):
        self.assertIn('"instance_scene":', self.catalog_src)
        self.assertIn('"toggle_debug_collisions":', self.catalog_src)
        self.assertIn('"invoke_level_designer":', self.catalog_src)

    def test_tools_bridge_registers_new_tools_and_keywords(self):
        self.assertIn('"instance_scene"', self.bridge_src)
        self.assertIn('"toggle_debug_collisions"', self.bridge_src)
        self.assertIn('"invoke_level_designer"', self.bridge_src)
        self.assertIn('"toggle_debug_collisions", "debug_collision"', self.bridge_src)
        self.assertIn('"level_design", "level_designer", "instance_scene", "invoke_level_designer"', self.bridge_src)

    def test_mcp_mapping_wires_instance_scene_and_debug_collisions(self):
        self.assertIn('"instance_scene": {"mcp_tools":["godot_scene_edit_instance_scene"]', self.mapping_src)
        self.assertIn('"toggle_debug_collisions":', self.mapping_src)
        self.assertIn('"invoke_level_designer":', self.mapping_src)

    def test_builtin_level_designer_skill(self):
        self.assertTrue(self.skill_file.exists(), "level_designer.md skill file must exist")
        skill_text = self.skill_file.read_text(encoding="utf-8")
        self.assertIn("id: level_designer", skill_text)
        self.assertIn("The TileMap-First Mandate", skill_text)
        self.assertIn("Reusable Scene Instancing Mandate", skill_text)
        self.assertIn("Irregular & Sloped Terrain Protocol (`Polygon2D` + `CollisionPolygon2D`)", skill_text)
        self.assertIn("Player Metrics & Jump Reach Constraints", skill_text)
        self.assertIn("Playtime Collision & Viewport Verification", skill_text)

    def test_agent_server_prompt_mandates(self):
        self.assertIn("### 10.12 TileMap-First Level Design, Irregular Polygons, and Scene Reuse Mandate", self.server_src)
        self.assertIn("The Strict TileMap-First Mandate (No Loose Floor Blocks)", self.server_src)
        self.assertIn("The Scene Instantiation & Reuse Mandate (Never Duplicate Entity Trees)", self.server_src)
        self.assertIn("Irregular Terrain & Slopes Protocol (`Polygon2D` + `CollisionPolygon2D`)", self.server_src)
        self.assertIn("Playtime Collision Debugging (`toggle_debug_collisions`)", self.server_src)
        self.assertIn("Specialized Level Designer Invocation (`invoke_level_designer`)", self.server_src)
        # Check Scene Construction Workflow steps
        self.assertIn("Scene Creation & Instantiation", self.server_src)
        self.assertIn("instance_scene(scene_path, parent_path, properties)", self.server_src)
        self.assertIn("TileMap-First Law", self.server_src)


if __name__ == "__main__":
    unittest.main()
