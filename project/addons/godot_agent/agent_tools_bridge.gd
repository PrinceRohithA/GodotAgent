@tool
extends RefCounted
## Routes only executable native tools and live MCP public tools.

signal log(msg: String)
signal tools_known_changed

const MAX_MODEL_TOOLS := 128

const LOCAL_TOOL_NAMES := [
	"inspect_project", "inspect_scene", "inspect_node", "list_files", "read_script",
	"write_script", "patch_script", "get_diagnostics", "set_property", "edit_node",
	"create_node", "delete_node", "delete_nodes", "reparent_node",
	"create_node_hierarchy", "create_collision_for_sprite", "create_sprite_frames",
	"create_scene", "attach_script", "save_scene", "run_game", "stop_game",
	"settings_get", "settings_set", "undo", "redo", "list_history", "playtest_wait",
	"delete_file", "restore_deleted_path", "run_shell", "reimport_assets", "web_search", "capture_viewport",
	"inspect_asset_image", "get_output_errors",
	"analyze_atlas_geometry", "preview_labelled_atlas", "inspect_tile_crop",
	"catalog_atlas_tiles", "validate_atlas_coords",
	"inspect_player_metrics", "inspect_tilemap_layer",
	"paint_tilemap_cells", "paint_tilemap_rect",
	"inspect_spatial_context", "convert_spatial_coordinates",
	"inspect_spatial_region", "query_spatial_relationships", "preview_spatial_overlay",
	"inspect_collision_geometry", "measure_visual_bounds",
	"calibrate_collision_shape", "preview_collision_overlay",
	"inspect_scene_diff", "set_task_criteria",
	"validate_tileset_physics", "test_runtime_action", "discover_capabilities",
	"inspect_animation_player", "inspect_animation_tracks", "edit_animation_player",
	"inspect_animation_tree", "edit_animation_tree", "edit_animation_state_machine",
	"edit_animation_blend_space", "get_set_animation_parameters",
	"validate_animation_system", "test_animation_runtime",
	"instance_scene", "toggle_debug_collisions", "invoke_level_designer",
	"auto_generate_atlas_tiles",
	"configure_input_action",
	"navigate_viewport",
	"search_mcp_tools", "activate_mcp_tools", "select_mcp_profile", "call_mcp_tool",
	"list_tool_bundles", "unpack_tool_bundle", "pack_tool_bundle",
]

# Specialized tool bundles for modular, window-capped loading (Option 1).
const TOOL_BUNDLES := {
	"physics": {
		"description": "2D/3D physics bodies, collision shapes, raycasts, layers, and masks",
		"prefixes": ["godot_physics_"],
		"keywords": ["physics", "collision", "collider", "collide", "body", "rigidbody", "characterbody", "staticbody", "animatablebody", "raycast", "gravity", "hitbox", "hurtbox", "velocity", "jump", "area2d", "area3d", "kinematic", "bounce", "friction", "calibrate", "calibration", "visual_bounds", "opaque", "feet", "baseline", "silhouette", "player", "character", "enemy", "controller", "movement", "platformer", "toggle_debug_collisions", "debug_collision"],
	},
	"tilemap": {
		"description": "TileMap and TileSet editing, layers, cells, terrain, and collision",
		"prefixes": ["godot_tilemap_"],
		"keywords": ["tile", "tilemap", "tileset", "tilemaplayer", "atlas", "cell", "terrain", "grid", "autotile", "tiles", "ground", "platform", "paint", "draw_tiles", "crop", "catalog", "preview", "metrics", "player_metrics", "jump", "layer", "level", "stage", "map", "world", "platformer", "level_design", "level_designer", "instance_scene", "invoke_level_designer", "polygon", "slope", "auto_generate_atlas_tiles", "auto_generate", "generate_tiles", "create_atlas_tiles"],
	},
	"animation": {
		"description": "Author animations, keyframes, AnimationTree state machines, blend trees, and sprite frames",
		"prefixes": ["godot_animation_"],
		"keywords": ["animation", "anim", "animate", "animated", "track", "keyframe", "spriteframes", "blend", "statemachine", "animatedsprite", "animationplayer", "animationtree", "spritesheet", "walk", "idle", "transition"],
	},
	"scene_3d": {
		"description": "Build 3D scenes: mesh instances, cameras, lights, WorldEnvironment, and GridMap cells",
		"prefixes": ["godot_scene_3d_"],
		"keywords": ["3d", "mesh", "meshinstance", "camera3d", "light3d", "omnilight", "directionallight", "spotlight", "environment", "worldenvironment", "gridmap", "sky", "lighting", "model"],
	},
	"spatial": {
		"description": "Structured spatial observation: transforms, 2D/3D bounds, coordinates, clearances, regions, relationships",
		"prefixes": ["godot_spatial_"],
		"keywords": ["spatial", "transform", "aabb", "bounds", "pivot", "position", "distance", "coordinates", "orientation", "bounding_box", "clearance", "region", "relationships", "support_surface", "reachability", "overlay"],
	},
	"audio": {
		"description": "Setup audio: stream players, audio bus layout, and effects",
		"prefixes": ["godot_audio_"],
		"keywords": ["audio", "sound", "music", "sfx", "bgm", "stream", "bus", "volume", "pitch", "audioplayer", "soundtrack", "jingle", "reverb"],
	},
	"particles": {
		"description": "Create GPU particle systems: process materials, color gradients, and VFX",
		"prefixes": ["godot_particles_"],
		"keywords": ["particle", "particles", "vfx", "emitter", "gpu", "explosion", "smoke", "sparks", "fire", "dust", "blood", "magic", "sparkle", "gpuparticles"],
	},
	"navigation": {
		"description": "Navigation authoring: regions, agents, navmesh baking, and layers",
		"prefixes": ["godot_navigation_"],
		"keywords": ["nav", "navigation", "navmesh", "agent", "pathfinding", "patrol", "obstacle", "chase", "route", "waypoint", "navigationregion", "navigationagent"],
	},
	"ui": {
		"description": "Themes, color overrides, font sizes, and styleboxes on Control nodes",
		"prefixes": ["godot_theme_ui_"],
		"keywords": ["ui", "theme", "gui", "button", "label", "control", "font", "stylebox", "hud", "menu", "canvaslayer", "panel", "container", "dialog", "healthbar"],
	},
	"shaders": {
		"description": "Create and edit GDShader files, ShaderMaterial, and Visual Shader graphs",
		"prefixes": ["godot_shader_", "godot_visual_shader_"],
		"keywords": ["shader", "material", "visualshader", "fragment", "vertex", "glsl", "gdshader", "glow", "outline", "dissolve", "water", "postprocess"],
	},
	"runtime_debugger": {
		"description": "Live game observation, runtime properties, breakpoints, and stack traces",
		"prefixes": ["godot_runtime_", "godot_debugger_"],
		"keywords": ["debug", "runtime", "breakpoint", "stack", "monitor", "watch", "live", "inspect_runtime", "running_game", "crash", "error", "stacktrace"],
	},
	"input": {
		"description": "Simulate key, mouse, and action input during play sessions",
		"prefixes": ["godot_input_"],
		"keywords": ["input", "simulate", "keyboard", "mouse", "action", "keypress", "click", "press", "playtest_input", "keystroke", "simulate_key"],
	},
	"composite": {
		"description": "Batch node creation and batch property edits in single transactions",
		"prefixes": ["godot_composite_"],
		"keywords": ["batch", "composite", "bulk", "multi", "many_nodes", "batch_create", "batch_edit"],
	},
	"profiling": {
		"description": "Performance monitors: FPS, draw calls, memory, physics time",
		"prefixes": ["godot_profiling_"],
		"keywords": ["profile", "profiling", "fps", "performance", "memory", "draw_calls", "lag", "bottleneck", "framerate", "vram"],
	},
	"vision": {
		"description": "Visual reasoning: inspect asset images with pixel dimensions, capture editor viewport and runtime game screenshot",
		"prefixes": ["godot_editor_capture_", "godot_runtime_capture_", "inspect_asset_"],
		"keywords": ["screenshot", "capture", "image", "visual", "look", "see", "vision", "viewport", "screen", "picture", "snapshot", "photo", "asset", "dimension", "dimensions", "pixels", "texture", "sprite"],
	},
}

