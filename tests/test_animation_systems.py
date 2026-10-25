"""Unit and integration tests for GodotAgent Animation Systems (AnimationPlayer and AnimationTree)."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class AnimationSystemsTests(unittest.TestCase):
    def setUp(self):
        self.bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8") + "\n" + (ADDON / "tools" / "agent_animation_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")

    # --------------------------------------------------------------------------
    # 1. Tool Registration in Catalog, Bridge, and Local Tools
    # --------------------------------------------------------------------------
    def test_local_tool_names_contain_all_ten_animation_tools(self):
        expected_tools = [
            "inspect_animation_player",
            "inspect_animation_tracks",
            "edit_animation_player",
            "inspect_animation_tree",
            "edit_animation_tree",
            "edit_animation_state_machine",
            "edit_animation_blend_space",
            "get_set_animation_parameters",
            "validate_animation_system",
            "test_animation_runtime",
        ]
        for tool_name in expected_tools:
            self.assertIn(f'"{tool_name}"', self.local_src, f"Missing {tool_name} in agent_local_tools.gd LOCAL_NAMES")
            self.assertIn(f'"{tool_name}"', self.bridge_src, f"Missing {tool_name} in agent_tools_bridge.gd LOCAL_TOOL_NAMES")
            self.assertIn(f'"{tool_name}":', self.catalog_src, f"Missing {tool_name} schema in agent_tool_catalog.gd")

    def test_has_tool_and_invoke_route_animation_tools(self):
        for tool_name in [
            "inspect_animation_player",
            "inspect_animation_tracks",
            "edit_animation_player",
            "inspect_animation_tree",
            "edit_animation_tree",
            "edit_animation_state_machine",
            "edit_animation_blend_space",
            "get_set_animation_parameters",
            "validate_animation_system",
            "test_animation_runtime",
        ]:
            self.assertIn(f'"{tool_name}"', self.local_src)
            self.assertIn(f"func _{tool_name}(", self.local_src, f"Missing handler func _{tool_name} in agent_local_tools.gd")

    # --------------------------------------------------------------------------
    # 2. Animation System Helpers
    # --------------------------------------------------------------------------
    def test_animation_helpers_present(self):
        helpers = [
            "func _parse_loop_mode",
            "func _loop_mode_to_string",
            "func _track_type_to_string",
            "func _track_string_to_type",
            "func _interpolation_type_to_string",
            "func _interpolation_string_to_type",
            "func _update_mode_to_string",
            "func _update_string_to_mode",
            "func _resolve_animation_player",
            "func _resolve_animation_tree",
            "func _split_animation_name",
        ]
        for helper in helpers:
            self.assertIn(helper, self.local_src)

    # --------------------------------------------------------------------------
    # 3. Standardized Mutation Contracts for Animation Editors
    # --------------------------------------------------------------------------
    def test_edit_animation_player_uses_mutation_envelope(self):
        self.assertIn('"edit_animation_player"', self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"edit_animation_player"', self.local_src)

    def test_edit_animation_tree_uses_mutation_envelope(self):
        self.assertIn('"edit_animation_tree"', self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"edit_animation_tree"', self.local_src)

    def test_edit_animation_state_machine_uses_mutation_envelope(self):
        self.assertIn('"edit_animation_state_machine"', self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"edit_animation_state_machine"', self.local_src)

    def test_edit_animation_blend_space_uses_mutation_envelope(self):
        self.assertIn('"edit_animation_blend_space"', self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"edit_animation_blend_space"', self.local_src)

    # --------------------------------------------------------------------------
    # 4. Capabilities Discovery Manifest
    # --------------------------------------------------------------------------
    def test_discover_capabilities_includes_animation_systems(self):
        self.assertIn('"animation_systems": {', self.local_src)
        self.assertIn('"animation_player_present": has_player', self.local_src)
        self.assertIn('"animation_tree_present": has_tree', self.local_src)

    # --------------------------------------------------------------------------
    # 5. Verification Tools Implementation
    # --------------------------------------------------------------------------
    def test_validate_animation_system_performs_player_and_tree_checks(self):
        self.assertIn("func _validate_animation_system(", self.local_src)
        self.assertIn("empty_anims", self.local_src)
        self.assertIn("broken_tracks", self.local_src)
        self.assertIn("missing_anims", self.local_src)
        self.assertIn("unreachable_states", self.local_src)

    def test_test_animation_runtime_handles_player_and_tree(self):
        self.assertIn("func _test_animation_runtime(", self.local_src)
        self.assertIn("player.play(target_name)", self.local_src)
        self.assertIn('call("travel", target_name)', self.local_src)
        self.assertIn('"observed_condition": observed_cond', self.local_src)

    # --------------------------------------------------------------------------
    # 6. Prompt Integration in agent_server.gd
    # --------------------------------------------------------------------------
    def test_agent_server_prompt_contains_animation_systems_section(self):
        self.assertIn("<animation_systems>", self.server_src)
        self.assertIn("## AnimationPlayer and AnimationTree Development", self.server_src)
        self.assertIn("### 1. Core Responsibility", self.server_src)
        self.assertIn("### 2. Mandatory Initial Planning", self.server_src)
        self.assertIn("### 3. Tool Discovery and Usage", self.server_src)
        self.assertIn("### 4. AnimationPlayer Authoring", self.server_src)
        self.assertIn("### 5. AnimationTree Authoring", self.server_src)
        self.assertIn("### 6. Playback Control and Parameters", self.server_src)
        self.assertIn("### 7. Mandatory Execution Cycle", self.server_src)
        self.assertIn("### 8. Verification Requirements", self.server_src)
        self.assertIn("### 9. Persistence and Resource Safety", self.server_src)
        self.assertIn("### 10. Failure Handling", self.server_src)
        self.assertIn("### 11. Completion Criteria", self.server_src)
        self.assertIn("</animation_systems>", self.server_src)


if __name__ == "__main__":
    unittest.main()
