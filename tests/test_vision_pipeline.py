"""Unit tests for Multimodal Vision Pipeline & Image Forwarding to Model."""

import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class MultimodalVisionPipelineTests(unittest.TestCase):
    def setUp(self):
        self.reasoner_src = (ADDON / "agent_reasoner_http.gd").read_text(encoding="utf-8")
        self.server_src = (ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.local_src = (ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        self.bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")

    def test_reasoner_formats_image_urls(self):
        self.assertIn("func format_image_url", self.reasoner_src)
        self.assertIn('"data:image/png;base64,"', self.reasoner_src)
        self.assertIn("data:image/", self.reasoner_src)
        self.assertIn("res://", self.reasoner_src)

    def test_reasoner_build_messages_supports_multimodal(self):
        self.assertIn("func build_messages(system_prompt: String, user_prompt: Variant, history: Array = [], images: Array = [])", self.reasoner_src)
        self.assertIn('"type": "image_url"', self.reasoner_src)
        self.assertIn('"image_url": {"url": u}', self.reasoner_src)
        # Verify history array content is preserved and not flattened with str(...)
        self.assertIn("if typeof(c) == TYPE_ARRAY:", self.reasoner_src)
        self.assertIn('msgs.append({"role": role, "content": c})', self.reasoner_src)

    def test_server_extracts_and_sanitizes_tool_images(self):
        self.assertIn("func _extract_image_from_tool_result", self.server_src)
        self.assertIn("func _strip_base64_recursively", self.server_src)
        self.assertIn("func _sanitize_result_for_tool_message", self.server_src)
        self.assertIn('"image_attached_for_vision"', self.server_src)

    def test_server_delivers_vision_message_to_model_after_screenshot(self):
        # Must append user role message with image_url after tool message
        self.assertIn('({"role": "tool", "tool_call_id": tc_id, "content": compact})', self.server_src)
        self.assertIn('"role": "user"', self.server_src)
        self.assertIn('"type": "image_url"', self.server_src)
        self.assertIn('"url": img_info["image_url"]', self.server_src)

    def test_server_auto_detects_image_in_user_prompt(self):
        self.assertIn("Detected image in prompt:", self.server_src)
        self.assertIn("res://", self.server_src)
        self.assertIn(".png", self.server_src)

    def test_capture_viewport_registered_in_local_tools(self):
        self.assertIn('"capture_viewport"', self.local_src)
        self.assertIn("func _capture_viewport", self.local_src)
        self.assertIn("get_viewport()", self.local_src)
        self.assertIn("save_png_to_buffer()", self.local_src)

    def test_vision_bundle_and_bridge_support(self):
        self.assertIn('"vision":', self.bridge_src)
        self.assertIn('"capture_viewport"', self.bridge_src)
        self.assertIn('"screenshot"', self.bridge_src)
        self.assertIn('"capture_viewport":', self.catalog_src)

    def test_inspect_asset_image_registered_and_wired(self):
        self.assertIn('"inspect_asset_image"', self.local_src)
        self.assertIn("func _inspect_asset_image", self.local_src)
        self.assertIn('"inspect_asset_image"', self.bridge_src)
        self.assertIn('"inspect_asset_image":', self.catalog_src)
        self.assertIn("dimensions", self.local_src)
        self.assertIn("Image.load_from_file", self.local_src)
        self.assertIn("save_png_to_buffer", self.local_src)
        self.assertIn("You can see images (assets) with their exact dimensions in pixels", self.server_src)
        self.assertIn("analyze their visual contents and layout, and take engineering actions", self.server_src)


if __name__ == "__main__":
    unittest.main()