# These are always retained so a profile switch cannot strand the agent without
# project inspection, scene/script editing, or a way to verify its work.
const PINNED_MCP_TOOLS := [
	"godot_health_check", "godot_list_history", "godot_undo", "godot_redo",
	"godot_enable_toolset", "godot_disable_toolset",
	"godot_inspection_get_project_info", "godot_inspection_get_active_scene", "godot_inspection_get_scene_tree", "godot_inspection_list_scenes",
	"godot_project_get_filesystem_tree", "godot_project_search_files",
	"godot_scene_edit_create_scene", "godot_scene_edit_open_scene", "godot_scene_edit_save_scene", "godot_scene_edit_create_node", "godot_scene_edit_delete_node", "godot_scene_edit_set_node_property",
	"godot_scripts_list", "godot_scripts_read", "godot_scripts_write", "godot_scripts_get_parse_errors",
	"godot_runtime_run_and_capture", "godot_runtime_is_playing", "godot_runtime_stop_scene",
]

# Explicitly disallowed tools to prevent false-completion loops or misleading diagnostics.
const DISALLOWED_MCP_TOOLS := [
	"godot_debug_workflow",
]

const PROFILE_PREFIXES := {
	"baseline": [],
	"full_game_authoring": [
		"godot_scene_edit_", "godot_scripts_", "godot_project_", "godot_runtime_", "godot_debugger_", "godot_debug_",
		"godot_animation_", "godot_tilemap_", "godot_input_", "godot_editor_", "godot_composite_", "godot_resources_", "godot_inspection_", "godot_spatial_",
		"godot_physics_", "godot_scene_3d_", "godot_audio_", "godot_navigation_", "godot_shader_", "godot_particles_", "godot_theme_ui_", "godot_profiling_",
	],
}

class AgentHistory:
	extends RefCounted
	var undo_entries: Array = []
	var redo_entries: Array = []
	func record(label: String, undo_call: Callable, redo_call: Callable, meta: Dictionary = {}) -> void:
		undo_entries.append({"label": label, "undo": undo_call, "redo": redo_call, "meta": meta})
		redo_entries.clear()
		if undo_entries.size() > 100: undo_entries.pop_front()
	func undo(steps: int = 1) -> Dictionary:
		var count := 0
		while count < maxi(steps, 1) and not undo_entries.is_empty():
			var entry: Dictionary = undo_entries.pop_back()
			if int(entry["undo"].call()) != OK:
				undo_entries.append(entry)
				return {"ok": false, "undone": count, "error": "undo_failed"}
			redo_entries.append(entry); count += 1
		return {"ok": true, "undone": count, "can_redo": not redo_entries.is_empty()}
	func redo(steps: int = 1) -> Dictionary:
		var count := 0
		while count < maxi(steps, 1) and not redo_entries.is_empty():
			var entry: Dictionary = redo_entries.pop_back()
			if int(entry["redo"].call()) != OK:
				redo_entries.append(entry)
				return {"ok": false, "redone": count, "error": "redo_failed"}
			undo_entries.append(entry); count += 1
		return {"ok": true, "redone": count, "can_undo": not undo_entries.is_empty()}
	func snapshot() -> Dictionary:
		var labels: Array = []
		for entry in undo_entries.slice(maxi(0, undo_entries.size() - 20)):
			labels.append(str(entry.get("label", "")))
		return {"undo_depth": undo_entries.size(), "redo_depth": redo_entries.size(), "can_undo": not undo_entries.is_empty(), "can_redo": not redo_entries.is_empty(), "recent": labels}

