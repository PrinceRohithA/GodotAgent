"""Unit tests for Input Action configuration, Level Designer Subagent Core Flow & Handover, and <think> reasoning display."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"
MCP_ADDON = ROOT / "project" / "addons" / "godot_mcp"


class InputActionAndLevelSubagentHandoverTests(unittest.TestCase):
    def setUp(self):
        self.local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (AGENT_ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.bridge_src = (AGENT_ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.mapping_src = (AGENT_ADDON / "mcp_mapping.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.dock_src = (AGENT_ADDON / "agent_dock.gd").read_text(encoding="utf-8")
        self.reasoner_src = (AGENT_ADDON / "agent_reasoner_http.gd").read_text(encoding="utf-8")
        self.mcp_input_src = (MCP_ADDON / "handlers" / "input_map.gd").read_text(encoding="utf-8")
        self.skill_file = AGENT_ADDON / "skills" / "builtin" / "level_designer.md"
        self.subagent_file = ROOT / ".agents" / "agents" / "level-designer" / "agent.md"

    def test_configure_input_action_in_local_tools(self):
        self.assertIn('"configure_input_action"', self.local_tools_src)
        self.assertIn('"add_input_action", "input_map_add_action", "set_input_action"', self.local_tools_src)
        self.assertIn("func _configure_input_action", self.local_tools_src)
        self.assertIn("ProjectSettings.save()", self.local_tools_src)
        self.assertIn("InputMap.load_from_project_settings()", self.local_tools_src)
        self.assertIn("InputMap.add_action", self.local_tools_src)
        self.assertIn("InputMap.action_add_event", self.local_tools_src)

    def test_settings_set_saves_project_settings_and_syncs_input(self):
        self.assertIn('ProjectSettings.save()', self.local_tools_src)
        self.assertIn('if key.begins_with("input/"):', self.local_tools_src)
        self.assertIn('_ensure_input_action_registered(act, false)', self.local_tools_src)

    def test_mcp_input_map_handler_updates_existing_and_detects_keys(self):
        self.assertIn("ProjectSettings.save()", self.mcp_input_src)
        self.assertIn("InputMap.add_action(action_name, deadzone)", self.mcp_input_src)
        self.assertIn('if event_type.is_empty():', self.mcp_input_src)
        self.assertIn("OS.find_keycode_from_string(code_str)", self.mcp_input_src)

    def test_input_tool_catalog_and_bridge_registration(self):
        self.assertIn('"configure_input_action":', self.catalog_src)
        self.assertIn('"configure_input_action"', self.bridge_src)
        self.assertIn('"configure_input_action": {"mcp_tools":', self.mapping_src)

    def test_section_4_3_mandates_think_enclosure(self):
        self.assertIn('### 4.3 Cognitive Reasoning Protocol ("Think Before You Act") & Mandatory <think> Enclosure', self.server_src)
        self.assertIn("<think>", self.server_src)
        self.assertIn("</think>", self.server_src)
        self.assertIn("Observation & Evidence", self.server_src)
        self.assertIn("Hypothesis & Intent", self.server_src)
        self.assertIn("Dependency & Impact Audit", self.server_src)
        self.assertIn("Risk & Fallback", self.server_src)
        self.assertIn("Verification Requirement", self.server_src)
        self.assertIn("Thinking:", self.server_src)

    def test_section_10_13_main_agent_delegation_and_handover(self):
        self.assertIn("### 10.13 Main Agent Delegation to Level Designer Subagent and Handover Protocol", self.server_src)
        self.assertIn("Mandatory Delegation When Level Design Work is Required", self.server_src)
        self.assertIn("Subagent Execution Following the Core Flow", self.server_src)
        self.assertIn("Step 1: Inspect", self.server_src)
        self.assertIn("Step 2: Orient & Plan", self.server_src)
        self.assertIn("Step 3: Mutate", self.server_src)
        self.assertIn("Step 4: Verify", self.server_src)
        self.assertIn("Step 5: Handover Report", self.server_src)
        self.assertIn("Structured Handover Report Format", self.server_src)
        self.assertIn("Main Agent Seamless Continuation", self.server_src)

    def test_dock_renders_think_block(self):
        self.assertIn('Thinking:', self.dock_src)
        self.assertIn('replace("<think>", "").replace("</think>", "")', self.dock_src)

    def test_reasoner_extracts_think_tags(self):
        self.assertIn('var think_start := raw_content.find("<think>")', self.reasoner_src)
        self.assertIn('var think_end := raw_content.find("</think>", think_start + 7)', self.reasoner_src)

    def test_level_designer_skill_and_agent_files_exist_and_specify_handover(self):
        self.assertTrue(self.skill_file.exists())
        skill_text = self.skill_file.read_text(encoding="utf-8")
        self.assertIn("auto_generate_atlas_tiles", skill_text)
        self.assertIn("paint_tilemap_rect", skill_text)
        self.assertIn("instance_scene", skill_text)
        self.assertIn("Handover Report", skill_text)
        self.assertIn("Core Flow", skill_text)
        self.assertIn("Picture the Entire Level First", skill_text)
        self.assertIn("Pan, Zoom, and Defect Resolution Loop", skill_text)
        self.assertIn("navigate_viewport", skill_text)

        if self.subagent_file.exists():
            subagent_text = self.subagent_file.read_text(encoding="utf-8")
            self.assertIn("auto_generate_atlas_tiles", subagent_text)
            self.assertIn("Handover Report", subagent_text)

    def test_navigate_viewport_tool_and_prompt_integration(self):
        self.assertIn('"navigate_viewport"', self.local_tools_src)
        self.assertIn('"pan_viewport"', self.bridge_src)
        self.assertIn('"zoom_viewport"', self.bridge_src)
        self.assertIn("func _navigate_viewport", self.local_tools_src)
        self.assertIn('"navigate_viewport":', self.catalog_src)
        self.assertIn('"navigate_viewport":', self.mapping_src)
        self.assertIn("navigate_viewport", self.server_src)

    def test_ui_differentiates_active_agents(self):
        self.assertIn('"agent_switch"', self.dock_src)
        self.assertIn("▶ Delegated to Level Designer Subagent", self.dock_src)
        self.assertIn("◀ Handover to Main Agent", self.dock_src)
        self.assertIn("Thinking: [Level Designer]", self.dock_src)
        self.assertIn("Thinking: [Main Agent]", self.dock_src)
        self.assertIn("[Level Designer]", self.dock_src)
        self.assertIn("[Main Agent]", self.dock_src)
        self.assertIn('"agent_switch"', self.server_src)
        self.assertIn('"LevelDesigner"', self.server_src)


if __name__ == "__main__":
    unittest.main()
