"""Tests for Context Window Extraction, Model Planning, and Leaked System Prompts Architecture."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class ContextAndPromptsTests(unittest.TestCase):
    def setUp(self):
        self.config_src = (ADDON / "agent_config.gd").read_text(encoding="utf-8")
        self.server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.dock_src = (ADDON / "agent_dock.gd").read_text(encoding="utf-8")
        self.dialog_src = (ADDON / "models_dialog.gd").read_text(encoding="utf-8")

    def test_config_extracts_provider_context_length(self):
        self.assertIn("func register_models_metadata", self.config_src)
        self.assertIn('"context_length"', self.config_src)
        self.assertIn('"context_window"', self.config_src)
        self.assertIn('"max_context_length"', self.config_src)
        self.assertIn('"max_model_len"', self.config_src)
        self.assertIn('"model_metadata"', self.config_src)

    def test_config_has_model_context_fallbacks(self):
        self.assertIn("MODEL_CONTEXT_FALLBACKS", self.config_src)
        self.assertIn('"claude-3-5": 200000', self.config_src)
        self.assertIn('"gemini-1.5": 1000000', self.config_src)
        self.assertIn('"gpt-4o": 128000', self.config_src)
        self.assertIn('"deepseek": 64000', self.config_src)
        self.assertIn('"llama-3.1": 128000', self.config_src)

    def test_config_computes_adaptive_context_budget(self):
        self.assertIn("func compute_context_budget", self.config_src)
        self.assertIn("func plan_for_model", self.config_src)
        self.assertIn("func get_compact_threshold", self.config_src)
        self.assertIn("func get_max_tool_output_chars", self.config_src)
        self.assertIn("func get_history_limit", self.config_src)
        self.assertIn("task_auto_compact_threshold", self.config_src)

    def test_dialog_wires_model_context_and_planning(self):
        self.assertIn("func _format_ctx", self.dialog_src)
        self.assertIn("func _update_model_plan_ui", self.dialog_src)
        self.assertIn("models.set_active", self.dialog_src)
        self.assertIn("plan_for_model", self.dialog_src)

    def test_server_system_prompt_has_xml_structure_from_proven_prompts(self):
        self.assertIn("func _build_system_prompt", self.server_src)
        self.assertIn("<role_and_environment>", self.server_src)
        self.assertIn("</role_and_environment>", self.server_src)
        self.assertIn("<live_editor_state>", self.server_src)
        self.assertIn("</live_editor_state>", self.server_src)
        self.assertIn("<core_mandate>", self.server_src)
        self.assertIn("</core_mandate>", self.server_src)
        self.assertIn("<workflow>", self.server_src)
        self.assertIn("</workflow>", self.server_src)
        self.assertIn("<tool_management>", self.server_src)
        self.assertIn("</tool_management>", self.server_src)
        self.assertIn("<verification_and_diagnostics>", self.server_src)
        self.assertIn("</verification_and_diagnostics>", self.server_src)
        self.assertIn("<recovery_and_execution>", self.server_src)
        self.assertIn("</recovery_and_execution>", self.server_src)
        self.assertIn("<project_conventions>", self.server_src)
        self.assertIn("</project_conventions>", self.server_src)
        self.assertIn("<code_standards>", self.server_src)
        self.assertIn("</code_standards>", self.server_src)
        self.assertIn("<scene_and_runtime>", self.server_src)
        self.assertIn("</scene_and_runtime>", self.server_src)
        self.assertIn("<safety_and_permissions>", self.server_src)
        self.assertIn("</safety_and_permissions>", self.server_src)
        self.assertIn("<context_and_persistence>", self.server_src)
        self.assertIn("</context_and_persistence>", self.server_src)
        self.assertIn("<communication>", self.server_src)
        self.assertIn("</communication>", self.server_src)
        self.assertIn("<acceptance_and_completion>", self.server_src)
        self.assertIn("</acceptance_and_completion>", self.server_src)
        self.assertIn("<final_principle>", self.server_src)
        self.assertIn("</final_principle>", self.server_src)

    def test_server_injects_live_editor_state(self):
        self.assertIn("func _get_live_editor_state", self.server_src)
        self.assertIn("EditorInterface.get_edited_scene_root()", self.server_src)
        self.assertIn("EditorInterface.get_selection()", self.server_src)
        self.assertIn("EditorInterface.get_script_editor()", self.server_src)
        self.assertIn("Active Scene:", self.server_src)
        self.assertIn("Selected Node(s):", self.server_src)
        self.assertIn("Open Script:", self.server_src)

    def test_server_handles_model_switching_plan(self):
        self.assertIn('"models.set_active"', self.server_src)
        self.assertIn("func _handle_models_set_active", self.server_src)
        self.assertIn('"model.plan_updated"', self.server_src)
        self.assertIn("memory.compaction_threshold_chars", self.server_src)

    def test_dock_records_assistant_turns_and_accumulates_chunks(self):
        self.assertIn("var _current_assistant_reply: String = \"\"", self.dock_src)
        self.assertIn("_current_assistant_reply += chunk_text", self.dock_src)
        self.assertIn('{"role": "assistant", "content": _current_assistant_reply}', self.dock_src)
        self.assertIn("get_history_limit", self.dock_src)
        self.assertIn('"model.plan_updated":', self.dock_src)

    def test_models_fetch_and_connection_test(self):
        self.assertIn("func set_provider_base_url", self.config_src)
        self.assertIn("_http = HTTPRequest.new()", self.dialog_src)
        self.assertIn("_on_http_completed", self.dialog_src)
        self.assertIn("_populate_models_list", self.dialog_src)
        self.assertIn("_http.timeout = 10.0", self.dialog_src)
        self.assertIn("Connection test SUCCESSFUL", self.dialog_src)
        self.assertIn("max_completion_tokens", self.dialog_src)
        self.assertIn("http.timeout = 10.0", self.server_src)
        self.assertIn("requested_pid", self.server_src)

    def test_reasoner_openai_completion_tokens_and_reasoning_effort(self):
        reasoner_src = (ADDON / "agent_reasoner_http.gd").read_text(encoding="utf-8")
        self.assertIn('body["max_completion_tokens"] = max_tokens', reasoner_src)
        self.assertIn("is_reasoning", reasoner_src)
        self.assertIn('body["reasoning_effort"] = reasoning_effort', reasoner_src)

    def test_server_listen_retry_and_resilience(self):
        self.assertIn("var _ws_retry_at := 0.0", self.server_src)
        self.assertIn("var _http_retry_at := 0.0", self.server_src)
        self.assertIn("if _tcp.is_listening():", self.server_src)
        self.assertIn("if not _tcp.is_listening():", self.server_src)
        self.assertIn("if _http.is_listening():", self.server_src)
        self.assertIn("if not _http.is_listening():", self.server_src)

    def test_client_handshake_timeout_and_dock_status(self):
        client_src = (ADDON / "agent_client.gd").read_text(encoding="utf-8")
        self.assertIn("var _connecting_started_at := 0.0", client_src)
        self.assertIn("WebSocketPeer.STATE_CONNECTING:", client_src)
        self.assertIn("_connecting_started_at > 3.0", client_src)
        self.assertIn("is_connected_to_agent", self.dock_src)
        self.assertIn("set_connected", self.dock_src)

    def test_play_scene_precondition_resilience(self):
        mcp_addon = ROOT / "project" / "addons" / "godot_mcp"
        audit_src = (mcp_addon / "mcp_authoring_audit.gd").read_text(encoding="utf-8")
        runtime_src = (mcp_addon / "handlers" / "runtime_session.gd").read_text(encoding="utf-8")
        local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")

        self.assertIn('func audit_for_play(router: Object, params: Dictionary = {})', audit_src)
        self.assertIn('params.get("force", false)', audit_src)
        self.assertIn('enforce_authoring_audit', audit_src)
        self.assertIn('audit_for_play(_router, params)', runtime_src)
    def test_server_system_prompt_anti_shortcut_and_scene_blueprints(self):
        self.assertIn("best game developer style", self.server_src)
        self.assertIn("Take as much time and as many tool calls as needed", self.server_src)
        self.assertIn("Strictly prohibit shortcuts", self.server_src)
        self.assertIn("Never bypass the Scene Tree", self.server_src)
        self.assertIn("The Professional Scene Construction Workflow (No Shortcuts)", self.server_src)
        self.assertIn("Standard Game Entity Blueprints (The Game Developer Standard)", self.server_src)
        self.assertIn("Playable 2D Character", self.server_src)
        self.assertIn("CharacterBody2D", self.server_src)
        self.assertIn("CollisionShape2D", self.server_src)
        self.assertIn("create_node", self.server_src)
        self.assertIn("set_property", self.server_src)

    def test_hierarchy_tools_in_local_catalog_and_bridge(self):
        local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")

        # Local tools
        self.assertIn('"create_node"', local_src)
        self.assertIn('"delete_node"', local_src)
        self.assertIn('"reparent_node"', local_src)
        self.assertIn("func _create_node", local_src)
        self.assertIn("func _delete_node", local_src)
        self.assertIn("func _reparent_node", local_src)
        self.assertIn("func _coerce_property_value", local_src)

        # Catalog
        self.assertIn('"create_node":', catalog_src)
        self.assertIn('"delete_node":', catalog_src)
        self.assertIn('"reparent_node":', catalog_src)

        # Bridge
        self.assertIn('"create_node"', bridge_src)
        self.assertIn('"add_node":', bridge_src)
        self.assertIn('"godot_scene_edit_create_node":', bridge_src)
        self.assertIn('"godot_scene_edit_set_node_property":', bridge_src)

    def test_bulk_hierarchy_and_collision_tools(self):
        local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")

        # Check local tool declarations and handlers
        self.assertIn('"create_node_hierarchy"', local_src)
        self.assertIn('"create_collision_for_sprite"', local_src)
        self.assertIn("func _create_node_hierarchy", local_src)
        self.assertIn("func _create_collision_for_sprite", local_src)
        self.assertIn("func _build_node_recursive", local_src)
        self.assertIn("validation_warnings", local_src)
        self.assertIn('"build_hierarchy"', local_src)
        self.assertIn('"create_hierarchy"', local_src)
        self.assertIn('"add_collision_shape"', local_src)

        # Check catalog schemas
        self.assertIn('"create_node_hierarchy":', catalog_src)
        self.assertIn('"create_collision_for_sprite":', catalog_src)

        # Check bridge registration and routing
        self.assertIn('"create_node_hierarchy"', bridge_src)
        self.assertIn('"create_collision_for_sprite"', bridge_src)
        self.assertIn('"build_hierarchy", "create_hierarchy":', bridge_src)
        self.assertIn('"add_collision_shape":', bridge_src)

        # Check server system prompt emphasizes bulk hierarchy & auto collision
        self.assertIn("create_node_hierarchy", self.server_src)
        self.assertIn("create_collision_for_sprite", self.server_src)
        self.assertIn("auto_shape", self.server_src)

    def test_create_sprite_frames_tool(self):
        local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")

        # Local tools
        self.assertIn('"create_sprite_frames"', local_src)
        self.assertIn("func _create_sprite_frames", local_src)
        self.assertIn('"build_sprite_frames"', local_src)
        self.assertIn('"godot_animation_create_sprite_frames"', local_src)
        # Verify node inspection serializes SpriteFrames
        self.assertIn('"type": "SpriteFrames"', local_src)
        self.assertIn("get_animation_names", local_src)

        # Catalog
        self.assertIn('"create_sprite_frames":', catalog_src)

        # Bridge
        self.assertIn('"create_sprite_frames"', bridge_src)
        self.assertIn('"build_sprite_frames", "godot_animation_create_sprite_frames":', bridge_src)

        # System prompt
        self.assertIn("create_sprite_frames", self.server_src)

    def test_server_system_prompt_tilemap_and_headless_verification_rules(self):
        self.assertIn("Before constructing a tilemap, establish the actual atlas tile size, margin, and separation", self.server_src)
        self.assertIn("Do not infer exact pixel dimensions from a scaled image alone", self.server_src)
        self.assertIn("verify the selected atlas coordinates and collision data", self.server_src)
        self.assertIn("test player traversal when gameplay is affected", self.server_src)
        self.assertIn("A successful headless run proves runtime stability only for the conditions exercised; it does not prove visual correctness or playability", self.server_src)

    def test_openai_multi_tool_call_vision_buffering(self):
        # Verify that vision messages are buffered until all tool messages in the turn are appended,
        # preventing HTTP 400 from OpenAI for non-consecutive tool responses.
        self.assertIn("pending_vision_messages", self.server_src)
        self.assertIn('ctx["pending_vision_messages"] = []', self.server_src)
        self.assertIn('(ctx["pending_vision_messages"] as Array).append(vision_msg)', self.server_src)
        self.assertIn('for v_msg in v_msgs:', self.server_src)


    def test_get_output_errors_tool_and_timestamping(self):
        local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        mapping_src = (ADDON / "mcp_mapping.gd").read_text(encoding="utf-8")
        server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")

        # 1. agent_local_tools.gd
        self.assertIn('"get_output_errors"', local_src)
        self.assertIn("func _get_output_errors", local_src)
        self.assertIn("func _parse_output_log", local_src)
        self.assertIn("func _format_age", local_src)
        self.assertIn('"age_human"', local_src)
        self.assertIn('"age_seconds"', local_src)
        self.assertIn('"time_unix"', local_src)
        self.assertIn('"status": "new" if is_new else "old"', local_src)
        self.assertIn('"is_new": is_new', local_src)
        self.assertIn("_last_mutation_timestamp", local_src)
        self.assertIn("func _record_mutation", local_src)
        self.assertIn('"output_panel_errors"', local_src)
        # Check aliases
        self.assertIn('"get_editor_output"', local_src)
        self.assertIn('"inspect_output_panel"', local_src)
        self.assertIn('"read_output_log"', local_src)
        self.assertIn('"output_errors"', local_src)

        # 2. agent_tool_catalog.gd
        self.assertIn('"get_output_errors":', catalog_src)
        self.assertIn('"level":', catalog_src)
        self.assertIn('"since_seconds":', catalog_src)
        self.assertIn('"only_new":', catalog_src)
        self.assertIn('"clear":', catalog_src)

        # 3. agent_tools_bridge.gd
        self.assertIn('"get_output_errors"', bridge_src)
        self.assertIn('"get_editor_output", "inspect_output_panel", "read_output_log", "output_errors":', bridge_src)

        # 4. mcp_mapping.gd
        self.assertIn('"get_output_errors":', mapping_src)

        # 5. agent_server.gd system prompt
        self.assertIn("get_output_errors", server_src)
        self.assertIn("Level 2 — Check diagnostics and Output panel errors", server_src)
        self.assertIn('status: "new"', server_src)
        self.assertIn('status: "old"', server_src)
        self.assertIn("is_new: true", server_src)

    def test_proposal_card_scroll_container_and_height_clamp(self):
        self.assertIn("var _proposal_scroll: ScrollContainer", self.dock_src)
        self.assertIn("_proposal_scroll = ScrollContainer.new()", self.dock_src)
        self.assertIn("_proposal_scroll.add_child(_proposal_desc)", self.dock_src)
        self.assertIn("vbox.add_child(_proposal_scroll)", self.dock_src)
        self.assertIn("clampi(line_count * 20 + 20, 48, 160)", self.dock_src)

    def test_reimport_assets_tool_and_registration(self):
        local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        mapping_src = (ADDON / "mcp_mapping.gd").read_text(encoding="utf-8")
        server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")

        # 1. agent_local_tools.gd
        self.assertIn('"reimport_assets"', local_src)
        self.assertIn("func _reimport_assets", local_src)
        self.assertIn("func _collect_asset_files_in_dir", local_src)
        self.assertIn("EditorInterface.get_resource_filesystem()", local_src)
        self.assertIn("fs.reimport_files(", local_src)
        self.assertIn("fs.scan()", local_src)
        self.assertIn("fs.scan_sources()", local_src)
        # Check aliases
        self.assertIn('"reimport_files"', local_src)
        self.assertIn('"reimport_asset"', local_src)

        # 2. agent_tool_catalog.gd
        self.assertIn('"reimport_assets":', catalog_src)
        self.assertIn('"files":', catalog_src)
        self.assertIn('"scan_mode":', catalog_src)
        self.assertIn('"recursive":', catalog_src)

        # 3. agent_tools_bridge.gd
        self.assertIn('"reimport_assets"', bridge_src)
        self.assertIn('"reimport_files", "reimport_asset":', bridge_src)

        # 4. mcp_mapping.gd
        self.assertIn('"reimport_assets":', mapping_src)

        # 5. agent_server.gd system prompt
        self.assertIn("reimport_assets", server_src)
        self.assertIn("trigger Godot editor import scan or immediately reimport specified asset files/folders", server_src)


if __name__ == "__main__":
    unittest.main()