var _parent: Node
var _local: RefCounted
var _history: RefCounted
var _catalog: RefCounted
var _mcp: Node
var _web: Node
var _cfg: RefCounted
var _mcp_tools: Array = []
var _selected_mcp_tools: Array = []
var _selected_profile := "baseline"
var _explicit_mcp_tools: Array = []
var _unpacked_bundles: Array = []
var _last_bundle_notice := ""
var _mcp_error := ""
var _mcp_state := "native_ready"
var _call_serial := 0
var _pending: Dictionary = {}
var _task_runtime: RefCounted
var _map := preload("res://addons/godot_agent/mcp_mapping.gd").new()

func _ensure_components() -> void:
	if _history == null:
		_history = AgentHistory.new()
	if _catalog == null:
		var cat_script: GDScript = preload("res://addons/godot_agent/agent_tool_catalog.gd")
		if cat_script != null and cat_script.can_instantiate():
			_catalog = cat_script.new()
	if _local == null:
		var loc_script: GDScript = preload("res://addons/godot_agent/agent_local_tools.gd")
		if loc_script != null and loc_script.can_instantiate():
			_local = loc_script.new()
			_local.history = _history
			if _task_runtime != null:
				_local.task_runtime = _task_runtime

func _init() -> void:
	_ensure_components()

func attach(parent: Node) -> void:
	_parent = parent
	if _mcp == null:
		_mcp = preload("res://addons/godot_agent/agent_mcp_client.gd").new()
		_parent.add_child(_mcp)
		_mcp.connected.connect(_on_mcp_connected)
		_mcp.disconnected.connect(_on_mcp_disconnected)
		_mcp.tools_changed.connect(_on_mcp_connected)
		_mcp.tool_finished.connect(_on_mcp_tool_finished)
	if _web == null:
		_web = preload("res://addons/godot_agent/agent_web_search.gd").new()
		_parent.add_child(_web)
		_web.cfg = _cfg
	tools_known_changed.emit()

func set_config(config: RefCounted) -> void:
	_cfg = config
	if _web != null: _web.cfg = _cfg

func set_task_runtime(rt: RefCounted) -> void:
	_task_runtime = rt
	if _local != null:
		_local.task_runtime = rt

func start() -> void:
	_ensure_components()
	log.emit("Native editor tools ready: %d" % _native_tool_names().size())
	var data: Dictionary = _cfg.data() if _cfg != null else {}
	var mcp_config: Dictionary = data.get("mcp", {})
	if bool(mcp_config.get("enabled", true)) and _mcp != null:
		_mcp_state = "mcp_connecting"
		_mcp.start(str(mcp_config.get("endpoint", "http://127.0.0.1:9090/mcp")))
	else:
		_mcp_state = "mcp_offline"
		_mcp_error = "MCP disabled in agent configuration"
	tools_known_changed.emit()

func stop() -> void:
	if _mcp != null:
		_mcp.stop(); _mcp.queue_free(); _mcp = null
	if _web != null:
		_web.queue_free(); _web = null
	_pending.clear()

func is_mcp_connected() -> bool:
	return _mcp != null and _mcp.is_mcp_ready()

func tools_known() -> bool:
	return true

func tool_names() -> Array:
	_ensure_components()
	if _catalog != null:
		return _catalog.tool_names(_native_tool_names(), _active_mcp_tools())
	return _native_tool_names()

func list_openai_tools() -> Array:
	_ensure_components()
	if _catalog != null:
		return _catalog.list_openai_tools(_native_tool_names(), _active_mcp_tools())
	var fallback: Array = []
	for n in _native_tool_names():
		fallback.append({
			"type": "function",
			"function": {
				"name": str(n),
				"description": "Godot agent native tool: " + str(n),
				"parameters": {"type": "object", "properties": {}, "additionalProperties": true}
			}
		})
	return fallback

func backend_status() -> Dictionary:
	var active_count := _active_mcp_tools().size()
	var pinned_count := _pinned_mcp_tools().size()
	return {
		"state": _mcp_state,
		"native_count": _native_tool_names().size(),
		"mcp_count": _mcp_tools.size() if is_mcp_connected() else 0,
		"model_mcp_count": active_count,
		"mcp_capacity": _model_mcp_capacity(),
		"pinned_mcp_count": pinned_count,
		"optional_mcp_count": maxi(0, active_count - pinned_count),
		"on_demand_mcp_count": maxi(0, _mcp_tools.size() - active_count),
		"profile": _selected_profile,
		"active_bundles": _unpacked_bundles.duplicate(),
		"all_bundles": TOOL_BUNDLES.keys(),
		"last_notice": _last_bundle_notice,
		"mcp_unavailable_intents": _unavailable_intents().size(),
		"last_error": _mcp_error
	}

func capability_registry() -> Array:
	var available := {}
	for remote in _mcp_tools:
		if typeof(remote) == TYPE_DICTIONARY: available[str(remote.get("name", ""))] = true
	var out: Array = []
	for intent in _map.ABSTRACT_TO_MCP:
		var spec: Dictionary = _map.ABSTRACT_TO_MCP[intent]
		var candidates: Array = spec.get("mcp_tools", [])
		var resolved: Array = []
		for candidate in candidates:
			if available.has(str(candidate)): resolved.append(candidate)
		var is_native: bool = (_local != null and _local.has_tool(str(intent)))
		out.append({"intent": intent, "source": "native" if is_native else "mcp", "available": is_native or not resolved.is_empty(), "mcp_tools": candidates, "resolved": resolved, "toolsets": spec.get("toolsets", [])})
	return out

