"""Unit tests for GodotAgent Reasoning Pipeline and Cognitive Protocol."""

import json
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
AGENT_ADDON = ROOT / "project" / "addons" / "godot_agent"


class ReasoningPipelineTests(unittest.TestCase):
    def setUp(self):
        self.reasoner_src = (AGENT_ADDON / "agent_reasoner_http.gd").read_text(encoding="utf-8")
        self.server_src = (AGENT_ADDON / "agent_server.gd").read_text(encoding="utf-8")
        self.dock_src = (AGENT_ADDON / "agent_dock.gd").read_text(encoding="utf-8")
        self.dialog_src = (AGENT_ADDON / "models_dialog.gd").read_text(encoding="utf-8")

    def test_reasoning_model_detection_expanded(self):
        """Verifies that DeepSeek-R1, QwQ, Claude 3.7, and thinking models are detected as reasoning models."""
        for token in ["deepseek-r1", "qwq", "claude-3-7", "thinking", "reasoner"]:
            self.assertIn(token, self.reasoner_src)
            self.assertIn(token, self.dialog_src)

    def test_openrouter_reasoning_payload_formatting(self):
        """Verifies OpenRouter reasoning parameter formatting."""
        self.assertIn('body["reasoning"] = {"effort": reasoning_effort}', self.reasoner_src)
        self.assertIn('body["reasoning_effort"] = reasoning_effort', self.reasoner_src)

    def test_extract_reasoning_and_content_logic(self):
        """Simulates GDScript extract_reasoning_and_content logic against various reasoning providers."""
        def extract(msg: dict, fallback_text: str = "") -> dict:
            reasoning = ""
            if "reasoning_content" in msg and msg["reasoning_content"]:
                reasoning = str(msg["reasoning_content"]).strip()
            elif "reasoning" in msg and msg["reasoning"]:
                reasoning = str(msg["reasoning"]).strip()
            elif "thought" in msg and msg["thought"]:
                reasoning = str(msg["thought"]).strip()

            raw = msg.get("content", fallback_text) or ""
            think_match = re.search(r"<think>(.*?)</think>", raw, flags=re.DOTALL)
            if think_match:
                embedded = think_match.group(1).strip()
                reasoning = (reasoning + "\n" + embedded).strip() if reasoning else embedded
                raw = re.sub(r"<think>.*?</think>", "", raw, flags=re.DOTALL).strip()

            thought_match = re.search(r"<thought>(.*?)</thought>", raw, flags=re.DOTALL)
            if thought_match:
                embedded = thought_match.group(1).strip()
                reasoning = (reasoning + "\n" + embedded).strip() if reasoning else embedded
                raw = re.sub(r"<thought>.*?</thought>", "", raw, flags=re.DOTALL).strip()

            return {"content": raw, "reasoning": reasoning}

        # Case 1: DeepSeek / OpenRouter structured reasoning_content
        d1 = extract({"content": "I will inspect the scene.", "reasoning_content": "Checking player position and colliders."})
        self.assertEqual(d1["content"], "I will inspect the scene.")
        self.assertEqual(d1["reasoning"], "Checking player position and colliders.")

        # Case 2: Ollama / Local LLM embedded <think> tag
        d2 = extract({"content": "<think>\nEvaluate if Player node exists\n</think>\nI am checking the Player node."})
        self.assertEqual(d2["content"], "I am checking the Player node.")
        self.assertEqual(d2["reasoning"], "Evaluate if Player node exists")

        # Case 3: Embedded <thought> tag
        d3 = extract({"content": "<thought>We need to add a collision shape</thought>Added CollisionShape2D"})
        self.assertEqual(d3["content"], "Added CollisionShape2D")
        self.assertEqual(d3["reasoning"], "We need to add a collision shape")

    def test_server_streams_model_reasoning_to_dock(self):
        """Verifies that agent_server emits thought events with source 'model' when reasoning is present."""
        self.assertIn('"reasoning"', self.server_src)
        self.assertIn('"type": "thought"', self.server_src)
        self.assertIn('"source": "model"', self.server_src)

    def test_server_sanitizes_assistant_messages_for_tools(self):
        """Verifies assistant messages remove reasoning_content and thought before subsequent tool turns."""
        self.assertIn('assistant_msg.erase("reasoning_content")', self.server_src)
        self.assertIn('assistant_msg.erase("thought")', self.server_src)

    def test_dock_formats_model_thoughts_and_checks_config(self):
        """Verifies dock formats model thoughts with distinct emoji and respects show_thoughts."""
        self.assertIn("show_thoughts", self.dock_src)
        self.assertIn("is_model", self.dock_src)
        self.assertIn("Thinking:", self.dock_src)

    def test_prompt_includes_cognitive_reasoning_protocol(self):
        """Verifies the system prompt contains Section 4.3 Cognitive Reasoning Protocol."""
        self.assertIn("### 4.3 Cognitive Reasoning Protocol (\"Think Before You Act\")", self.server_src)
        self.assertIn("Observation & Evidence", self.server_src)
        self.assertIn("Hypothesis & Intent", self.server_src)
        self.assertIn("Dependency & Impact Audit", self.server_src)
        self.assertIn("Risk & Fallback", self.server_src)
        self.assertIn("Verification Requirement", self.server_src)

    def test_create_sprite_frames_spritesheet_schema_and_prompt(self):
        """Verifies that create_sprite_frames supports sprite sheets in catalog, local tools, and prompt."""
        catalog_src = (AGENT_ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        local_tools_src = (AGENT_ADDON / "agent_local_tools.gd").read_text(encoding="utf-8")
        
        # Tool catalog exposes texture and frame_size
        self.assertIn('"create_sprite_frames"', catalog_src)
        self.assertIn('"texture"', catalog_src)
        self.assertIn('"frame_size"', catalog_src)

        # Local tools supports slicing with anim_fw, anim_fh, start_col
        self.assertIn("anim_fw", local_tools_src)
        self.assertIn("anim_fh", local_tools_src)
        self.assertIn("start_col", local_tools_src)

        # System prompt explains sprite sheet grid slicing
        self.assertIn("Option A — Spritesheet Grid Slicing", self.server_src)
        self.assertIn("player_sheet.png", self.server_src)


if __name__ == "__main__":
    unittest.main()
