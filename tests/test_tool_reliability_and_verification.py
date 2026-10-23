"""Unit and integration tests for GodotAgent Tool Reliability and Verification Infrastructure."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class ToolReliabilityAndVerificationTests(unittest.TestCase):
    def setUp(self):
        self.bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.task_src = (ADDON / "agent_task_runtime.gd").read_text(encoding="utf-8")

    # --------------------------------------------------------------------------
    # 1. Standardized Mutation Contract
    # --------------------------------------------------------------------------
    def test_mutation_result_contract_helper_exists(self):
        self.assertIn("func _build_mutation_result", self.local_src)
        for field in [
            '"ok": ok',
            '"status": status',
            '"operation": operation',
            '"requested": requested',
            '"applied": applied',
            '"readback": readback',
            '"changed_paths": changed_paths',
            '"warnings": warnings',
            '"errors": errors',
            '"persistence_verified": persistence_verified',
            '"postconditions_verified":',
            '"rollback_available": rollback_available',
            '"rollback_status": rollback_status',
            '"source": "local"',
        ]:
            self.assertIn(field, self.local_src)

    def test_create_node_returns_standardized_mutation_result_and_detects_renames(self):
        self.assertIn("func _create_node(", self.local_src)
        self.assertIn("_build_mutation_result", self.local_src)
        # Automatic renaming detection
        self.assertIn("Automatic renaming occurred: requested name '%s' was renamed to '%s'", self.local_src)
        self.assertIn('"requested_name": requested_name', self.local_src)
        self.assertIn('_readback_node_state(root, n)', self.local_src)

    def test_set_property_returns_standardized_mutation_result_and_readback(self):
        self.assertIn("func _set_property(", self.local_src)
        self.assertIn('applied[prop] = _jsonish(new_value)', self.local_src)
        self.assertIn('readback[prop] = _jsonish(post_val)', self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"set_property"', self.local_src)

    def test_create_node_hierarchy_builds_tree_diff_and_checks_validation(self):
        self.assertIn("func _create_node_hierarchy(", self.local_src)
        self.assertIn("var before_snap := _snapshot_scene_tree(root)", self.local_src)
        self.assertIn("var after_snap := _snapshot_scene_tree(root)", self.local_src)
        self.assertIn("var tree_diff := _diff_scene_trees(before_snap, after_snap)", self.local_src)
        self.assertIn('"tree_diff": tree_diff', self.local_src)
        self.assertIn('status = "partially_applied"', self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"create_node_hierarchy"', self.local_src)

    def test_attach_script_verifies_attachment(self):
        self.assertIn("func _attach_script(", self.local_src)
        self.assertIn("var readback_path := (actual_scr as Resource).resource_path", self.local_src)
        self.assertIn('var ok := readback_path == script_path', self.local_src)
        self.assertIn('_build_mutation_result("attach_script"', self.local_src)

    def test_save_scene_verifies_disk_persistence(self):
        self.assertIn("func _save_scene()", self.local_src)
        self.assertIn("var file_exists := false", self.local_src)
        self.assertIn("FileAccess.file_exists(scn_path)", self.local_src)
        self.assertIn('var status := "persisted"', self.local_src)
        self.assertIn('_build_mutation_result("save_scene"', self.local_src)

    def test_delete_nodes_returns_standardized_result(self):
        self.assertIn("func _delete_nodes(", self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"delete_nodes"', self.local_src)
        self.assertIn('"deleted_count": deleted.size()', self.local_src)

    def test_paint_tilemap_tools_return_standardized_results(self):
        self.assertIn("func _paint_tilemap_cells(", self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"paint_tilemap_cells"', self.local_src)
        self.assertIn("func _paint_tilemap_rect(", self.local_src)
        self.assertIn('_build_mutation_result(\n\t\t"paint_tilemap_rect"', self.local_src)

    # --------------------------------------------------------------------------
    # 2. Scene Hierarchy Consistency & Scene Diff
    # --------------------------------------------------------------------------
    def test_scene_snapshot_and_diff_helpers(self):
        self.assertIn("func _snapshot_scene_tree", self.local_src)
        self.assertIn("func _diff_scene_trees", self.local_src)
        self.assertIn("func _inspect_scene_diff", self.local_src)
        self.assertIn('"inspect_scene_diff"', self.local_src)
        self.assertIn('"inspect_scene_diff"', self.bridge_src)
        self.assertIn('"inspect_scene_diff":', self.catalog_src)

    # --------------------------------------------------------------------------
    # 3. Acceptance Criteria Ledger & Completion Gate
    # --------------------------------------------------------------------------
    def test_task_runtime_has_criteria_ledger(self):
        self.assertIn('"criteria": [],', self.task_src)
        self.assertIn("func set_criteria", self.task_src)
        self.assertIn("func update_criterion", self.task_src)
        self.assertIn("func get_criteria", self.task_src)
        self.assertIn("func get_unverified_criteria", self.task_src)

    def test_task_runtime_can_succeed_requires_verification_cleared(self):
        self.assertIn("func can_succeed(id: String) -> bool:", self.task_src)
        self.assertIn('return not bool(task.get("verification_pending", false))', self.task_src)

    def test_agent_server_completion_gate_checks_unverified_criteria(self):
        self.assertIn('task_runtime.can_succeed(task_id)', self.server_src)
        self.assertIn('task_runtime.get_unverified_criteria(task_id)', self.server_src)
        self.assertIn("Task completion blocked: unverified acceptance criteria remain", self.server_src)

    def test_verify_criterion_tool_removed_and_criteria_management(self):
        # set_task_criteria remains for up-front criteria planning
        self.assertIn('"set_task_criteria"', self.local_src)
        self.assertIn('"set_task_criteria"', self.bridge_src)
        self.assertIn('"set_task_criteria":', self.catalog_src)

        # verify_criterion tool is removed to prevent repetitive artificial verification loops
        self.assertNotIn('"verify_criterion"', self.local_src)
        self.assertNotIn('"verify_criterion"', self.bridge_src)
        self.assertNotIn('"verify_criterion":', self.catalog_src)

    def test_in_place_file_editing_mandate_in_system_prompt(self):
        self.assertIn("In-Place File Editing Mandate (Zero Recreation / Zero Duplication)", self.server_src)
        self.assertIn("Inspect Current Implementation", self.server_src)
        self.assertIn("zero file duplication", self.server_src)
        self.assertIn("Mandatory Pre-Action Analysis & In-Place Editing Protocol", self.server_src)

    def test_level_designer_in_place_editing_directive(self):
        self.assertIn("IN-PLACE EDITING & ZERO DUPLICATION", self.local_src)

    def test_test_runtime_action_informs_about_editor_vs_runtime(self):
        self.assertIn("In-editor scene nodes do not step game physics during editor execution", self.local_src)

    # --------------------------------------------------------------------------
    # 4. First-Class TileSet Physics Validation
    # --------------------------------------------------------------------------
    def test_validate_tileset_physics_tool_registered_and_checks_collision_chain(self):
        self.assertIn('"validate_tileset_physics"', self.local_src)
        self.assertIn('"validate_tileset_physics"', self.bridge_src)
        self.assertIn('"validate_tileset_physics":', self.catalog_src)
        self.assertIn("func _validate_tileset_physics", self.local_src)

        # Asserts checking the 7-step collision chain
        self.assertIn("get_physics_layers_count", self.local_src)
        self.assertIn("get_cell_tile_data", self.local_src)
        self.assertIn("get_collision_polygons_count", self.local_src)
        self.assertIn("get_collision_polygon_points", self.local_src)
        self.assertIn("collision_enabled", self.local_src)
        self.assertIn("collision_mask", self.local_src)
        self.assertIn('"tileset_physics_layer_exists":', self.local_src)
        self.assertIn('"required_tiles_inspected":', self.local_src)
        self.assertIn('"tiles_with_collision":', self.local_src)
        self.assertIn('"tiles_without_collision":', self.local_src)
        self.assertIn('"collision_geometry_valid":', self.local_src)
        self.assertIn('"layer_and_mask_configuration_valid":', self.local_src)
        self.assertIn('"runtime_player_collision_verified":', self.local_src)
        self.assertIn('"unverified_criteria":', self.local_src)

    # --------------------------------------------------------------------------
    # 5. Runtime Input Simulation & Capability Discovery
    # --------------------------------------------------------------------------
    def test_test_runtime_action_tool_registered_and_safe_cleanup(self):
        self.assertIn('"test_runtime_action"', self.local_src)
        self.assertIn('"test_runtime_action"', self.bridge_src)
        self.assertIn('"test_runtime_action":', self.catalog_src)
        self.assertIn("func _test_runtime_action", self.local_src)
        self.assertIn("InputMap.has_action(action)", self.local_src)
        self.assertIn("Input.action_press(action", self.local_src)
        self.assertIn("Input.action_release(action)", self.local_src)
        self.assertIn('"player_position_before":', self.local_src)
        self.assertIn('"player_position_after":', self.local_src)
        self.assertIn('"velocity_before":', self.local_src)
        self.assertIn('"velocity_after":', self.local_src)
        self.assertIn('"expected_condition":', self.local_src)
        self.assertIn('"observed_condition":', self.local_src)

    def test_discover_capabilities_tool_registered_and_reports_manifest(self):
        self.assertIn('"discover_capabilities"', self.local_src)
        self.assertIn('"discover_capabilities"', self.bridge_src)
        self.assertIn('"discover_capabilities":', self.catalog_src)
        self.assertIn("func _discover_capabilities", self.local_src)
        self.assertIn('"scene_mutation":', self.local_src)
        self.assertIn('"tilemap_physics":', self.local_src)
        self.assertIn('"runtime_input":', self.local_src)
        self.assertIn('"visual_inspection":', self.local_src)

    def test_capture_viewport_reports_metadata_and_verification_status(self):
        self.assertIn("visual_verification_status", self.local_src)
        self.assertIn("image_captured_pending_inspection", self.local_src)
        self.assertIn("active_scene", self.local_src)
        self.assertIn("camera", self.local_src)

    # --------------------------------------------------------------------------
    # 6. Tool Window Ceiling & Catalog Consistency
    # --------------------------------------------------------------------------
    def test_local_tool_names_match_catalog_schemas(self):
        # Extract LOCAL_TOOL_NAMES from bridge
        match = re.search(r"const LOCAL_TOOL_NAMES := \[(.*?)\]", self.bridge_src, re.DOTALL)
        self.assertIsNotNone(match)
        tool_names = re.findall(r'"([a-zA-Z0-9_]+)"', match.group(1))

        # Check each local tool has an entry in agent_tool_catalog _meta()
        cat_match = re.search(r"func _meta\(\) -> Dictionary:.*?return \{(.*?)\n\t\}", self.catalog_src, re.DOTALL)
        self.assertIsNotNone(cat_match)
        catalog_names = re.findall(r'"([a-zA-Z0-9_]+)":\s*\{', cat_match.group(1))

        for name in tool_names:
            self.assertIn(
                name,
                catalog_names,
                f"Local tool '{name}' registered in LOCAL_TOOL_NAMES has no schema in agent_tool_catalog.gd _meta()"
            )

    def test_tool_window_ceiling_is_respected(self):
        # Window ceiling is 128
        self.assertIn("const MAX_MODEL_TOOLS := 128", self.bridge_src)
        match = re.search(r"const LOCAL_TOOL_NAMES := \[(.*?)\]", self.bridge_src, re.DOTALL)
        tool_names = re.findall(r'"([a-zA-Z0-9_]+)"', match.group(1))
        # Total local tools should not exceed 85, leaving abundant room for dynamic MCP bundles
        self.assertLessEqual(len(tool_names), 85, f"Too many local tools ({len(tool_names)}), exceeding bundle headroom.")

    def test_task_runtime_budget_tracks_active_seconds_and_disables_time_cutoff(self):
        self.assertIn('"active_seconds": 0.0, "session_started_at": 0.0', self.task_src)
        self.assertIn('active_sec += maxf(0.0, now - session_start)', self.task_src)
        self.assertIn('Time budget completely disabled', self.task_src)

    def test_agent_server_resumes_budget_exhausted_task(self):
        self.assertIn('if str(task.get("status", "")) in ["succeeded", "cancelled"]:', self.server_src)
        self.assertIn('friendly_msg = "Task paused: active execution time limit reached', self.server_src)

    def test_navigate_viewport_registered_in_tools_bridge_and_catalog(self):
        self.assertIn('"navigate_viewport"', self.local_src)
        self.assertIn('"navigate_viewport"', self.bridge_src)
        self.assertIn('"navigate_viewport":', self.catalog_src)
        self.assertIn('"pan_viewport"', self.bridge_src)
        self.assertIn('"zoom_viewport"', self.bridge_src)


if __name__ == "__main__":
    unittest.main()