func call_tool_async(name: String, args: Dictionary, completed: Callable) -> void:
	if name in DISALLOWED_MCP_TOOLS or name == "godot_debug_workflow":
		completed.call_deferred({
			"ok": false,
			"error": "tool_deprecated_and_removed",
			"name": name,
			"message": "godot_debug_workflow has been removed to prevent false completion conclusions. Use get_output_errors, inspect_spatial_context, run_game, or inspect_collision_geometry to verify actual task acceptance criteria."
		})
		return
	if name == "search_mcp_tools":
		completed.call_deferred(_search_mcp_tools(args))
		return
	if name == "activate_mcp_tools":
		completed.call_deferred(_activate_mcp_tools(args))
		return
	if name == "select_mcp_profile":
		completed.call_deferred(_select_mcp_profile(str(args.get("profile", ""))))
		return
	if name == "call_mcp_tool":
		_call_discovered_mcp(args, completed)
		return
	if name == "list_tool_bundles":
		completed.call_deferred(_list_tool_bundles(args))
		return
	if name == "unpack_tool_bundle":
		completed.call_deferred(_unpack_tool_bundle(args))
		return
	if name == "pack_tool_bundle":
		completed.call_deferred(_pack_tool_bundle(args))
		return
	var scope := str(args.get("scope", "native"))
	if name in ["undo", "redo", "list_history"] and scope == "mcp_editor":
		_call_mcp("godot_list_history" if name == "list_history" else "godot_" + name, _without_scope(args), completed)
		return
	var target_name := name
	match name:
		"add_node":
			target_name = "create_node"
		"remove_node":
			target_name = "delete_node"
		"delete_nodes_batch", "batch_delete_nodes", "bulk_delete_nodes":
			target_name = "delete_nodes"
		"move_node":
			target_name = "reparent_node"
		"set_node_property":
			target_name = "set_property"
		"godot_scene_edit_create_node":
			target_name = "create_node"
		"godot_scene_edit_set_node_property":
			target_name = "set_property"
		"godot_scene_edit_delete_node":
			target_name = "delete_node"
		"build_hierarchy", "create_hierarchy":
			target_name = "create_node_hierarchy"
		"add_collision_shape":
			target_name = "create_collision_for_sprite"
		"build_sprite_frames", "godot_animation_create_sprite_frames":
			target_name = "create_sprite_frames"
		"get_editor_output", "inspect_output_panel", "read_output_log", "output_errors":
			target_name = "get_output_errors"
		"reimport_files", "reimport_asset":
			target_name = "reimport_assets"
		"preview_coordinate_labelled_atlas", "inspect_atlas_geometry":
			target_name = "preview_labelled_atlas" if name == "preview_coordinate_labelled_atlas" else "analyze_atlas_geometry"
		"generate_tile_catalog":
			target_name = "catalog_atlas_tiles"
		"measure_player_metrics":
			target_name = "inspect_player_metrics"
		"tilemap_layer_inspect":
			target_name = "inspect_tilemap_layer"
		"tilemap_paint_cells":
			target_name = "paint_tilemap_cells"
		"tilemap_paint_rect":
			target_name = "paint_tilemap_rect"
		"spatial_context", "spatial_inspect":
			target_name = "inspect_spatial_context"
		"convert_coordinates", "convert_coords":
			target_name = "convert_spatial_coordinates"
		"spatial_region", "inspect_region":
			target_name = "inspect_spatial_region"
		"spatial_relationships", "query_relationships":
			target_name = "query_spatial_relationships"
		"spatial_overlay", "draw_spatial_overlay":
			target_name = "preview_spatial_overlay"
		"collision_geometry", "inspect_collider", "inspect_collision":
			target_name = "inspect_collision_geometry"
		"visual_bounds", "measure_sprite_bounds", "sprite_bounds":
			target_name = "measure_visual_bounds"
		"calibrate_collision", "calibrate_collider", "fit_collision_shape":
			target_name = "calibrate_collision_shape"
		"collision_overlay", "preview_collision":
			target_name = "preview_collision_overlay"
		"instantiate_scene", "add_instance", "instance_child_scene":
			target_name = "instance_scene"
		"toggle_collision_debug", "debug_collisions_toggle", "set_debug_collisions":
			target_name = "toggle_debug_collisions"
		"delegate_level_design", "level_designer_agent", "run_level_designer":
			target_name = "invoke_level_designer"
		"setup_tilemap_atlas", "tileset_auto_create_tiles", "create_atlas_tiles":
			target_name = "auto_generate_atlas_tiles"
		"add_input_action", "input_map_add_action", "set_input_action":
			target_name = "configure_input_action"
		"pan_viewport", "zoom_viewport", "pan_zoom_viewport", "focus_viewport":
			target_name = "navigate_viewport"
		"play_scene":
			target_name = "godot_runtime_play_scene"
		"stop_scene":
			target_name = "godot_runtime_stop_scene"
		"is_playing":
			target_name = "godot_runtime_is_playing"
		"simulate_key", "simulate_action", "simulate_mouse", "play_sequence":
			target_name = "godot_input_" + name
		"playtest_input":
			var kind := str(args.get("kind", "")).to_lower()
			if kind == "key" or args.has("key"):
				target_name = "godot_input_simulate_key"
				args = {
					"key": str(args.get("key", args.get("action", args.get("name", "")))),
					"pressed": bool(args.get("pressed", true))
				}
			elif args.has("sequence"):
				target_name = "godot_input_play_sequence"
			else:
				target_name = "godot_input_simulate_action"
				args = {
					"action": str(args.get("action", args.get("name", ""))),
					"pressed": bool(args.get("pressed", true)),
					"strength": float(args.get("strength", 1.0))
				}

	_ensure_components()
	if _local != null and _local.has_tool(target_name):
		if target_name == "web_search":
			if _web == null: completed.call_deferred({"ok": false, "error": "web_backend_unavailable", "source": "web"})
			else: _web.search(args, completed)
			return
		completed.call_deferred(_local.invoke(target_name, args))
		return

	var mcp_target := target_name
	if not _has_mcp_tool(mcp_target) and _has_mcp_tool("godot_" + mcp_target):
		mcp_target = "godot_" + mcp_target

	if _has_mcp_tool(mcp_target):
		var b_name := _bundle_for_tool(mcp_target)
		var catalog_updated := false
		if b_name != "" and not _unpacked_bundles.has(b_name):
			_unpack_tool_bundle({"bundle_name": b_name})
			catalog_updated = true
		_call_mcp(mcp_target, args, func(res: Dictionary) -> void:
			if catalog_updated and not res.has("catalog_changed"):
				res["catalog_changed"] = true
			completed.call(res)
		)
		return

	var suggested_bundle := _bundle_for_tool(name)
	var err_res := {"ok": false, "error": "tool_unavailable", "name": name, "source": "registry"}
	if suggested_bundle != "":
		err_res["hint"] = "Tool '%s' belongs to the '%s' bundle. Call unpack_tool_bundle({'bundle_name': '%s'}) to activate it into your tool window, or call it via call_mcp_tool." % [name, suggested_bundle, suggested_bundle]
	else:
		err_res["hint"] = "Start the MCP fixture to expose this public capability."
	completed.call_deferred(err_res)

