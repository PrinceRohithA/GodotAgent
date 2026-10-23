"""Unit tests for SpriteFrames Authoring, Spritesheet Slicing, AnimatedSprite2D auto-creation and editor display."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"
MCP_ADDON = ROOT / "project" / "addons" / "godot_mcp"


class SpriteFramesAuthoringTests(unittest.TestCase):
    def setUp(self):
        self.local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (AGENT_ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.mcp_handler_src = (MCP_ADDON / "handlers" / "sprite_frames.gd").read_text(encoding="utf-8")

    def test_local_tools_texture_loading_resilience(self):
        self.assertIn("func _load_texture_resource", self.local_tools_src)
        self.assertIn("ImageTexture.create_from_image(img)", self.local_tools_src)
        self.assertIn("itex.take_over_path(p)", self.local_tools_src)

    def test_local_tools_frame_size_parsing(self):
        self.assertIn("func _parse_frame_size", self.local_tools_src)
        self.assertIn('var parts := s.split("x")', self.local_tools_src)
        self.assertIn("TYPE_VECTOR2I", self.local_tools_src)
        self.assertIn("TYPE_DICTIONARY", self.local_tools_src)

    def test_local_tools_slicing_variants(self):
        # Supports flat index arrays, row without count, count without row
        self.assertIn("var idx := int(idx_v)", self.local_tools_src)
        self.assertIn("idx % cols", self.local_tools_src)
        self.assertIn("int(idx / cols)", self.local_tools_src)
        self.assertIn("margin_x", self.local_tools_src)
        self.assertIn("spacing_x", self.local_tools_src)

    def test_local_tools_auto_creates_animated_sprite_if_missing(self):
        self.assertIn("var new_spr := AnimatedSprite2D.new()", self.local_tools_src)
        self.assertIn("target_parent.add_child(new_spr, true)", self.local_tools_src)
        self.assertIn("new_spr.owner = root", self.local_tools_src)
        self.assertIn('"node_created": node_created', self.local_tools_src)

    def test_local_tools_auto_detects_existing_animated_sprite(self):
        self.assertIn('_find_first_child_of_type(root, "AnimatedSprite2D")', self.local_tools_src)

    def test_editor_display_and_animation_selection(self):
        # Sets animation, autoplay, and frame 0 so 2D editor displays immediately
        self.assertIn('assigned_node.set("animation", autoplay)', self.local_tools_src)
        self.assertIn('assigned_node.set("frame", 0)', self.local_tools_src)
        self.assertIn('node.set("animation", autoplay)', self.mcp_handler_src)
        self.assertIn('node.set("frame", 0)', self.mcp_handler_src)

    def test_hierarchy_creation_forwards_texture_and_frame_size(self):
        self.assertIn('"texture": spec.get("texture"', self.local_tools_src)
        self.assertIn('"frame_size": spec.get("frame_size"', self.local_tools_src)

    def test_collision_shape_auto_sizing_supports_animated_sprite(self):
        # _create_collision_for_sprite supports AnimatedSprite2D
        self.assertIn("sp_node is AnimatedSprite2D", self.local_tools_src)
        self.assertIn("sf.get_frame_texture(cur_anim, 0)", self.local_tools_src)
        # _build_node_recursive auto-shape supports AnimatedSprite2D
        self.assertIn('child.is_class("AnimatedSprite2D")', self.local_tools_src)

    def test_default_save_path_generation(self):
        self.assertIn('"res://resources/%s_frames.tres" % base_name', self.local_tools_src)

    def test_coerce_property_value_returns_frames_object(self):
        self.assertIn('if sf_res.has("frames") and sf_res["frames"] is SpriteFrames:', self.local_tools_src)
        self.assertIn('return sf_res["frames"]', self.local_tools_src)

    def test_tool_catalog_documents_flexible_authoring(self):
        self.assertIn("Auto-created if it does not exist.", self.catalog_src)
        self.assertIn("Auto-generated if omitted.", self.catalog_src)
        self.assertIn("Flat index array: [0, 1, 2, 3]", self.catalog_src)

    def test_server_prompt_instructs_spritesheet_authoring(self):
        self.assertIn("`create_sprite_frames` automatically creates it under the specified parent", self.server_src)
        self.assertIn("sets its active animation and frame 0 so it renders immediately", self.server_src)


if __name__ == "__main__":
    unittest.main()
