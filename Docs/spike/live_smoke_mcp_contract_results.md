# Live smoke — MCP Antigravity contract

**Mode:** `http:http://127.0.0.1:9090/mcp`

| Test | Status | Detail |
|---|---|---|
| parse_bad_write | **pass** | {"status": "error", "errors": [{"message": "Unexpected \"Indent\" in class body.", "source": "res://scripts/_contract_bad.gd", "line": 3, "file": "res://scripts/_contract_bad.gd"}], "warnings": []} |
| parse_good_write | **pass** | parse.status=ok |
| create_scene_mcp | **pass** | {'scene_path': 'res://scenes/_contract_marker.tscn', 'root_type': 'Node2D', 'created': True, 'dry_run': False} |
| probe_connected | **pass** | play={'playing': True, 'scene': 'res://scenes/main.tscn', 'paused': False, 'probe_connected': True, 'hint': ''} |
| output_ready | **pass** | entries=0 |
| stale_output_clear | **pass** | play2_probe=True entries=0 |
| authoring_mcp_play | **pass** | saved={'saved': True, 'path': 'res://scenes/_contract_marker.tscn', 'dry_run': False} play={'playing': True, 'scene': 'res://scenes/_contract_marker.tscn', 'paused': False, 'probe_connected': True, 'hint': ''} |

**Rollup:** pass=7 total=7