func history_snapshot() -> Dictionary:
	return {"native": _history.snapshot() if _history != null else {}, "mcp_editor_available": _has_mcp_tool("godot_list_history")}

func _call_mcp(name: String, args: Dictionary, completed: Callable) -> void:
	if not is_mcp_connected() or not _has_mcp_tool(name):
		completed.call_deferred({"ok": false, "error": "mcp_tool_unavailable", "name": name, "source": "mcp", "last_error": _mcp_error})
		return
	_call_serial += 1
	var call_id := "agent_%d" % _call_serial
	_pending[call_id] = completed
	_mcp.call_tool(name, args, call_id)

func _bundle_for_tool(tool_name: String) -> String:
	var target := tool_name
	if not target.begins_with("godot_"):
		target = "godot_" + target
	for b_name in TOOL_BUNDLES:
		var prefixes: Array = TOOL_BUNDLES[b_name].get("prefixes", [])
		for p in prefixes:
			if target.begins_with(str(p)):
				return str(b_name)
	return ""

func _resolve_bundle_name(raw_name: String) -> String:
	var lower := raw_name.strip_edges().to_lower().replace("-", "_").replace(" ", "_")
	var aliases := {
		"3d": "scene_3d",
		"3d_scene": "scene_3d",
		"scene3d": "scene_3d",
		"mesh": "scene_3d",
		"sound": "audio",
		"music": "audio",
		"sfx": "audio",
		"collision": "physics",
		"collider": "physics",
		"colliders": "physics",
		"particle": "particles",
		"vfx": "particles",
		"theme": "ui",
		"gui": "ui",
		"control": "ui",
		"tiles": "tilemap",
		"tileset": "tilemap",
		"anim": "animation",
		"animate": "animation",
		"statemachine": "animation",
		"blendtree": "animation",
		"shader": "shaders",
		"debugger": "runtime_debugger",
		"debug": "runtime_debugger",
		"runtime": "runtime_debugger",
		"nav": "navigation",
		"pathfinding": "navigation",
		"batch": "composite",
		"profile": "profiling",
		"screenshot": "vision",
		"capture": "vision",
	}
	if aliases.has(lower):
		return str(aliases[lower])
	return lower

func _call_discovered_mcp(args: Dictionary, completed: Callable) -> void:
	var name := str(args.get("name", ""))
	var params_v: Variant = args.get("arguments", {})
	var params: Dictionary = params_v if typeof(params_v) == TYPE_DICTIONARY else {}
	if name == "":
		completed.call_deferred({"ok": false, "error": "missing_mcp_tool_name", "source": "mcp"})
		return
	var mcp_target := name
	if not _has_mcp_tool(mcp_target) and _has_mcp_tool("godot_" + mcp_target):
		mcp_target = "godot_" + mcp_target
	if not _has_mcp_tool(mcp_target):
		var suggested := _bundle_for_tool(name)
		var hint := "Use search_mcp_tools to choose a discovered exact name."
		if suggested != "":
			hint = "This tool belongs to the '%s' bundle. Call unpack_tool_bundle({'bundle_name': '%s'}) to activate it." % [suggested, suggested]
		completed.call_deferred({"ok": false, "error": "mcp_tool_unavailable", "name": name, "source": "mcp", "hint": hint})
		return
	var b_for_it := _bundle_for_tool(mcp_target)
	var catalog_updated := false
	if b_for_it != "" and not _unpacked_bundles.has(b_for_it):
		_unpack_tool_bundle({"bundle_name": b_for_it})
		catalog_updated = true
	_call_mcp(mcp_target, params, func(res: Dictionary) -> void:
		if catalog_updated and not res.has("catalog_changed"):
			res["catalog_changed"] = true
		completed.call(res)
	)

func _on_mcp_connected(tools: Array) -> void:
	_mcp_tools = tools.duplicate(true)
	_rebuild_selection()
	_mcp_error = ""; _mcp_state = "mcp_ready"
	log.emit("MCP tools discovered: %d" % _mcp_tools.size())
	tools_known_changed.emit()

func _on_mcp_disconnected(reason: String) -> void:
	_mcp_tools.clear(); _selected_mcp_tools.clear(); _explicit_mcp_tools.clear(); _unpacked_bundles.clear(); _last_bundle_notice = ""; _mcp_error = reason; _mcp_state = "mcp_offline"
	log.emit("MCP offline: " + reason)
	tools_known_changed.emit()

func _on_mcp_tool_finished(call_id: String, result: Dictionary) -> void:
	var completed: Variant = _pending.get(call_id, null)
	_pending.erase(call_id)
	if completed is Callable: (completed as Callable).call(result)

func _has_mcp_tool(name: String) -> bool:
	if DISALLOWED_MCP_TOOLS.has(name): return false
	if not is_mcp_connected(): return false
	for remote in _mcp_tools:
		if typeof(remote) == TYPE_DICTIONARY and str(remote.get("name", "")) == name: return true
	return false

func _unavailable_intents() -> Array:
	var unavailable: Array = []
	for entry in capability_registry():
		if not bool(entry.get("available", false)): unavailable.append(entry.get("intent", ""))
	return unavailable

func _without_scope(args: Dictionary) -> Dictionary:
	var out := args.duplicate(); out.erase("scope"); return out

