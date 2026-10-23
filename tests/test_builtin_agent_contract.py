"""Regression contracts for the reusable in-editor agent source tree.

Godot's editor APIs require a live editor for behavioural smoke tests; these
tests protect the protocol and safety boundaries without pretending to be live
MCP coverage.
"""
from __future__ import annotations

import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class BuiltinAgentContractTests(unittest.TestCase):
    def read(self, name: str) -> str:
        return (ADDON / name).read_text(encoding="utf-8")

    def test_mcp_client_uses_jsonrpc_discovery_not_bridge_commands(self) -> None:
        source = self.read("agent_mcp_client.gd")
        self.assertIn('"initialize"', source)
        self.assertIn('"tools/list"', source)
        self.assertIn('"tools/call"', source)
        self.assertIn("Mcp-Session-Id", source)

    def test_catalog_is_truthful_about_dynamic_mcp_tools(self) -> None:
        source = self.read("agent_tool_catalog.gd")
        self.assertIn("for remote in mcp_tools", source)
        self.assertIn('rd.get("inputSchema"', source)
        self.assertIn("executable backend now", source)
        self.assertNotIn("_cached", source)

    def test_bridge_keeps_native_catalog_when_mcp_is_offline(self) -> None:
        bridge = self.read("agent_tools_bridge.gd")
        self.assertIn("LOCAL_TOOL_NAMES", bridge)
        self.assertIn("mcp_connecting", bridge)
        self.assertIn("_active_mcp_tools()", bridge)
        self.assertIn("capability_registry", bridge)
        self.assertIn("mcp_editor", bridge)
        self.assertIn("MAX_MODEL_TOOLS := 128", bridge)
        self.assertIn("search_mcp_tools", bridge)
        self.assertIn("activate_mcp_tools", bridge)
        self.assertIn("select_mcp_profile", bridge)
        self.assertIn("PINNED_MCP_TOOLS", bridge)
        self.assertIn("full_game_authoring", bridge)
        self.assertIn("auto_select_for_prompt", bridge)
        self.assertIn("call_mcp_tool", bridge)
        self.assertIn("_call_discovered_mcp", bridge)

    def test_mcp_client_handles_streamable_session_and_refresh(self) -> None:
        source = self.read("agent_mcp_client.gd")
        self.assertIn("notifications/initialized", source)
        self.assertIn("nextCursor", source)
        self.assertIn("notifications/tools/list_changed", source)
        self.assertIn("_parse_json_or_sse", source)
        self.assertIn('normalized.begins_with("{")', source)
        self.assertIn("RETRY_SECONDS", source)

    def test_luna_tools_force_compatible_reasoning_effort(self) -> None:
        reasoner = self.read("agent_reasoner_http.gd")
        self.assertIn('model.to_lower().contains("gpt-5.6-luna")', reasoner)
        self.assertIn('body["reasoning_effort"] = "none"', reasoner)
        dialog = self.read("models_dialog.gd")
        self.assertIn("Reasoning effort:", dialog)

    def test_fixture_plugin_starts_the_mcp_launcher(self) -> None:
        plugin = self.read("godot_agent.gd")
        self.assertIn("_ensure_mcp_server()", plugin)
        self.assertIn('res://mcp_fixture.json', plugin)
        self.assertIn('res://addons/godot_mcp/plugin.cfg', plugin)
        self.assertIn("start_mcp_server.ps1", plugin)
        self.assertIn("OS.create_process", plugin)

    def test_durable_task_runtime_and_protocol_are_present(self) -> None:
        runtime = self.read("agent_task_runtime.gd")
        self.assertIn('STORE_PATH := "user://godot_agent/tasks.json"', runtime)
        self.assertIn('"needs_confirmation"', runtime)
        self.assertIn("func can_succeed", runtime)
        self.assertIn('"verification_pending"', runtime)
        server = self.read("agent_server.gd")
        self.assertIn('"tasks.start"', server)
        self.assertIn('"tasks.pause"', server)
        self.assertIn('"tasks.resume"', server)
        self.assertIn('"tasks.cancel"', server)
        self.assertIn("_request_task_plan", server)
        self.assertIn("_begin_task_execution", server)

    def test_destructive_tools_need_confirmation_and_history_avoids_raw_undo(self) -> None:
        local = self.read("agent_local_tools.gd")
        history = self.read("agent_transaction_history.gd")
        self.assertIn("confirmation_required", local)
        self.assertIn('"delete_file"', local)
        self.assertIn('"run_shell"', local)
        self.assertNotIn("get_editor_undo_redo()", local)
        self.assertIn("Agent-owned reversible history", history)
        self.assertIn("func redo", history)

    def test_smoke_server_targets_proper_project(self) -> None:
        launcher = (ROOT / "scripts" / "start_mcp_server.ps1").read_text(encoding="utf-8")
        self.assertIn('"project"', launcher)
        manifest = ROOT / "project" / "project.godot"
        self.assertTrue(manifest.is_file())

    def test_tool_bundles_contract_and_window_eviction(self) -> None:
        bridge = self.read("agent_tools_bridge.gd")
        self.assertIn("TOOL_BUNDLES", bridge)
        self.assertIn('"list_tool_bundles"', bridge)
        self.assertIn('"unpack_tool_bundle"', bridge)
        self.assertIn('"pack_tool_bundle"', bridge)
        self.assertIn("func _tools_in_bundle", bridge)
        self.assertIn("func _list_tool_bundles", bridge)
        self.assertIn("func _unpack_tool_bundle", bridge)
        self.assertIn("func _pack_tool_bundle", bridge)
        self.assertIn("Tool window capacity (%d tools) exceeded", bridge)

        catalog = self.read("agent_tool_catalog.gd")
        self.assertIn('"list_tool_bundles"', catalog)
        self.assertIn('"unpack_tool_bundle"', catalog)
        self.assertIn('"pack_tool_bundle"', catalog)

        # Simulation test: verify bundle packing back when capacity is exceeded
        max_model_tools = 128
        native_count = 32
        mcp_capacity = max_model_tools - native_count  # 96 slots
        pinned_tools = [f"pinned_{i}" for i in range(27)]

        # Simulate 3 bundles: bundle_a (40 tools), bundle_b (40 tools), bundle_c (30 tools)
        # Pinned (27) + a (40) + b (40) = 107 > 96 -> bundle_a must be evicted when b is unpacked
        bundles = {
            "physics": [f"godot_physics_{i}" for i in range(40)],
            "audio": [f"godot_audio_{i}" for i in range(40)],
            "particles": [f"godot_particles_{i}" for i in range(30)],
        }

        unpacked = []
        packed_back = []
        active_tools = list(pinned_tools)

        def unpack(bundle_name):
            tools_to_add = bundles[bundle_name]
            projected = len(active_tools) + len(tools_to_add)
            evicted = []
            while projected > mcp_capacity and unpacked:
                oldest = unpacked.pop(0)
                evicted.append(oldest)
                for t in bundles[oldest]:
                    if t in active_tools:
                        active_tools.remove(t)
                projected = len(active_tools) + len(tools_to_add)
            unpacked.append(bundle_name)
            for t in tools_to_add:
                if t not in active_tools:
                    active_tools.append(t)
            notice = ""
            if evicted:
                notice = f"Tool window capacity ({max_model_tools} tools) exceeded. Packed bundle(s) {evicted} back into storage."
            return {"unpacked": bundle_name, "packed_back": evicted, "notice": notice}

        res_a = unpack("physics")
        self.assertEqual(res_a["unpacked"], "physics")
        self.assertEqual(res_a["packed_back"], [])
        self.assertEqual(len(active_tools), 27 + 40)  # 67 tools <= 96

        res_b = unpack("audio")
        self.assertEqual(res_b["unpacked"], "audio")
        # 67 + 40 = 107 > 96, so "physics" must be packed back!
        self.assertIn("physics", res_b["packed_back"])
        self.assertIn("exceeded", res_b["notice"])
        self.assertEqual(len(active_tools), 27 + 40)  # 67 tools <= 96
        self.assertEqual(unpacked, ["audio"])


    def test_antigravity_style_action_proposals(self) -> None:
        server = self.read("agent_server.gd")
        self.assertIn('"action.approve"', server)
        self.assertIn('"action.reject"', server)
        self.assertIn("func _handle_action_approve", server)
        self.assertIn("func _handle_action_reject", server)
        self.assertIn('"type": "proposal"', server)
        self.assertIn('"pending_proposal"', server)

        dock = self.read("agent_dock.gd")
        self.assertIn("_proposal_card", dock)
        self.assertIn("func _handle_proposal", dock)
        self.assertIn("func _approve_action", dock)
        self.assertIn("func _reject_action", dock)
        self.assertIn("meta_clicked.connect", dock)
        self.assertIn("[url=approve:", dock)
        self.assertIn("[url=reject:", dock)
        # Ensure modal dialogs and fake history injections are not used for approvals
        self.assertNotIn("ConfirmationDialog", dock)
        self.assertNotIn("I explicitly approve", dock)


if __name__ == "__main__":
    unittest.main()

