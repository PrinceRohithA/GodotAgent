# Live smoke spatial/debug - GREEN

**UTC:** 2026-10-04T11:37:44.679434+00:00
**Project:** GodotAgentTest
**URL:** http://127.0.0.1:9090/mcp

- PASS `open_scene`
- PASS `create_host`
- PASS `create_fixtures`
- PASS `create_nested_child`
- PASS `editor_spatial_observe`
  - AABB A/B/D + nested local/global OK
  - unsupported Node2D geometry unavailable OK
- PASS `save_scene`
- PASS `run_game`
  - play probe=True
- PASS `runtime_tree`
- PASS `runtime_spatial`
- PASS `debug_status`
  - session_id=0 breaked=False
- PASS `force_break`
- PASS `debug_status_after_break`
- PASS `debug_error`
  - breaked=True reason=force_break stack_frames=0
- PASS `continue`
- PASS `stop_game`
