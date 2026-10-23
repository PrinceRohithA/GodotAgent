"""Unit tests for Deletion Freedom, Pragmatic Security, and Unhindered Node/File Cleanup."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"


class DeletionFreedomAndPragmaticSecurityTests(unittest.TestCase):
    def setUp(self):
        self.local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.catalog_src = (AGENT_ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")

    def test_local_tools_node_deletion_has_no_confirmation_gate(self):
        # In edit_node ("delete"), node deletion must proceed directly with history recording
        # and not block on _confirmation
        idx = self.local_tools_src.find('"delete":')
        self.assertNotEqual(idx, -1)
        delete_block = self.local_tools_src[idx:idx + 800]
        self.assertNotIn('_confirmation("delete_node', delete_block)
        self.assertNotIn('return node_approval', delete_block)
        self.assertIn("parent.remove_child(node)", delete_block)
        self.assertIn('history.record("Delete "', delete_block)

    def test_local_tools_strict_confirmation_flag_and_pragmatic_defaults(self):
        self.assertIn("var strict_confirmation := false", self.local_tools_src)
        self.assertIn("if not strict_confirmation or bool(args.get(\"force\", false))", self.local_tools_src)
        self.assertIn('return {"approved": true}', self.local_tools_src)

    def test_catalog_delete_file_schema_unhindered(self):
        idx = self.catalog_src.find('"delete_file":')
        self.assertNotEqual(idx, -1)
        schema_chunk = self.catalog_src[idx:idx + 700]
        self.assertIn('"required": ["path"]', schema_chunk)
        self.assertNotIn('"required": ["path", "confirmation_token"]', schema_chunk)
        self.assertIn("Move a project file to the agent trash for safe, recoverable deletion.", schema_chunk)

    def test_catalog_run_shell_schema_unhindered(self):
        idx = self.catalog_src.find('"run_shell":')
        self.assertNotEqual(idx, -1)
        schema_chunk = self.catalog_src[idx:idx + 700]
        self.assertIn('"required": ["command"]', schema_chunk)
        self.assertNotIn('"required": ["command", "confirmation_token"]', schema_chunk)
        self.assertIn("Run a PowerShell command in the project directory.", schema_chunk)

    def test_server_prompt_mandates_deletion_freedom_and_pragmatic_security(self):
        self.assertIn("## 11. Security, Pragmatic Autonomy, and Deletion Freedom", self.server_src)
        self.assertIn("DO NOT HESITATE to delete nodes!", self.server_src)
        self.assertIn("Safe, Recoverable File Deletion (`delete_file`)", self.server_src)
        self.assertIn("Sensible Security Without Over-Enforcement", self.server_src)
        self.assertIn("Do NOT stop or interrupt the user with \"Are you sure?\"", self.server_src)


if __name__ == "__main__":
    unittest.main()
