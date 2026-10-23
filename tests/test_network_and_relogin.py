"""Unit tests for GodotAgent LLM network issue resilience and relogin handling."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"


class NetworkAndReloginTests(unittest.TestCase):
    def setUp(self):
        self.reasoner_src = (AGENT_ADDON / "agent_reasoner_http.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.dock_src = (AGENT_ADDON / "agent_dock.gd").read_text(encoding="utf-8")

    def test_transient_network_error_detection_in_reasoner(self):
        """Verifies that agent_reasoner_http.gd defines transient network error classification."""
        self.assertIn("func is_transient_network_error(result: int, code: int) -> bool:", self.reasoner_src)
        for result_code in [
            "HTTPRequest.RESULT_CANT_CONNECT",
            "HTTPRequest.RESULT_CANT_RESOLVE",
            "HTTPRequest.RESULT_CONNECTION_ERROR",
            "HTTPRequest.RESULT_NO_RESPONSE",
            "HTTPRequest.RESULT_REQUEST_FAILED",
            "HTTPRequest.RESULT_TIMEOUT",
        ]:
            self.assertIn(result_code, self.reasoner_src)
        for http_code in ["429", "500", "502", "503", "504"]:
            self.assertIn(http_code, self.reasoner_src)

    def test_auth_error_detection_in_reasoner(self):
        """Verifies that agent_reasoner_http.gd defines auth/relogin error detection."""
        self.assertIn("func is_auth_error(code: int, error_text: String = \"\") -> bool:", self.reasoner_src)
        self.assertIn("401", self.reasoner_src)
        self.assertIn("403", self.reasoner_src)
        for keyword in ["invalid_api_key", "incorrect api key", "unauthorized", "token expired"]:
            self.assertIn(keyword, self.reasoner_src)

    def test_network_and_auth_descriptions(self):
        """Verifies human-readable descriptions for network errors and auth failures."""
        self.assertIn("func describe_network_error(", self.reasoner_src)
        self.assertIn("func describe_auth_error(", self.reasoner_src)
        self.assertIn("Request timed out waiting for LLM response", self.reasoner_src)
        self.assertIn("Connection refused. Model server or network endpoint is unreachable", self.reasoner_src)
        self.assertIn("Rate limit exceeded (HTTP 429", self.reasoner_src)
        self.assertIn("Bad Gateway (HTTP 502", self.reasoner_src)
        self.assertIn("Invalid or expired API key (HTTP 401 Unauthorized)", self.reasoner_src)

    def test_missing_api_key_returns_auth_required(self):
        """Verifies that missing API key returns error_type: 'auth_required'."""
        self.assertIn('"error_type": "auth_required"', self.reasoner_src)
        self.assertIn('"provider": pid', self.reasoner_src)
        self.assertIn('key.strip_edges() == ""', self.reasoner_src)

    def test_server_network_retry_constants_and_state(self):
        """Verifies that agent_server.gd configures network retry limits and backoff."""
        self.assertIn("const MAX_NETWORK_RETRIES :=", self.server_src)
        self.assertIn("const INITIAL_RETRY_DELAY :=", self.server_src)
        self.assertIn("var _planning_ctx: Dictionary = {}", self.server_src)
        self.assertIn("func _handle_chat_network_issue(", self.server_src)
        self.assertIn("func _handle_plan_network_issue(", self.server_src)

    def test_server_chat_retry_and_auth_update_handlers(self):
        """Verifies that agent_server.gd handles chat.retry and auth.update_key / relogin."""
        self.assertIn('"chat.retry":', self.server_src)
        self.assertIn('"auth.update_key":', self.server_src)
        self.assertIn('"auth.relogin":', self.server_src)
        self.assertIn("func _handle_chat_retry(", self.server_src)
        self.assertIn("func _handle_auth_update_key(", self.server_src)

    def test_server_resumes_suspended_llm_call_on_auth_update(self):
        """Verifies that updating the key resumes suspended chat or task planning."""
        self.assertIn('bool(_chat_ctx[id].get("waiting_for_auth", false))', self.server_src)
        self.assertIn('bool(_planning_ctx[id].get("waiting_for_auth", false))', self.server_src)
        self.assertIn('ctx.erase("waiting_for_auth")', self.server_src)
        self.assertIn("_llm_round(id)", self.server_src)
        self.assertIn("_request_task_plan(id, task)", self.server_src)

    def test_dock_handles_network_issue_and_auth_required_events(self):
        """Verifies that agent_dock.gd handles network_issue, auth_required, and auth.updated events."""
        self.assertIn('"network_issue":', self.dock_src)
        self.assertIn('"auth_required":', self.dock_src)
        self.assertIn('"auth.updated":', self.dock_src)

    def test_dock_creates_interactive_relogin_and_network_cards(self):
        """Verifies that agent_dock.gd builds dedicated UI cards for relogin and network issues."""
        self.assertIn("func _create_auth_card() -> PanelContainer:", self.dock_src)
        self.assertIn("func _create_network_card() -> PanelContainer:", self.dock_src)
        self.assertIn("func _show_relogin_card(", self.dock_src)
        self.assertIn("func _show_network_retry_card(", self.dock_src)
        self.assertIn("func _submit_relogin_key() -> void:", self.dock_src)
        self.assertIn("func _retry_chat() -> void:", self.dock_src)

    def test_dock_supports_slash_commands_for_network_and_auth(self):
        """Verifies that agent_dock.gd supports /retry, /relogin, and /login <key> slash commands."""
        self.assertIn('t == "/retry"', self.dock_src)
        self.assertIn('t == "/relogin"', self.dock_src)
        self.assertIn('t.begins_with("/login ") or t.begins_with("/key ")', self.dock_src)

    def test_dock_meta_links_click_handling(self):
        """Verifies that in-chat links trigger retry, relogin, and model config."""
        self.assertIn('s == "retry_chat"', self.dock_src)
        self.assertIn('s == "relogin"', self.dock_src)
        self.assertIn('s == "open_models"', self.dock_src)

    def test_transient_simulation_logic(self):
        """Simulates transient network error and auth classification logic in Python."""
        def is_transient(result: int, code: int) -> bool:
            transient_results = {2, 3, 4, 6, 8, 12}
            if result in transient_results:
                return True
            if code in {429, 500, 502, 503, 504}:
                return True
            return False

        def is_auth(code: int, error_text: str = "") -> bool:
            if code in {401, 403}:
                return True
            lower = error_text.lower()
            if any(k in lower for k in ["invalid_api_key", "incorrect api key", "unauthorized", "token expired"]):
                return True
            return False

        # Transient cases
        self.assertTrue(is_transient(12, 0))  # RESULT_TIMEOUT
        self.assertTrue(is_transient(2, 0))   # RESULT_CANT_CONNECT
        self.assertTrue(is_transient(3, 0))   # RESULT_CANT_RESOLVE
        self.assertTrue(is_transient(0, 429)) # Rate limited
        self.assertTrue(is_transient(0, 503)) # Service unavailable
        self.assertTrue(is_transient(0, 502)) # Bad gateway
        self.assertFalse(is_transient(0, 200)) # Success
        self.assertFalse(is_transient(0, 400)) # Bad request
        self.assertFalse(is_transient(0, 404)) # Not found

        # Auth cases
        self.assertTrue(is_auth(401, ""))
        self.assertTrue(is_auth(403, ""))
        self.assertTrue(is_auth(200, "Error: invalid_api_key provided"))
        self.assertTrue(is_auth(200, "User unauthorized"))
        self.assertFalse(is_auth(200, "Normal output"))
        self.assertFalse(is_auth(500, "Internal error"))


if __name__ == "__main__":
    unittest.main()
