"""Unit tests for Bulk Node Deletion and Explicit Instantiated Scene Identification."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"
MCP_ADDON = ROOT / "project" / "addons" / "godot_mcp"


class BulkDeleteAndInstanceTests(unittest.TestCase):
    def setUp(self):
        self.local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (AGENT_ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.bridge_src = (AGENT_ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.mapping_src = (AGENT_ADDON / "mcp_mapping.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.scene_inspect_src = (MCP_ADDON / "scene_inspect.gd").read_text(encoding="utf-8")

    def test_local_tools_registers_delete_nodes(self):
        self.assertIn('"delete_nodes"', self.local_tools_src)
        self.assertIn('"delete_nodes_batch"', self.local_tools_src)
        self.assertIn('"batch_delete_nodes"', self.local_tools_src)
        self.assertIn('"bulk_delete_nodes"', self.local_tools_src)
        self.assertIn("func _delete_nodes", self.local_tools_src)

    def test_local_tools_delete_nodes_implementation_contracts(self):
        self.assertIn("missing_node_paths", self.local_tools_src)
        self.assertIn("cannot_delete_scene_root", self.local_tools_src)
        self.assertIn("other.is_ancestor_of(node)", self.local_tools_src)
        self.assertIn("is_inst", self.local_tools_src)
        self.assertIn("instance_scene", self.local_tools_src)
        self.assertIn("is_instance_child", self.local_tools_src)
        self.assertIn('entry_data["instance_scene"] = inst_scene', self.local_tools_src)
        self.assertIn('"deleted_count": deleted.size()', self.local_tools_src)

    def test_local_tools_delete_node_single_reports_instance(self):
        self.assertIn('del_data["instance_scene"] = inst_scene', self.local_tools_src)
        self.assertIn('"is_instance": is_inst', self.local_tools_src)

    def test_local_tools_inspect_node_and_tree_explicitly_report_instances(self):
        self.assertIn('data["is_instance"] = true', self.local_tools_src)
        self.assertIn('data["instance_scene"] = node.scene_file_path', self.local_tools_src)
        self.assertIn('data["is_instance_child"] = true', self.local_tools_src)
        self.assertIn('d["is_instance"] = true', self.local_tools_src)
        self.assertIn('d["instance_scene"] = n.scene_file_path', self.local_tools_src)
        self.assertIn('d["is_instance_child"] = true', self.local_tools_src)

    def test_tool_catalog_defines_delete_nodes_schema(self):
        self.assertIn('"delete_nodes":', self.catalog_src)
        self.assertIn('"node_paths"', self.catalog_src)
        self.assertIn('"required": ["node_paths"]', self.catalog_src)

    def test_tools_bridge_pins_delete_nodes_and_aliases(self):
        self.assertIn('"delete_nodes"', self.bridge_src)
        self.assertIn('"delete_nodes_batch", "batch_delete_nodes", "bulk_delete_nodes":', self.bridge_src)
        self.assertIn('target_name = "delete_nodes"', self.bridge_src)

    def test_mcp_mapping_wires_delete_nodes(self):
        self.assertIn('"delete_nodes":', self.mapping_src)

    def test_scene_inspect_explicitly_reports_instance_scenes(self):
        self.assertIn('data["is_instance"] = true', self.scene_inspect_src)
        self.assertIn('data["instance_scene"] = node.scene_file_path', self.scene_inspect_src)
        self.assertIn('data["is_instance_child"] = true', self.scene_inspect_src)
        self.assertIn('info["is_instance"] = true', self.scene_inspect_src)
        self.assertIn('info["instance_scene"] = node.scene_file_path', self.scene_inspect_src)
        self.assertIn('info["is_instance_child"] = true', self.scene_inspect_src)

    def test_server_prompt_instructs_bulk_deletion_and_instance_handling(self):
        self.assertIn("Bulk Node Deletion", self.server_src)
        self.assertIn("delete_nodes(node_paths=", self.server_src)
        self.assertIn("Instantiated Scene Identification", self.server_src)
        self.assertIn('is_instance: true', self.server_src)
        self.assertIn('instance_scene:', self.server_src)
        self.assertIn('is_instance_child: true', self.server_src)
        self.assertIn("delete_nodes", self.server_src)


if __name__ == "__main__":
    unittest.main()
