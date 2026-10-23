"""Tests for Firecrawl v2 Search & Scraping Integration."""

import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "project" / "addons" / "godot_agent"


class FirecrawlSearchTests(unittest.TestCase):
    def setUp(self):
        self.config_src = (ADDON / "agent_config.gd").read_text(encoding="utf-8")
        self.web_src = (ADDON / "agent_web_search.gd").read_text(encoding="utf-8")
        self.bridge_src = (ADDON / "agent_tools_bridge.gd").read_text(encoding="utf-8")
        self.catalog_src = (ADDON / "agent_tool_catalog.gd").read_text(encoding="utf-8")
        self.dialog_src = (ADDON / "models_dialog.gd").read_text(encoding="utf-8")

    def test_config_defaults_to_firecrawl_v2(self):
        self.assertIn('"provider": "firecrawl"', self.config_src)
        self.assertIn('"https://api.firecrawl.dev/v2/search"', self.config_src)
        self.assertIn("scrape_content", self.config_src)
        self.assertIn("func set_web_search", self.config_src)

    def test_web_adapter_implements_firecrawl_search_and_scrape(self):
        self.assertIn("func _search_firecrawl", self.web_src)
        self.assertIn("func _normalize_firecrawl_scrape", self.web_src)
        self.assertIn("func _normalize_firecrawl_search", self.web_src)
        self.assertIn('"https://api.firecrawl.dev/v2/search"', self.web_src)
        self.assertIn('"https://api.firecrawl.dev/v2/scrape"', self.web_src)
        self.assertIn('"scrapeOptions"', self.web_src)
        self.assertIn('"formats": ["markdown"]', self.web_src)

    def test_bridge_allows_keyless_firecrawl_search(self):
        self.assertIn('provider := str(web.get("provider", "firecrawl")).to_lower()', self.bridge_src)
        self.assertIn('if provider == "brave" and str(web.get("api_key", "")) == "":', self.bridge_src)
        self.assertIn('names.erase("web_search")', self.bridge_src)

    def test_catalog_exposes_firecrawl_schema(self):
        self.assertIn('"web_search":', self.catalog_src)
        self.assertIn("Firecrawl", self.catalog_src)
        self.assertIn('"url"', self.catalog_src)

    def test_models_dialog_has_firecrawl_controls(self):
        self.assertIn("Firecrawl v2", self.dialog_src)
        self.assertIn("web_provider", self.dialog_src)
        self.assertIn("web_scrape_content", self.dialog_src)
        self.assertIn("func _on_web_provider_sel", self.dialog_src)


if __name__ == "__main__":
    unittest.main()