func _native_tool_names() -> Array:
	var names: Array = LOCAL_TOOL_NAMES.duplicate()
	var data: Dictionary = _cfg.data() if _cfg != null else {}
	var web: Dictionary = data.get("web_search", {})
	var provider := str(web.get("provider", "firecrawl")).to_lower()
	if provider == "brave" and str(web.get("api_key", "")) == "":
		names.erase("web_search")
	return names

func _model_mcp_capacity() -> int:
	return maxi(0, MAX_MODEL_TOOLS - _native_tool_names().size())

func _active_mcp_tools() -> Array:
	if not is_mcp_connected(): return []
	var wanted := {}
	for name in _selected_mcp_tools:
		if not DISALLOWED_MCP_TOOLS.has(str(name)):
			wanted[str(name)] = true
	var out: Array = []
	for tool in _mcp_tools:
		if typeof(tool) == TYPE_DICTIONARY:
			var tname := str(tool.get("name", ""))
			if wanted.has(tname) and not DISALLOWED_MCP_TOOLS.has(tname):
				out.append(tool)
	return out

func _pinned_mcp_tools() -> Array:
	var out: Array = []
	for name in PINNED_MCP_TOOLS:
		if not DISALLOWED_MCP_TOOLS.has(name) and _has_discovered_tool(name): out.append(name)
	return out

func _profile_candidates(profile: String) -> Array:
	if profile == "baseline":
		return []
	var prefixes: Array = PROFILE_PREFIXES.get(profile, PROFILE_PREFIXES["baseline"])
	var ranked: Array = []
	for tool in _mcp_tools:
		if typeof(tool) != TYPE_DICTIONARY: continue
		var name := str(tool.get("name", ""))
		if name == "" or PINNED_MCP_TOOLS.has(name) or DISALLOWED_MCP_TOOLS.has(name): continue
		var priority := prefixes.size() + 1
		for index in prefixes.size():
			if name.begins_with(str(prefixes[index])):
				priority = index
				break
		if priority <= prefixes.size(): ranked.append({"name": name, "rank": "%02d_%s" % [priority, name]})
	ranked.sort_custom(func(a, b): return str(a.get("rank", "")) < str(b.get("rank", "")))
	var out: Array = []
	for entry in ranked: out.append(str(entry.get("name", "")))
	return out

func _rebuild_selection() -> void:
	var selected: Array = []
	for name in _pinned_mcp_tools():
		if selected.size() < _model_mcp_capacity(): selected.append(name)
	for name in _explicit_mcp_tools:
		if _has_discovered_tool(str(name)) and not selected.has(str(name)) and selected.size() < _model_mcp_capacity(): selected.append(str(name))
	for b_name in _unpacked_bundles:
		for tool_name in _tools_in_bundle(str(b_name)):
			if not selected.has(tool_name) and selected.size() < _model_mcp_capacity():
				selected.append(tool_name)
	for name in _profile_candidates(_selected_profile):
		if not selected.has(name) and selected.size() < _model_mcp_capacity(): selected.append(name)
	_selected_mcp_tools = selected

func _has_discovered_tool(name: String) -> bool:
	for tool in _mcp_tools:
		if typeof(tool) == TYPE_DICTIONARY and str(tool.get("name", "")) == name: return true
	return false

func _tools_in_bundle(bundle_name: String) -> Array:
	if not TOOL_BUNDLES.has(bundle_name):
		return []
	var prefixes: Array = TOOL_BUNDLES[bundle_name].get("prefixes", [])
	var out: Array = []
	for tool in _mcp_tools:
		if typeof(tool) != TYPE_DICTIONARY: continue
		var name := str(tool.get("name", ""))
		if name == "" or PINNED_MCP_TOOLS.has(name) or DISALLOWED_MCP_TOOLS.has(name): continue
		for p in prefixes:
			if name.begins_with(str(p)):
				if not out.has(name): out.append(name)
				break
	return out

func _list_tool_bundles(_args: Dictionary = {}) -> Dictionary:
	var bundles: Array = []
	for b_name in TOOL_BUNDLES:
		var spec: Dictionary = TOOL_BUNDLES[b_name]
		var tools_in_b := _tools_in_bundle(str(b_name))
		bundles.append({
			"name": str(b_name),
			"description": str(spec.get("description", "")),
			"tool_count": tools_in_b.size(),
			"tools": tools_in_b,
			"status": "unpacked" if _unpacked_bundles.has(str(b_name)) else "packed",
		})
	var current_mcp := _selected_mcp_tools.size()
	var native_cnt := _native_tool_names().size()
	return {
		"ok": true,
		"data": {
			"bundles": bundles,
			"active_bundles": _unpacked_bundles.duplicate(),
			"pinned_mcp_tools": _pinned_mcp_tools().size(),
			"native_tools": native_cnt,
			"total_active_tools": native_cnt + current_mcp,
			"max_model_tools": MAX_MODEL_TOOLS,
			"remaining_capacity": maxi(0, _model_mcp_capacity() - (current_mcp - _pinned_mcp_tools().size())),
		},
		"source": "mcp"
	}

