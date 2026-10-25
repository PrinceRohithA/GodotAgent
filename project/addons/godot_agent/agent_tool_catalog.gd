@tool
extends RefCounted
## OpenAI tool catalog built only from executable backends.

var _map := preload("res://addons/godot_agent/mcp_mapping.gd").new()

const LOCAL_EXTRAS: Array = []


const DISALLOWED_TOOLS := [
	"godot_debug_workflow",
]

func list_openai_tools(native_names: Array, mcp_tools: Array = []) -> Array:
	var out: Array = []
	var seen := {}
	var meta := _meta()
	# An advertised model tool must have an executable backend now.  Abstract
	# intents stay in mcp_mapping.gd for validation and UI diagnostics only.
	for native in native_names:
		var native_name := str(native)
		if DISALLOWED_TOOLS.has(native_name):
			continue
		if seen.has(native_name):
			continue
		seen[native_name] = true
		out.append(_tool_entry(native_name, meta))
	for n2 in LOCAL_EXTRAS:
		if DISALLOWED_TOOLS.has(n2):
			continue
		if not seen.has(n2):
			seen[n2] = true
			out.append(_tool_entry(n2, meta))
	for remote in mcp_tools:
		if typeof(remote) != TYPE_DICTIONARY:
			continue
		var rd: Dictionary = remote
		var name := str(rd.get("name", ""))
		if name == "" or DISALLOWED_TOOLS.has(name):
			continue
		# Preserve native behavior for collisions.  The remote tool remains
		# discoverable in status but is not exposed under an ambiguous name.
		if seen.has(name):
			continue
		seen[name] = true
		out.append({"type": "function", "function": {
			"name": name,
			"description": str(rd.get("description", "MCP tool: " + name)),
			"parameters": rd.get("inputSchema", {"type": "object", "properties": {}}),
		}})
	out.sort_custom(func(a, b): return str(a["function"]["name"]) < str(b["function"]["name"]))
	return out


func tool_names(native_names: Array, mcp_tools: Array = []) -> Array:
	var names: Array = []
	for t in list_openai_tools(native_names, mcp_tools):
		names.append(str(t["function"]["name"]))
	return names


func count(native_names: Array, mcp_tools: Array = []) -> int:
	return list_openai_tools(native_names, mcp_tools).size()


func _tool_entry(name: String, meta: Dictionary) -> Dictionary:
	var desc := "Godot agent tool: %s" % name
	var params := {"type": "object", "properties": {}, "additionalProperties": true}
	var meta_v: Variant = meta.get(name, null)
	if typeof(meta_v) == TYPE_DICTIONARY:
		desc = str(meta_v.get("desc", desc))
		var p_v: Variant = meta_v.get("params", params)
		if typeof(p_v) == TYPE_DICTIONARY:
			params = p_v
	var abs_v: Variant = _map.ABSTRACT_TO_MCP.get(name, null)
	if typeof(abs_v) == TYPE_DICTIONARY:
		var sets: Array = abs_v.get("toolsets", [])
		if sets.size() > 0:
			desc += " [optional MCP toolsets: %s]" % ", ".join(sets)
	return {
		"type": "function",
		"function": {
			"name": name,
			"description": desc,
			"parameters": params,
		},
	}


func _obj(keys: Array) -> Dictionary:
	var props := {}
	for k in keys:
		props[str(k)] = {}
	return {"type": "object", "properties": props, "additionalProperties": true}


