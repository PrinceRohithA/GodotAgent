"""Unit tests for Replacement, Refactoring, and Zero-Orphan Cleanup Protocol."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"


class ReplacementAndCleanupTests(unittest.TestCase):
    def setUp(self):
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")

    def test_server_prompt_contains_replacement_workflow_step(self):
        """Verifies Step 15 Replacement, Refactoring & Cleanup Mandate in Scene Construction Workflow."""
        self.assertIn("15. **Replacement, Refactoring & Cleanup Mandate**:", self.server_src)
        self.assertIn("NEVER treat it as additive-only", self.server_src)
        self.assertIn("delete_nodes(node_paths=[...])", self.server_src)

    def test_server_prompt_contains_replacement_protocol_section(self):
        """Verifies Section 10.11 exists with exact header and core problem description."""
        self.assertIn("### 10.11 Replacement, Refactoring, and Zero-Orphan Cleanup Protocol", self.server_src)
        self.assertIn("Duplicate Visual Nodes", self.server_src)
        self.assertIn("Duplicate Physics Bodies", self.server_src)
        self.assertIn("Name and Path Collisions", self.server_src)
        self.assertIn("Dangling Signals & Method Errors", self.server_src)
        self.assertIn("Dead Code and Duplicate Functions", self.server_src)

    def test_server_prompt_enforces_atomic_replacement_contract(self):
        """Verifies the Atomic Replacement Contract (Zero Ghost Nodes) mandate."""
        self.assertIn("1. **The Atomic Replacement Contract (Zero Ghost Nodes)**:", self.server_src)
        self.assertIn("A replacement operation is ONLY complete when the replacement is installed AND the replaced element is 100% removed", self.server_src)
        self.assertIn("A replacement is NEVER finished if the obsolete element remains disabled, hidden, renamed to `_Old`, or lingering in the tree", self.server_src)

    def test_server_prompt_node_replacement_procedure(self):
        """Verifies the 5-step node replacement recipe including reparenting and name preservation."""
        self.assertIn("2. **Step-by-Step Node Replacement Procedure**:", self.server_src)
        self.assertIn("Step 1: Inspect & Audit the Original", self.server_src)
        self.assertIn("Step 2: Child Preservation & Reparenting", self.server_src)
        self.assertIn("reparent_node(node_path=", self.server_src)
        self.assertIn("Step 3: Delete the Obsolete Node", self.server_src)
        self.assertIn('delete_nodes(node_paths=["OldNode"])', self.server_src)
        self.assertIn("Step 4: Create and Name the Replacement", self.server_src)
        self.assertIn("Name Preservation", self.server_src)
        self.assertIn("Step 5: Rewire Signal Connections", self.server_src)

    def test_server_prompt_script_and_logic_replacement_standards(self):
        """Verifies script pruning, single _process/_physics_process, and orphaned file cleanup."""
        self.assertIn("3. **Script and Logic Replacement Standards (Zero Dead Code)**:", self.server_src)
        self.assertIn("Prune, Do Not Just Append", self.server_src)
        self.assertIn("Unified `_process` and `_physics_process`", self.server_src)
        self.assertIn("Exported Property Cleanup", self.server_src)
        self.assertIn("Orphaned Script Files", self.server_src)

    def test_server_prompt_instance_swapping_in_levels(self):
        """Verifies level prefab instance swapping rules with bulk delete."""
        self.assertIn("4. **Scene Instance Swapping in Levels**:", self.server_src)
        self.assertIn("Call `delete_nodes(node_paths=[...])` passing all old instance root node paths in a single batch", self.server_src)

    def test_server_prompt_mandatory_absence_audit(self):
        """Verifies the absence verification mandate using inspect_scene and get_output_errors."""
        self.assertIn("5. **Mandatory Post-Replacement Absence Audit**:", self.server_src)
        self.assertIn("confirm that the old node path is absent from the node tree", self.server_src)
        self.assertIn("Call `get_output_errors()` to confirm there are no broken `get_node()` paths, invalid callables, or missing method warnings", self.server_src)

    def test_delete_nodes_includes_deleted_key_and_path_fallback(self):
        """Verifies that _delete_nodes in agent_local_tools.gd populates deleted key and path array."""
        self.assertIn('"deleted": node_path_rel', self.local_tools_src)
        self.assertIn('deleted_paths.append(str(d.get("deleted", d.get("node_path", ""))))', self.local_tools_src)


if __name__ == "__main__":
    unittest.main()