func _unpack_tool_bundle(args: Dictionary) -> Dictionary:
	if not is_mcp_connected():
		return {"ok": false, "error": "mcp_offline", "source": "mcp"}
	var bundle_name := _resolve_bundle_name(str(args.get("bundle_name", "")))
	if bundle_name == "":
		return {"ok": false, "error": "missing_bundle_name", "available_bundles": TOOL_BUNDLES.keys(), "source": "mcp"}
	if not TOOL_BUNDLES.has(bundle_name):
		return {"ok": false, "error": "unknown_bundle", "requested": bundle_name, "available_bundles": TOOL_BUNDLES.keys(), "source": "mcp"}

	var tools_to_add := _tools_in_bundle(bundle_name)
	if tools_to_add.is_empty():
		return {"ok": false, "error": "bundle_tools_not_discovered", "bundle": bundle_name, "hint": "Ensure the MCP server is exposing this toolset.", "source": "mcp"}

	if _unpacked_bundles.has(bundle_name):
		_unpacked_bundles.erase(bundle_name)
		_unpacked_bundles.append(bundle_name)
		var msg := "Bundle '%s' is already unpacked and active." % bundle_name
		return {
			"ok": true,
			"unpacked": bundle_name,
			"tools_count": tools_to_add.size(),
			"notice": msg,
			"active_bundles": _unpacked_bundles.duplicate(),
			"catalog_changed": false
		}

	var cap := _model_mcp_capacity()
	var pinned_cnt := _pinned_mcp_tools().size()
	var packed_back: Array = []

	var active_tools_without_pinned: Array = []
	for b in _unpacked_bundles:
		for t in _tools_in_bundle(str(b)):
			if not active_tools_without_pinned.has(t) and not PINNED_MCP_TOOLS.has(t):
				active_tools_without_pinned.append(t)

	var unique_new: Array = []
	for t in tools_to_add:
		if not active_tools_without_pinned.has(t) and not PINNED_MCP_TOOLS.has(t):
			unique_new.append(t)

	var projected := pinned_cnt + active_tools_without_pinned.size() + unique_new.size()

	# If adding tools exceeds MAX_MODEL_TOOLS, get oldest bundles back!
	while projected > cap and not _unpacked_bundles.is_empty():
		var oldest_b: String = str(_unpacked_bundles.pop_front())
		packed_back.append(oldest_b)
		active_tools_without_pinned.clear()
		for b in _unpacked_bundles:
			for t in _tools_in_bundle(str(b)):
				if not active_tools_without_pinned.has(t) and not PINNED_MCP_TOOLS.has(t):
					active_tools_without_pinned.append(t)
		unique_new.clear()
		for t in tools_to_add:
			if not active_tools_without_pinned.has(t) and not PINNED_MCP_TOOLS.has(t):
				unique_new.append(t)
		projected = pinned_cnt + active_tools_without_pinned.size() + unique_new.size()

	_unpacked_bundles.append(bundle_name)
	_rebuild_selection()
	tools_known_changed.emit()

	var notice := ""
	if not packed_back.is_empty():
		notice = "Tool window capacity (%d tools) exceeded. Packed bundle(s) %s back into storage. Unpacked bundle '%s' (%d tools). Active bundles: %s. Window usage: %d / %d tools." % [
			MAX_MODEL_TOOLS,
			JSON.stringify(packed_back),
			bundle_name,
			tools_to_add.size(),
			JSON.stringify(_unpacked_bundles),
			_native_tool_names().size() + _selected_mcp_tools.size(),
			MAX_MODEL_TOOLS
		]
	else:
		notice = "Unpacked bundle '%s' (%d tools). Active bundles: %s. Window usage: %d / %d tools." % [
			bundle_name,
			tools_to_add.size(),
			JSON.stringify(_unpacked_bundles),
			_native_tool_names().size() + _selected_mcp_tools.size(),
			MAX_MODEL_TOOLS
		]
	_last_bundle_notice = notice

	return {
		"ok": true,
		"unpacked": bundle_name,
		"tools_added": tools_to_add.size(),
		"packed_back": packed_back,
		"active_bundles": _unpacked_bundles.duplicate(),
		"notice": notice,
		"window_usage": "%d / %d" % [_native_tool_names().size() + _selected_mcp_tools.size(), MAX_MODEL_TOOLS],
		"catalog_changed": true
	}

func _pack_tool_bundle(args: Dictionary) -> Dictionary:
	var bundle_name := _resolve_bundle_name(str(args.get("bundle_name", "")))
	if not _unpacked_bundles.has(bundle_name):
		return {
			"ok": false,
			"error": "bundle_not_unpacked",
			"bundle": bundle_name,
			"active_bundles": _unpacked_bundles.duplicate(),
			"source": "mcp"
		}
	_unpacked_bundles.erase(bundle_name)
	var tools_removed := _tools_in_bundle(bundle_name).size()
	_rebuild_selection()
	tools_known_changed.emit()
	var notice := "Packed bundle '%s' back into storage (%d tools removed). Active bundles: %s. Window usage: %d / %d tools." % [
		bundle_name,
		tools_removed,
		JSON.stringify(_unpacked_bundles),
		_native_tool_names().size() + _selected_mcp_tools.size(),
		MAX_MODEL_TOOLS
	]
	_last_bundle_notice = notice
	return {
		"ok": true,
		"packed_back": bundle_name,
		"tools_removed": tools_removed,
		"active_bundles": _unpacked_bundles.duplicate(),
		"notice": notice,
		"catalog_changed": true
	}

func auto_select_for_prompt(prompt: String) -> Dictionary:
	var text := prompt.to_lower()
	var scored_bundles: Array = []
	for b_name in TOOL_BUNDLES:
		var spec: Dictionary = TOOL_BUNDLES[b_name]
		var score := 0
		if text.contains(str(b_name).replace("_", " ")):
			score += 10
		var kws: Array = spec.get("keywords", [])
		for kw in kws:
			if text.contains(str(kw)):
				score += 2
		if score > 0:
			scored_bundles.append({"name": str(b_name), "score": score})

	scored_bundles.sort_custom(func(a, b): return int(a.get("score", 0)) > int(b.get("score", 0)))

	var matched_any := false
	for entry in scored_bundles:
		var b_name := str(entry.get("name", ""))
		var res: Dictionary = _unpack_tool_bundle({"bundle_name": b_name})
		if bool(res.get("ok", false)):
			matched_any = true

	if not matched_any:
		var game_words := ["game", "platformer", "level", "player", "gameplay", "asset", "tileset", "tilemap"]
		for word in game_words:
			if text.contains(word):
				var selected: Dictionary = _select_mcp_profile("full_game_authoring", false)
				if word in ["game", "platformer", "player", "gameplay"]:
					_unpack_tool_bundle({"bundle_name": "physics"})
				if word in ["platformer", "level", "tileset", "tilemap"]:
					_unpack_tool_bundle({"bundle_name": "tilemap"})
				var st: Dictionary = selected.get("data", backend_status())
				if _last_bundle_notice != "":
					st["notice"] = _last_bundle_notice
				return st

	var status := backend_status()
	if _last_bundle_notice != "":
		status["notice"] = _last_bundle_notice
	return status