func _meta() -> Dictionary:
	return {
		"inspect_project": {
			"desc": "Inspect project name, main scene, features, autoloads, open scenes.",
			"params": {"type": "object", "properties": {"include_autoload": {"type": "boolean"}}},
		},
		"inspect_scene": {
			"desc": "Inspect edited (or given) scene tree.",
			"params": {"type": "object", "properties": {
				"scene_path": {"type": "string"},
				"max_depth": {"type": "integer"},
			}},
		},
		"inspect_node": {
			"desc": "Inspect a node by path in the edited scene.",
			"params": {"type": "object", "properties": {
				"node_path": {"type": "string"},
				"include_properties": {"type": "boolean"},
				"include_children": {"type": "boolean"},
			}, "required": ["node_path"]},
		},
		"set_property": {
			"desc": "Set one or more node properties in the edited scene. Supports automatic type coercion for Vector2/3 ([x, y] or {x, y}), Color ('#ff0000'), NodePath, and loads Resources from 'res://...' paths (e.g. textures, audio).",
			"params": {"type": "object", "properties": {
				"node_path": {"type": "string", "description": "Node path relative to scene root (e.g. '.' or 'Player' or 'Sprite2D')"},
				"property_name": {"type": "string", "description": "Property name to set (e.g. 'position', 'texture', 'modulate', 'scale', 'shape')"},
				"value": {"description": "New property value. Vector2 as [x, y], Color as hex string, Texture2D as 'res://path.png', Shape2D as class name or dict"},
				"properties": {"type": "object", "description": "Optional dictionary of multiple property names to values to set in one call"},
			}, "required": ["node_path"]},
		},
		"create_node": {
			"desc": "Create a new child node in the currently edited scene and optionally set initial properties. Use this to construct proper scene hierarchies (e.g. Sprite2D, CollisionShape2D, Camera2D, CharacterBody2D) instead of creating nodes in code.",
			"params": {"type": "object", "properties": {
				"parent_path": {"type": "string", "description": "Parent node path relative to scene root (e.g. '.' for scene root, or 'Player')"},
				"type": {"type": "string", "description": "Godot node class name (e.g. 'Sprite2D', 'CollisionShape2D', 'Camera2D', 'CharacterBody2D', 'Area2D', 'Control', 'Label', 'Button')"},
				"name": {"type": "string", "description": "Optional custom node name (defaults to class type)"},
				"properties": {"type": "object", "description": "Optional initial properties to set immediately (e.g. {'position': [100, 200], 'texture': 'res://icon.svg'})"},
			}, "required": ["type"]},
		},
		"delete_node": {
			"desc": "Delete a node from the edited scene. Requires confirmation token for safety.",
			"params": {"type": "object", "properties": {
				"node_path": {"type": "string", "description": "Node path relative to scene root to delete"},
				"confirmation_token": {"type": "string"},
			}, "required": ["node_path"]},
		},
		"delete_nodes": {
			"desc": "Bulk delete multiple nodes in a single call. Safely handles hierarchy dependencies, cleans up instanced scene subtrees, and returns detailed deletion reports including instantiated scene source paths.",
			"params": {
				"type": "object",
				"properties": {
					"node_paths": {
						"type": "array",
						"items": {"type": "string"},
						"description": "Array of node paths relative to scene root to delete, e.g. ['PlatformA', 'PlatformB', 'Enemy01']"
					},
					"confirm": {"type": "boolean", "description": "Confirm deletion (default true)"}
				},
				"required": ["node_paths"]
			}
		},
		"reparent_node": {
			"desc": "Reparent a node under a new parent in the edited scene.",
			"params": {"type": "object", "properties": {
				"node_path": {"type": "string", "description": "Path to node to move"},
				"new_parent_path": {"type": "string", "description": "Path to new parent node"},
			}, "required": ["node_path", "new_parent_path"]},
		},
		"create_node_hierarchy": {
			"desc": "Create a full hierarchy of nodes in one batch with arbitrary nesting, automatic collision shape sizing, and an automated verification check. Each node can define 'name', 'type', 'properties', 'script_path', 'auto_shape', and nested 'children'.",
			"params": {
				"type": "object",
				"properties": {
					"root_path": {"type": "string", "description": "Parent path relative to scene root where the hierarchy is attached (default '.')"},
					"hierarchy": {
						"type": "array",
						"description": "Array of node definitions with optional nested 'children' arrays. Supports CharacterBody2D, Sprite2D, CollisionShape2D, Camera2D, Area2D, etc.",
						"items": {
							"type": "object",
							"properties": {
								"name": {"type": "string", "description": "Node name"},
								"type": {"type": "string", "description": "Godot node class name (e.g. CharacterBody2D, Sprite2D, CollisionShape2D)"},
								"properties": {"type": "object", "description": "Properties to set on the node (position, texture, modulate, etc.)"},
								"script_path": {"type": "string", "description": "Optional script path to attach"},
								"auto_shape": {"type": "boolean", "description": "If true on CollisionShape2D, automatically sizes the shape matching the sibling Sprite2D texture!"},
								"shape_type": {"type": "string", "enum": ["RectangleShape2D", "CircleShape2D", "CapsuleShape2D"]},
								"children": {"type": "array", "description": "Nested child node definitions"}
							},
							"required": ["type"]
						}
					}
				},
				"required": ["hierarchy"]
			}
		},
		"create_collision_for_sprite": {
			"desc": "Inspect an existing Sprite2D's texture dimensions and create a matching CollisionShape2D (RectangleShape2D, CircleShape2D, or CapsuleShape2D) correctly placed as a sibling under the same parent.",
			"params": {
				"type": "object",
				"properties": {
					"sprite_path": {"type": "string", "description": "Path to the Sprite2D node (e.g. 'Player/Sprite2D' or 'Sprite2D')"},
					"shape_type": {"type": "string", "enum": ["RectangleShape2D", "CircleShape2D", "CapsuleShape2D"], "description": "Collision shape type (default RectangleShape2D)"},
					"name": {"type": "string", "description": "Node name (default CollisionShape2D)"},
					"padding": {"description": "Optional padding in pixels to expand or contract collision bounds (number or [x, y])"}
				},
				"required": ["sprite_path"]
			}
		},
		"create_sprite_frames": {
			"desc": "Build, persist, and assign a SpriteFrames resource from spritesheets or individual image files with full animation control (fps, looping, autoplay). Automatically creates the AnimatedSprite2D node in the scene if it does not already exist, and sets its active animation and frame so it immediately renders in the 2D editor.",
			"params": {
				"type": "object",
				"properties": {
					"texture": {
						"type": "string",
						"description": "Optional global spritesheet image path (e.g. 'res://assets/player_sheet.png') used for grid slicing."
					},
					"frame_size": {
						"description": "Frame dimensions [width, height] in pixels for spritesheet slicing (e.g. [32, 32], [48, 48], or '32x32'). Auto-calculated from image dimensions if count is provided."
					},
					"animations": {
						"type": "object",
						"description": "Dictionary mapping animation names ('idle', 'walk', 'jump') to frame configs. Supports: 1) Spritesheet row: {'row': 0, 'count': 4, 'fps': 8.0, 'loop': true}. 2) Spritesheet frame count: {'count': 4, 'fps': 8.0}. 3) Flat index array: [0, 1, 2, 3] or {'frames': [0, 1, 2, 3]}. 4) Grid coordinates: {'frames': [[0, 0], [1, 0]], 'fps': 10.0}. 5) Image file list: ['res://f1.png', 'res://f2.png']. 6) Per-animation sheet: {'texture': 'res://sheet.png', 'frame_size': [32, 32], 'row': 1, 'count': 6}."
					},
					"assign_to": {"type": "string", "description": "Optional node path to AnimatedSprite2D to assign the frames to (e.g. 'World/Player/AnimatedSprite2D' or 'AnimatedSprite2D'). Auto-created if it does not exist."},
					"save_path": {"type": "string", "description": "Optional res:// path to save the .tres resource (e.g. 'res://resources/player_frames.tres'). Auto-generated if omitted."},
					"autoplay": {"type": "string", "description": "Optional animation name to autoplay and display in editor (default 'idle' or first animation)"},
					"default_fps": {"type": "number", "description": "Default frame rate in FPS (default 8.0)"}
				},
				"required": ["animations"]
			}
		},
		"edit_node": {
			"desc": "Create/delete/rename/duplicate/reparent a node. Prefer create_node / delete_node for direct operations.",
			"params": {"type": "object", "properties": {
				"operation": {"type": "string", "enum": ["create", "delete", "rename", "duplicate", "reparent"]},
				"node_path": {"type": "string"},
				"type": {"type": "string"},
				"name": {"type": "string"},
				"new_name": {"type": "string"},
				"parent_path": {"type": "string"},
				"properties": {"type": "object"},
				"confirmation_token": {"type": "string"},
			}, "required": ["operation", "node_path"]},
		},
		"create_scene": {
			"desc": "Create a new scene file with a root node type under res://scenes/ or a feature folder.",
			"params": {"type": "object", "properties": {
				"scene_path": {"type": "string", "description": "Canonical scene path under res://scenes/ (e.g. res://scenes/main.tscn or res://scenes/levels/level_01.tscn). Never place loose scenes directly in res:// root."},
				"root_type": {"type": "string", "description": "Root node type: Node2D, Node3D, Control, CharacterBody2D, etc."},
			}, "required": ["scene_path"]},
		},
		"instance_scene": {
			"desc": "Instantiate a saved scene (.tscn / .scn) as a child node in the currently edited scene. Essential for composing levels from modular entity scenes (e.g. player.tscn, platform.tscn) without duplicating nodes.",
			"params": {"type": "object", "properties": {
				"scene_path": {"type": "string", "description": "Canonical scene path to instantiate under res:// (e.g. res://scenes/player.tscn or res://scenes/platform.tscn)"},
				"parent_path": {"type": "string", "description": "Target parent node path relative to edited scene root (default: '.' for scene root)"},
				"name": {"type": "string", "description": "Optional custom instance node name (defaults to scene filename/root name)"},
				"properties": {"type": "object", "description": "Dictionary of properties to apply upon instantiation (e.g. {'position': [100, 200], 'z_index': 1})"}
			}, "required": ["scene_path"]},
		},
		"save_scene": {
			"desc": "Save the currently edited scene to disk.",
			"params": {"type": "object", "properties": {"scene_path": {"type": "string", "description": "Optional scene path under res://scenes/"}}},
		},
		"attach_script": {
			"desc": "Attach a script resource to a node in the edited scene.",
			"params": {"type": "object", "properties": {
				"node_path": {"type": "string", "description": "Node path relative to edited scene root (e.g. '.' or 'Player')"},
				"script_path": {"type": "string", "description": "Script path under res://scripts/ (e.g. res://scripts/player.gd)"},
			}, "required": ["node_path", "script_path"]},
		},
		"patch_script": {
			"desc": "Patch or write a script file under res://scripts/.",
			"params": {"type": "object", "properties": {
				"path": {"type": "string", "description": "Path to script file under res://scripts/ (e.g. res://scripts/player.gd)"},
				"content": {"type": "string", "description": "Full replacement content if replacing the entire script"},
				"search": {"type": "string", "description": "Exact text to search and replace"},
				"replace": {"type": "string", "description": "New replacement text"},
			}, "required": ["path"]},
		},
		"read_script": {
			"desc": "Read a text/script file from res://.",
			"params": {"type": "object", "properties": {
				"path": {"type": "string", "description": "Path to file (e.g. res://scripts/player.gd)"},
				"max_chars": {"type": "integer"},
			}, "required": ["path"]},
		},
		"settings_get": {
			"desc": "Get a ProjectSettings value.",
			"params": {"type": "object", "properties": {"key": {"type": "string"}}, "required": ["key"]},
		},
		"settings_set": {
			"desc": "Set a ProjectSettings value.",
			"params": {"type": "object", "properties": {"key": {"type": "string"}, "value": {}}, "required": ["key", "value"]},
		},
		"list_files": {
			"desc": "List files under a res:// directory.",
			"params": {"type": "object", "properties": {
				"path": {"type": "string", "description": "Directory to inspect (e.g. res://scenes, res://scripts, res://assets)"},
				"extensions": {"type": "array", "items": {"type": "string"}},
				"recursive": {"type": "boolean"},
				"max_files": {"type": "integer"},
			}},
		},
		"write_script": {
			"desc": "Write/overwrite a script or text file under res://scripts/ or a dedicated feature directory.",
			"params": {"type": "object", "properties": {
				"path": {"type": "string", "description": "Canonical path under res://scripts/ (e.g. res://scripts/player.gd). Never place loose scripts in res:// root."},
				"content": {"type": "string", "description": "Full GDScript 4 code content with strict typing"},
			}, "required": ["path", "content"]},
		},
		"delete_file": {"desc": "Move a project file to the agent trash for safe, recoverable deletion.", "params": {"type": "object", "properties": {"path": {"type": "string", "description": "Project path under res:// to safely delete/move to trash."}, "force": {"type": "boolean", "description": "Whether to delete immediately without confirmation."}, "confirmation_token": {"type": "string", "description": "Optional confirmation token if prompted."}}, "required": ["path"]}},
		"restore_deleted_path": {"desc": "Restore a file previously moved to agent trash.", "params": _obj(["trash_path", "destination"] )},
		"run_shell": {"desc": "Run a PowerShell command in the project directory. Use for archive extraction, file inspection, and project tooling.", "params": {"type": "object", "properties": {"command": {"type": "string", "description": "Shell command to execute."}, "timeout_seconds": {"type": "number", "description": "Execution timeout in seconds (default 30)."}, "force": {"type": "boolean", "description": "Whether to run immediately without confirmation."}, "confirmation_token": {"type": "string", "description": "Optional confirmation token if prompted."}}, "required": ["command"]}},
		"reimport_assets": {
			"desc": "Trigger Godot editor import scan or immediately reimport specified asset files/directories (textures, audio, 3D scenes, fonts) so they are recognized by Godot without manual UI intervention.",
			"params": {
				"type": "object",
				"properties": {
					"files": {
						"type": "array",
						"items": {"type": "string"},
						"description": "Specific asset file path(s) to reimport immediately (e.g. ['res://assets/textures/player.png'])."
					},
					"path": {
						"type": "string",
						"description": "Directory or file path to scan/reimport (e.g. 'res://assets/textures')."
					},
					"recursive": {
						"type": "boolean",
						"description": "Whether to recursively discover and reimport assets in directory subfolders (default: true)."
					},
					"scan_mode": {
						"type": "string",
						"enum": ["auto", "reimport", "scan", "scan_sources"],
						"description": "Reimport strategy: 'auto' reimports files and scans if directories changed, 'reimport' reimports specific files, 'scan' triggers filesystem scan, 'scan_sources' scans external sources."
					}
				}
			}
		},
		"web_search": {"desc": "Search the web and scrape clean, cited content using Firecrawl. Accepts a search query or a direct URL to scrape markdown.", "params": {"type": "object", "properties": {"query": {"type": "string", "description": "Search keywords or a direct URL to scrape"}, "count": {"type": "integer", "description": "Number of results to return (1-10)"}, "url": {"type": "string", "description": "Optional direct URL to scrape markdown from"}}, "required": ["query"]}},
		"search_mcp_tools": {"desc": "Search the full discovered MCP catalog. Use before activating a specialized tool family.", "params": _obj(["query", "limit"] )},
		"activate_mcp_tools": {"desc": "Add exact discovered MCP tools to the current profile while retaining pinned inspection, project, scene, script, runtime, and diagnostic tools. Pass names as an array returned by search_mcp_tools.", "params": {"type": "object", "properties": {"names": {"type": "array", "items": {"type": "string"}, "minItems": 1}}, "required": ["names"], "additionalProperties": false}},
		"select_mcp_profile": {"desc": "Select a managed MCP tool profile. Note: 'full_game_authoring' only loads general scene/script authoring tools. Specialized systems (physics, tilemap, animation, audio, 3D, navigation, particles, shaders) reside in tool bundles and MUST be activated via unpack_tool_bundle() or invoked via call_mcp_tool(). Do not retry this tool expecting specialized tools to appear.", "params": {"type": "object", "properties": {"profile": {"type": "string", "enum": ["baseline", "full_game_authoring"]}}, "required": ["profile"], "additionalProperties": false}},
		"call_mcp_tool": {"desc": "Invoke any discovered MCP tool, including one outside the current 128-tool model window. First use search_mcp_tools to obtain the exact name and input_schema, then pass its arguments unchanged.", "params": {"type": "object", "properties": {"name": {"type": "string"}, "arguments": {"type": "object"}}, "required": ["name", "arguments"], "additionalProperties": false}},
		"list_tool_bundles": {"desc": "List all specialized tool bundles (physics, audio, tilemap, scene_3d, animation, etc.), which tools they contain, their status (unpacked vs packed in storage), and remaining window capacity.", "params": {"type": "object", "properties": {}}},
		"unpack_tool_bundle": {"desc": "Unpack a specialized bundle of tools into the active model window so they can be invoked. If the 128-tool window capacity is exceeded, older bundles are automatically packed back into storage and you are notified.", "params": {"type": "object", "properties": {"bundle_name": {"type": "string"}}, "required": ["bundle_name"], "additionalProperties": false}},
		"pack_tool_bundle": {"desc": "Pack an active tool bundle back into storage to free up tool window slots.", "params": {"type": "object", "properties": {"bundle_name": {"type": "string"}}, "required": ["bundle_name"], "additionalProperties": false}},
		"undo": {"desc": "Undo a reversible native change, or use scope mcp_editor for the separate editor history.", "params": _obj(["steps", "scope"] )},
		"redo": {"desc": "Redo a reversible native change, or use scope mcp_editor for the separate editor history.", "params": _obj(["steps", "scope"] )},
		"list_history": {"desc": "Show native history, or separate MCP editor history with scope mcp_editor.", "params": _obj(["scope"] )},
		"animation_inspect": {"desc": "List/inspect AnimationPlayer animations.", "params": _obj(["node_path", "animation"])},
		"animation_edit": {"desc": "Create animation / add track / insert keyframe.", "params": _obj(["node_path", "operation", "animation", "params"])},
		"animation_tree_inspect": {"desc": "Inspect AnimationTree / state machine.", "params": _obj(["node_path"])},
		"animation_tree_edit": {"desc": "Edit AnimationTree blend/state machine.", "params": _obj(["node_path", "operation", "params"])},
		"nodes_create_batch": {"desc": "Create many nodes in one batch.", "params": _obj(["parent_path", "nodes"])},
		"nodes_edit_batch": {"desc": "Edit many nodes in one batch.", "params": _obj(["edits"])},
		"spatial_observe": {"desc": "Observe 2D/3D spatial objects and geometry.", "params": _obj(["scope", "filters", "max_objects"])},
		"observe": {"desc": "High-level observe: runtime + spatial + debugger snapshot.", "params": _obj(["include_runtime", "include_spatial", "include_debugger"])},
		"runtime_tree": {"desc": "Get live game scene tree (play session).", "params": _obj(["max_depth"])},
		"runtime_node_inspect": {"desc": "Inspect a live runtime node.", "params": _obj(["node_path"])},
		"runtime_get_property": {"desc": "Read a live runtime property.", "params": _obj(["node_path", "property"])},
		"runtime_set_property": {"desc": "Write a live runtime property.", "params": _obj(["node_path", "property", "value"])},
		"debug_status": {"desc": "Debugger session status.", "params": {"type": "object", "properties": {}}},
		"debug_control": {"desc": "Break/continue/step debugger.", "params": _obj(["action"])},
		"debug_breakpoint": {"desc": "Set/remove/list breakpoints.", "params": _obj(["operation", "path", "line"])},
		"debug_stack": {"desc": "Get debugger stack frames.", "params": {"type": "object", "properties": {}}},
		"debug_error": {"desc": "Get last debugger error.", "params": {"type": "object", "properties": {}}},
		"debug_state": {"desc": "Get debugger error + frame variables.", "params": _obj(["frame"])},
		"debug_visuals": {"desc": "Toggle debugger visuals.", "params": _obj(["enabled"])},
		"debug_profiler": {"desc": "Read performance monitors.", "params": {"type": "object", "properties": {}}},
		"run_game": {"desc": "Play main or current scene.", "params": {"type": "object", "properties": {"current": {"type": "boolean"}, "scene_path": {"type": "string"}}}},
		"stop_game": {"desc": "Stop play session.", "params": {"type": "object", "properties": {}}},
		"toggle_debug_collisions": {
			"desc": "Toggle or explicitly set runtime collision shape visibility during playtime (ProjectSettings debug/shapes/collision/visible and SceneTree debug_collisions_hint). Persists to project.godot.",
			"params": {"type": "object", "properties": {
				"visible": {"type": "boolean", "description": "Optional explicit boolean to enable (true) or disable (false) playtime collision shape rendering. If omitted, toggles current value."}
			}},
		},
		"playtest_input": {"desc": "Simulate input during play (needs runtime probe).", "params": _obj(["kind", "action", "key", "sequence"])},
		"playtest_wait": {"desc": "Wait N seconds during playtest loop.", "params": {"type": "object", "properties": {"seconds": {"type": "number"}}}},
		"observe_runtime": {"desc": "Observe game output/tree/properties during play.", "params": _obj(["include_output", "include_tree"])},
		"capture_viewport": {"desc": "Capture game or editor screenshot for visual reasoning. Image is automatically passed to model vision.", "params": {"type": "object", "properties": {"target": {"type": "string", "description": "Target viewport: 'editor' or 'game'"}, "path": {"type": "string", "description": "Optional file path to save PNG (e.g. res://screenshot.png)"}}}},
		"inspect_asset_image": {
			"desc": "Inspect any image or texture asset (PNG, JPG, WebP, SVG, BMP, TGA, or Texture2D resource) or directory. Returns exact pixel dimensions (width x height in pixels), color format, alpha channel, and delivers the full visual image directly to your vision input so you can visually see and analyze the asset.",
			"params": {
				"type": "object",
				"properties": {
					"path": {
						"type": "string",
						"description": "Path to the image asset (e.g. res://icon.svg, res://assets/sprites/player.png) or an asset directory (e.g. res://assets/sprites/) to inspect pixel dimensions of all image assets in that directory."
					},
					"max_dimension": {
						"type": "integer",
						"description": "Maximum width/height for visual image delivery (default 1024). Original exact pixel dimensions are always reported."
					}
				},
				"required": ["path"]
			}
		},
		"get_diagnostics": {"desc": "Collect diagnostics: parse errors, health, open scene.", "params": {"type": "object", "properties": {}}},
		"get_output_errors": {
			"desc": "Inspect errors and warnings from the Godot Editor Output panel and engine log. Each error includes its exact timestamp, human-readable age (e.g. '12s ago'), callstack location (file and line), and an 'is_new' / 'status' flag indicating whether the error is new (occurred during/after the latest action) or old (pre-existing historical error).",
			"params": {
				"type": "object",
				"properties": {
					"level": {"type": "string", "enum": ["errors", "warnings", "all"], "description": "Filter by message level: 'errors' (default, only errors/script errors), 'warnings' (errors + warnings), 'all' (all messages including stdout)"},
					"since_seconds": {"type": "number", "description": "Optional: only return errors that occurred within the last N seconds (e.g. 60.0)"},
					"only_new": {"type": "boolean", "description": "If true, only returns new errors that occurred after the last action or check"},
					"limit": {"type": "integer", "description": "Maximum number of error entries to return (default 50, max 200)"},
					"clear": {"type": "boolean", "description": "If true, marks current errors as read so subsequent calls only show newly arriving errors"}
				}
			}
		},
		"tileset_create": {"desc": "Create a TileSet resource.", "params": _obj(["path"])},
		"tileset_add_atlas": {"desc": "Add atlas source to TileSet.", "params": _obj(["tileset_path", "texture_path"])},
		"tileset_create_tile": {"desc": "Create a tile in an atlas.", "params": _obj(["tileset_path", "source_id", "atlas_coords"])},
		"tileset_inspect": {"desc": "Inspect a TileSet.", "params": _obj(["tileset_path"])},
		"tileset_atlas_inspect": {"desc": "Inspect a TileSet atlas source.", "params": _obj(["tileset_path", "source_id"])},
		"get_tile_data": {"desc": "Get tile data for atlas coords.", "params": _obj(["tileset_path", "source_id", "atlas_coords"])},
		"add_tileset_physics_layer": {"desc": "Add physics layer to TileSet.", "params": _obj(["tileset_path"])},
		"set_tile_collision": {"desc": "Set tile collision polygons.", "params": _obj(["tileset_path", "source_id", "atlas_coords", "polygons"])},
		"clear_tile_collision": {"desc": "Clear tile collision.", "params": _obj(["tileset_path", "source_id", "atlas_coords"])},
		"tilemap_layer_set_physics": {"desc": "Enable/disable TileMapLayer physics.", "params": _obj(["node_path", "enabled"])},
		"tilemap_set_cells_batch": {"desc": "Set many TileMap cells at once.", "params": _obj(["node_path", "cells"])},
		"add_tileset_custom_data_layer": {"desc": "Add custom data layer to TileSet.", "params": _obj(["tileset_path", "layer_name", "type"])},
		"set_tile_custom_data": {"desc": "Set tile custom data value.", "params": _obj(["tileset_path", "source_id", "atlas_coords", "layer", "value"])},
		"add_tileset_terrain_set": {"desc": "Add terrain set to TileSet.", "params": _obj(["tileset_path"])},
		"add_tileset_terrain": {"desc": "Add terrain to a set.", "params": _obj(["tileset_path", "terrain_set", "name"])},
		"set_tile_terrain": {"desc": "Assign terrain peering on a tile.", "params": _obj(["tileset_path", "source_id", "atlas_coords", "terrain_set", "terrain"])},
		"tilemap_set_terrain": {"desc": "Paint terrain cells on TileMap.", "params": _obj(["node_path", "cells", "terrain_set", "terrain"])},
		"tileset_add_pattern": {"desc": "Add pattern to TileSet.", "params": _obj(["tileset_path", "pattern"])},
		"tilemap_set_pattern": {"desc": "Stamp a TileSet pattern.", "params": _obj(["node_path", "position", "pattern_index"])},
		"create_alternative_tile": {"desc": "Create alternative tile id.", "params": _obj(["tileset_path", "source_id", "atlas_coords"])},
		"set_tile_animation": {"desc": "Set tile animation frames.", "params": _obj(["tileset_path", "source_id", "atlas_coords", "frames"])},
		"add_tileset_navigation_layer": {"desc": "Add navigation layer to TileSet.", "params": _obj(["tileset_path"])},
		"set_tile_navigation": {"desc": "Set tile navigation polygon.", "params": _obj(["tileset_path", "source_id", "atlas_coords", "polygons"])},
		"tilemap_layer_set_navigation": {"desc": "Enable/disable TileMapLayer navigation.", "params": _obj(["node_path", "enabled"])},
		"add_tileset_occlusion_layer": {"desc": "Add occlusion layer to TileSet.", "params": _obj(["tileset_path"])},
		"set_tile_occlusion": {"desc": "Set tile occlusion polygons.", "params": _obj(["tileset_path", "source_id", "atlas_coords", "polygons"])},
		"add_tileset_scenes_collection_source": {"desc": "Add scenes collection source.", "params": _obj(["tileset_path"])},
		"create_scene_tile": {"desc": "Create a scene tile in collection source.", "params": _obj(["tileset_path", "source_id", "scene_path"])},
		"set_tile_constant_velocity": {"desc": "Set tile constant linear velocity.", "params": _obj(["tileset_path", "source_id", "atlas_coords", "velocity"])},
		"tilemap_layer_set_kinematic": {"desc": "Enable kinematic on TileMapLayer.", "params": _obj(["node_path", "enabled"])},
		"tilemap_inspect": {"desc": "Inspect TileMap layers / used cells.", "params": _obj(["node_path"])},
		"tilemap_get_cell": {"desc": "Get a single TileMap cell.", "params": _obj(["node_path", "coords"])},
		"tilemap_set_cell": {"desc": "Set a single TileMap cell.", "params": _obj(["node_path", "coords", "source_id", "atlas_coords"])},
		"tilemap_fill_rect": {"desc": "Fill a rect of TileMap cells.", "params": _obj(["node_path", "rect", "source_id", "atlas_coords"])},
		"tilemap_clear": {"desc": "Clear a TileMap layer.", "params": _obj(["node_path"])},
		"analyze_atlas_geometry": {
			"desc": "Analyze an atlas texture or TileSet to determine exact image dimensions, grid geometry (columns, rows, total tiles), tile size, margins, separation, and active non-empty tiles.",
			"params": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path to the atlas texture (e.g. res://assets/textures/tiles.png) or TileSet resource."},
					"tile_size": {"type": "array", "description": "Optional [width, height] in pixels (e.g. [16, 16] or [64, 64]). If omitted, tests standard candidates against dimensions to auto-detect grid size.", "items": {"type": "integer"}},
					"margin": {"type": "array", "description": "Optional [margin_x, margin_y] offset in pixels from texture top-left.", "items": {"type": "integer"}},
					"separation": {"type": "array", "description": "Optional [sep_x, sep_y] pixel spacing between adjacent tiles.", "items": {"type": "integer"}}
				},
				"required": ["path"]
			}
		},
		"preview_labelled_atlas": {
			"desc": "Generate a coordinate-labelled contact sheet preview image of an atlas where every tile cell is bounded with a grid border and stamped with its exact (x, y) atlas coordinates. Returns base64 PNG data for vision models.",
			"params": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path to the atlas texture."},
					"tile_size": {"type": "array", "description": "Optional [width, height] in pixels. If omitted, auto-detected.", "items": {"type": "integer"}},
					"margin": {"type": "array", "description": "Optional [margin_x, margin_y] offset.", "items": {"type": "integer"}},
					"separation": {"type": "array", "description": "Optional [sep_x, sep_y] spacing.", "items": {"type": "integer"}},
					"max_dimension": {"type": "integer", "description": "Maximum width/height of the generated preview image (default 1280)."}
				},
				"required": ["path"]
			}
		},
		"inspect_tile_crop": {
			"desc": "Inspect an individual tile at specific (x, y) atlas coordinates. Extracts the cropped thumbnail, analyzes boundary transparency profiles, and classifies candidate role (ground_top, interior_fill, left_edge, right_edge, corner, decoration, or unknown).",
			"params": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path to the atlas texture."},
					"atlas_coords": {"type": "array", "description": "Atlas grid coordinates [x, y] to crop and inspect.", "items": {"type": "integer"}},
					"tile_size": {"type": "array", "description": "Tile [width, height] in pixels.", "items": {"type": "integer"}},
					"margin": {"type": "array", "description": "Optional [margin_x, margin_y] offset.", "items": {"type": "integer"}},
					"separation": {"type": "array", "description": "Optional [sep_x, sep_y] spacing.", "items": {"type": "integer"}}
				},
				"required": ["path", "atlas_coords"]
			}
		},
		"catalog_atlas_tiles": {
			"desc": "Generate an evidence-based structural catalog of all tiles in an atlas, grouping coordinates into ground_top, interior_fill, left_edge, right_edge, corners, bottom_edge, decoration, and unknown without hallucinating semantic labels.",
			"params": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path to the atlas texture."},
					"tile_size": {"type": "array", "description": "Tile [width, height] in pixels.", "items": {"type": "integer"}},
					"margin": {"type": "array", "description": "Optional [margin_x, margin_y] offset.", "items": {"type": "integer"}},
					"separation": {"type": "array", "description": "Optional [sep_x, sep_y] spacing.", "items": {"type": "integer"}}
				},
				"required": ["path"]
			}
		},
		"validate_atlas_coords": {
			"desc": "Verify that a list of candidate atlas coordinates exists within the texture grid bounds and contains non-empty artwork before painting.",
			"params": {
				"type": "object",
				"properties": {
					"path": {"type": "string", "description": "Resource path to the atlas texture."},
					"coords": {"type": "array", "description": "Array of [x, y] atlas coordinates to validate (e.g. [[0, 0], [1, 0], [2, 1]]).", "items": {"type": "array"}},
					"tile_size": {"type": "array", "description": "Tile [width, height] in pixels.", "items": {"type": "integer"}}
				},
				"required": ["path", "coords"]
			}
		},
		"inspect_player_metrics": {
			"desc": "Inspect a CharacterBody2D player character to extract collision dimensions, jump velocity, gravity, and speed. Quantitatively computes max jump height, air time, max horizontal jump reach, and recommended safe platform gaps and elevation steps in tile units.",
			"params": {
				"type": "object",
				"properties": {
					"character_path": {"type": "string", "description": "Node path to CharacterBody2D (e.g. World/Player). If omitted, automatically discovers CharacterBody2D in the active scene."},
					"tile_dimension": {"type": "number", "description": "Tile size in pixels (e.g. 16, 32, 64) used to calculate platform gap recommendations in tile units (default 64.0)."}
				}
			}
		},
		"inspect_tilemap_layer": {
			"desc": "Inspect a TileMapLayer node: reads TileSet resource, tile size, used cell count, used bounding rect, layer visibility, and validates all occupied cells against the TileSet source to flag any invalid tile coordinates.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Node path to the TileMapLayer (e.g. World/TileMapLayer or World/GroundLayer)."}
				},
				"required": ["node_path"]
			}
		},
		"paint_tilemap_cells": {
			"desc": "Batch paint multiple cells onto a TileMapLayer with undo/redo support and mutation tracking.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Node path to the TileMapLayer."},
					"cells": {
						"type": "array",
						"description": "Array of cell definitions: [{'coords': [x, y], 'source_id': 0, 'atlas_coords': [ax, ay], 'alternative_tile': 0}, ...]",
						"items": {"type": "object"}
					}
				},
				"required": ["node_path", "cells"]
			}
		},
		"paint_tilemap_rect": {
			"desc": "Fill a rectangular region of cells on a TileMapLayer with a specified atlas tile.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Node path to the TileMapLayer."},
					"rect": {"type": "array", "description": "Rect coordinates [x, y, width, height] in map grid cells.", "items": {"type": "integer"}},
					"source_id": {"type": "integer", "description": "TileSet source ID (default 0)."},
					"atlas_coords": {"type": "array", "description": "Atlas tile coordinates [x, y].", "items": {"type": "integer"}},
					"alternative_tile": {"type": "integer", "description": "Alternative tile ID (default 0)."}
				},
				"required": ["node_path", "rect", "atlas_coords"]
			}
		},
		"invoke_level_designer": {
			"desc": "MANDATORY tool to invoke whenever the user asks to build, populate, modify, or layout a level, platformer stage, terrain, or tiles. Audits the active scene for TileMapLayers, available entity scenes to instance, measures player jump reach metrics, activates Level Designer subagent mode, and returns strict TileMap-first directives with pan/zoom verification loop.",
			"params": {
				"type": "object",
				"properties": {
					"task": {"type": "string", "description": "Goal or description of the level design task (e.g. 'Build starter platformer layout with spawn, ground, two jump platforms, and goal')."},
					"scene_path": {"type": "string", "description": "Optional scene path to design if not already open."}
				}
			}
		},
		"auto_generate_atlas_tiles": {
			"desc": "Automatically slice and populate all tiles in a TileSet atlas from a texture grid in a single call. Automatically detects grid columns/rows, filters out fully transparent empty tiles, creates TileSet/TileMapLayer if needed, and optionally applies full-rect collision polygons to solid tiles.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "TileMapLayer or TileMap node path (auto-finds active layer in scene if omitted)."},
					"texture_path": {"type": "string", "description": "Path to texture file (e.g. 'res://assets/tiles.png'). Auto-creates atlas source if needed."},
					"tile_size": {"type": "array", "description": "Tile pixel dimensions [width, height], e.g. [16, 16] or [32, 32] (default [16, 16]).", "items": {"type": "integer"}},
					"tileset_path": {"type": "string", "description": "Optional path to standalone TileSet resource (.tres)."},
					"source_id": {"type": "integer", "description": "Source ID to populate (default 0 or next available)."},
					"filter_empty": {"type": "boolean", "description": "When true, transparent cells with zero opaque pixels are skipped (default true)."},
					"auto_collision": {"type": "boolean", "description": "When true, automatically ensures a physics layer exists and applies full-rect collision shape to all generated tiles (default false)."},
					"physics_layer": {"type": "integer", "description": "Physics layer index to apply collision to (default 0)."},
					"one_way": {"type": "boolean", "description": "When auto_collision is true, set collision to one-way platform (default false)."}
				}
			}
		},
		"inspect_spatial_context": {
			"desc": "Inspect 2D spatial state of the active scene: camera view, viewport size, and compact structured array of nodes with local and global transforms, global AABBs, collision shapes/layers, TileMapLayer bounds, and scene instantiation info.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Node path to inspect from (default '.' for root)."},
					"max_depth": {"type": "integer", "description": "Maximum tree traversal depth (-1 for unlimited)."},
					"include_tiles": {"type": "boolean", "description": "Whether to summarize TileMapLayer nodes (default true)."},
					"include_collision": {"type": "boolean", "description": "Whether to extract collision shapes and layer masks (default true)."}
				}
			}
		},
		"convert_spatial_coordinates": {
			"desc": "Accurately convert 2D coordinates between reference frames: 'global' (world), 'local' (node-relative), 'viewport' (screen/camera), 'tilemap_cell' (grid coordinates), and 'tilemap_atlas' (tile coordinates).",
			"params": {
				"type": "object",
				"properties": {
					"point": {"type": "array", "description": "Input coordinates [x, y].", "items": {"type": "number"}},
					"from_frame": {"type": "string", "description": "Source coordinate frame: 'global', 'local', 'viewport', 'tilemap_cell', or 'tilemap_atlas'.", "enum": ["global", "world", "local", "viewport", "screen", "tilemap_cell", "tilemap_atlas"]},
					"to_frame": {"type": "string", "description": "Target coordinate frame: 'global', 'local', 'viewport', 'tilemap_cell', or 'tilemap_atlas'.", "enum": ["global", "world", "local", "viewport", "screen", "tilemap_cell", "tilemap_atlas"]},
					"node_path": {"type": "string", "description": "Node path required when converting to/from 'local'."},
					"layer_path": {"type": "string", "description": "TileMapLayer path required when converting to/from 'tilemap_cell' or 'tilemap_atlas'."}
				},
				"required": ["point", "from_frame", "to_frame"]
			}
		},
		"inspect_spatial_region": {
			"desc": "Query a world-space rectangle [x, y, width, height] to detect all intersecting nodes, colliders, TileMapLayer cells, solid horizontal platform surfaces, and hazard zones.",
			"params": {
				"type": "object",
				"properties": {
					"rect": {"type": "array", "description": "World-space query rectangle [x, y, width, height].", "items": {"type": "number"}},
					"type_filter": {"type": "array", "description": "Optional list of node class names to filter by (e.g. ['TileMapLayer', 'CharacterBody2D', 'StaticBody2D']).", "items": {"type": "string"}},
					"include_cells": {"type": "boolean", "description": "Whether to list intersecting TileMapLayer cells (default true)."},
					"max_cells": {"type": "integer", "description": "Maximum number of cells to return (default 100)."}
				},
				"required": ["rect"]
			}
		},
		"query_spatial_relationships": {
			"desc": "Compute deterministic geometric relationships between node_a and other nodes (or node_b): euclidean distances, delta_x, delta_y, horizontal clearance, vertical clearance, relative direction ('above', 'below', 'left_of', 'right_of', etc.), bounding box overlap, candidate support surfaces, and hazard proximity.",
			"params": {
				"type": "object",
				"properties": {
					"node_a": {"type": "string", "description": "Primary node path (e.g. 'Player' or 'World/Player')."},
					"node_b": {"type": "string", "description": "Optional specific secondary node to compare against (e.g. 'World/Platform1', or 'all')."},
					"target_nodes": {"type": "array", "description": "Optional explicit array of node paths to compare against node_a.", "items": {"type": "string"}},
					"max_targets": {"type": "integer", "description": "Maximum number of nearby targets to evaluate when discovering automatically (default 12)."}
				},
				"required": ["node_a"]
			}
		},
		"preview_spatial_overlay": {
			"desc": "Generate an annotated 2D spatial preview image with node bounding boxes, axes, and name labels overlaid onto the editor viewport or schematic canvas for visual verification.",
			"params": {
				"type": "object",
				"properties": {
					"node_paths": {"type": "array", "description": "Optional array of node paths to annotate. If omitted, annotates all 2D visual and collision nodes.", "items": {"type": "string"}},
					"show_labels": {"type": "boolean", "description": "Whether to draw text labels with node names (default true)."},
					"show_bounds": {"type": "boolean", "description": "Whether to outline node bounding boxes (default true)."},
					"show_axes": {"type": "boolean", "description": "Whether to draw pivot crosshairs (default true)."},
					"show_camera": {"type": "boolean", "description": "Whether to outline Camera2D visible rect if camera exists (default true)."},
					"max_width": {"type": "integer", "description": "Maximum width of output image in pixels (default 640)."},
					"save_path": {"type": "string", "description": "Path to save preview PNG (default user://godot_agent_previews/spatial_overlay.png)."}
				}
			}
		},
		"inspect_collision_geometry": {
			"desc": "Inspect deep collision geometry of CollisionShape2D, CollisionPolygon2D, or physics bodies: shape type, exact local and global dimensions, transforms, non-unit scale warnings, disabled state, one-way collision, layers/masks, and shared resource detection.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to CollisionShape2D, CollisionPolygon2D, or parent physics body (CharacterBody2D, StaticBody2D, Area2D, etc.)."}
				},
				"required": ["node_path"]
			}
		},
		"measure_visual_bounds": {
			"desc": "Measure visual bounds and opaque silhouette of a Sprite2D or AnimatedSprite2D using source texture alpha analysis: calculates tight opaque bounding rect, centering/offset, ground baseline Y (feet line), and multi-frame animation envelopes.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to Sprite2D or AnimatedSprite2D, or parent node containing one."},
					"animation": {"type": "string", "description": "Optional animation name for AnimatedSprite2D (default current animation)."},
					"frame_index": {"type": "integer", "description": "Optional specific frame index (-1 for union envelope across all frames)."},
					"alpha_threshold": {"type": "number", "description": "Alpha threshold (0.0 to 1.0) for considering a pixel opaque (default 0.05)."}
				},
				"required": ["node_path"]
			}
		},
		"calibrate_collision_shape": {
			"desc": "Calibrate a 2D collision shape to tightly and professionally match visual artwork: supports gameplay profiles (platformer_body, top_down_body, solid_object, hurtbox, attack_hitbox, trigger), ground baseline feet alignment, non-unit scale reset, and safe duplication of shared resources. Set apply=true to commit changes.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to CollisionShape2D or parent physics body."},
					"visual_node_path": {"type": "string", "description": "Optional path to Sprite2D or AnimatedSprite2D (auto-discovered if omitted)."},
					"profile": {"type": "string", "description": "Gameplay collision profile: 'platformer_body' (capsule, 85% width, feet grounded), 'top_down_body' (bottom 40% legs/shadow), 'solid_object' (100% full bounds), 'hurtbox' (90% generous to player), 'attack_hitbox' (110% generous hit), 'trigger', or 'custom'.", "enum": ["platformer_body", "top_down_body", "solid_object", "hurtbox", "attack_hitbox", "trigger", "custom"]},
					"shape_type": {"type": "string", "description": "Shape type to use ('CapsuleShape2D', 'RectangleShape2D', 'CircleShape2D', or 'keep')."},
					"width_factor": {"type": "number", "description": "Optional custom width multiplier relative to visual bounds."},
					"height_factor": {"type": "number", "description": "Optional custom height multiplier relative to visual bounds."},
					"align_feet": {"type": "boolean", "description": "Whether to align the bottom edge of the collider exactly with the visual ground baseline (default true for platformer_body)."},
					"make_unique": {"type": "boolean", "description": "Whether to duplicate shared shape resources before modifying to prevent cross-node mutation (default true)."},
					"reset_scale": {"type": "boolean", "description": "Whether to reset non-unit collider scale to (1.0, 1.0) and bake size into shape resource (default true)."},
					"apply": {"type": "boolean", "description": "If false (default), runs in dry-run analysis mode without mutating the scene. Set true to commit changes."}
				},
				"required": ["node_path"]
			}
		},
		"preview_collision_overlay": {
			"desc": "Generate a side-by-side visual preview image overlaying the sprite artwork, opaque silhouette bounds (blue), ground baseline (cyan), current collider (red), and proposed calibrated collider (green).",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to CollisionShape2D or parent physics body."},
					"visual_node_path": {"type": "string", "description": "Optional path to Sprite2D or AnimatedSprite2D."},
					"profile": {"type": "string", "description": "Collision profile to preview ('platformer_body', 'top_down_body', etc.)."},
					"scale_factor": {"type": "integer", "description": "Pixel upscale multiplier (e.g. 2, 4) for crisp pixel art preview (default auto)."},
					"save_path": {"type": "string", "description": "Path to save preview PNG (default user://godot_agent_previews/collision_overlay.png)."}
				},
				"required": ["node_path"]
			}
		},
		"inspect_scene_diff": {
			"desc": "Inspect scene tree changes against an optional baseline snapshot or view current scene tree hierarchy diff.",
			"params": {
				"type": "object",
				"properties": {
					"baseline": {"type": "object", "description": "Optional previous scene tree snapshot to diff against."}
				}
			}
		},
		"set_task_criteria": {
			"desc": "Declare acceptance criteria ledger for the active task. Completion requires verifying each criterion with evidence.",
			"params": {
				"type": "object",
				"properties": {
					"criteria": {
						"type": "array",
						"description": "List of criterion objects with id, description, required_evidence, status ('pending', 'in_progress', 'passed', 'failed', 'unverified', 'blocked').",
						"items": {"type": "object"}
					},
					"task_id": {"type": "string", "description": "Optional task ID (defaults to active task)."}
				},
				"required": ["criteria"]
			}
		},
		"validate_tileset_physics": {
			"desc": "Perform complete 7-step TileSet and TileMapLayer physics collision verification: inspects physics layers, per-tile TileData collision polygons, layer/mask compatibility, and body interaction.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to TileMapLayer (or TileMap)."},
					"physics_layer_index": {"type": "integer", "description": "Index of TileSet physics layer to validate (default 0)."},
					"body_path": {"type": "string", "description": "Optional path to CharacterBody2D or physics body to test collision mask compatibility."}
				}
			}
		},
		"test_runtime_action": {
			"desc": "Validate or register an InputMap action with key/button bindings and test editor-level dispatch. Note: In-editor execution does not step physics frames on scene nodes; use run_game or runtime MCP tools for live gameplay simulation.",
			"params": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "description": "Name of the InputMap action to simulate."},
					"duration_seconds": {"type": "number", "description": "Duration in seconds to hold the action (default 0.5s, max 5s)."},
					"node_path": {"type": "string", "description": "Path to target node to observe (e.g. 'Player')."},
					"expected_condition": {"type": "string", "description": "Expected condition to verify (e.g. 'player moved right')."},
					"auto_create": {"type": "boolean", "description": "When true (default), automatically loads from ProjectSettings or auto-registers the action in InputMap if missing with standard default keybindings."}
				},
				"required": ["action"]
			}
		},
		"navigate_viewport": {
			"desc": "Pan, zoom, center, and capture the Godot 2D editor workspace viewport or scene Camera2D. Can center on specific [x, y] coordinates or frame a target node. When capture=true (default), immediately captures and returns a screenshot so the vision model can inspect the framed area.",
			"params": {
				"type": "object",
				"properties": {
					"position": {"type": "array", "description": "Target [x, y] coordinates in world space to center the viewport on.", "items": {"type": "number"}},
					"node_path": {"type": "string", "description": "Node path in active scene to center and frame the viewport on."},
					"zoom": {"type": "number", "description": "Target zoom factor for Camera2D (e.g. 1.0, 1.5, 0.5)."},
					"zoom_delta": {"type": "integer", "description": "Editor zoom steps: positive to zoom in (+1, +2), negative to zoom out (-1, -2)."},
					"target": {"type": "string", "description": "Target to navigate: 'editor' (default, 2D editor canvas), 'camera' (scene Camera2D), or 'both'."},
					"capture": {"type": "boolean", "description": "Whether to immediately capture and return a screenshot after navigating. Default is true."}
				}
			}
		},
		"configure_input_action": {
			"desc": "Define or update an InputMap action, assign key/mouse/joypad events, set deadzone, and persist immediately to ProjectSettings (project.godot) and runtime InputMap.",
			"params": {
				"type": "object",
				"properties": {
					"action": {"type": "string", "description": "Action name (e.g. 'move_right', 'move_left', 'jump', 'attack')."},
					"keys": {"type": "array", "description": "List of key names or codes to bind (e.g. ['D', 'Right'], ['Space'], ['W', 'Up']).", "items": {"type": "string"}},
					"deadzone": {"type": "number", "description": "Input action deadzone (default 0.5)."},
					"replace": {"type": "boolean", "description": "When true (default), replaces existing events for this action instead of appending."}
				},
				"required": ["action"]
			}
		},
		"discover_capabilities": {
			"desc": "Discover available engine and agent capabilities (scene mutation, tilemap physics, runtime input simulation, visual inspection) for planning verifiable execution.",
			"params": {
				"type": "object",
				"properties": {}
			}
		},
		"inspect_animation_player": {
			"desc": "Discover animation libraries, animation names, durations, loop modes, autoplay, speed scale, blend times, root paths, and playback status.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationPlayer (defaults to first AnimationPlayer child in scene)."},
					"library": {"type": "string", "description": "Optional library name filter."}
				}
			}
		},
		"inspect_animation_tracks": {
			"desc": "Read track types, target paths, track indices, keyframe timestamps and values, interpolation, and update modes. Support property, transform, method-call, audio, and other applicable track types.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationPlayer."},
					"animation": {"type": "string", "description": "Name of animation to inspect (defaults to current or first animation)."},
					"track_index": {"type": "integer", "description": "Optional specific track index to inspect (-1 for all tracks)."}
				}
			}
		},
		"edit_animation_player": {
			"desc": "Create or edit animations, libraries, tracks and keyframes; configure duration, looping, autoplay, playback speed, and cross-fade settings. Support safe rename and removal operations.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationPlayer."},
					"operation": {"type": "string", "description": "Operation: create_animation, edit_animation, remove_animation, rename_animation, set_autoplay, set_speed_scale, set_blend_time, add_track, remove_track, insert_keyframe, remove_keyframe, create_library, remove_library."},
					"animation": {"type": "string", "description": "Target animation name."},
					"duration": {"type": "number", "description": "Animation duration in seconds."},
					"loop_mode": {"type": "string", "description": "Loop mode: none, linear, pingpong."},
					"step": {"type": "number", "description": "Step interval in seconds."},
					"track_type": {"type": "string", "description": "Track type: property, method, audio, bezier, position_3d, rotation_3d, scale_3d."},
					"path": {"type": "string", "description": "Track target path (e.g. 'Sprite2D:frame', 'Player:position')."},
					"time": {"type": "number", "description": "Keyframe timestamp in seconds."},
					"value": {"description": "Keyframe value (int, float, Vector2, string, etc.)."},
					"transition": {"type": "number", "description": "Keyframe easing transition (default 1.0)."},
					"interpolation": {"type": "string", "description": "Interpolation: nearest, linear, cubic."},
					"update_mode": {"type": "string", "description": "Update mode: continuous, discrete, capture."},
					"track_index": {"type": "integer", "description": "Track index."},
					"key_index": {"type": "integer", "description": "Keyframe index."},
					"old_name": {"type": "string", "description": "Old animation name for rename."},
					"new_name": {"type": "string", "description": "New animation name for rename."},
					"library_name": {"type": "string", "description": "AnimationLibrary name for create/remove library."},
					"anim_from": {"type": "string", "description": "Source animation for cross-fade blend time."},
					"anim_to": {"type": "string", "description": "Destination animation for cross-fade blend time."},
					"blend_time": {"type": "number", "description": "Blend time in seconds."}
				},
				"required": ["operation"]
			}
		},
		"inspect_animation_tree": {
			"desc": "Read its linked AnimationPlayer, root node, blend graph, state machine, connections, parameters, and relevant configuration.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationTree (defaults to first AnimationTree child in scene)."}
				}
			}
		},
		"edit_animation_tree": {
			"desc": "Create or modify blend trees, animation nodes, graph connections, graph positions, and the tree root. Verify all referenced animation names against the linked AnimationPlayer.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationTree."},
					"operation": {"type": "string", "description": "Operation: set_tree_root, set_anim_player, set_active, add_node, remove_node, connect_nodes, disconnect_nodes, set_node_position."},
					"root_type": {"type": "string", "description": "Root type: AnimationNodeStateMachine, AnimationNodeBlendTree, AnimationNodeBlendSpace2D, AnimationNodeBlendSpace1D."},
					"anim_player": {"type": "string", "description": "NodePath to linked AnimationPlayer."},
					"active": {"type": "boolean", "description": "Set AnimationTree active state."},
					"node_name": {"type": "string", "description": "Name for new or target blend node."},
					"node_type": {"type": "string", "description": "Blend node type: AnimationNodeAnimation, AnimationNodeBlend2, AnimationNodeBlend3, AnimationNodeOneShot, AnimationNodeTimeScale, AnimationNodeTransition."},
					"animation": {"type": "string", "description": "Animation name in AnimationPlayer for AnimationNodeAnimation."},
					"position": {"description": "Graph node position [x, y] or Vector2."},
					"input_node": {"type": "string", "description": "Source node name in connection."},
					"input_index": {"type": "integer", "description": "Input port index in connection (default 0)."},
					"output_node": {"type": "string", "description": "Target node name in connection (e.g. 'output')."}
				},
				"required": ["operation"]
			}
		},
		"edit_animation_state_machine": {
			"desc": "Add, rename, and remove states; add transitions; configure transition duration, switch mode, advance conditions, priorities, and reset behavior. Verify that required states are reachable.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationTree containing state machine root."},
					"operation": {"type": "string", "description": "Operation: add_state, remove_state, rename_state, set_start_node, set_end_node, add_transition, remove_transition."},
					"state_name": {"type": "string", "description": "State name to add, remove, or configure."},
					"animation": {"type": "string", "description": "Animation name to play in state."},
					"position": {"description": "State node position in graph [x, y]."},
					"old_name": {"type": "string", "description": "Current state name for rename."},
					"new_name": {"type": "string", "description": "New state name for rename."},
					"from_state": {"type": "string", "description": "Source state for transition (e.g. 'idle', 'Start')."},
					"to_state": {"type": "string", "description": "Destination state for transition (e.g. 'walk', 'End')."},
					"switch_mode": {"type": "string", "description": "Switch mode: immediate, sync, at_end."},
					"advance_mode": {"type": "string", "description": "Advance mode: disabled, enabled, auto."},
					"advance_condition": {"type": "string", "description": "Condition name in parameters/conditions/<name>."},
					"advance_expression": {"type": "string", "description": "Expression string evaluated for transition."},
					"xfade_time": {"type": "number", "description": "Cross-fade duration in seconds."},
					"priority": {"type": "integer", "description": "Transition priority order (default 1)."},
					"reset_teleport": {"type": "boolean", "description": "Whether playback teleports to start of destination animation."}
				},
				"required": ["operation"]
			}
		},
		"edit_animation_blend_space": {
			"desc": "Configure BlendSpace1D and BlendSpace2D points, animation references, point positions, blend mode, and supported synchronization settings.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationTree containing blend space root."},
					"operation": {"type": "string", "description": "Operation: set_space_limits, add_point, remove_point, set_point_position, add_triangle, auto_triangles."},
					"min_space": {"description": "Minimum space coordinate(s) [x, y] or float."},
					"max_space": {"description": "Maximum space coordinate(s) [x, y] or float."},
					"snap": {"description": "Grid snap increment [x, y] or float."},
					"blend_mode": {"type": "string", "description": "Blend mode: interpolated, discrete, discrete_carry."},
					"animation": {"type": "string", "description": "Animation name for blend point."},
					"position": {"description": "Point coordinate [x, y] or float."},
					"point_index": {"type": "integer", "description": "Point index to configure or remove."},
					"point_1": {"type": "integer", "description": "First triangle point index."},
					"point_2": {"type": "integer", "description": "Second triangle point index."},
					"point_3": {"type": "integer", "description": "Third triangle point index."},
					"auto_triangles": {"type": "boolean", "description": "Enable automatic Delaunay triangulation."}
				},
				"required": ["operation"]
			}
		},
		"get_set_animation_parameters": {
			"desc": "Inspect and set actual AnimationTree parameter paths for blend positions, transition requests, OneShot requests, and state-machine playback where supported.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationTree."},
					"parameters": {"type": "object", "description": "Dictionary of {parameter_path: value} to set on tree."},
					"filter": {"type": "string", "description": "Optional substring filter for inspecting parameters."}
				}
			}
		},
		"validate_animation_system": {
			"desc": "Check animation references, track paths, missing targets, malformed graph connections, invalid state references, tree-player linkage, required transitions, and saved resource integrity.",
			"params": {
				"type": "object",
				"properties": {
					"player_path": {"type": "string", "description": "Optional path to AnimationPlayer."},
					"tree_path": {"type": "string", "description": "Optional path to AnimationTree."},
					"node_path": {"type": "string", "description": "Path to either animation node or scene root."}
				}
			}
		},
		"test_animation_runtime": {
			"desc": "When the runtime supports it, play or transition to a target animation state, wait for a specified condition, inspect the current animation/state, check relevant properties, and return real observed results. Distinguish runtime testing from static resource validation.",
			"params": {
				"type": "object",
				"properties": {
					"node_path": {"type": "string", "description": "Path to AnimationPlayer or AnimationTree."},
					"target_animation": {"type": "string", "description": "Animation name to play (for AnimationPlayer)."},
					"target_state": {"type": "string", "description": "State machine state to travel to (for AnimationTree)."},
					"parameters": {"type": "object", "description": "Optional parameters to set before testing."},
					"duration_seconds": {"type": "number", "description": "Duration to advance/simulate (default 0.2s, max 5s)."},
					"expected_condition": {"type": "string", "description": "Expected condition description to verify."}
				}
			}
		},
	}
