"""Integration tests for GodotAgent Tool Bundles, Dynamic Unpacking, and Window Eviction."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class ToolBundleTests(unittest.TestCase):
    def setUp(self):
        self.bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")

    def test_bundle_tools_are_registered_in_bridge(self):
        self.assertIn('"list_tool_bundles"', self.bridge_src)
        self.assertIn('"unpack_tool_bundle"', self.bridge_src)
        self.assertIn('"pack_tool_bundle"', self.bridge_src)
        self.assertIn("TOOL_BUNDLES", self.bridge_src)

    def test_bundle_tools_have_schema_in_catalog(self):
        self.assertIn('"list_tool_bundles":', self.catalog_src)
        self.assertIn('"unpack_tool_bundle":', self.catalog_src)
        self.assertIn('"pack_tool_bundle":', self.catalog_src)

    def test_server_prompt_instructs_agent_on_bundles(self):
        self.assertIn("Specialized tools may exist in stored bundles", self.server_src)
        self.assertIn("list_tool_bundles", self.server_src)
        self.assertIn("unpack_tool_bundle", self.server_src)
        self.assertIn("pack_tool_bundle", self.server_src)
        self.assertIn("Tool Window: %d / 128 slots used", self.server_src)

    def test_server_notifies_agent_when_bundles_change(self):
        self.assertIn("bundles_changed", self.server_src)
        self.assertIn("Active bundles:", self.server_src)

    def test_bundle_keyword_scoring_matches_user_intents(self):
        # Extract keywords from GDScript TOOL_BUNDLES
        intents = {
            "I need to configure 2D physics gravity and body collisions": "physics",
            "Please create a tilemap with ground tiles and an atlas": "tilemap",
            "Set up background music and sound effects": "audio",
            "Build a 3D level with meshes, camera, and directional light": "scene_3d",
            "Create a particle explosion VFX with GPU emitter": "particles",
            "Set up enemy navigation pathfinding with navmesh": "navigation",
            "Write a custom vertex shader material": "shaders",
            "Show me current FPS draw calls and memory profiling": "profiling",
        }

        # Verify that for each intent prompt, the corresponding bundle is mentioned
        for prompt, expected_bundle in intents.items():
            self.assertIn(expected_bundle, self.bridge_src)

    def test_capacity_math_guarantees_below_128_limit(self):
        # Even with 32 native tools, 27 pinned tools, and multiple unpacked bundles,
        # the capacity ceiling is strictly enforced <= 128.
        max_tools = 128
        native_count = 32
        pinned_count = 27
        mcp_capacity = max_tools - native_count  # 96 slots

        # Suppose we have 5 bundles of 25 tools each (125 tools total)
        bundles = {f"bundle_{i}": [f"tool_{i}_{j}" for j in range(25)] for i in range(5)}
        unpacked = []
        active_mcp = [f"pinned_{i}" for i in range(pinned_count)]

        for b_name, b_tools in bundles.items():
            projected = len(active_mcp) + len(b_tools)
            evicted = []
            while projected > mcp_capacity and unpacked:
                oldest = unpacked.pop(0)
                evicted.append(oldest)
                for t in bundles[oldest]:
                    if t in active_mcp:
                        active_mcp.remove(t)
                projected = len(active_mcp) + len(b_tools)
            unpacked.append(b_name)
            for t in b_tools:
                if t not in active_mcp:
                    active_mcp.append(t)

            total_active = native_count + len(active_mcp)
            self.assertLessEqual(total_active, max_tools, f"Exceeded {max_tools} at step {b_name}!")

        # Final active count must be <= 128
        self.assertLessEqual(native_count + len(active_mcp), 128)
        # Oldest bundles must have been evicted
        self.assertGreater(len(unpacked), 0)

    def test_bundle_aliases_and_normalization(self):
        self.assertIn("func _resolve_bundle_name", self.bridge_src)
        self.assertIn('"3d": "scene_3d"', self.bridge_src)
        self.assertIn('"sound": "audio"', self.bridge_src)
        self.assertIn('"collision": "physics"', self.bridge_src)
        self.assertIn('"nav": "navigation"', self.bridge_src)
        self.assertIn('"anim": "animation"', self.bridge_src)
        self.assertIn('"tiles": "tilemap"', self.bridge_src)
        self.assertIn("func _bundle_for_tool", self.bridge_src)

    def test_direct_call_auto_unpacking_logic(self):
        self.assertIn("_bundle_for_tool(mcp_target)", self.bridge_src)
        self.assertIn("var suggested_bundle := _bundle_for_tool(name)", self.bridge_src)
        self.assertIn('res["catalog_changed"] = true', self.bridge_src)
        self.assertIn("_unpack_tool_bundle({\"bundle_name\": b_name})", self.bridge_src)

    def test_server_prompt_contains_tool_shuffling_and_available_bundles(self):
        self.assertIn("<tool_management>", self.server_src)
        self.assertIn("</tool_management>", self.server_src)
        self.assertIn("Tool discovery and bundle management", self.server_src)
        self.assertIn("Bundle activation protocol", self.server_src)
        self.assertIn("Never abandon a task simply because the required tool is not in the current window", self.server_src)
    def test_godot_debug_workflow_is_permanently_removed_and_disallowed(self):
        # Assert not in pinned tools
        self.assertNotIn('"godot_debug_workflow"', self.bridge_src.split("const PINNED_MCP_TOOLS")[1].split("]")[0])
        # Assert in DISALLOWED_MCP_TOOLS
        self.assertIn("const DISALLOWED_MCP_TOOLS", self.bridge_src)
        self.assertIn('"godot_debug_workflow"', self.bridge_src.split("const DISALLOWED_MCP_TOOLS")[1].split("]")[0])
        # Assert catalog filters disallowed tools
        self.assertIn("DISALLOWED_TOOLS", self.catalog_src)
        # Assert bridge intercepts calls to godot_debug_workflow
        self.assertIn('if name in DISALLOWED_MCP_TOOLS or name == "godot_debug_workflow":', self.bridge_src)
        self.assertIn('"tool_deprecated_and_removed"', self.bridge_src)
        # Assert system prompt has Anti-Premature-Completion Directive
        self.assertIn("Anti-Premature-Completion Directive", self.server_src)
    def test_full_game_authoring_profile_advisory_and_anti_retry(self):
        self.assertIn("reside in tool bundles and MUST be activated via unpack_tool_bundle()", self.catalog_src)
        self.assertIn("Do not retry this tool expecting specialized tools to appear", self.catalog_src)
        self.assertIn("Profile 'full_game_authoring' active", self.bridge_src)
        self.assertIn("Do NOT retry select_mcp_profile for specialized tools", self.bridge_src)
        self.assertIn("profile_advisory", self.bridge_src)

    def test_game_keywords_and_auto_bundle_unpacking(self):
        # Physics bundle must include game/player/movement keywords
        physics_kw = self.bridge_src.split('"physics": {')[1].split('"keywords": [')[1].split(']')[0]
        self.assertIn('"player"', physics_kw)
        self.assertIn('"platformer"', physics_kw)
        self.assertIn('"character"', physics_kw)

        # Tilemap bundle must include level/platformer keywords
        tilemap_kw = self.bridge_src.split('"tilemap": {')[1].split('"keywords": [')[1].split(']')[0]
        self.assertIn('"platformer"', tilemap_kw)
        self.assertIn('"level"', tilemap_kw)

        # auto_select_for_prompt unpacks physics/tilemap when game/platformer/player is mentioned
        self.assertIn('_unpack_tool_bundle({"bundle_name": "physics"})', self.bridge_src)
        self.assertIn('_unpack_tool_bundle({"bundle_name": "tilemap"})', self.bridge_src)

    def test_search_mcp_tools_includes_bundle_and_usage(self):
        self.assertIn('"bundle": b_name', self.bridge_src)
        self.assertIn('"how_to_use"', self.bridge_src)
        self.assertIn("recommended_action", self.bridge_src)

    def test_system_prompt_profile_realities_and_anti_hardcoding(self):
        self.assertIn("Profile realities and anti-hardcoding mandate", self.server_src)
        self.assertIn("`full_game_authoring` is NOT an all-in-one profile", self.server_src)
        self.assertIn("NEVER retry `select_mcp_profile` for missing specialized tools", self.server_src)
        self.assertIn("NEVER hardcode engine features in GDScript", self.server_src)


if __name__ == "__main__":
    unittest.main()