func _mcp_rank(name: String) -> String:
	var priority := ["godot_health", "godot_inspection", "godot_scene_edit", "godot_scripts", "godot_project", "godot_runtime", "godot_debugger", "godot_undo", "godot_redo", "godot_list_history"]
	for i in priority.size():
		if name.begins_with(priority[i]): return "%02d_%s" % [i, name]
	return "99_" + name

func _search_mcp_tools(args: Dictionary) -> Dictionary:
	if not is_mcp_connected(): return {"ok": false, "error": "mcp_offline", "source": "mcp"}
	var query := str(args.get("query", "")).to_lower().strip_edges()
	var limit := clampi(int(args.get("limit", 20)), 1, 50)
	var matches: Array = []
	for tool in _mcp_tools:
		if typeof(tool) != TYPE_DICTIONARY: continue
		var name := str(tool.get("name", ""))
		if name == "" or DISALLOWED_MCP_TOOLS.has(name): continue
		var description := str(tool.get("description", ""))
		if query == "" or name.to_lower().contains(query) or description.to_lower().contains(query):
			var state := "active" if _selected_mcp_tools.has(name) else "omitted"
			if PINNED_MCP_TOOLS.has(name): state = "pinned"
			var b_name := _bundle_for_tool(name)
			var item := {
				"name": name,
				"description": description.substr(0, 240),
				"bundle": b_name,
				"input_schema": tool.get("inputSchema", {"type": "object", "properties": {}}),
				"state": state
			}
			if state == "omitted":
				if b_name != "":
					item["how_to_use"] = "Call unpack_tool_bundle({'bundle_name': '%s'}) or invoke via call_mcp_tool('%s', args)." % [b_name, name]
				else:
					item["how_to_use"] = "Invoke via call_mcp_tool('%s', args)." % name
			matches.append(item)
			if matches.size() >= limit: break
	var recommended_action := "Unpack domain bundles (e.g. unpack_tool_bundle) or call tools directly using call_mcp_tool."
	return {"ok": true, "data": {"matches": matches, "total_discovered": _mcp_tools.size(), "active_capacity": _model_mcp_capacity(), "profile": _selected_profile, "recommended_action": recommended_action, "recommended_profile": "full_game_authoring" if query.contains("game") or query.contains("asset") or query.contains("tile") else "baseline"}, "source": "mcp"}

func _activate_mcp_tools(args: Dictionary) -> Dictionary:
	if not is_mcp_connected(): return {"ok": false, "error": "mcp_offline", "source": "mcp"}
	# Older model calls were given an underspecified schema and may have sent a
	# single string. Accept it as one exact name, but keep the public schema
	# strict so future calls reliably send an array.
	var names_value: Variant = args.get("names", [])
	var requested: Array = []
	if typeof(names_value) == TYPE_ARRAY:
		requested = names_value
	elif typeof(names_value) == TYPE_STRING and not str(names_value).strip_edges().is_empty():
		requested = [str(names_value)]
	else:
		return {"ok": false, "error": "missing_tool_names", "source": "mcp", "hint": "Call search_mcp_tools, then pass names as an array of exact results."}
	var known := {}
	for tool in _mcp_tools:
		if typeof(tool) == TYPE_DICTIONARY: known[str(tool.get("name", ""))] = true
	var selected: Array = []
	var invalid: Array = []
	for raw_name in requested:
		var name := str(raw_name)
		if DISALLOWED_MCP_TOOLS.has(name):
			invalid.append(name)
		elif known.has(name) and not name in selected:
			selected.append(name)
		elif not known.has(name):
			invalid.append(name)
	if selected.is_empty(): return {"ok": false, "error": "no_valid_mcp_tools", "invalid": invalid, "source": "mcp", "hint": "Use exact names returned by search_mcp_tools."}
	_explicit_mcp_tools = selected
	_rebuild_selection()
	tools_known_changed.emit()
	return {"ok": true, "data": {"requested_tools": selected, "active_tools": _selected_mcp_tools, "active_count": _selected_mcp_tools.size(), "pinned_count": _pinned_mcp_tools().size(), "capacity": _model_mcp_capacity(), "invalid": invalid}, "source": "mcp", "catalog_changed": true}

func _select_mcp_profile(profile: String, notify: bool = true) -> Dictionary:
	if not is_mcp_connected(): return {"ok": false, "error": "mcp_offline", "source": "mcp"}
	if not PROFILE_PREFIXES.has(profile): return {"ok": false, "error": "unknown_profile", "available_profiles": PROFILE_PREFIXES.keys(), "source": "mcp"}
	var changed := _selected_profile != profile
	_selected_profile = profile
	_rebuild_selection()
	if changed and notify: tools_known_changed.emit()
	var status := backend_status()
	var advisory := ""
	var warn := ""
	if profile == "full_game_authoring":
		advisory = "Profile 'full_game_authoring' active (%d general scene/script tools in window). NOTE: Specialized game mechanics (physics, tilemaps, animations, audio, 3D, navigation, particles, shaders) reside in TOOL BUNDLES and are NOT in this profile slice. Call unpack_tool_bundle('bundle_name') or call_mcp_tool('exact_tool_name', args). Do NOT retry select_mcp_profile for specialized tools, and do NOT hardcode engine features." % _selected_mcp_tools.size()
		warn = "Do NOT retry select_mcp_profile for specialized tools (physics, tilemap, animation, audio, etc.). Use unpack_tool_bundle('bundle_name') or call_mcp_tool()."
	else:
		advisory = "Profile '%s' active." % profile
	status["profile_advisory"] = advisory
	var res := {"ok": true, "data": status, "profile": profile, "notice": advisory, "source": "mcp", "catalog_changed": changed}
	if warn != "":
		res["warning"] = warn
	return res
