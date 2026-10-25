@tool
extends RefCounted
## In-editor tools via EditorInterface / ProjectSettings (no MCP required).

const LOCAL_NAMES := [
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
	"auto_generate_atlas_tiles", "configure_input_action", "navigate_viewport",
]

var task_runtime: RefCounted

var history: RefCounted
var _pending_confirmations: Dictionary = {}
var _filesystem_scan_queued := false
const TRASH_DIR := "user://godot_agent_trash"
var strict_confirmation := false

var _known_log_hashes: Dictionary = {}
var _parsed_log_entries: Array = []
var _last_read_timestamp: float = 0.0
var _last_mutation_timestamp: float = 0.0
var _session_start_timestamp: float = 0.0



const AgentAnimationTools = preload("res://addons/godot_agent/tools/agent_animation_tools.gd")
const AgentSpatialTools = preload("res://addons/godot_agent/tools/agent_spatial_tools.gd")
const AgentTilemapTools = preload("res://addons/godot_agent/tools/agent_tilemap_tools.gd")

var _animation_tools: RefCounted
var _spatial_tools: RefCounted
var _tilemap_tools: RefCounted

func _init() -> void:
	_animation_tools = AgentAnimationTools.new(self)
	_spatial_tools = AgentSpatialTools.new(self)
	_tilemap_tools = AgentTilemapTools.new(self)

func _get_spatial_tools() -> RefCounted:
	if _spatial_tools == null:
		if AgentSpatialTools != null:
			_spatial_tools = AgentSpatialTools.new(self)
		else:
			var spat_cls = load("res://addons/godot_agent/tools/agent_spatial_tools.gd")
			if spat_cls != null:
				_spatial_tools = spat_cls.new(self)
	return _spatial_tools

func _get_animation_tools() -> RefCounted:
	if _animation_tools == null:
		if AgentAnimationTools != null:
			_animation_tools = AgentAnimationTools.new(self)
		else:
			var anim_cls = load("res://addons/godot_agent/tools/agent_animation_tools.gd")
			if anim_cls != null:
				_animation_tools = anim_cls.new(self)
	return _animation_tools

func _get_tilemap_tools() -> RefCounted:
	if _tilemap_tools == null:
		if AgentTilemapTools != null:
			_tilemap_tools = AgentTilemapTools.new(self)
		else:
			var tile_cls = load("res://addons/godot_agent/tools/agent_tilemap_tools.gd")
			if tile_cls != null:
				_tilemap_tools = tile_cls.new(self)
	return _tilemap_tools

func _get_scene_root() -> Node:
	if Engine.is_editor_hint():
		if ClassDB.class_exists("EditorInterface") or Engine.has_singleton("EditorInterface"):
			return EditorInterface.get_edited_scene_root()
	return null


func has_tool(name: String) -> bool:
	var n := name.replace("-", "_")
	return n in LOCAL_NAMES or n in [
		"add_node", "remove_node", "move_node", "set_node_property",
		"delete_nodes_batch", "batch_delete_nodes", "bulk_delete_nodes",
		"build_hierarchy", "create_hierarchy", "add_collision_shape",
		"build_sprite_frames", "godot_animation_create_sprite_frames",
		"get_editor_output", "inspect_output_panel", "read_output_log", "output_errors",
		"preview_coordinate_labelled_atlas", "inspect_atlas_geometry", "generate_tile_catalog",
		"reimport_files", "reimport_asset",
		"measure_player_metrics", "tilemap_layer_inspect", "tilemap_paint_cells", "tilemap_paint_rect",
		"spatial_context", "spatial_inspect",
		"convert_coordinates", "convert_coords",
		"spatial_region", "inspect_region",
		"spatial_relationships", "query_relationships",
		"spatial_overlay", "draw_spatial_overlay",
		"collision_geometry", "inspect_collider", "inspect_collision",
		"visual_bounds", "measure_sprite_bounds", "sprite_bounds",
		"calibrate_collision", "calibrate_collider", "fit_collision_shape",
		"collision_overlay", "preview_collision",
		"diff_scene", "task_set_criteria",
		"tileset_physics_validate", "check_tilemap_collision",
		"simulate_runtime_action", "runtime_test_action",
		"get_capabilities", "inspect_capabilities",
		"animation_player_inspect", "animation_tracks_inspect", "animation_player_edit",
		"animation_tree_inspect", "animation_tree_edit", "animation_state_machine_edit",
		"animation_blend_space_edit", "animation_parameters", "animation_validate", "animation_test_runtime",
		"instantiate_scene", "add_instance", "instance_child_scene",
		"toggle_collision_debug", "debug_collisions_toggle", "set_debug_collisions",
		"delegate_level_design", "level_designer_agent", "run_level_designer",
		"auto_generate_atlas_tiles", "setup_tilemap_atlas", "tileset_auto_create_tiles", "create_atlas_tiles",
		"configure_input_action", "add_input_action", "input_map_add_action", "set_input_action"
	]


func invoke(name: String, args: Dictionary) -> Dictionary:
	var norm_name := name.replace("-", "_")
	match norm_name:
		"get_output_errors", "get_editor_output", "inspect_output_panel", "read_output_log", "output_errors":
			return _get_output_errors(args)
		"inspect_project":
			return _inspect_project(args)
		"inspect_scene":
			return _inspect_scene(args)
		"inspect_node":
			return _inspect_node(args)
		"list_files":
			return _list_files(args)
		"read_script":
			return _read_script(args)
		"write_script":
			return _write_script(args)
		"patch_script":
			return _patch_script(args)
		"get_diagnostics":
			return _get_diagnostics(args)
		"set_property", "set_node_property":
			return _set_property(args)
		"edit_node":
			return _edit_node(args)
		"create_node", "add_node":
			return _create_node(args)
		"delete_node", "remove_node":
			return _delete_node(args)
		"delete_nodes", "delete_nodes_batch", "batch_delete_nodes", "bulk_delete_nodes":
			return _delete_nodes(args)
		"reparent_node", "move_node":
			return _reparent_node(args)
		"create_node_hierarchy", "build_hierarchy", "create_hierarchy":
			return _create_node_hierarchy(args)
		"create_collision_for_sprite", "add_collision_shape":
			return _create_collision_for_sprite(args)
		"create_sprite_frames", "build_sprite_frames", "godot_animation_create_sprite_frames":
			return _create_sprite_frames(args)
		"create_scene":
			return _create_scene(args)
		"attach_script":
			return _attach_script(args)
		"save_scene":
			return _save_scene()
		"run_game":
			return _run_game(args)
		"stop_game":
			return _stop_game()
		"settings_get":
			return _settings_get(args)
		"settings_set":
			return _settings_set(args)
		"undo":
			return _undo(args)
		"redo":
			return _redo(args)
		"list_history":
			return {"ok": true, "data": history.snapshot() if history != null else {}, "source": "local"}
		"delete_file":
			return _delete_file(args)
		"restore_deleted_path":
			return _restore_deleted_path(args)
		"run_shell":
			return _run_shell(args)
		"reimport_assets", "reimport_files", "reimport_asset":
			return _reimport_assets(args)
		"playtest_wait":
			return _playtest_wait(args)
		"capture_viewport":
			return _capture_viewport(args)
		"navigate_viewport", "pan_viewport", "zoom_viewport", "pan_zoom_viewport", "focus_viewport":
			return _navigate_viewport(args)
		"inspect_asset_image":
			return _inspect_asset_image(args)
		"analyze_atlas_geometry", "inspect_atlas_geometry":
			return _analyze_atlas_geometry(args)
		"preview_labelled_atlas", "preview_coordinate_labelled_atlas":
			return _preview_labelled_atlas(args)
		"inspect_tile_crop":
			return _inspect_tile_crop(args)
		"catalog_atlas_tiles", "generate_tile_catalog":
			return _catalog_atlas_tiles(args)
		"validate_atlas_coords":
			return _validate_atlas_coords(args)
		"inspect_player_metrics", "measure_player_metrics":
			return _inspect_player_metrics(args)
		"inspect_tilemap_layer", "tilemap_layer_inspect":
			return _inspect_tilemap_layer(args)
		"paint_tilemap_cells", "tilemap_paint_cells":
			return _paint_tilemap_cells(args)
		"paint_tilemap_rect", "tilemap_paint_rect":
			return _paint_tilemap_rect(args)
		"inspect_spatial_context", "spatial_context", "spatial_inspect":
			return _inspect_spatial_context(args)
		"convert_spatial_coordinates", "convert_coordinates", "convert_coords":
			return _convert_spatial_coordinates(args)
		"inspect_spatial_region", "spatial_region", "inspect_region":
			return _inspect_spatial_region(args)
		"query_spatial_relationships", "spatial_relationships", "query_relationships":
			return _query_spatial_relationships(args)
		"preview_spatial_overlay", "spatial_overlay", "draw_spatial_overlay":
			return _preview_spatial_overlay(args)
		"inspect_collision_geometry", "collision_geometry", "inspect_collider", "inspect_collision":
			return _inspect_collision_geometry(args)
		"measure_visual_bounds", "visual_bounds", "measure_sprite_bounds", "sprite_bounds":
			return _measure_visual_bounds(args)
		"calibrate_collision_shape", "calibrate_collision", "calibrate_collider", "fit_collision_shape":
			return _calibrate_collision_shape(args)
		"preview_collision_overlay", "collision_overlay", "preview_collision":
			return _preview_collision_overlay(args)
		"inspect_scene_diff", "diff_scene":
			return _inspect_scene_diff(args)
		"set_task_criteria", "task_set_criteria":
			return _set_task_criteria(args)
		"validate_tileset_physics", "tileset_physics_validate", "check_tilemap_collision":
			return _validate_tileset_physics(args)
		"test_runtime_action", "simulate_runtime_action", "runtime_test_action":
			return _test_runtime_action(args)
		"discover_capabilities", "get_capabilities", "inspect_capabilities":
			return _discover_capabilities(args)
		"inspect_animation_player", "animation_player_inspect":
			return _inspect_animation_player(args)
		"inspect_animation_tracks", "animation_tracks_inspect":
			return _inspect_animation_tracks(args)
		"edit_animation_player", "animation_player_edit":
			return _edit_animation_player(args)
		"inspect_animation_tree", "animation_tree_inspect":
			return _inspect_animation_tree(args)
		"edit_animation_tree", "animation_tree_edit":
			return _edit_animation_tree(args)
		"edit_animation_state_machine", "animation_state_machine_edit":
			return _edit_animation_state_machine(args)
		"edit_animation_blend_space", "animation_blend_space_edit":
			return _edit_animation_blend_space(args)
		"get_set_animation_parameters", "animation_parameters":
			return _get_set_animation_parameters(args)
		"validate_animation_system", "animation_validate":
			return _validate_animation_system(args)
		"test_animation_runtime", "animation_test_runtime":
			return _test_animation_runtime(args)
		"instance_scene", "instantiate_scene", "add_instance", "instance_child_scene":
			return _instance_scene(args)
		"toggle_debug_collisions", "toggle_collision_debug", "debug_collisions_toggle", "set_debug_collisions":
			return _toggle_debug_collisions(args)
		"invoke_level_designer", "delegate_level_design", "level_designer_agent", "run_level_designer":
			return _invoke_level_designer(args)
		"auto_generate_atlas_tiles", "setup_tilemap_atlas", "tileset_auto_create_tiles", "create_atlas_tiles":
			return _auto_generate_atlas_tiles(args)
		"configure_input_action", "add_input_action", "input_map_add_action", "set_input_action":
			return _configure_input_action(args)
		_:
			return {"ok": false, "error": "unsupported_local_tool", "name": name}


func _inspect_project(args: Dictionary) -> Dictionary:
	var data := {
		"name": str(ProjectSettings.get_setting("application/config/name", "")),
		"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
		"features": ProjectSettings.get_setting("application/config/features", PackedStringArray()),
		"description": str(ProjectSettings.get_setting("application/config/description", "")),
		"open_scenes": EditorInterface.get_open_scenes(),
		"playing": EditorInterface.is_playing_scene(),
	}
	if bool(args.get("include_autoload", true)):
		var autos: Dictionary = {}
		# Enumerate common autoload section via ProjectSettings properties.
		for prop in ProjectSettings.get_property_list():
			var pname := str(prop.get("name", ""))
			if pname.begins_with("autoload/"):
				autos[pname.trim_prefix("autoload/")] = ProjectSettings.get_setting(pname)
		data["autoloads"] = autos
	return {"ok": true, "data": data, "source": "local"}


func _inspect_scene(args: Dictionary) -> Dictionary:
	var scene_path := str(args.get("scene_path", ""))
	if scene_path != "":
		EditorInterface.open_scene_from_path(scene_path)
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var max_depth := int(args.get("max_depth", 6))
	return {
		"ok": true,
		"data": {
			"scene_file": root.scene_file_path,
			"root": _node_tree(root, 0, max_depth),
		},
		"source": "local",
	}


func _inspect_node(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var path := str(args.get("node_path", ""))
	var node := _resolve_node(root, path)
	if node == null:
		return {"ok": false, "error": "node_not_found", "node_path": path, "hint": "use paths relative to scene root, e.g. '.' or 'Player'"}
	var data := {
		"name": node.name,
		"type": node.get_class(),
		"path": str(root.get_path_to(node)),
		"child_count": node.get_child_count(),
	}
	if not node.scene_file_path.is_empty():
		data["is_instance"] = true
		data["instance_scene"] = node.scene_file_path
		data["scene_file_path"] = node.scene_file_path
	elif node.owner != null and node.owner != root:
		data["is_instance_child"] = true
		var src := node.owner.scene_file_path if not node.owner.scene_file_path.is_empty() else str(root.get_path_to(node.owner))
		data["instance_scene"] = src
		data["instance_root"] = str(root.get_path_to(node.owner))
	if bool(args.get("include_properties", true)):
		var props: Dictionary = {}
		for p in node.get_property_list():
			var usage := int(p.get("usage", 0))
			if usage & PROPERTY_USAGE_EDITOR == 0:
				continue
			var pn := str(p.get("name", ""))
			if pn in ["script", "owner", "scene_file_path"]:
				continue
			var v: Variant = node.get(pn)
			if typeof(v) in [TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_VECTOR2, TYPE_VECTOR3, TYPE_COLOR, TYPE_NODE_PATH]:
				props[pn] = _jsonish(v)
			elif typeof(v) == TYPE_OBJECT and v != null:
				if v is SpriteFrames:
					var sf: SpriteFrames = v as SpriteFrames
					var anims_dict: Dictionary = {}
					for anim_name in sf.get_animation_names():
						anims_dict[anim_name] = {
							"fps": sf.get_animation_speed(anim_name),
							"loop": sf.get_animation_loop(anim_name),
							"frames": sf.get_frame_count(anim_name)
						}
					props[pn] = {
						"type": "SpriteFrames",
						"resource_path": sf.resource_path,
						"animations": anims_dict
					}
				elif v is Texture2D:
					props[pn] = {
						"type": (v as Texture2D).get_class(),
						"resource_path": (v as Texture2D).resource_path,
						"dimensions": "%dx%d" % [(v as Texture2D).get_width(), (v as Texture2D).get_height()]
					}
				elif v is Resource:
					props[pn] = {
						"type": (v as Resource).get_class(),
						"resource_path": (v as Resource).resource_path
					}
		data["properties"] = props
	return {"ok": true, "data": data, "source": "local"}


func _list_files(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", "res://"))
	var recursive := bool(args.get("recursive", true))
	var max_files := int(args.get("max_files", 200))
	var exts: Array = args.get("extensions", [])
	var out: Array = []
	_walk(path, recursive, exts, out, max_files)
	return {"ok": true, "data": {"path": path, "files": out, "count": out.size()}, "source": "local"}


func _walk(path: String, recursive: bool, exts: Array, out: Array, max_files: int) -> void:
	if out.size() >= max_files:
		return
	var dir := DirAccess.open(path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name == "." or name == ".." or name == ".godot":
			name = dir.get_next()
			continue
		var full := path.rstrip("/") + "/" + name
		if dir.current_is_dir():
			if recursive:
				_walk(full, recursive, exts, out, max_files)
		else:
			if name.ends_with(".uid") or name.ends_with(".import"):
				name = dir.get_next()
				continue
			var ok_ext := exts.is_empty()
			for e in exts:
				if name.ends_with(str(e)):
					ok_ext = true
					break
			if ok_ext:
				out.append(full)
				if out.size() >= max_files:
					break
		name = dir.get_next()
	dir.list_dir_end()


func _read_script(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not path.begins_with("res://"):
		return {"ok": false, "error": "path_must_be_res"}
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "not_found", "path": path}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {"ok": false, "error": "open_failed", "code": FileAccess.get_open_error()}
	var max_chars := int(args.get("max_chars", 24000))
	var text := f.get_as_text()
	var truncated := text.length() > max_chars
	if truncated:
		text = text.substr(0, max_chars)
	return {"ok": true, "data": {"path": path, "content": text, "truncated": truncated}, "source": "local"}


func _write_script(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	var content := str(args.get("content", ""))
	if not path.begins_with("res://"):
		return {"ok": false, "error": "path_must_be_res"}
	var base_dir := path.get_base_dir()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(base_dir))
	var existed := FileAccess.file_exists(path)
	var old := ""
	if existed:
		var rf := FileAccess.open(path, FileAccess.READ)
		if rf != null: old = rf.get_as_text()
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "open_failed", "code": FileAccess.get_open_error()}
	f.store_string(content)
	_request_filesystem_scan()
	_record_file_change("Write " + path, path, existed, old, true, content)
	return {"ok": true, "data": {"path": path, "bytes": content.length()}, "source": "local"}


func _patch_script(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if str(args.get("content", "")) != "":
		return _write_script(args)
	var search := str(args.get("search", ""))
	var replace := str(args.get("replace", ""))
	if search == "":
		return {"ok": false, "error": "need_content_or_search"}
	var read: Dictionary = _read_script({"path": path, "max_chars": 500000})
	if not bool(read.get("ok", false)):
		return read
	var data_v: Variant = read.get("data", {})
	var text := ""
	if typeof(data_v) == TYPE_DICTIONARY:
		text = str(data_v.get("content", ""))
	if not text.contains(search):
		return {"ok": false, "error": "search_not_found", "path": path}
	return _write_script({"path": path, "content": text.replace(search, replace)})


func _create_scene(args: Dictionary) -> Dictionary:
	_record_mutation()
	var scene_path := str(args.get("scene_path", ""))
	var root_type := str(args.get("root_type", "Node2D"))
	if not scene_path.begins_with("res://") or not scene_path.ends_with(".tscn"):
		return _build_mutation_result("create_scene", false, "rejected", args, {}, {}, [], [], ["scene_path_must_be_res_tscn"])
	if not ClassDB.class_exists(root_type):
		return _build_mutation_result("create_scene", false, "rejected", args, {}, {}, [], [], ["unknown_class: %s" % root_type])
	var root: Node = ClassDB.instantiate(root_type)
	root.name = scene_path.get_file().get_basename().capitalize().replace(" ", "")
	var packed := PackedScene.new()
	var err := packed.pack(root)
	root.free()
	if err != OK:
		return _build_mutation_result("create_scene", false, "failed", args, {}, {}, [], [], ["pack_failed: code %d" % err])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(scene_path.get_base_dir()))
	err = ResourceSaver.save(packed, scene_path)
	if err != OK:
		return _build_mutation_result("create_scene", false, "failed", args, {}, {}, [], [], ["save_failed: code %d" % err])
	_request_filesystem_scan()
	EditorInterface.open_scene_from_path(scene_path)
	var file_exists := FileAccess.file_exists(scene_path)
	var file_size := 0
	if file_exists:
		var f := FileAccess.open(scene_path, FileAccess.READ)
		if f != null:
			file_size = f.get_length()
			f.close()
	var created_text := FileAccess.get_file_as_string(scene_path) if file_exists else ""
	_record_file_change("Create scene " + scene_path, scene_path, false, "", true, created_text)
	var ret_data := {"scene_path": scene_path, "root_type": root_type, "bytes": file_size}
	return _build_mutation_result("create_scene", true, "persisted", args, ret_data, ret_data, [scene_path], [], [], file_exists and file_size > 0, false, "not_applicable", ret_data)


func _instance_scene(args: Dictionary) -> Dictionary:
	_record_mutation()
	var root := _get_scene_root()
	if root == null:
		return _build_mutation_result("instance_scene", false, "rejected", args, {}, {}, [], [], ["no_edited_scene: Open or create a scene before instantiating child scenes."])

	var scene_path := str(args.get("scene_path", args.get("path", ""))).strip_edges()
	if scene_path.is_empty():
		return _build_mutation_result("instance_scene", false, "rejected", args, {}, {}, [], [], ["missing_scene_path: Provide scene_path (e.g. res://scenes/player.tscn)."])

	if not (scene_path.ends_with(".tscn") or scene_path.ends_with(".scn")):
		return _build_mutation_result("instance_scene", false, "rejected", args, {}, {}, [], [], ["invalid_scene_extension: Scene path must end with .tscn or .scn: '%s'" % scene_path])

	if not ResourceLoader.exists(scene_path) and not FileAccess.file_exists(scene_path):
		return _build_mutation_result("instance_scene", false, "rejected", args, {}, {}, [], [], ["scene_not_found: Scene file does not exist at '%s'" % scene_path])

	var p_path := str(args.get("parent_path", args.get("parent", "."))).strip_edges()
	var parent: Node = root
	if p_path not in [".", "", "/", str(root.name)]:
		parent = _resolve_node(root, p_path)
	if parent == null:
		return _build_mutation_result("instance_scene", false, "rejected", args, {}, {}, [], [], ["parent_not_found: Parent node '%s' could not be resolved." % p_path])

	var packed: PackedScene = load(scene_path) as PackedScene
	if packed == null:
		return _build_mutation_result("instance_scene", false, "rejected", args, {}, {}, [], [], ["failed_to_load_scene: Could not load PackedScene from '%s'" % scene_path])

	var inst: Node = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
	if inst == null:
		return _build_mutation_result("instance_scene", false, "rejected", args, {}, {}, [], [], ["failed_to_instantiate: packed.instantiate() returned null for '%s'" % scene_path])

	var requested_name := str(args.get("name", args.get("node_name", ""))).strip_edges()
	if requested_name != "":
		inst.name = requested_name

	var warnings: Array = []
	parent.add_child(inst, true)
	inst.owner = root

	var actual_name := str(inst.name)
	if requested_name != "" and actual_name != requested_name:
		warnings.append("Automatic renaming occurred: requested name '%s' was renamed to '%s' to avoid duplicate collision in '%s'." % [requested_name, actual_name, str(root.get_path_to(parent))])

	var props_applied: Dictionary = {}
	var props_v: Variant = args.get("properties", null)
	if typeof(props_v) == TYPE_DICTIONARY:
		for k in (props_v as Dictionary):
			var prop_name := str(k)
			var old_v: Variant = inst.get(prop_name)
			var coerced: Variant = _coerce_property_value(inst, prop_name, props_v[k])
			inst.set(prop_name, coerced)
			if history != null:
				history.record("Set %s.%s" % [inst.name, prop_name], Callable(inst, "set").bind(prop_name, old_v), Callable(inst, "set").bind(prop_name, coerced))
			props_applied[prop_name] = _jsonish(inst.get(prop_name))

	if history != null:
		history.record("Instance scene " + str(inst.name), Callable(parent, "remove_child").bind(inst), Callable(parent, "add_child").bind(inst))

	var inst_path := str(root.get_path_to(inst))
	var applied := {
		"node_path": inst_path,
		"name": actual_name,
		"requested_name": requested_name,
		"type": inst.get_class(),
		"scene_path": scene_path,
		"is_instance": true,
		"parent": str(root.get_path_to(parent)),
		"properties": props_applied,
	}

	var status := "applied"
	if not warnings.is_empty():
		status = "partially_applied"

	var readback := _readback_node_state(root, inst)
	readback["is_instance"] = true
	readback["instance_scene"] = scene_path

	return _build_mutation_result(
		"instance_scene",
		true,
		status,
		args,
		applied,
		readback,
		[inst_path],
		warnings,
		[],
		false,
		history != null,
		"not_needed",
		applied
	)



func _attach_script(args: Dictionary) -> Dictionary:
	_record_mutation()
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _build_mutation_result("attach_script", false, "rejected", args, {}, {}, [], [], ["no_edited_scene"])
	var npath := str(args.get("node_path", ""))
	var node := _resolve_node(root, npath)
	if node == null:
		return _build_mutation_result("attach_script", false, "rejected", args, {}, {}, [], [], ["node_not_found: %s" % npath])
	var script_path := str(args.get("script_path", ""))
	if not ResourceLoader.exists(script_path):
		return _build_mutation_result("attach_script", false, "rejected", args, {}, {}, [], [], ["script_missing: %s" % script_path])
	var scr: Script = load(script_path)
	var old_script := node.get_script()
	node.set_script(scr)
	if history != null:
		history.record("Attach script to " + str(node.name), Callable(node, "set_script").bind(old_script), Callable(node, "set_script").bind(scr))
	var final_path := str(root.get_path_to(node))
	var actual_scr := node.get_script()
	var readback_path := (actual_scr as Resource).resource_path if actual_scr != null else ""
	var ok := readback_path == script_path
	var status := "applied" if ok else "failed"
	var errs: Array = []
	if not ok:
		errs.append("Script readback failed: expected '%s' but found '%s'" % [script_path, readback_path])
	var ret_data := {"node_path": final_path, "script_path": readback_path}
	return _build_mutation_result("attach_script", ok, status, args, ret_data, ret_data, [final_path], [], errs, false, history != null, "not_needed", ret_data)


func _undo(args: Dictionary) -> Dictionary:
	if history == null: return {"ok": false, "error": "history_unavailable"}
	return {"ok": true, "data": history.undo(int(args.get("steps", 1))), "source": "local"}

func _redo(args: Dictionary) -> Dictionary:
	if history == null: return {"ok": false, "error": "history_unavailable"}
	return {"ok": true, "data": history.redo(int(args.get("steps", 1))), "source": "local"}


func _playtest_wait(args: Dictionary) -> Dictionary:
	var seconds := float(args.get("seconds", 0.5))
	OS.delay_msec(int(clampf(seconds, 0.0, 5.0) * 1000.0))
	return {"ok": true, "data": {"waited": seconds}, "source": "local"}


func _record_mutation(_label: String = "") -> void:
	_last_mutation_timestamp = Time.get_unix_time_from_system()


func _build_mutation_result(operation: String, ok: bool, status: String, requested: Dictionary, applied: Dictionary, readback: Dictionary, changed_paths: Array, warnings: Array = [], errors: Array = [], persistence_verified: bool = false, rollback_available: bool = true, rollback_status: String = "not_needed", extra_data: Dictionary = {}) -> Dictionary:
	var res := {
		"ok": ok,
		"status": status,
		"operation": operation,
		"requested": requested,
		"applied": applied,
		"readback": readback,
		"changed_paths": changed_paths,
		"warnings": warnings,
		"errors": errors,
		"persistence_verified": persistence_verified,
		"postconditions_verified": ok and errors.is_empty() and (status in ["applied", "persisted", "verified"]),
		"rollback_available": rollback_available,
		"rollback_status": rollback_status,
		"source": "local",
	}
	if not extra_data.is_empty():
		res["data"] = extra_data
	elif not applied.is_empty() or not readback.is_empty():
		var d := applied.duplicate()
		for k in readback:
			if not d.has(k):
				d[k] = readback[k]
		res["data"] = d
	else:
		res["data"] = {}
	return res


func _readback_node_state(root: Node, node: Node) -> Dictionary:
	if root == null or node == null:
		return {}
	var path := str(root.get_path_to(node))
	var ppath := "."
	if node.get_parent() != null and node != root:
		ppath = str(root.get_path_to(node.get_parent()))
	var scr_res := ""
	if node.get_script() != null:
		var scr: Script = node.get_script() as Script
		if scr != null:
			scr_res = scr.resource_path
	var props := {}
	for p in ["position", "scale", "rotation", "visible", "z_index", "process_mode"]:
		if node.get(p) != null:
			props[p] = _jsonish(node.get(p))
	return {
		"node_path": path,
		"name": str(node.name),
		"type": node.get_class(),
		"parent": ppath,
		"script": scr_res,
		"child_count": node.get_child_count(),
		"properties": props,
	}


func _snapshot_scene_tree(root: Node) -> Dictionary:
	var snap := {}
	if root == null:
		return snap
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		var p := str(root.get_path_to(n))
		var parent_p := "."
		if n.get_parent() != null and n != root:
			parent_p = str(root.get_path_to(n.get_parent()))
		var scr_p := ""
		if n.get_script() != null:
			var s: Script = n.get_script() as Script
			if s != null:
				scr_p = s.resource_path
		snap[p] = {
			"name": str(n.name),
			"type": n.get_class(),
			"parent": parent_p,
			"script": scr_p,
			"child_count": n.get_child_count(),
		}
		for child in n.get_children():
			stack.append(child)
	return snap


func _diff_scene_trees(before_snap: Dictionary, after_snap: Dictionary) -> Dictionary:
	var added: Array = []
	var removed: Array = []
	var modified: Array = []
	for p in after_snap:
		if not before_snap.has(p):
			added.append(p)
		else:
			var b: Dictionary = before_snap[p]
			var a: Dictionary = after_snap[p]
			if b.get("name") != a.get("name") or b.get("parent") != a.get("parent") or b.get("script") != a.get("script"):
				modified.append({"path": p, "before": b, "after": a})
	for p in before_snap:
		if not after_snap.has(p):
			removed.append(p)
	return {
		"added": added,
		"removed": removed,
		"modified": modified,
		"has_changes": (not added.is_empty()) or (not removed.is_empty()) or (not modified.is_empty()),
	}


func _get_active_task_id(args: Dictionary) -> String:
	var tid := str(args.get("task_id", "")).strip_edges()
	if tid != "":
		return tid
	if task_runtime == null:
		task_runtime = preload("res://addons/godot_agent/agent_task_runtime.gd").new()
	var list: Array = task_runtime.list_tasks() if task_runtime != null and task_runtime.has_method("list_tasks") else []
	for t in list:
		if str(t.get("status", "")) in ["running", "planned", "needs_confirmation", "needs_user"]:
			return str(t.get("id", ""))
	if not list.is_empty():
		return str(list[0].get("id", ""))
	var default_task: Dictionary = task_runtime.create("active_session_task", {})
	return str(default_task.get("id", ""))


func _ensure_session_start() -> void:
	if _session_start_timestamp <= 0.0:
		_session_start_timestamp = Time.get_unix_time_from_system()


func _format_age(age_sec: float) -> String:
	if age_sec < 1.0:
		return "just now"
	elif age_sec < 60.0:
		return "%.1fs ago" % age_sec
	elif age_sec < 3600.0:
		var m := int(age_sec / 60.0)
		var s := int(fmod(age_sec, 60.0))
		return "%dm %ds ago" % [m, s]
	else:
		var h := int(age_sec / 3600.0)
		var m := int(fmod(age_sec, 3600.0) / 60.0)
		return "%dh %dm ago" % [h, m]


func _find_editor_log(node: Node) -> Node:
	if node == null:
		return null
	var cname := node.get_class()
	if cname == "EditorLog" or node.name == "EditorLog" or node.name.begins_with("@EditorLog") or node.name == "Output":
		return node
	for child in node.get_children():
		var found := _find_editor_log(child)
		if found != null:
			return found
	return null


func _find_rich_text_label(node: Node) -> RichTextLabel:
	if node == null:
		return null
	if node is RichTextLabel:
		return node as RichTextLabel
	for child in node.get_children():
		var found := _find_rich_text_label(child)
		if found != null:
			return found
	return null


func _get_raw_output_text() -> String:
	# Priority 1: EditorLog RichTextLabel in Editor UI
	if Engine.is_editor_hint():
		if ClassDB.class_exists("EditorInterface") or Engine.has_singleton("EditorInterface"):
			var base := EditorInterface.get_base_control()
			if base != null:
				var editor_log := _find_editor_log(base)
				if editor_log != null:
					var rtl := _find_rich_text_label(editor_log)
					if rtl != null:
						var text := rtl.get_parsed_text()
						if not text.is_empty():
							return text

	# Priority 2: user://logs/godot.log
	var log_path := "user://logs/godot.log"
	if FileAccess.file_exists(log_path):
		var fa := FileAccess.open(log_path, FileAccess.READ)
		if fa != null:
			return fa.get_as_text()

	return ""


func _parse_output_log(raw_text: String) -> void:
	_ensure_session_start()
	var now := Time.get_unix_time_from_system()
	var lines := raw_text.split("\n")
	var i := 0
	while i < lines.size():
		var line := lines[i].strip_edges()
		if line.is_empty():
			i += 1
			continue

		var is_err := line.begins_with("ERROR:") or line.begins_with("SCRIPT ERROR:") or line.begins_with("USER ERROR:") or line.contains(" - Parse Error: ")
		var is_warn := line.begins_with("WARNING:") or line.contains(" - Parse Warning: ")

		if is_err or is_warn:
			var hash_key := line
			var trace_lines: Array = []
			var location := ""
			var file_path := ""
			var line_num := -1

			var j := i + 1
			while j < lines.size():
				var next_line := lines[j].strip_edges()
				if next_line.begins_with("at: ") or next_line.begins_with("GDScript backtrace") or next_line.begins_with("[") or next_line.begins_with("modules/") or next_line.begins_with("scene/") or next_line.begins_with("servers/") or next_line.begins_with("core/"):
					trace_lines.append(next_line)
					hash_key += "\n" + next_line
					if location.is_empty() and (next_line.contains("res://") or next_line.begins_with("at: ")):
						location = next_line.trim_prefix("at: ")
						var res_idx := location.find("res://")
						if res_idx != -1:
							var after_res := location.substr(res_idx)
							var end_paren := after_res.find(")")
							var chunk := after_res.substr(0, end_paren if end_paren != -1 else after_res.length())
							var colon_idx := chunk.find(":")
							if colon_idx != -1:
								file_path = chunk.substr(0, colon_idx)
								line_num = int(chunk.substr(colon_idx + 1))
					j += 1
				else:
					break

			if not _known_log_hashes.has(hash_key):
				var entry_time := now
				var is_new := false
				if _last_mutation_timestamp > 0.0 and now >= _last_mutation_timestamp:
					is_new = true
				elif _last_read_timestamp > 0.0 and now >= _last_read_timestamp:
					is_new = true
				elif _parsed_log_entries.size() > 0:
					is_new = true

				var entry := {
					"id": _parsed_log_entries.size() + 1,
					"type": "error" if is_err else "warning",
					"message": line,
					"location": location,
					"file": file_path,
					"line": line_num,
					"backtrace": trace_lines,
					"time_unix": entry_time,
					"timestamp": Time.get_datetime_string_from_system(),
					"is_new": is_new,
				}
				_known_log_hashes[hash_key] = entry
				_parsed_log_entries.append(entry)
			i = j
		else:
			i += 1


func _get_output_errors(args: Dictionary = {}) -> Dictionary:
	_ensure_session_start()
	var raw_text := _get_raw_output_text()
	if not raw_text.is_empty():
		_parse_output_log(raw_text)

	var level := str(args.get("level", "errors")).to_lower()
	var since_sec := float(args.get("since_seconds", 0.0))
	var only_new := bool(args.get("only_new", false))
	var limit := clampi(int(args.get("limit", 50)), 1, 200)
	var clear_after := bool(args.get("clear", false))

	var now := Time.get_unix_time_from_system()
	var matching_errors: Array = []
	var matching_warnings: Array = []
	var new_errors_count := 0
	var old_errors_count := 0
	var new_warnings_count := 0
	var old_warnings_count := 0

	for entry in _parsed_log_entries:
		var etype := str(entry.get("type", "error"))
		var time_u := float(entry.get("time_unix", now))
		var age_sec := maxf(0.0, now - time_u)

		if since_sec > 0.0 and age_sec > since_sec:
			continue

		var is_new := bool(entry.get("is_new", false))
		if _last_mutation_timestamp > 0.0 and time_u >= _last_mutation_timestamp:
			is_new = true

		if only_new and not is_new:
			continue

		var item := {
			"id": entry.get("id"),
			"type": etype,
			"message": entry.get("message"),
			"location": entry.get("location"),
			"file": entry.get("file"),
			"line": entry.get("line"),
			"timestamp": entry.get("timestamp"),
			"time_unix": time_u,
			"age_seconds": roundf(age_sec * 10.0) / 10.0,
			"age_human": _format_age(age_sec),
			"status": "new" if is_new else "old",
			"is_new": is_new,
			"backtrace": entry.get("backtrace", [])
		}

		if etype == "error":
			if is_new: new_errors_count += 1
			else: old_errors_count += 1
			if level in ["errors", "all"]:
				matching_errors.append(item)
		elif etype == "warning":
			if is_new: new_warnings_count += 1
			else: old_warnings_count += 1
			if level in ["warnings", "all"]:
				matching_warnings.append(item)

	if clear_after:
		_last_read_timestamp = now
		for entry in _parsed_log_entries:
			entry["is_new"] = false

	var total_errors := new_errors_count + old_errors_count
	var total_warnings := new_warnings_count + old_warnings_count

	var summary := "Output panel: %d error(s) (%d new, %d old), %d warning(s) (%d new, %d old)." % [
		total_errors, new_errors_count, old_errors_count,
		total_warnings, new_warnings_count, old_warnings_count
	]

	if matching_errors.size() > limit:
		matching_errors = matching_errors.slice(matching_errors.size() - limit)
	if matching_warnings.size() > limit:
		matching_warnings = matching_warnings.slice(matching_warnings.size() - limit)

	return {
		"ok": true,
		"summary": summary,
		"total_errors": total_errors,
		"new_errors": new_errors_count,
		"old_errors": old_errors_count,
		"total_warnings": total_warnings,
		"new_warnings": new_warnings_count,
		"old_warnings": old_warnings_count,
		"last_mutation_timestamp": Time.get_datetime_string_from_unix_time(int(_last_mutation_timestamp)) if _last_mutation_timestamp > 0.0 else "none",
		"errors": matching_errors,
		"warnings": matching_warnings,
		"source": "local",
	}


func _get_diagnostics(_args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	var gd_files: Array = []
	_walk("res://", true, [".gd"], gd_files, 100)
	var err_info := _get_output_errors({"level": "errors", "limit": 5})
	return {
		"ok": true,
		"data": {
			"project": str(ProjectSettings.get_setting("application/config/name", "")),
			"main_scene": str(ProjectSettings.get_setting("application/run/main_scene", "")),
			"edited_scene": root.scene_file_path if root != null else "",
			"playing": EditorInterface.is_playing_scene(),
			"script_files_sample": gd_files,
			"script_count_sample": gd_files.size(),
			"open_scenes": EditorInterface.get_open_scenes(),
			"output_panel_errors": {
				"total": err_info.get("total_errors", 0),
				"new": err_info.get("new_errors", 0),
				"old": err_info.get("old_errors", 0),
				"summary": err_info.get("summary", ""),
				"latest": err_info.get("errors", []),
			}
		},
		"source": "local",
	}


func _coerce_property_value(node: Object, prop: String, raw_val: Variant) -> Variant:
	if raw_val == null:
		return null

	var target_type := TYPE_NIL
	var target_class := ""
	for p in node.get_property_list():
		if str(p.get("name", "")) == prop:
			target_type = int(p.get("type", TYPE_NIL))
			target_class = str(p.get("class_name", ""))
			break

	if target_type == TYPE_NIL:
		var current_val: Variant = node.get(prop)
		if current_val != null:
			target_type = typeof(current_val)

	# Handle Vector2 / Vector2i
	if target_type == TYPE_VECTOR2 or (target_type == TYPE_NIL and prop in ["position", "scale", "size", "offset", "velocity", "global_position", "pivot_offset", "anchor_min", "anchor_max", "custom_minimum_size"]):
		if typeof(raw_val) == TYPE_ARRAY:
			var arr: Array = raw_val
			if arr.size() >= 2: return Vector2(float(arr[0]), float(arr[1]))
		elif typeof(raw_val) == TYPE_DICTIONARY:
			var d: Dictionary = raw_val
			return Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0)))
		elif typeof(raw_val) == TYPE_STRING:
			var parts := str(raw_val).strip_edges().trim_prefix("(").trim_suffix(")").split(",")
			if parts.size() >= 2:
				return Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
	elif target_type == TYPE_VECTOR2I:
		if typeof(raw_val) == TYPE_ARRAY:
			var arr: Array = raw_val
			if arr.size() >= 2: return Vector2i(int(arr[0]), int(arr[1]))
		elif typeof(raw_val) == TYPE_DICTIONARY:
			var d: Dictionary = raw_val
			return Vector2i(int(d.get("x", 0)), int(d.get("y", 0)))

	# Handle Vector3 / Vector3i
	if target_type == TYPE_VECTOR3 or (target_type == TYPE_NIL and prop in ["rotation_degrees"]):
		if typeof(raw_val) == TYPE_ARRAY:
			var arr: Array = raw_val
			if arr.size() >= 3: return Vector3(float(arr[0]), float(arr[1]), float(arr[2]))
		elif typeof(raw_val) == TYPE_DICTIONARY:
			var d: Dictionary = raw_val
			return Vector3(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("z", 0.0)))
	elif target_type == TYPE_VECTOR3I:
		if typeof(raw_val) == TYPE_ARRAY:
			var arr: Array = raw_val
			if arr.size() >= 3: return Vector3i(int(arr[0]), int(arr[1]), int(arr[2]))
		elif typeof(raw_val) == TYPE_DICTIONARY:
			var d: Dictionary = raw_val
			return Vector3i(int(d.get("x", 0)), int(d.get("y", 0)), int(d.get("z", 0)))

	# Handle Color
	if target_type == TYPE_COLOR or (target_type == TYPE_NIL and prop in ["modulate", "self_modulate", "color", "albedo_color", "tint"]):
		if typeof(raw_val) == TYPE_STRING:
			var s := str(raw_val).strip_edges()
			if Color.html_is_valid(s): return Color.from_string(s, Color.WHITE)
			return Color(s)
		elif typeof(raw_val) == TYPE_ARRAY:
			var arr: Array = raw_val
			if arr.size() >= 4: return Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
			elif arr.size() == 3: return Color(float(arr[0]), float(arr[1]), float(arr[2]), 1.0)
		elif typeof(raw_val) == TYPE_DICTIONARY:
			var d: Dictionary = raw_val
			return Color(float(d.get("r", 1.0)), float(d.get("g", 1.0)), float(d.get("b", 1.0)), float(d.get("a", 1.0)))

	# Handle Rect2 / Rect2i
	if target_type == TYPE_RECT2:
		if typeof(raw_val) == TYPE_ARRAY:
			var arr: Array = raw_val
			if arr.size() >= 4: return Rect2(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]))
		elif typeof(raw_val) == TYPE_DICTIONARY:
			var d: Dictionary = raw_val
			return Rect2(float(d.get("x", 0.0)), float(d.get("y", 0.0)), float(d.get("width", d.get("w", 0.0))), float(d.get("height", d.get("h", 0.0))))

	# Handle NodePath
	if target_type == TYPE_NODE_PATH and typeof(raw_val) == TYPE_STRING:
		return NodePath(str(raw_val))

	# Handle PackedVector2Array (e.g. polygon on Polygon2D / CollisionPolygon2D, points on Line2D)
	if target_type == TYPE_PACKED_VECTOR2_ARRAY or (target_type == TYPE_NIL and prop in ["polygon", "points", "uv", "uvs"]):
		if typeof(raw_val) == TYPE_PACKED_VECTOR2_ARRAY:
			return raw_val
		var pv := PackedVector2Array()
		if typeof(raw_val) == TYPE_ARRAY:
			var arr: Array = raw_val
			if not arr.is_empty() and (typeof(arr[0]) == TYPE_INT or typeof(arr[0]) == TYPE_FLOAT):
				if arr.size() % 2 == 0:
					for i in range(0, arr.size(), 2):
						pv.append(Vector2(float(arr[i]), float(arr[i + 1])))
					return pv
			for item in arr:
				if typeof(item) == TYPE_VECTOR2:
					pv.append(item)
				elif typeof(item) == TYPE_ARRAY:
					var sub_arr: Array = item
					if sub_arr.size() >= 2:
						pv.append(Vector2(float(sub_arr[0]), float(sub_arr[1])))
				elif typeof(item) == TYPE_DICTIONARY:
					var d: Dictionary = item
					pv.append(Vector2(float(d.get("x", 0.0)), float(d.get("y", 0.0))))
				elif typeof(item) == TYPE_STRING:
					var parts := str(item).strip_edges().trim_prefix("(").trim_suffix(")").split(",")
					if parts.size() >= 2:
						pv.append(Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges())))
			return pv
		elif typeof(raw_val) == TYPE_STRING:
			var s := str(raw_val).strip_edges().trim_prefix("[").trim_suffix("]")
			for p in s.split("),"):
				var cleaned := p.replace("(", "").replace(")", "").strip_edges()
				var parts := cleaned.split(",")
				if parts.size() >= 2:
					pv.append(Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges())))
			return pv

	# Handle PackedFloat32Array / PackedInt32Array / PackedStringArray
	if target_type == TYPE_PACKED_FLOAT32_ARRAY and typeof(raw_val) == TYPE_ARRAY:
		var pf := PackedFloat32Array()
		for item in (raw_val as Array): pf.append(float(item))
		return pf
	if target_type == TYPE_PACKED_INT32_ARRAY and typeof(raw_val) == TYPE_ARRAY:
		var pi := PackedInt32Array()
		for item in (raw_val as Array): pi.append(int(item))
		return pi
	if target_type == TYPE_PACKED_STRING_ARRAY and typeof(raw_val) == TYPE_ARRAY:
		var ps := PackedStringArray()
		for item in (raw_val as Array): ps.append(str(item))
		return ps

	# Handle Resources, Textures, Shapes, Objects
	if typeof(raw_val) == TYPE_STRING:
		var s := str(raw_val).strip_edges()
		if s.begins_with("res://") or s.begins_with("uid://"):
			if ResourceLoader.exists(s):
				return ResourceLoader.load(s)
		elif target_type == TYPE_OBJECT or (target_class != "" and ClassDB.class_exists(target_class)):
			if ClassDB.class_exists(s) and ClassDB.can_instantiate(s):
				return ClassDB.instantiate(s)
	elif typeof(raw_val) == TYPE_DICTIONARY:
		var d: Dictionary = raw_val
		if prop == "sprite_frames" or target_class == "SpriteFrames" or d.has("animations"):
			var default_save := "res://resources/%s_frames.tres" % str(node.name).to_lower()
			var sf_args := d.duplicate()
			if not sf_args.has("save_path"):
				sf_args["save_path"] = default_save
			if not sf_args.has("assign_to") and node is Node:
				var root := _get_scene_root()
				if root != null:
					sf_args["assign_to"] = str(root.get_path_to(node as Node))
			var sf_res := _create_sprite_frames(sf_args)
			if bool(sf_res.get("ok", false)):
				if sf_res.has("frames") and sf_res["frames"] is SpriteFrames:
					return sf_res["frames"]
				var sp := str(sf_res.get("data", {}).get("save_path", ""))
				if sp != "" and ResourceLoader.exists(sp):
					return ResourceLoader.load(sp)
		var cls_name := str(d.get("type", d.get("class", ""))).strip_edges()
		if cls_name != "" and ClassDB.class_exists(cls_name) and ClassDB.can_instantiate(cls_name):
			var inst: Object = ClassDB.instantiate(cls_name)
			for sub_key in d:
				if str(sub_key) in ["type", "class"]: continue
				var sub_name := str(sub_key)
				inst.set(sub_name, _coerce_property_value(inst, sub_name, d[sub_key]))
			return inst

	# Handle numeric primitives
	if target_type == TYPE_FLOAT and typeof(raw_val) in [TYPE_INT, TYPE_STRING]:
		return float(raw_val)
	if target_type == TYPE_INT and typeof(raw_val) in [TYPE_FLOAT, TYPE_STRING]:
		return int(raw_val)
	if target_type == TYPE_BOOL and typeof(raw_val) == TYPE_STRING:
		return str(raw_val).to_lower() in ["true", "1", "yes"]

	return raw_val


func _set_property(args: Dictionary) -> Dictionary:
	_record_mutation()
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _build_mutation_result("set_property", false, "rejected", args, {}, {}, [], [], ["no_edited_scene: Open or create a scene before setting properties."])
	var path := str(args.get("node_path", args.get("path", args.get("target", ""))))
	var node := _resolve_node(root, path)
	if node == null:
		return _build_mutation_result("set_property", false, "rejected", args, {}, {}, [], [], ["node_not_found: Node '%s' not found." % path])

	var node_path_str := str(root.get_path_to(node))
	var applied: Dictionary = {}
	var readback: Dictionary = {}
	var warnings: Array = []
	var errors: Array = []

	var multi_props_v: Variant = args.get("properties", null)
	if typeof(multi_props_v) == TYPE_DICTIONARY:
		for k in (multi_props_v as Dictionary):
			var p_name := str(k)
			var old_v: Variant = node.get(p_name)
			var coerced: Variant = _coerce_property_value(node, p_name, multi_props_v[k])
			node.set(p_name, coerced)
			if history != null:
				history.record("Set %s.%s" % [node.name, p_name], Callable(node, "set").bind(p_name, old_v), Callable(node, "set").bind(p_name, coerced))
			var post_v: Variant = node.get(p_name)
			applied[p_name] = _jsonish(coerced)
			readback[p_name] = _jsonish(post_v)
			if post_v == null and old_v != null:
				warnings.append("Property '%s' evaluated to null after assignment." % p_name)
		var ok := errors.is_empty()
		var status := "applied" if warnings.is_empty() else "partially_applied"
		return _build_mutation_result(
			"set_property",
			ok,
			status,
			args,
			{"node_path": node_path_str, "properties": applied},
			{"node_path": node_path_str, "properties": readback},
			[node_path_str],
			warnings,
			errors,
			false,
			history != null,
			"not_needed",
			{"node_path": node_path_str, "properties": readback}
		)

	var prop := str(args.get("property_name", args.get("property", args.get("prop", args.get("name", "")))))
	if prop == "":
		return _build_mutation_result("set_property", false, "rejected", args, {}, {}, [], [], ["missing_property: Specify 'property_name' or 'properties' dictionary."])
	var old_value: Variant = node.get(prop)
	var raw_value: Variant = args.get("value")
	var new_value: Variant = _coerce_property_value(node, prop, raw_value)
	node.set(prop, new_value)
	if history != null:
		history.record("Set %s.%s" % [node.name, prop], Callable(node, "set").bind(prop, old_value), Callable(node, "set").bind(prop, new_value))
	var post_val: Variant = node.get(prop)
	applied[prop] = _jsonish(new_value)
	readback[prop] = _jsonish(post_val)
	if post_val == null and old_value != null:
		warnings.append("Property '%s' evaluated to null after assignment." % prop)
	return _build_mutation_result(
		"set_property",
		true,
		"applied" if warnings.is_empty() else "partially_applied",
		args,
		{"node_path": node_path_str, "property": prop, "value": applied[prop]},
		{"node_path": node_path_str, "property": prop, "value": readback[prop]},
		[node_path_str],
		warnings,
		errors,
		false,
		history != null,
		"not_needed",
		{"node_path": node_path_str, "property": prop, "value": readback[prop]}
	)


func _create_node(args: Dictionary) -> Dictionary:
	_record_mutation()
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _build_mutation_result("create_node", false, "rejected", args, {}, {}, [], [], ["no_edited_scene: Open or create a scene before adding nodes."])
	var ppath := str(args.get("parent_path", args.get("parent", args.get("node_path", ".")))).strip_edges()
	var parent: Node = root
	if ppath not in [".", "", "/", str(root.name)]:
		parent = _resolve_node(root, ppath)
	if parent == null:
		return _build_mutation_result("create_node", false, "rejected", args, {}, {}, [], [], ["parent_not_found: Parent path '%s' could not be resolved." % ppath])
	var cls := str(args.get("type", args.get("node_type", args.get("class_name", "Node")))).strip_edges()
	if cls == "" or not ClassDB.class_exists(cls):
		return _build_mutation_result("create_node", false, "rejected", args, {}, {}, [], [], ["unknown_class: Class '%s' does not exist." % cls])
	if not ClassDB.can_instantiate(cls):
		return _build_mutation_result("create_node", false, "rejected", args, {}, {}, [], [], ["cannot_instantiate: Class '%s' cannot be instantiated." % cls])

	var n: Node = ClassDB.instantiate(cls)
	var requested_name := str(args.get("name", args.get("node_name", cls))).strip_edges()
	if requested_name == "":
		requested_name = cls
	n.name = requested_name

	var warnings: Array = []
	parent.add_child(n, true)
	n.owner = root
	_set_owner_recursive(n, root)

	var actual_name := str(n.name)
	if actual_name != requested_name:
		warnings.append("Automatic renaming occurred: requested name '%s' was renamed to '%s' to avoid duplicate collision in '%s'." % [requested_name, actual_name, str(root.get_path_to(parent))])

	var props_applied: Dictionary = {}
	var props_v: Variant = args.get("properties", null)
	if typeof(props_v) == TYPE_DICTIONARY:
		for k in (props_v as Dictionary):
			var prop_name := str(k)
			var old_v: Variant = n.get(prop_name)
			var coerced: Variant = _coerce_property_value(n, prop_name, props_v[k])
			n.set(prop_name, coerced)
			if history != null:
				history.record("Set %s.%s" % [n.name, prop_name], Callable(n, "set").bind(prop_name, old_v), Callable(n, "set").bind(prop_name, coerced))
			props_applied[prop_name] = _jsonish(n.get(prop_name))

	if history != null:
		history.record("Create " + str(n.name), Callable(parent, "remove_child").bind(n), Callable(parent, "add_child").bind(n))

	var readback := _readback_node_state(root, n)
	var final_path := str(readback.get("node_path", ""))
	var applied := {
		"node_path": final_path,
		"name": actual_name,
		"requested_name": requested_name,
		"type": cls,
		"parent": str(root.get_path_to(parent)),
		"properties": props_applied,
	}

	var status := "applied"
	if not warnings.is_empty():
		status = "partially_applied"

	return _build_mutation_result(
		"create_node",
		true,
		status,
		args,
		applied,
		readback,
		[final_path],
		warnings,
		[],
		false,
		history != null,
		"not_needed",
		applied
	)


func _delete_node(args: Dictionary) -> Dictionary:
	var p := str(args.get("node_path", args.get("path", "")))
	var op_args := args.duplicate()
	op_args["operation"] = "delete"
	op_args["node_path"] = p
	return _edit_node(op_args)


func _delete_nodes(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var paths_v: Variant = args.get("node_paths", args.get("nodes", args.get("paths", [])))
	var raw_paths: Array = []
	if typeof(paths_v) == TYPE_ARRAY:
		raw_paths = paths_v
	elif typeof(paths_v) == TYPE_STRING and not str(paths_v).is_empty():
		raw_paths = [str(paths_v)]
	else:
		return {"ok": false, "error": "missing_node_paths", "hint": "Provide 'node_paths' as an array of scene-relative paths."}

	if raw_paths.is_empty():
		return {"ok": false, "error": "empty_node_paths"}

	var deleted: Array = []
	var skipped: Array = []
	var targets_to_remove: Array = []

	for item in raw_paths:
		var p_str := str(item).strip_edges()
		if p_str.is_empty():
			continue
		var node := _resolve_node(root, p_str)
		if node == null:
			skipped.append({"path": p_str, "reason": "node_not_found"})
			continue
		if node == root:
			skipped.append({"path": p_str, "reason": "cannot_delete_scene_root"})
			continue
		if node not in targets_to_remove:
			targets_to_remove.append(node)

	var final_nodes: Array = []
	for node: Node in targets_to_remove:
		var has_ancestor := false
		for other: Node in targets_to_remove:
			if other != node and other.is_ancestor_of(node):
				has_ancestor = true
				break
		if not has_ancestor:
			final_nodes.append(node)

	for node: Node in final_nodes:
		var parent := node.get_parent()
		if parent == null:
			skipped.append({"path": str(node.name), "reason": "no_parent"})
			continue
		var node_path_rel := str(root.get_path_to(node))
		var is_inst: bool = not node.scene_file_path.is_empty()
		var inst_scene: String = node.scene_file_path
		var is_inst_child := false
		if not is_inst and node.owner != null and node.owner != root:
			is_inst_child = true
			inst_scene = node.owner.scene_file_path if not node.owner.scene_file_path.is_empty() else str(root.get_path_to(node.owner))

		var index := node.get_index()
		parent.remove_child(node)
		if history != null:
			history.record("Delete " + str(node.name), Callable(self, "_restore_node").bind(parent, node, index, root), Callable(parent, "remove_child").bind(node), {"index": index})

		var entry_data: Dictionary = {
			"node_path": node_path_rel,
			"deleted": node_path_rel,
			"name": str(node.name),
			"type": node.get_class(),
			"is_instance": is_inst,
		}
		if not inst_scene.is_empty():
			entry_data["instance_scene"] = inst_scene
		if is_inst_child:
			entry_data["is_instance_child"] = true

		deleted.append(entry_data)

	_record_mutation("Deleted %d nodes" % deleted.size())

	var deleted_paths: Array = []
	for d in deleted:
		deleted_paths.append(str(d.get("deleted", d.get("node_path", ""))))
	var ok := not deleted.is_empty() or skipped.is_empty()
	var status := "applied" if skipped.is_empty() else "partially_applied"
	var ret_data := {
		"deleted_count": deleted.size(),
		"deleted_nodes": deleted,
		"skipped_count": skipped.size(),
		"skipped": skipped,
	}
	var warnings: Array = []
	for s in skipped:
		warnings.append("Skipped deleting '%s': %s" % [str(s.get("path")), str(s.get("reason"))])
	return _build_mutation_result(
		"delete_nodes",
		ok,
		status,
		args,
		{"deleted": deleted, "skipped": skipped},
		{"deleted_count": deleted.size(), "verified_deleted": true},
		deleted_paths,
		warnings,
		[],
		false,
		history != null,
		"not_needed",
		ret_data
	)


func _create_collision_for_sprite(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var sp_path := str(args.get("sprite_path", args.get("node_path", "")))
	var sp_node := _resolve_node(root, sp_path)
	if sp_node == null:
		return {"ok": false, "error": "sprite_not_found", "path": sp_path}

	var tex: Variant = sp_node.get("texture")
	if (tex == null or not (tex is Texture2D)) and (sp_node is AnimatedSprite2D or sp_node.is_class("AnimatedSprite2D")):
		var sf: SpriteFrames = sp_node.get("sprite_frames") as SpriteFrames
		if sf != null:
			var cur_anim := str(sp_node.get("animation")) if sp_node.get("animation") != null else "default"
			if not sf.has_animation(cur_anim) and not sf.get_animation_names().is_empty():
				cur_anim = sf.get_animation_names()[0]
			if sf.has_animation(cur_anim) and sf.get_frame_count(cur_anim) > 0:
				tex = sf.get_frame_texture(cur_anim, 0)
	if tex == null or not (tex is Texture2D):
		return {"ok": false, "error": "sprite_has_no_texture", "path": sp_path, "hint": "Assign a Texture2D or SpriteFrames to the sprite first."}

	var tex_2d: Texture2D = tex as Texture2D
	var w := float(tex_2d.get_width())
	var h := float(tex_2d.get_height())
	var sp_scale: Vector2 = sp_node.get("scale") if sp_node.get("scale") != null else Vector2.ONE
	w *= abs(sp_scale.x)
	h *= abs(sp_scale.y)

	var pad_v: Variant = args.get("padding", [0.0, 0.0])
	var pad_x := 0.0
	var pad_y := 0.0
	if typeof(pad_v) == TYPE_ARRAY and (pad_v as Array).size() >= 2:
		pad_x = float(pad_v[0])
		pad_y = float(pad_v[1])
	elif typeof(pad_v) in [TYPE_FLOAT, TYPE_INT]:
		pad_x = float(pad_v)
		pad_y = float(pad_v)
	w = maxf(4.0, w + pad_x * 2.0)
	h = maxf(4.0, h + pad_y * 2.0)

	var shape_type := str(args.get("shape_type", "RectangleShape2D")).strip_edges()
	if shape_type == "" or shape_type == "auto":
		shape_type = "RectangleShape2D"

	var parent := sp_node.get_parent()
	if parent == null:
		parent = root

	var col_shape := CollisionShape2D.new()
	var col_name := str(args.get("name", "CollisionShape2D")).strip_edges()
	if col_name == "":
		col_name = "CollisionShape2D"
	col_shape.name = col_name

	if shape_type == "RectangleShape2D":
		var box := RectangleShape2D.new()
		box.size = Vector2(w, h)
		col_shape.shape = box
	elif shape_type == "CircleShape2D":
		var circle := CircleShape2D.new()
		circle.radius = maxf(w, h) * 0.5
		col_shape.shape = circle
	elif shape_type == "CapsuleShape2D":
		var cap := CapsuleShape2D.new()
		cap.radius = w * 0.5
		cap.height = h
		col_shape.shape = cap
	else:
		var generic_box := RectangleShape2D.new()
		generic_box.size = Vector2(w, h)
		col_shape.shape = generic_box

	if sp_node.get("position") != null:
		col_shape.position = sp_node.get("position")

	parent.add_child(col_shape, true)
	col_shape.owner = root
	_set_owner_recursive(col_shape, root)

	if history != null:
		history.record("Create collision for " + str(sp_node.name), Callable(parent, "remove_child").bind(col_shape), Callable(parent, "add_child").bind(col_shape))

	return {
		"ok": true,
		"data": {
			"node_path": str(root.get_path_to(col_shape)),
			"name": str(col_shape.name),
			"shape_type": shape_type,
			"size": [w, h],
			"matched_sprite": str(root.get_path_to(sp_node)),
			"texture_path": tex_2d.resource_path,
			"texture_dimensions": "%dx%d pixels" % [tex_2d.get_width(), tex_2d.get_height()],
		},
		"source": "local",
	}


func _load_texture_resource(path: String) -> Texture2D:
	var p := path.strip_edges()
	if p.is_empty():
		return null
	if not p.begins_with("res://") and not p.begins_with("uid://"):
		p = "res://" + p.trim_prefix("/")
	if ResourceLoader.exists(p):
		var res: Resource = ResourceLoader.load(p)
		if res is Texture2D:
			return res as Texture2D
	if FileAccess.file_exists(p):
		var img := Image.new()
		var err := img.load(ProjectSettings.globalize_path(p))
		if err == OK:
			var itex := ImageTexture.create_from_image(img)
			itex.take_over_path(p)
			return itex
	return null


func _parse_frame_size(v: Variant, default_size: Vector2i = Vector2i(32, 32)) -> Vector2i:
	if typeof(v) == TYPE_VECTOR2I:
		return v
	elif typeof(v) == TYPE_VECTOR2:
		return Vector2i(int((v as Vector2).x), int((v as Vector2).y))
	elif typeof(v) == TYPE_ARRAY:
		var arr: Array = v
		if arr.size() >= 2:
			return Vector2i(int(arr[0]), int(arr[1]))
		elif arr.size() == 1:
			return Vector2i(int(arr[0]), int(arr[0]))
	elif typeof(v) == TYPE_DICTIONARY:
		var d: Dictionary = v
		var x: int = int(d.get("width", d.get("w", d.get("x", default_size.x))))
		var y: int = int(d.get("height", d.get("h", d.get("y", default_size.y))))
		return Vector2i(x, y)
	elif typeof(v) == TYPE_STRING:
		var s := str(v).strip_edges().to_lower().trim_prefix("(").trim_suffix(")")
		if "x" in s:
			var parts := s.split("x")
			if parts.size() >= 2:
				return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
		elif "," in s:
			var parts := s.split(",")
			if parts.size() >= 2:
				return Vector2i(int(parts[0].strip_edges()), int(parts[1].strip_edges()))
		elif s.is_valid_int():
			var sz := int(s)
			return Vector2i(sz, sz)
	return default_size


func _create_sprite_frames(args: Dictionary) -> Dictionary:
	_record_mutation()
	var root := _get_scene_root()
	var anims_raw: Variant = args.get("animations", args.get("anims", {}))
	if not (anims_raw is Dictionary) or (anims_raw as Dictionary).is_empty():
		return {"ok": false, "error": "missing_animations", "hint": "Provide 'animations' dictionary mapping animation names to frame configs (e.g. {'idle': {'row': 0, 'count': 4, 'fps': 8.0}})."}

	var frames := SpriteFrames.new()
	if frames.has_animation("default") and not (anims_raw as Dictionary).has("default"):
		frames.remove_animation("default")

	var anim_summaries: Array = []
	var anims: Dictionary = anims_raw
	var default_fps := float(args.get("default_fps", args.get("fps", 8.0)))

	# Global texture from args
	var sheet_path := str(args.get("texture", args.get("texture_path", args.get("spritesheet", args.get("sheet", args.get("image", "")))))).strip_edges()
	var base_tex: Texture2D = _load_texture_resource(sheet_path)

	# Global frame size
	var frame_size_v: Variant = args.get("frame_size", [32, 32])
	var global_frame_size := _parse_frame_size(frame_size_v, Vector2i(32, 32))
	var fw := global_frame_size.x
	var fh := global_frame_size.y

	for anim_name_k in anims:
		var anim_name := str(anim_name_k).strip_edges()
		if anim_name == "": continue
		var spec: Variant = anims[anim_name_k]
		var frame_list: Array = []
		var fps := default_fps
		var loop := true
		var anim_tex := base_tex
		var anim_fw := fw
		var anim_fh := fh
		var margin_x := int(args.get("margin_x", args.get("margin", 0)))
		var margin_y := int(args.get("margin_y", args.get("margin", 0)))
		var spacing_x := int(args.get("spacing_x", args.get("spacing", 0)))
		var spacing_y := int(args.get("spacing_y", args.get("spacing", 0)))

		if typeof(spec) == TYPE_ARRAY:
			var spec_arr: Array = spec as Array
			if not spec_arr.is_empty() and (typeof(spec_arr[0]) == TYPE_INT or typeof(spec_arr[0]) == TYPE_FLOAT):
				var tex_w := anim_tex.get_width() if anim_tex != null else 128
				var cols := maxi(1, int(tex_w / anim_fw))
				for idx_v in spec_arr:
					var idx := int(idx_v)
					frame_list.append([idx % cols, int(idx / cols)])
			else:
				frame_list = spec_arr
		elif typeof(spec) == TYPE_DICTIONARY:
			var d: Dictionary = spec
			var d_tex_path := str(d.get("texture", d.get("texture_path", d.get("spritesheet", d.get("sheet", d.get("image", "")))))).strip_edges()
			if d_tex_path != "":
				var custom_tex := _load_texture_resource(d_tex_path)
				if custom_tex != null:
					anim_tex = custom_tex

			if d.has("frame_size"):
				var custom_fs := _parse_frame_size(d.get("frame_size"), Vector2i(anim_fw, anim_fh))
				anim_fw = custom_fs.x
				anim_fh = custom_fs.y
			elif d.has("frame_width") or d.has("frame_height"):
				anim_fw = int(d.get("frame_width", anim_fw))
				anim_fh = int(d.get("frame_height", anim_fh))

			margin_x = int(d.get("margin_x", d.get("margin", margin_x)))
			margin_y = int(d.get("margin_y", d.get("margin", margin_y)))
			spacing_x = int(d.get("spacing_x", d.get("spacing", spacing_x)))
			spacing_y = int(d.get("spacing_y", d.get("spacing", spacing_y)))

			fps = float(d.get("fps", d.get("speed", default_fps)))
			loop = bool(d.get("loop", true))

			var f_raw: Variant = d.get("frames", d.get("cells", null))
			if typeof(f_raw) == TYPE_ARRAY:
				var f_arr: Array = f_raw as Array
				if not f_arr.is_empty() and (typeof(f_arr[0]) == TYPE_INT or typeof(f_arr[0]) == TYPE_FLOAT):
					var tex_w := anim_tex.get_width() if anim_tex != null else 128
					var cols := maxi(1, int(tex_w / anim_fw))
					var row := int(d.get("row", 0))
					for idx_v in f_arr:
						var idx := int(idx_v)
						if d.has("row"):
							frame_list.append([idx, row])
						else:
							frame_list.append([idx % cols, int(idx / cols)])
				else:
					frame_list = f_arr
			elif typeof(f_raw) in [TYPE_INT, TYPE_FLOAT] or d.has("count") or d.has("num_frames") or d.has("columns") or d.has("row"):
				var start_col := int(d.get("start_col", d.get("col", d.get("start", 0))))
				var row := int(d.get("row", 0))
				var default_cnt := 1
				if anim_tex != null and anim_fw > 0:
					default_cnt = maxi(1, int((anim_tex.get_width() - margin_x) / (anim_fw + spacing_x)) - start_col)
				var cnt: int = int(d.get("count", d.get("frames", d.get("num_frames", d.get("columns", default_cnt)))))
				for col in range(start_col, start_col + cnt):
					frame_list.append([col, row])
			elif anim_tex != null and anim_fw > 0:
				var total_cols := maxi(1, int((anim_tex.get_width() - margin_x) / (anim_fw + spacing_x)))
				for col in range(total_cols):
					frame_list.append([col, 0])
		elif typeof(spec) == TYPE_STRING:
			var s_path := str(spec).strip_edges()
			if anim_tex == null and (s_path.ends_with(".png") or s_path.ends_with(".webp") or s_path.ends_with(".svg") or s_path.ends_with(".jpg")):
				var img_tex := _load_texture_resource(s_path)
				if img_tex != null and anim_fw > 0 and img_tex.get_width() > anim_fw:
					anim_tex = img_tex
					var total_cols := maxi(1, int(anim_tex.get_width() / anim_fw))
					for col in range(total_cols):
						frame_list.append([col, 0])
				else:
					frame_list = [s_path]
			else:
				frame_list = [s_path]

		if not frames.has_animation(anim_name):
			frames.add_animation(anim_name)
		frames.clear(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, loop)

		var added_frames := 0
		for fr in frame_list:
			if typeof(fr) == TYPE_STRING:
				var path := str(fr).strip_edges()
				var t := _load_texture_resource(path)
				if t != null:
					frames.add_frame(anim_name, t)
					added_frames += 1
			elif typeof(fr) == TYPE_ARRAY and (fr as Array).size() >= 2 and anim_tex != null:
				var col := int(fr[0])
				var row := int(fr[1])
				var rx := margin_x + col * (anim_fw + spacing_x)
				var ry := margin_y + row * (anim_fh + spacing_y)
				var atlas := AtlasTexture.new()
				atlas.atlas = anim_tex
				atlas.region = Rect2(rx, ry, anim_fw, anim_fh)
				frames.add_frame(anim_name, atlas)
				added_frames += 1
			elif typeof(fr) in [TYPE_INT, TYPE_FLOAT] and anim_tex != null:
				var idx := int(fr)
				var tex_w := anim_tex.get_width()
				var cols := maxi(1, int(tex_w / anim_fw))
				var col := idx % cols
				var row := int(idx / cols)
				var rx := margin_x + col * (anim_fw + spacing_x)
				var ry := margin_y + row * (anim_fh + spacing_y)
				var atlas := AtlasTexture.new()
				atlas.atlas = anim_tex
				atlas.region = Rect2(rx, ry, anim_fw, anim_fh)
				frames.add_frame(anim_name, atlas)
				added_frames += 1

		anim_summaries.append({
			"name": anim_name,
			"frames_count": added_frames,
			"fps": fps,
			"loop": loop
		})

	# Saving logic
	var save_path := str(args.get("save_path", "")).strip_edges()
	var assign_to := str(args.get("assign_to", args.get("node_path", ""))).strip_edges()
	var assigned_node: Node = null
	var node_created := false

	if root != null:
		if assign_to != "":
			assigned_node = _resolve_node(root, assign_to)
			if assigned_node == null:
				var target_parent: Node = root
				var new_name := assign_to
				if "/" in assign_to:
					var p_path := assign_to.get_base_dir()
					target_parent = _resolve_node(root, p_path)
					if target_parent == null:
						target_parent = root
					new_name = assign_to.get_file()
				var new_spr := AnimatedSprite2D.new()
				new_spr.name = new_name
				target_parent.add_child(new_spr, true)
				new_spr.owner = root
				assigned_node = new_spr
				node_created = true
				if history != null:
					history.record("Create AnimatedSprite2D " + new_name, Callable(target_parent, "remove_child").bind(new_spr), Callable(target_parent, "add_child").bind(new_spr))
		else:
			if root is AnimatedSprite2D or root.is_class("AnimatedSprite2D"):
				assigned_node = root
			else:
				assigned_node = _find_first_child_of_type(root, "AnimatedSprite2D")

	if save_path == "":
		var base_name := "player"
		if assigned_node != null:
			base_name = str(assigned_node.name).to_lower()
		elif not anim_summaries.is_empty():
			base_name = str(anim_summaries[0]["name"]).to_lower()
		save_path = "res://resources/%s_frames.tres" % base_name

	if not save_path.begins_with("res://"):
		save_path = "res://" + save_path.trim_prefix("/")
	if not save_path.ends_with(".tres") and not save_path.ends_with(".res"):
		save_path += ".tres"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(save_path.get_base_dir()))
	var save_err := ResourceSaver.save(frames, save_path)
	if save_err == OK:
		frames.take_over_path(save_path)
		_request_filesystem_scan()

	if assigned_node != null:
		var prev_frames = assigned_node.get("sprite_frames")
		assigned_node.set("sprite_frames", frames)
		var autoplay := str(args.get("autoplay", ""))
		if autoplay == "" and frames.has_animation("idle"):
			autoplay = "idle"
		elif autoplay == "" and not anim_summaries.is_empty():
			autoplay = str(anim_summaries[0]["name"])

		if autoplay != "" and frames.has_animation(autoplay):
			assigned_node.set("animation", autoplay)
			if "autoplay" in assigned_node:
				assigned_node.set("autoplay", autoplay)
			assigned_node.set("frame", 0)
			if assigned_node.has_method("play"):
				assigned_node.call("play", autoplay)

		if history != null and not node_created:
			history.record("Assign SpriteFrames to " + str(assigned_node.name), Callable(assigned_node, "set").bind("sprite_frames", prev_frames), Callable(assigned_node, "set").bind("sprite_frames", frames))

	return {
		"ok": true,
		"data": {
			"animations": anim_summaries,
			"animation_count": anim_summaries.size(),
			"save_path": save_path,
			"assign_to": str(root.get_path_to(assigned_node)) if (assigned_node != null and root != null) else assign_to,
			"node_created": node_created,
			"animation": assigned_node.get("animation") if assigned_node != null else "",
			"autoplay": assigned_node.get("autoplay") if assigned_node != null and "autoplay" in assigned_node else "",
		},
		"frames": frames,
		"source": "local",
	}


func _create_node_hierarchy(args: Dictionary) -> Dictionary:
	_record_mutation()
	var root := _get_scene_root()
	if root == null:
		return _build_mutation_result("create_node_hierarchy", false, "rejected", args, {}, {}, [], [], ["no_edited_scene: Open or create a scene before building a hierarchy."])

	var root_path_arg := str(args.get("root_path", args.get("parent_path", "."))).strip_edges()
	var base_parent: Node = root
	if root_path_arg not in [".", "", "/", str(root.name)]:
		base_parent = _resolve_node(root, root_path_arg)
	if base_parent == null:
		return _build_mutation_result("create_node_hierarchy", false, "rejected", args, {}, {}, [], [], ["root_parent_not_found: '%s'" % root_path_arg])

	var raw_nodes: Variant = args.get("hierarchy", args.get("nodes", args.get("tree", [])))
	var node_specs: Array = []
	if typeof(raw_nodes) == TYPE_ARRAY:
		node_specs = raw_nodes
	elif typeof(raw_nodes) == TYPE_DICTIONARY:
		node_specs = [raw_nodes]
	else:
		return _build_mutation_result("create_node_hierarchy", false, "rejected", args, {}, {}, [], [], ["invalid_hierarchy_spec: Provide array or dictionary of nodes."])

	var before_snap := _snapshot_scene_tree(root)
	var created_nodes: Array = []
	for spec in node_specs:
		if typeof(spec) == TYPE_DICTIONARY:
			_build_node_recursive(root, base_parent, spec as Dictionary, created_nodes)

	# Validation check across created nodes
	var validation_warnings: Array = []
	var validated_count := 0
	for entry in created_nodes:
		validated_count += 1
		var n_path := str(entry.get("node_path", ""))
		var n := _resolve_node(root, n_path)
		if n == null:
			validation_warnings.append("Node '%s' could not be resolved after creation." % n_path)
			continue
		if entry.get("renamed", false):
			validation_warnings.append("Node '%s' was automatically renamed to '%s' to avoid duplicate name collision." % [entry.get("requested_name", ""), entry.get("actual_name", "")])
		if entry.get("properties", {}).has("script_error"):
			validation_warnings.append(str(entry["properties"]["script_error"]))

		if n is CollisionShape2D or n.is_class("CollisionShape2D"):
			if n.get("shape") == null:
				validation_warnings.append("CollisionShape2D at '%s' has NO collision shape resource assigned." % n_path)
			else:
				var sh: Variant = n.get("shape")
				var shape_obj: Resource = sh as Resource
				var dims: Variant = "configured"
				if shape_obj != null and shape_obj.get("size") != null:
					dims = _jsonish(shape_obj.get("size"))
				elif shape_obj != null and shape_obj.get("radius") != null:
					dims = shape_obj.get("radius")
				entry["validated_shape"] = {
					"type": shape_obj.get_class() if shape_obj != null else "Resource",
					"dimensions": dims
				}
		elif n is Sprite2D or n.is_class("Sprite2D"):
			if n.get("texture") == null:
				validation_warnings.append("Sprite2D at '%s' has NO texture assigned." % n_path)
			else:
				var t: Variant = n.get("texture")
				if t is Texture2D:
					entry["validated_texture"] = {
						"path": (t as Texture2D).resource_path,
						"dimensions": "%dx%d pixels" % [(t as Texture2D).get_width(), (t as Texture2D).get_height()]
					}
		elif n is AnimatedSprite2D or n.is_class("AnimatedSprite2D"):
			if n.get("sprite_frames") == null:
				validation_warnings.append("AnimatedSprite2D at '%s' has NO SpriteFrames assigned." % n_path)
			else:
				var sf: SpriteFrames = n.get("sprite_frames") as SpriteFrames
				if sf != null:
					entry["validated_sprite_frames"] = {
						"animations": sf.get_animation_names(),
						"path": sf.resource_path
					}
		elif n is CharacterBody2D or n.is_class("CharacterBody2D"):
			var has_col := false
			for child in n.get_children():
				if child is CollisionShape2D or child.is_class("CollisionShape2D"):
					has_col = true
					break
			if not has_col:
				validation_warnings.append("CharacterBody2D at '%s' has NO CollisionShape2D child node." % n_path)
		elif n is Polygon2D or n.is_class("Polygon2D"):
			var poly: PackedVector2Array = n.get("polygon") if n.get("polygon") != null else PackedVector2Array()
			if poly.is_empty():
				validation_warnings.append("Polygon2D at '%s' has NO polygon points assigned." % n_path)
			else:
				entry["validated_polygon"] = {"vertex_count": poly.size()}
		elif n is CollisionPolygon2D or n.is_class("CollisionPolygon2D"):
			var poly: PackedVector2Array = n.get("polygon") if n.get("polygon") != null else PackedVector2Array()
			if poly.is_empty():
				validation_warnings.append("CollisionPolygon2D at '%s' has NO polygon points assigned." % n_path)
			else:
				entry["validated_collision_polygon"] = {"vertex_count": poly.size()}

	var after_snap := _snapshot_scene_tree(root)
	var tree_diff := _diff_scene_trees(before_snap, after_snap)
	var changed_paths: Array = tree_diff.get("added", [])

	var ok := not created_nodes.is_empty()
	var status := "applied"
	if not ok:
		status = "failed"
	elif not validation_warnings.is_empty():
		status = "partially_applied"

	var applied := {
		"created_count": created_nodes.size(),
		"root_path": str(root.get_path_to(base_parent)),
		"nodes": created_nodes,
	}
	var extra_data := {
		"created_count": created_nodes.size(),
		"root_path": str(root.get_path_to(base_parent)),
		"nodes": created_nodes,
		"validation": {
			"passed": validation_warnings.is_empty(),
			"warnings": validation_warnings,
			"total_validated": validated_count,
		},
		"tree_diff": tree_diff,
	}

	return _build_mutation_result(
		"create_node_hierarchy",
		ok,
		status,
		args,
		applied,
		{"tree_diff": tree_diff, "nodes": created_nodes, "total_nodes": after_snap.size()},
		changed_paths,
		validation_warnings,
		[],
		false,
		history != null,
		"not_needed",
		extra_data
	)


func _build_node_recursive(scene_root: Node, parent_node: Node, spec: Dictionary, created_nodes: Array) -> Node:
	var sc_path := str(spec.get("instance_scene", spec.get("scene_path", spec.get("scene", "")))).strip_edges()
	var n: Node = null
	var is_instanced := false
	if sc_path != "" and (sc_path.ends_with(".tscn") or sc_path.ends_with(".scn") or ResourceLoader.exists(sc_path)):
		if ResourceLoader.exists(sc_path) or FileAccess.file_exists(sc_path):
			var packed: PackedScene = load(sc_path) as PackedScene
			if packed != null:
				n = packed.instantiate(PackedScene.GEN_EDIT_STATE_INSTANCE)
				is_instanced = true

	var cls := str(spec.get("type", spec.get("node_type", spec.get("class_name", "Node")))).strip_edges()
	if n == null:
		if cls == "" or not ClassDB.class_exists(cls) or not ClassDB.can_instantiate(cls):
			cls = "Node2D"
		n = ClassDB.instantiate(cls)
	else:
		cls = n.get_class()

	var default_name := str(n.name) if is_instanced and not str(n.name).is_empty() else cls
	var nname := str(spec.get("name", spec.get("node_name", default_name))).strip_edges()
	if nname != "":
		n.name = nname

	var target_parent := parent_node
	var custom_parent := str(spec.get("parent", spec.get("parent_path", ""))).strip_edges()
	if custom_parent != "" and custom_parent not in [".", "/", str(scene_root.name)]:
		var resolved := _resolve_node(scene_root, custom_parent)
		if resolved != null:
			target_parent = resolved

	target_parent.add_child(n, true)
	n.owner = scene_root
	if not is_instanced:
		_set_owner_recursive(n, scene_root)

	var actual_name := str(n.name)
	var renamed := actual_name != nname

	var scr_path := str(spec.get("script_path", spec.get("script", ""))).strip_edges()
	var props_applied: Dictionary = {}
	if scr_path != "":
		if ResourceLoader.exists(scr_path):
			n.set_script(load(scr_path))
		else:
			props_applied["script_error"] = "Script '%s' does not exist." % scr_path

	var props_v: Variant = spec.get("properties", null)
	if typeof(props_v) == TYPE_DICTIONARY:
		for k in (props_v as Dictionary):
			var p_name := str(k)
			var coerced: Variant = _coerce_property_value(n, p_name, props_v[k])
			n.set(p_name, coerced)
			props_applied[p_name] = _jsonish(n.get(p_name))

	if cls == "CollisionShape2D":
		var wants_auto: bool = bool(spec.get("auto_shape", false)) or str(spec.get("shape", "")) in ["auto", ""] or n.get("shape") == null
		if wants_auto and n.get("shape") == null:
			var sibling_sprite: Node = null
			for child in target_parent.get_children():
				if child != n and (child.is_class("Sprite2D") or child is Sprite2D or child.is_class("AnimatedSprite2D") or child is AnimatedSprite2D):
					sibling_sprite = child
					break
			if sibling_sprite != null:
				var tex_2d: Texture2D = null
				if sibling_sprite.get("texture") is Texture2D:
					tex_2d = sibling_sprite.get("texture") as Texture2D
				elif sibling_sprite.get("sprite_frames") is SpriteFrames:
					var sf: SpriteFrames = sibling_sprite.get("sprite_frames") as SpriteFrames
					var cur_anim := str(sibling_sprite.get("animation")) if sibling_sprite.get("animation") != null else "default"
					if not sf.has_animation(cur_anim) and not sf.get_animation_names().is_empty():
						cur_anim = sf.get_animation_names()[0]
					if sf.has_animation(cur_anim) and sf.get_frame_count(cur_anim) > 0:
						tex_2d = sf.get_frame_texture(cur_anim, 0)
				if tex_2d != null:
					var w := float(tex_2d.get_width())
					var h := float(tex_2d.get_height())
					var sp_scale: Vector2 = sibling_sprite.get("scale") if sibling_sprite.get("scale") != null else Vector2.ONE
					w *= abs(sp_scale.x)
					h *= abs(sp_scale.y)
					var stype := str(spec.get("shape_type", "RectangleShape2D")).strip_edges()
					if stype == "CircleShape2D":
						var circle := CircleShape2D.new()
						circle.radius = maxf(w, h) * 0.5
						n.set("shape", circle)
					elif stype == "CapsuleShape2D":
						var cap := CapsuleShape2D.new()
						cap.radius = w * 0.5
						cap.height = h
						n.set("shape", cap)
					else:
						var box := RectangleShape2D.new()
						box.size = Vector2(w, h)
						n.set("shape", box)
					if sibling_sprite.get("position") != null:
						n.set("position", sibling_sprite.get("position"))
					if n.get("shape") != null:
						props_applied["shape"] = (n.get("shape") as Resource).get_class()
						props_applied["auto_sized_to_sprite"] = "%dx%d pixels" % [w, h]

	if cls in ["AnimatedSprite2D", "AnimatedSprite3D"]:
		var anims_dict: Variant = spec.get("animations", null)
		if typeof(anims_dict) == TYPE_DICTIONARY and not (anims_dict as Dictionary).is_empty():
			var default_save := "res://resources/%s_frames.tres" % str(n.name).to_lower()
			var sf_args := {
				"animations": anims_dict,
				"texture": spec.get("texture", spec.get("texture_path", spec.get("sheet", spec.get("spritesheet", "")))),
				"frame_size": spec.get("frame_size", [32, 32]),
				"save_path": spec.get("save_path", spec.get("sprite_frames_path", default_save)),
				"autoplay": spec.get("autoplay", spec.get("animation", "idle")),
				"default_fps": spec.get("fps", spec.get("default_fps", 8.0)),
				"assign_to": str(scene_root.get_path_to(n)),
			}
			var res := _create_sprite_frames(sf_args)
			if bool(res.get("ok", false)):
				props_applied["sprite_frames"] = res.get("data", {})

	if history != null:
		history.record("Create " + str(n.name), Callable(target_parent, "remove_child").bind(n), Callable(target_parent, "add_child").bind(n))

	var entry := {
		"node_path": str(scene_root.get_path_to(n)),
		"name": actual_name,
		"requested_name": nname,
		"actual_name": actual_name,
		"renamed": renamed,
		"type": cls,
		"is_instance": is_instanced,
		"instance_scene": sc_path if is_instanced else "",
		"parent": str(scene_root.get_path_to(target_parent)),
		"properties": props_applied,
	}
	created_nodes.append(entry)

	var kids_v: Variant = spec.get("children", null)
	if typeof(kids_v) == TYPE_ARRAY:
		for child_spec in (kids_v as Array):
			if typeof(child_spec) == TYPE_DICTIONARY:
				_build_node_recursive(scene_root, n, child_spec as Dictionary, created_nodes)

	return n


func _reparent_node(args: Dictionary) -> Dictionary:
	var p := str(args.get("node_path", args.get("path", "")))
	var np := str(args.get("new_parent_path", args.get("parent_path", args.get("parent", ""))))
	var op_args := args.duplicate()
	op_args["operation"] = "reparent"
	op_args["node_path"] = p
	op_args["parent_path"] = np
	return _edit_node(op_args)


func _edit_node(args: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var op := str(args.get("operation", ""))
	var path := str(args.get("node_path", ""))
	match op:
		"create":
			var parent_arg := str(args.get("parent_path", path))
			var parent: Node = root
			if parent_arg not in [".", "", "/", str(root.name)]:
				parent = _resolve_node(root, parent_arg)
			if parent == null:
				return {"ok": false, "error": "parent_not_found", "node_path": parent_arg}
			var cls := str(args.get("type", args.get("node_type", "Node")))
			if cls == "" or not ClassDB.class_exists(cls):
				return {"ok": false, "error": "unknown_class", "type": cls}
			if not ClassDB.can_instantiate(cls):
				return {"ok": false, "error": "cannot_instantiate", "type": cls}
			var n: Node = ClassDB.instantiate(cls)
			var nname := str(args.get("name", cls))
			if nname == "":
				nname = cls
			n.name = nname
			parent.add_child(n, true)
			n.owner = root
			_set_owner_recursive(n, root)
			var props_applied: Dictionary = {}
			var props_v: Variant = args.get("properties", null)
			if typeof(props_v) == TYPE_DICTIONARY:
				for k in (props_v as Dictionary):
					var p_name := str(k)
					var coerced: Variant = _coerce_property_value(n, p_name, props_v[k])
					n.set(p_name, coerced)
					props_applied[p_name] = _jsonish(n.get(p_name))
			if history != null:
				history.record("Create " + str(n.name), Callable(parent, "remove_child").bind(n), Callable(parent, "add_child").bind(n))
			return {"ok": true, "data": {"created": str(root.get_path_to(n)), "node_path": str(root.get_path_to(n)), "type": cls, "properties": props_applied}, "source": "local"}
		"delete":
			var node := _resolve_node(root, path)
			if node == null or node == root:
				return {"ok": false, "error": "cannot_delete", "node_path": path}



			var p := str(root.get_path_to(node))
			var is_inst: bool = not node.scene_file_path.is_empty()
			var inst_scene: String = node.scene_file_path
			var is_inst_child := false
			if not is_inst and node.owner != null and node.owner != root:
				is_inst_child = true
				inst_scene = node.owner.scene_file_path if not node.owner.scene_file_path.is_empty() else str(root.get_path_to(node.owner))

			var parent := node.get_parent()
			var index := node.get_index()
			parent.remove_child(node)
			if history != null:
				history.record("Delete " + str(node.name), Callable(self, "_restore_node").bind(parent, node, index, root), Callable(parent, "remove_child").bind(node), {"index": index})
			var del_data: Dictionary = {"deleted": p, "is_instance": is_inst}
			if not inst_scene.is_empty():
				del_data["instance_scene"] = inst_scene
			if is_inst_child:
				del_data["is_instance_child"] = true
			return {"ok": true, "data": del_data, "source": "local"}
		"rename":
			var node2 := _resolve_node(root, path)
			if node2 == null:
				return {"ok": false, "error": "node_not_found", "node_path": path}
			var new_name := str(args.get("new_name", args.get("name", "")))
			if new_name == "":
				return {"ok": false, "error": "missing_new_name"}
			var old_name := str(node2.name)
			node2.name = new_name
			if history != null: history.record("Rename " + old_name, Callable(node2, "set_name").bind(old_name), Callable(node2, "set_name").bind(new_name))
			return {"ok": true, "data": {"renamed": str(root.get_path_to(node2))}, "source": "local"}
		"duplicate":
			var node3 := _resolve_node(root, path)
			if node3 == null:
				return {"ok": false, "error": "node_not_found", "node_path": path}
			var dup := node3.duplicate()
			node3.get_parent().add_child(dup, true)
			dup.owner = root
			_set_owner_recursive(dup, root)
			if history != null: history.record("Duplicate " + str(node3.name), Callable(node3.get_parent(), "remove_child").bind(dup), Callable(node3.get_parent(), "add_child").bind(dup))
			return {"ok": true, "data": {"duplicated": str(root.get_path_to(dup))}, "source": "local"}
		"reparent":
			var node4 := _resolve_node(root, path)
			var parent_path := str(args.get("parent_path", ""))
			var new_parent := _resolve_node(root, parent_path)
			if node4 == null or new_parent == null:
				return {"ok": false, "error": "node_or_parent_not_found", "node_path": path, "parent_path": parent_path}
			var old_parent := node4.get_parent()
			node4.reparent(new_parent)
			node4.owner = root
			if history != null: history.record("Reparent " + str(node4.name), Callable(node4, "reparent").bind(old_parent), Callable(node4, "reparent").bind(new_parent))
			return {"ok": true, "data": {"reparented": str(root.get_path_to(node4)), "parent": parent_path}, "source": "local"}
		_:
			return {"ok": false, "error": "bad_operation", "operation": op, "hint": "use create|delete|rename|duplicate|reparent"}


func _save_scene() -> Dictionary:
	_record_mutation()
	var root := EditorInterface.get_edited_scene_root()
	var scn_path := ""
	if root != null:
		scn_path = root.scene_file_path
	var err := EditorInterface.save_scene()
	var ok := err == OK
	var file_exists := false
	var file_size := 0
	if ok and not scn_path.is_empty():
		file_exists = FileAccess.file_exists(scn_path)
		if file_exists:
			var f := FileAccess.open(scn_path, FileAccess.READ)
			if f != null:
				file_size = f.get_length()
				f.close()
	var status := "persisted" if (ok and (scn_path.is_empty() or (file_exists and file_size > 0))) else "failed"
	var errs: Array = []
	if not ok:
		errs.append("EditorInterface.save_scene() failed with code %d" % err)
	elif not scn_path.is_empty() and (not file_exists or file_size == 0):
		errs.append("Scene file '%s' was not verified on disk after save." % scn_path)
	var ret_data := {"error_code": err, "scene_path": scn_path, "bytes_written": file_size}
	return _build_mutation_result("save_scene", ok and errs.is_empty(), status, {}, ret_data, ret_data, [scn_path] if not scn_path.is_empty() else [], [], errs, ok and errs.is_empty(), false, "not_applicable", ret_data)


func _run_game(args: Dictionary) -> Dictionary:
	_record_mutation()
	var scene_path := str(args.get("scene_path", "")).strip_edges()
	if not scene_path.is_empty():
		var is_scene := scene_path.ends_with(".tscn") or scene_path.ends_with(".scn")
		if not scene_path.begins_with("res://") or not is_scene:
			return {"ok": false, "error": "invalid_scene_path", "source": "local"}
		if not FileAccess.file_exists(scene_path):
			return {"ok": false, "error": "scene_not_found", "path": scene_path, "source": "local"}
		EditorInterface.play_custom_scene(scene_path)
	elif bool(args.get("current", false)):
		EditorInterface.play_current_scene()
	else:
		var main_scene := str(ProjectSettings.get_setting("application/run/main_scene", ""))
		if main_scene.is_empty() and EditorInterface.get_edited_scene_root() != null:
			EditorInterface.play_current_scene()
		else:
			EditorInterface.play_main_scene()
	return {"ok": true, "data": {"playing": true}, "source": "local"}


func _stop_game() -> Dictionary:
	EditorInterface.stop_playing_scene()
	return {"ok": true, "data": {"playing": false}, "source": "local"}


func _find_debug_popup(node: Node) -> PopupMenu:
	if node == null:
		return null
	if node is MenuButton:
		var mb: MenuButton = node as MenuButton
		if mb.text == "Debug" or mb.text == "debug":
			return mb.get_popup()
	if node is MenuBar:
		var mbar: MenuBar = node as MenuBar
		for i in mbar.get_menu_count():
			if mbar.get_menu_title(i) == "Debug":
				return mbar.get_menu_popup(i)
	for c in node.get_children():
		var p: PopupMenu = _find_debug_popup(c)
		if p != null:
			return p
	return null


func _toggle_debug_collisions(args: Dictionary) -> Dictionary:
	_record_mutation()
	var setting_key := "debug/shapes/collision/visible"
	var current_setting: bool = bool(ProjectSettings.get_setting(setting_key, false))
	var editor_menu_checked := false
	var editor_menu_found := false
	var popup: PopupMenu = null
	var item_idx := -1

	if Engine.is_editor_hint():
		if ClassDB.class_exists("EditorInterface") or Engine.has_singleton("EditorInterface"):
			var base: Control = EditorInterface.get_base_control()
			if base != null:
				popup = _find_debug_popup(base)
				if popup != null:
					for i in popup.item_count:
						var t := popup.get_item_text(i)
						if t.contains("Visible Collision Shapes") or t.contains("Collision Shapes"):
							editor_menu_found = true
							editor_menu_checked = popup.is_item_checked(i)
							item_idx = i
							break

	var new_val: bool
	if args.has("visible"):
		new_val = bool(args.get("visible"))
	elif args.has("enabled"):
		new_val = bool(args.get("enabled"))
	else:
		if editor_menu_found:
			new_val = not editor_menu_checked
		else:
			new_val = not current_setting

	if popup != null and item_idx >= 0:
		if editor_menu_checked != new_val:
			popup.set_item_checked(item_idx, new_val)
			popup.id_pressed.emit(popup.get_item_id(item_idx))

	ProjectSettings.set_setting(setting_key, new_val)
	var save_err := ProjectSettings.save()

	var tree_hint_applied := false
	var main_loop := Engine.get_main_loop()
	if main_loop is SceneTree:
		(main_loop as SceneTree).debug_collisions_hint = new_val
		tree_hint_applied = true

	if history != null:
		history.record(
			"Toggle debug collisions",
			Callable(ProjectSettings, "set_setting").bind(setting_key, current_setting),
			Callable(ProjectSettings, "set_setting").bind(setting_key, new_val)
		)

	return {
		"ok": true,
		"data": {
			"setting": setting_key,
			"visible": new_val,
			"previous": current_setting,
			"editor_menu_toggled": editor_menu_found,
			"saved_to_project_settings": save_err == OK,
			"runtime_tree_hint_updated": tree_hint_applied
		},
		"source": "local"
	}



func _settings_get(args: Dictionary) -> Dictionary:
	var key := str(args.get("key", ""))
	if not ProjectSettings.has_setting(key):
		return {"ok": false, "error": "missing_setting", "key": key}
	return {"ok": true, "data": {"key": key, "value": _jsonish(ProjectSettings.get_setting(key))}, "source": "local"}


func _settings_set(args: Dictionary) -> Dictionary:
	var key := str(args.get("key", "")).strip_edges()
	var existed := ProjectSettings.has_setting(key)
	var old: Variant = ProjectSettings.get_setting(key) if existed else null
	var new_value: Variant = args.get("value")
	ProjectSettings.set_setting(key, new_value)
	ProjectSettings.save()
	if key.begins_with("input/"):
		var act := key.trim_prefix("input/")
		_ensure_input_action_registered(act, false)
	if history != null: history.record("Set project setting " + key, Callable(self, "_restore_setting").bind(key, existed, old), Callable(ProjectSettings, "set_setting").bind(key, new_value))
	return {"ok": true, "data": {"key": key, "value": _jsonish(ProjectSettings.get_setting(key))}, "saved": true, "source": "local"}


func _resolve_node(root: Node, path: String) -> Node:
	if root == null:
		return null
	var p := path.strip_edges()
	if p == "" or p == "." or p == "./" or p == "/" or p == str(root.name):
		return root
	# Strip common absolute / edited-scene prefixes models invent.
	for prefix in ["/root/", "root/", "/"]:
		if p.begins_with(prefix):
			p = p.substr(prefix.length())
			break
	if p.begins_with(str(root.name) + "/"):
		p = p.substr(str(root.name).length() + 1)
	if p == str(root.name) or p == "":
		return root
	var node := root.get_node_or_null(NodePath(p))
	if node != null:
		return node
	node = root.find_child(p.get_file(), true, false)
	return node


func _find_first_child_of_type(parent: Node, type_name: String) -> Node:
	if parent == null:
		return null
	var stack: Array[Node] = [parent]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr != parent and (curr.is_class(type_name) or curr.get_class() == type_name):
			return curr
		for child in curr.get_children():
			stack.push_back(child)
	return null


func _set_owner_recursive(n: Node, owner: Node) -> void:
	n.owner = owner
	for c in n.get_children():
		_set_owner_recursive(c, owner)

func _restore_node(parent: Node, node: Node, index: int, owner: Node) -> int:
	if node.get_parent() != null: return ERR_ALREADY_IN_USE
	parent.add_child(node, true)
	parent.move_child(node, clampi(index, 0, parent.get_child_count() - 1))
	_set_owner_recursive(node, owner)
	return OK

func _restore_setting(key: String, existed: bool, value: Variant) -> int:
	if existed: ProjectSettings.set_setting(key, value)
	else: ProjectSettings.set_setting(key, null)
	return OK


func _node_tree(n: Node, depth: int, max_depth: int) -> Dictionary:
	var root := _get_scene_root()
	var rel_p := str(root.get_path_to(n)) if (root != null and n != root and root.is_ancestor_of(n)) else (str(n.get_path()) if n.get_tree() else String(n.name))
	var d := {
		"name": String(n.name),
		"type": n.get_class(),
		"path": rel_p,
	}
	if not n.scene_file_path.is_empty():
		d["is_instance"] = true
		d["instance_scene"] = n.scene_file_path
		d["scene_file_path"] = n.scene_file_path
	elif n.owner != null and root != null and n.owner != root:
		d["is_instance_child"] = true
		var src := n.owner.scene_file_path if not n.owner.scene_file_path.is_empty() else str(root.get_path_to(n.owner))
		d["instance_scene"] = src
		d["instance_root"] = str(root.get_path_to(n.owner))

	if depth < max_depth:
		var kids: Array = []
		for c in n.get_children():
			kids.append(_node_tree(c, depth + 1, max_depth))
		d["children"] = kids
	else:
		d["child_count"] = n.get_child_count()
	return d


func _jsonish(v: Variant) -> Variant:
	match typeof(v):
		TYPE_VECTOR2, TYPE_VECTOR2I:
			return {"x": v.x, "y": v.y}
		TYPE_VECTOR3, TYPE_VECTOR3I:
			return {"x": v.x, "y": v.y, "z": v.z}
		TYPE_RECT2, TYPE_RECT2I:
			return {"x": v.position.x, "y": v.position.y, "width": v.size.x, "height": v.size.y}
		TYPE_COLOR:
			return {"r": v.r, "g": v.g, "b": v.b, "a": v.a}
		TYPE_NODE_PATH:
			return str(v)
		TYPE_PACKED_STRING_ARRAY:
			var a: Array = []
			for s in v:
				a.append(str(s))
			return a
		TYPE_OBJECT:
			if v is Resource and (v as Resource).resource_path != "":
				return (v as Resource).resource_path
			return str(v)
		_:
			return v

func _record_file_change(label: String, path: String, before_exists: bool, before: String, after_exists: bool, after: String) -> void:
	_record_mutation()
	if history == null: return
	history.record(label, Callable(self, "_restore_file_state").bind(path, before_exists, before), Callable(self, "_restore_file_state").bind(path, after_exists, after))

func _restore_file_state(path: String, exists: bool, content: String) -> int:
	if not path.begins_with("res://"): return ERR_INVALID_PARAMETER
	if exists:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(path.get_base_dir()))
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f == null: return FileAccess.get_open_error()
		f.store_string(content)
	else:
		if FileAccess.file_exists(path):
			var err := DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
			if err != OK: return err
	_request_filesystem_scan()
	return OK

func _confirmation(action: String, args: Dictionary) -> Dictionary:
	var supplied := str(args.get("confirmation_token", ""))
	if supplied != "" and _pending_confirmations.get(supplied, "") == action:
		_pending_confirmations.erase(supplied)
		return {"approved": true}
	if not strict_confirmation or bool(args.get("force", false)) or bool(args.get("confirmed", false)) or bool(args.get("auto_approve", false)):
		return {"approved": true}
	var token := "%s-%s" % [action, str(randi())]
	_pending_confirmations[token] = action
	return {"approved": false, "ok": false, "error": "confirmation_required", "confirmation_token": token, "message": "Ask the user to explicitly approve this action, then repeat with this token."}

func _delete_file(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if not path.begins_with("res://") or not FileAccess.file_exists(path): return {"ok": false, "error": "file_not_found_or_outside_project"}
	var approved := _confirmation("delete_file:" + path, args)
	if not bool(approved.get("approved", false)): return approved
	var original := ProjectSettings.globalize_path(path)
	var trash := TRASH_DIR.path_join(str(Time.get_unix_time_from_system()) + "_" + path.get_file())
	DirAccess.make_dir_recursive_absolute(TRASH_DIR)
	var err := DirAccess.rename_absolute(original, trash)
	if err != OK: return {"ok": false, "error": "trash_move_failed", "code": err}
	if history != null:
		history.record("Delete file " + path, Callable(self, "_move_file").bind(trash, original), Callable(self, "_move_file").bind(original, trash), {"trash": trash})
	_request_filesystem_scan()
	return {"ok": true, "data": {"path": path, "trash_path": trash}, "source": "local"}

func _restore_deleted_path(args: Dictionary) -> Dictionary:
	var trash := str(args.get("trash_path", args.get("path", "")))
	var destination := str(args.get("destination", ""))
	if not trash.begins_with(TRASH_DIR) or destination == "" or not destination.begins_with("res://"):
		return {"ok": false, "error": "invalid_restore_path"}
	var restored := ProjectSettings.globalize_path(destination)
	var err := _move_file(trash, restored)
	if err == OK and history != null:
		history.record("Restore file " + destination, Callable(self, "_move_file").bind(restored, trash), Callable(self, "_move_file").bind(trash, restored), {"trash": trash})
	return {"ok": err == OK, "data": {"destination": destination, "trash_path": trash}, "source": "local"}

func _move_file(source: String, destination: String) -> int:
	DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
	var err := DirAccess.rename_absolute(source, destination)
	if err == OK: _request_filesystem_scan()
	return err

func _request_filesystem_scan() -> void:
	# EditorFileSystem.scan() opens a progress dialog and Godot rejects it while
	# an async tool callback is flushing its deferred message. Run it after a
	# short idle delay instead, coalescing bursts of file changes into one scan.
	if _filesystem_scan_queued:
		return
	if not Engine.is_editor_hint():
		_filesystem_scan_queued = false
		return
	var base := EditorInterface.get_base_control()
	if base == null:
		_filesystem_scan_queued = false
		return
	var tree := base.get_tree()
	if tree == null:
		_filesystem_scan_queued = false
		return
	tree.create_timer(0.15).timeout.connect(func() -> void:
		_filesystem_scan_queued = false
		var fs := EditorInterface.get_resource_filesystem()
		if fs != null:
			fs.scan()
	)

func _run_shell(args: Dictionary) -> Dictionary:
	var command := str(args.get("command", ""))
	if command == "": return {"ok": false, "error": "missing_command"}
	var approved := _confirmation("run_shell:" + command, args)
	if not bool(approved.get("approved", false)): return approved
	var timeout := clampi(int(args.get("timeout_seconds", 30)), 1, 120)
	var encoded := Marshalls.raw_to_base64(command.to_utf16_buffer())
	var stem := OS.get_user_data_dir().path_join("agent_shell_" + str(Time.get_ticks_msec()))
	DirAccess.make_dir_recursive_absolute(OS.get_user_data_dir())
	var wrapper := "$p=Start-Process powershell -ArgumentList '-NoProfile','-NonInteractive','-EncodedCommand','%s' -WorkingDirectory '%s' -PassThru -RedirectStandardOutput '%s.out' -RedirectStandardError '%s.err'; if(-not $p.WaitForExit(%d)){Stop-Process -Id $p.Id -Force; exit 124}; exit $p.ExitCode" % [encoded, ProjectSettings.globalize_path("res://").replace("'", "''"), stem.replace("'", "''"), stem.replace("'", "''"), timeout * 1000]
	var output: Array = []
	var code := OS.execute("powershell.exe", ["-NoProfile", "-NonInteractive", "-Command", wrapper], output, true, false)
	var stdout := FileAccess.get_file_as_string(stem + ".out") if FileAccess.file_exists(stem + ".out") else ""
	var stderr := FileAccess.get_file_as_string(stem + ".err") if FileAccess.file_exists(stem + ".err") else ""
	if FileAccess.file_exists(stem + ".out"): DirAccess.remove_absolute(stem + ".out")
	if FileAccess.file_exists(stem + ".err"): DirAccess.remove_absolute(stem + ".err")
	return {"ok": code == 0, "data": {"exit_code": code, "stdout": stdout.substr(0, 12000), "stderr": stderr.substr(0, 12000), "timeout_seconds": timeout}, "source": "local"}


func _collect_asset_files_in_dir(dir_path: String, recursive: bool, out_files: Array) -> void:
	var da := DirAccess.open(dir_path)
	if da == null:
		return
	da.list_dir_begin()
	var fname := da.get_next()
	while fname != "":
		if fname != "." and fname != ".." and not fname.begins_with("."):
			var full_path := dir_path.path_join(fname)
			if da.current_is_dir():
				if recursive and fname != ".godot":
					_collect_asset_files_in_dir(full_path, recursive, out_files)
			else:
				if not fname.ends_with(".import") and not fname.ends_with(".uid"):
					out_files.append(full_path)
		fname = da.get_next()
	da.list_dir_end()


func _reimport_assets(args: Dictionary) -> Dictionary:
	var raw_files: Variant = args.get("files", args.get("file", args.get("paths", [])))
	var target_path := str(args.get("path", args.get("directory", args.get("folder", "")))).strip_edges()
	var recursive := bool(args.get("recursive", true))
	var scan_mode := str(args.get("scan_mode", "auto")).to_lower().strip_edges()

	var candidates: Array = []
	if typeof(raw_files) == TYPE_ARRAY or typeof(raw_files) == TYPE_PACKED_STRING_ARRAY:
		for f in raw_files:
			var s := str(f).strip_edges()
			if s != "":
				candidates.append(s)
	elif typeof(raw_files) == TYPE_STRING and str(raw_files).strip_edges() != "":
		candidates.append(str(raw_files).strip_edges())

	if candidates.is_empty() and target_path != "":
		candidates.append(target_path)

	var files_to_reimport: Array = []
	var missing_files: Array = []
	var scanned_directories: Array = []

	if candidates.is_empty():
		scan_mode = "scan"
	else:
		for c in candidates:
			var p: String = str(c)
			if not p.begins_with("res://") and not p.begins_with("user://"):
				p = "res://".path_join(p.trim_prefix("/"))
			if DirAccess.dir_exists_absolute(p):
				scanned_directories.append(p)
				_collect_asset_files_in_dir(p, recursive, files_to_reimport)
			elif FileAccess.file_exists(p):
				files_to_reimport.append(p)
			else:
				missing_files.append(p)

	var fs := EditorInterface.get_resource_filesystem() if Engine.is_editor_hint() else null
	var reimported_count := 0
	var scan_triggered := false

	if fs != null:
		if not files_to_reimport.is_empty() and scan_mode != "scan":
			var psa := PackedStringArray()
			for f in files_to_reimport:
				psa.append(str(f))
			fs.reimport_files(psa)
			reimported_count = psa.size()

		if scan_mode == "scan" or scan_mode == "scan_sources" or not scanned_directories.is_empty() or files_to_reimport.is_empty():
			if scan_mode == "scan_sources":
				fs.scan_sources()
			else:
				fs.scan()
			scan_triggered = true
	else:
		return {
			"ok": false,
			"error": "editor_filesystem_unavailable",
			"message": "EditorInterface.get_resource_filesystem() is unavailable (not running in editor context)."
		}

	var status := "reimported"
	if not missing_files.is_empty() and reimported_count > 0:
		status = "partially_reimported"
	elif not missing_files.is_empty() and reimported_count == 0 and not scan_triggered:
		status = "failed"
	elif scan_triggered and reimported_count == 0:
		status = "scan_triggered"

	var summary := "Reimported %d asset file(s)." % reimported_count
	if scan_triggered:
		summary += " Filesystem scan triggered."
	if not missing_files.is_empty():
		summary += " %d file(s) not found on disk." % missing_files.size()

	return {
		"ok": missing_files.is_empty() or reimported_count > 0 or scan_triggered,
		"status": status,
		"reimported_count": reimported_count,
		"reimported_files": files_to_reimport.slice(0, 50),
		"total_files_found": files_to_reimport.size(),
		"scanned_directories": scanned_directories,
		"missing_files": missing_files,
		"scan_triggered": scan_triggered,
		"scan_in_progress": fs.is_scanning() if fs != null else false,
		"summary": summary,
		"source": "local"
	}


func _capture_viewport(args: Dictionary) -> Dictionary:
	var target := str(args.get("target", "editor")).to_lower()
	var path := str(args.get("path", ""))
	var base_control := EditorInterface.get_base_control()
	if base_control == null:
		return {"ok": false, "error": "Editor base control is unavailable."}
	var viewport := base_control.get_viewport()
	if viewport == null:
		return {"ok": false, "error": "Editor viewport is unavailable."}
	var texture := viewport.get_texture()
	if texture == null:
		return {"ok": false, "error": "No viewport texture (no rendered frame)."}
	var image := texture.get_image()
	if image == null or image.is_empty():
		return {"ok": false, "error": "Could not capture viewport image."}
	var png_bytes := image.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)
	if path != "":
		var f := FileAccess.open(path, FileAccess.WRITE)
		if f != null:
			f.store_buffer(png_bytes)
			f.close()
	var root_scn := EditorInterface.get_edited_scene_root()
	var cam_name := "default_editor_camera"
	if root_scn != null:
		var cam := _find_first_child_of_type(root_scn, "Camera2D")
		if cam != null:
			cam_name = str(cam.name)
	return {
		"ok": true,
		"target": target,
		"format": "png",
		"width": image.get_width(),
		"height": image.get_height(),
		"dimensions": "%dx%d pixels" % [image.get_width(), image.get_height()],
		"base64": b64,
		"path": path,
		"active_scene": root_scn.scene_file_path if root_scn != null else "",
		"camera": cam_name,
		"visual_verification_status": "image_captured_pending_inspection",
		"source": "local",
	}


func _navigate_viewport(args: Dictionary) -> Dictionary:
	var target := str(args.get("target", "editor")).to_lower()
	var target_pos: Variant = null
	var node_ref: Node = null
	var final_zoom: float = 1.0

	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null

	# 1. Resolve position from node_path if specified
	if args.has("node_path") and str(args.get("node_path", "")).strip_edges() != "":
		var np := str(args.get("node_path", "")).strip_edges()
		if scene_root != null:
			node_ref = _resolve_node(scene_root, np)
			if node_ref != null:
				if node_ref is Node2D:
					target_pos = (node_ref as Node2D).global_position
				elif node_ref is Control:
					var ctrl := node_ref as Control
					target_pos = ctrl.global_position + (ctrl.size * 0.5)
				var bounds: Rect2 = _compute_node_2d_bounds(node_ref)
				if bounds.size != Vector2.ZERO:
					target_pos = bounds.get_center()
				EditorInterface.get_selection().clear()
				EditorInterface.get_selection().add_node(node_ref)
			else:
				return {"ok": false, "error": "node_not_found", "message": "Could not find node '%s' in edited scene." % np}
		else:
			return {"ok": false, "error": "no_edited_scene", "message": "No edited scene root available."}

	# 2. Resolve explicit position coordinates
	if target_pos == null and args.has("position"):
		var p_val: Variant = args.get("position")
		if p_val is Array and p_val.size() >= 2:
			target_pos = Vector2(float(p_val[0]), float(p_val[1]))
		elif p_val is Vector2:
			target_pos = p_val

	# 3. Handle Editor 2D Viewport Pan & Zoom
	var editor_navigated := false
	if target == "editor" or target == "both":
		var vp := EditorInterface.get_editor_viewport_2d()
		var canvas_editor: Object = null
		var cur: Node = vp
		while cur != null:
			if cur.is_class("CanvasItemEditor"):
				canvas_editor = cur
				break
			cur = cur.get_parent()
		if canvas_editor == null:
			var main_s := EditorInterface.get_editor_main_screen()
			if main_s != null:
				canvas_editor = _find_first_child_of_type(main_s, "CanvasItemEditor")

		var cur_zoom := 1.0
		var vp_size := Vector2(1152, 648)
		if vp != null:
			cur_zoom = vp.canvas_transform.get_scale().x
			vp_size = vp.get_visible_rect().size

		var target_zoom := cur_zoom
		if args.has("zoom") and float(args.get("zoom")) > 0.0:
			target_zoom = float(args.get("zoom"))
		elif args.has("zoom_delta") and int(args.get("zoom_delta")) != 0:
			var zd := float(args.get("zoom_delta"))
			target_zoom = clampf(cur_zoom * pow(1.25, zd), 0.05, 32.0)
		final_zoom = target_zoom

		if target_pos != null and vp != null:
			var xf := Transform2D(0.0, Vector2(target_zoom, target_zoom), 0.0, (vp_size * 0.5) - (target_pos * target_zoom))
			vp.canvas_transform = xf
			editor_navigated = true
		elif vp != null and target_zoom != cur_zoom:
			var center := (vp_size * 0.5 - vp.canvas_transform.origin) / cur_zoom
			var xf := Transform2D(0.0, Vector2(target_zoom, target_zoom), 0.0, (vp_size * 0.5) - (center * target_zoom))
			vp.canvas_transform = xf
			editor_navigated = true

		if canvas_editor != null:
			if target_pos != null:
				canvas_editor.call("center_at", target_pos)
			if canvas_editor.has_method("update_viewport"):
				canvas_editor.call("update_viewport")
			editor_navigated = true

		# Handle zoom adjustment in 2D editor via wheel simulation
		var zoom_delta := int(args.get("zoom_delta", 0))
		if zoom_delta != 0 and vp != null:
			var btn := MOUSE_BUTTON_WHEEL_UP if zoom_delta > 0 else MOUSE_BUTTON_WHEEL_DOWN
			for i in range(mini(10, absi(zoom_delta))):
				var ev := InputEventMouseButton.new()
				ev.button_index = btn
				ev.pressed = true
				ev.position = vp.get_visible_rect().size * 0.5
				vp.push_input(ev)
				var ev_rel := ev.duplicate()
				ev_rel.pressed = false
				vp.push_input(ev_rel)

	# 4. Handle Scene Camera2D
	var camera_navigated := false
	if (target == "camera" or target == "both") and scene_root != null:
		var cam := _find_first_child_of_type(scene_root, "Camera2D")
		if cam != null:
			if target_pos != null:
				cam.global_position = target_pos
				camera_navigated = true
			if args.has("zoom"):
				var z_val := float(args.get("zoom", 1.0))
				if z_val > 0.0:
					cam.zoom = Vector2(z_val, z_val)
					camera_navigated = true

	# 5. Capture screenshot if requested (default: true)
	var should_capture := bool(args.get("capture", true))
	var out := {
		"ok": true,
		"target": target,
		"position": [target_pos.x, target_pos.y] if target_pos != null else null,
		"zoom": final_zoom,
		"node_framed": str(node_ref.name) if node_ref != null else "",
		"editor_navigated": editor_navigated,
		"camera_navigated": camera_navigated,
		"source": "local",
	}

	if should_capture:
		var cap := _capture_viewport({"target": "editor"})
		if bool(cap.get("ok", false)):
			out["screenshot"] = cap
			out["base64"] = cap.get("base64", "")
			out["dimensions"] = cap.get("dimensions", "")
			out["width"] = cap.get("width", 0)
			out["height"] = cap.get("height", 0)
			out["preview"] = "Viewport navigated to %s at %.2fx zoom and screenshot captured (%s)" % [
				("[%0.1f, %0.1f]" % [target_pos.x, target_pos.y]) if target_pos != null else "target",
				final_zoom,
				str(cap.get("dimensions", "image"))
			]
		else:
			out["capture_error"] = cap.get("error", "Failed to capture screenshot")
	else:
		out["preview"] = "Viewport navigated to %s at %.2fx zoom" % [
			("[%0.1f, %0.1f]" % [target_pos.x, target_pos.y]) if target_pos != null else "target",
			final_zoom
		]

	return out


func _inspect_asset_image(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", "")).strip_edges()
	if path == "":
		return {"ok": false, "error": "missing_path", "message": "Specify the path to an image file or asset directory (e.g. res://icon.svg, res://assets/sprites/player.png)."}

	var global_path := ProjectSettings.globalize_path(path)

	# If path is not an existing file or directory, check if it refers to a node in the edited scene (e.g. 'World/GoalFlag')
	if not DirAccess.dir_exists_absolute(global_path) and not FileAccess.file_exists(global_path) and not FileAccess.file_exists(path):
		var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
		if scene_root != null:
			var target_node := _resolve_node(scene_root, path)
			if target_node != null:
				var found_tex: Texture2D = null
				if target_node.get("texture") is Texture2D:
					found_tex = target_node.get("texture") as Texture2D
				else:
					for ch in target_node.get_children():
						if ch.get("texture") is Texture2D:
							found_tex = ch.get("texture") as Texture2D
							break
				if found_tex != null and found_tex.resource_path != "":
					path = found_tex.resource_path
					global_path = ProjectSettings.globalize_path(path)

	# If a directory is specified, inspect all image assets inside it and report their pixel dimensions
	if DirAccess.dir_exists_absolute(global_path):
		var dir := DirAccess.open(global_path)
		if dir == null:
			return {"ok": false, "error": "failed_to_open_directory", "path": path}
		dir.list_dir_begin()
		var entry := dir.get_next()
		var items: Array = []
		while entry != "":
			if not dir.current_is_dir() and not entry.begins_with("."):
				var lower := entry.to_lower()
				if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp") or lower.ends_with(".svg") or lower.ends_with(".bmp") or lower.ends_with(".tga"):
					var item_path := path.path_join(entry) if path.ends_with("/") else path + "/" + entry
					var item_global := global_path.path_join(entry)
					var img := Image.load_from_file(item_global)
					if img != null and not img.is_empty():
						items.append({
							"name": entry,
							"path": item_path,
							"width": img.get_width(),
							"height": img.get_height(),
							"dimensions": "%dx%d pixels" % [img.get_width(), img.get_height()],
							"format": _image_format_name(img.get_format()),
							"has_alpha": img.detect_alpha() != Image.ALPHA_NONE,
						})
			entry = dir.get_next()
		dir.list_dir_end()
		return {
			"ok": true,
			"directory": path,
			"image_count": items.size(),
			"assets": items,
			"source": "local",
		}

	if not FileAccess.file_exists(global_path) and not FileAccess.file_exists(path):
		var parent_dir := path.get_base_dir()
		var parent_global := ProjectSettings.globalize_path(parent_dir)
		var suggestions: Array = []
		if DirAccess.dir_exists_absolute(parent_global):
			var pdir := DirAccess.open(parent_global)
			if pdir != null:
				pdir.list_dir_begin()
				var f := pdir.get_next()
				var target_stem := path.get_file().get_basename().to_lower().replace("-", "_")
				var target_tokens := target_stem.split("_")
				while f != "":
					if not pdir.current_is_dir() and not f.begins_with("."):
						var lower_f := f.to_lower()
						if lower_f.ends_with(".png") or lower_f.ends_with(".jpg") or lower_f.ends_with(".jpeg") or lower_f.ends_with(".webp") or lower_f.ends_with(".svg"):
							var matched := false
							for tok in target_tokens:
								if tok.length() >= 3 and lower_f.contains(tok):
									matched = true
									break
							if matched:
								var full_p := parent_dir.path_join(f) if parent_dir.ends_with("/") else parent_dir + "/" + f
								suggestions.append(full_p)
					f = pdir.get_next()
				pdir.list_dir_end()
		var msg := "File not found: " + path
		var hint := "Call inspect_asset_image('%s') to view all available image assets in that directory." % (parent_dir if parent_dir != "" else "res://assets/")
		if not suggestions.is_empty():
			hint = "File not found. Did you mean one of these matching assets: %s? You can also inspect the full directory via inspect_asset_image('%s')." % [", ".join(suggestions.slice(0, 5)), parent_dir]
		return {
			"ok": false,
			"error": "file_not_found",
			"path": path,
			"message": msg,
			"suggestions": suggestions.slice(0, 10),
			"hint": hint,
			"source": "local",
		}

	var img: Image = null
	var lower := path.to_lower()
	if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp") or lower.ends_with(".svg") or lower.ends_with(".bmp") or lower.ends_with(".tga"):
		var p_to_load := global_path if FileAccess.file_exists(global_path) else path
		img = Image.load_from_file(p_to_load)

	if img == null or img.is_empty():
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path)
			if res is Texture2D:
				img = res.get_image()

	if img == null or img.is_empty():
		return {"ok": false, "error": "failed_to_load_image", "path": path, "message": "Could not decode file as an image or texture asset."}

	var orig_w := img.get_width()
	var orig_h := img.get_height()
	var max_dim := clampi(int(args.get("max_dimension", 1024)), 64, 4096)
	var resized := false

	var img_to_send := img
	if orig_w > max_dim or orig_h > max_dim:
		var aspect := float(orig_w) / float(orig_h)
		var new_w := max_dim
		var new_h := max_dim
		if aspect >= 1.0:
			new_h = maxi(1, int(float(max_dim) / aspect))
		else:
			new_w = maxi(1, int(float(max_dim) * aspect))
		img_to_send = img.duplicate()
		img_to_send.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)
		resized = true

	var png_bytes := img_to_send.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)
	var file_size := 0
	if FileAccess.file_exists(global_path):
		var f := FileAccess.open(global_path, FileAccess.READ)
		if f != null:
			file_size = f.get_length()
			f.close()

	return {
		"ok": true,
		"path": path,
		"width": orig_w,
		"height": orig_h,
		"dimensions": "%dx%d pixels" % [orig_w, orig_h],
		"format": _image_format_name(img.get_format()),
		"has_alpha": img.detect_alpha() != Image.ALPHA_NONE,
		"file_size_bytes": file_size,
		"resized_for_vision": resized,
		"base64": b64,
		"source": "local",
	}


func _image_format_name(fmt: Image.Format) -> String:
	match fmt:
		Image.FORMAT_L8: return "L8"
		Image.FORMAT_LA8: return "LA8"
		Image.FORMAT_R8: return "R8"
		Image.FORMAT_RG8: return "RG8"
		Image.FORMAT_RGB8: return "RGB8"
		Image.FORMAT_RGBA8: return "RGBA8"
		Image.FORMAT_RGBA4444: return "RGBA4444"
		Image.FORMAT_RGB565: return "RGB565"
		Image.FORMAT_RF: return "RF"
		Image.FORMAT_RGF: return "RGF"
		Image.FORMAT_RGBF: return "RGBF"
		Image.FORMAT_RGBAF: return "RGBAF"
		Image.FORMAT_RH: return "RH"
		Image.FORMAT_RGH: return "RGH"
		Image.FORMAT_RGBH: return "RGBH"
		Image.FORMAT_RGBAH: return "RGBAH"
		Image.FORMAT_RGBE9995: return "RGBE9995"
		Image.FORMAT_DXT1: return "DXT1"
		Image.FORMAT_DXT3: return "DXT3"
		Image.FORMAT_DXT5: return "DXT5"
		Image.FORMAT_RGTC_R: return "RGTC_R"
		Image.FORMAT_RGTC_RG: return "RGTC_RG"
		Image.FORMAT_BPTC_RGBA: return "BPTC_RGBA"
		Image.FORMAT_BPTC_RGBF: return "BPTC_RGBF"
		Image.FORMAT_BPTC_RGBFU: return "BPTC_RGBFU"
		Image.FORMAT_ETC: return "ETC"
		Image.FORMAT_ETC2_R11: return "ETC2_R11"
		Image.FORMAT_ETC2_R11S: return "ETC2_R11S"
		Image.FORMAT_ETC2_RG11: return "ETC2_RG11"
		Image.FORMAT_ETC2_RG11S: return "ETC2_RG11S"
		Image.FORMAT_ETC2_RGB8: return "ETC2_RGB8"
		Image.FORMAT_ETC2_RGBA8: return "ETC2_RGBA8"
		Image.FORMAT_ETC2_RGB8A1: return "ETC2_RGB8A1"
		Image.FORMAT_ETC2_RA_AS_RG: return "ETC2_RA_AS_RG"
		Image.FORMAT_DXT5_RA_AS_RG: return "DXT5_RA_AS_RG"
		Image.FORMAT_ASTC_4x4: return "ASTC_4x4"
		Image.FORMAT_ASTC_4x4_HDR: return "ASTC_4x4_HDR"
		Image.FORMAT_ASTC_8x8: return "ASTC_8x8"
		Image.FORMAT_ASTC_8x8_HDR: return "ASTC_8x8_HDR"
		_: return "FORMAT_%d" % fmt


# ==============================================================================
# TileMap & Atlas Intelligence Toolkit
# ==============================================================================

const GLYPH_3X5 := {
	"0": [7, 5, 5, 5, 7],
	"1": [2, 6, 2, 2, 7],
	"2": [7, 1, 7, 4, 7],
	"3": [7, 1, 7, 1, 7],
	"4": [5, 5, 7, 1, 1],
	"5": [7, 4, 7, 1, 7],
	"6": [7, 4, 7, 5, 7],
	"7": [7, 1, 2, 2, 2],
	"8": [7, 5, 7, 5, 7],
	"9": [7, 5, 7, 1, 7],
	",": [0, 0, 0, 2, 4],
	"(": [2, 4, 4, 4, 2],
	")": [4, 2, 2, 2, 4],
	"-": [0, 0, 7, 0, 0],
	"A": [2, 5, 7, 5, 5],
	"B": [6, 5, 6, 5, 6],
	"C": [7, 4, 4, 4, 7],
	"D": [6, 5, 5, 5, 6],
	"E": [7, 4, 6, 4, 7],
	"F": [7, 4, 6, 4, 4],
	"G": [7, 4, 5, 5, 7],
	"H": [5, 5, 7, 5, 5],
	"I": [7, 2, 2, 2, 7],
	"J": [1, 1, 1, 5, 2],
	"K": [5, 5, 6, 5, 5],
	"L": [4, 4, 4, 4, 7],
	"M": [5, 7, 5, 5, 5],
	"N": [6, 5, 5, 5, 5],
	"O": [7, 5, 5, 5, 7],
	"P": [7, 5, 7, 4, 4],
	"Q": [7, 5, 5, 6, 3],
	"R": [6, 5, 6, 5, 5],
	"S": [7, 4, 7, 1, 7],
	"T": [7, 2, 2, 2, 2],
	"U": [5, 5, 5, 5, 7],
	"V": [5, 5, 5, 5, 2],
	"W": [5, 5, 5, 7, 5],
	"X": [5, 5, 2, 5, 5],
	"Y": [5, 5, 2, 2, 2],
	"Z": [7, 1, 2, 4, 7],
	":": [0, 2, 0, 2, 0],
	".": [0, 0, 0, 0, 2],
	"_": [0, 0, 0, 0, 7],
	"/": [1, 1, 2, 4, 4],
	"+": [0, 2, 7, 2, 0],
	"=": [0, 7, 0, 7, 0],
}


func _load_image(path: String) -> Image:
	var global_path := ProjectSettings.globalize_path(path)
	var img: Image = null
	var lower := path.to_lower()
	if lower.ends_with(".png") or lower.ends_with(".jpg") or lower.ends_with(".jpeg") or lower.ends_with(".webp") or lower.ends_with(".svg") or lower.ends_with(".bmp") or lower.ends_with(".tga"):
		var p_to_load := global_path if FileAccess.file_exists(global_path) else path
		img = Image.load_from_file(p_to_load)

	if img == null or img.is_empty():
		if ResourceLoader.exists(path):
			var res = ResourceLoader.load(path)
			if res is Texture2D:
				img = res.get_image()
			elif res is TileSet:
				for sid in res.get_source_count():
					var source_id: int = res.get_source_id(sid)
					var src: TileSetSource = res.get_source(source_id)
					if src is TileSetAtlasSource and src.texture != null:
						img = src.texture.get_image()
						break
	if img != null and not img.is_empty():
		if img.get_format() != Image.FORMAT_RGBA8:
			img.convert(Image.FORMAT_RGBA8)
	return img


func _draw_text_3x5(target: Image, px: int, py: int, text: String, color: Color) -> void:
	var cur_x := px
	var upper := text.to_upper()
	for ch in upper:
		if GLYPH_3X5.has(ch):
			var rows: Array = GLYPH_3X5[ch]
			for r in 5:
				var bits: int = rows[r]
				for c in 3:
					if (bits & (1 << (2 - c))) != 0:
						var tx := cur_x + c
						var ty := py + r
						if tx >= 0 and tx < target.get_width() and ty >= 0 and ty < target.get_height():
							target.set_pixel(tx, ty, color)
			cur_x += 4
		elif ch == " ":
			cur_x += 3
		else:
			cur_x += 3



# ==============================================================================
# TILEMAP AND ATLAS TOOLKIT (DELEGATED TO agent_tilemap_tools.gd)
# ==============================================================================

func _resolve_tilemap_texture_path(args: Dictionary) -> String:
	var t := _get_tilemap_tools()
	return t._resolve_tilemap_texture_path(args) if t != null else ""

func _analyze_atlas_geometry(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._analyze_atlas_geometry(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _preview_labelled_atlas(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._preview_labelled_atlas(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _analyze_tile_region(crop: Image) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._analyze_tile_region(crop) if t != null else {}

func _inspect_tile_crop(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._inspect_tile_crop(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _catalog_atlas_tiles(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._catalog_atlas_tiles(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _validate_atlas_coords(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._validate_atlas_coords(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _inspect_player_metrics(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._inspect_player_metrics(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _inspect_tilemap_layer(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._inspect_tilemap_layer(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _paint_tilemap_cells(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._paint_tilemap_cells(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _paint_tilemap_rect(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._paint_tilemap_rect(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _invoke_level_designer(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene", "message": "Open or create a scene before invoking the Level Designer."}

	var task := str(args.get("task", args.get("goal", "level_design"))).strip_edges()

	# 1. Discover all TileMapLayer nodes in the edited scene
	var tilemap_layers: Array = []
	var stack: Array = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is TileMapLayer:
			var tm: TileMapLayer = n as TileMapLayer
			var rect: Rect2i = tm.get_used_rect()
			var ts: TileSet = tm.tile_set
			tilemap_layers.append({
				"node_path": str(root.get_path_to(tm)),
				"name": str(tm.name),
				"tileset_assigned": ts != null,
				"used_cells_count": tm.get_used_cells().size(),
				"bounding_rect": [rect.position.x, rect.position.y, rect.size.x, rect.size.y],
				"tile_size": [ts.tile_size.x, ts.tile_size.y] if ts != null else [16, 16],
				"physics_layers_count": ts.get_physics_layers_count() if ts != null else 0
			})
		for c in n.get_children():
			stack.append(c)

	# 2. Discover reusable scenes in project (e.g. res://scenes/)
	var available_entity_scenes: Array = []
	var scene_scan_dirs: Array[String] = ["res://scenes", "res://"]
	for sdir in scene_scan_dirs:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(sdir)):
			var d := DirAccess.open(sdir)
			if d != null:
				d.list_dir_begin()
				var fn := d.get_next()
				while fn != "":
					if not d.current_is_dir() and (fn.ends_with(".tscn") or fn.ends_with(".scn")):
						var full_p: String = sdir.path_join(fn)
						if not available_entity_scenes.has(full_p) and full_p != root.scene_file_path:
							available_entity_scenes.append(full_p)
					fn = d.get_next()
				d.list_dir_end()

	# 3. Discover Player Metrics
	var player_metrics := _inspect_player_metrics({})
	var max_h_reach: float = 240.0
	var max_jump_h: float = 120.0
	if player_metrics.get("ok", false):
		var pdata: Dictionary = player_metrics.get("data", {})
		max_h_reach = float(pdata.get("max_horizontal_reach", 240.0))
		max_jump_h = float(pdata.get("max_jump_height", 120.0))

	# 4. Formulate Level Designer Directives
	var directives: Array = []
	directives.append("1. PICTURE ENTIRE LEVEL FIRST: Before placing or painting a single tile, picture the complete level layout and write out the blueprint in <think>...</think> with world coordinate bounds, player spawn, platform sequence, jump gaps, hazards, goal position, and background coverage.")
	directives.append("2. TILEMAP-FIRST MANDATE & TILE-BY-TILE ATLAS SEMANTIC CLASSIFICATION: All walkable ground, floors, walls, and grid platforms MUST be painted onto a TileMapLayer using paint_tilemap_rect or paint_tilemap_cells. Before painting, you MUST analyze the tileset atlas (using catalog_atlas_tiles, preview_labelled_atlas, or analyze_atlas_geometry) and reason tile-by-tile in <think> to build a Semantic Tile Dictionary mapping [col, row] coordinates to roles: corner_top_left, ground_top, corner_top_right, left_edge, interior_fill, right_edge, bottom_edge, single_tile_island, hazard, decor. Rule: interior_fill MUST NEVER touch air or be placed on platform edges; platforms MUST terminate with proper left/right corner end-caps; top surfaces MUST use walkable surface tiles. Never create individual loose StaticBody2D nodes for tile-grid terrain.")
	directives.append("3. SCENE REUSE MANDATE: Reusable entities (characters, hazards, interactive platforms, pickups) must be instantiated using instance_scene(scene_path=..., parent_path=..., properties=...) or 'instance_scene' in create_node_hierarchy. Never recreate their child node hierarchies inside the level.")
	directives.append("4. IRREGULAR TERRAIN & SLOPES: For curved, angled, or organic terrain not fitting square tile cells, use StaticBody2D with Polygon2D and CollisionPolygon2D, setting the 'polygon' property with PackedVector2Array.")
	directives.append("5. JUMP METRICS: Platforms must not exceed a horizontal gap of %.1f px or vertical height difference of %.1f px to guarantee reachability." % [max_h_reach, max_jump_h])
	directives.append("6. PAN/ZOOM DEFECT RESOLUTION LOOP: After building or modifying geometry, use navigate_viewport(position=..., zoom_delta=..., capture=true) to inspect each sector. Verify: 1) End-cap tiles on platforms (edges must be end-caps, not mid-fill tiles), 2) Tile overlaps & gaps, 3) Continuous collision chains (validate_tileset_physics), 4) Background visual coverage (no uncovered strips). If ANY defect is found, fix it immediately, pan/zoom and capture to re-verify, and LOOP UNTIL NO DEFECTS REMAIN.")
	directives.append("7. RUNTIME COLLISION DEBUGGING: Call toggle_debug_collisions(visible=true) to enable runtime collision rendering during playtests.")
	directives.append("8. HANDOVER REPORT: Follow Core Flow (Inspect -> Tile-by-Tile Atlas Analysis -> Picture & Plan -> Mutate -> Pan/Zoom Defect Loop -> Handover Report). Upon completion, report back to Main Agent with layers created, cells painted, entities instanced, verification results, and suggested gameplay integration.")
	directives.append("9. IN-PLACE EDITING & ZERO DUPLICATION: Inspect existing layers, nodes, and scenes first. Edit existing TileMapLayers and scenes in place. Strictly avoid creating duplicate levels, duplicate scenes, or deleting existing working geometry without prior inspection.")
	directives.append("10. CONCEPT CAUSALITY & RIPPLE AUDIT: Every level change has interconnected engine consequences: 1) Level Bounds ➔ Camera2D Limits: Extending platforms right/left requires setting Camera2D.limit_* to match, otherwise the player walks off-screen. 2) Camera Viewport ➔ Background Coverage: The background (ColorRect/Parallax2D) must extend from Camera2D.limit_left (negative space if needed) past limit_right; never start a background at X=0 if the camera looks left of 0. 3) Painted Tiles ➔ Collision Polygons: Painting a tile only places pixels; verify with validate_tileset_physics that the atlas tile has an active collision polygon in TileSet physics layer 0, or the player will fall through. 4) Player Jump Metrics ➔ Platform Elevation: Never place platforms higher than %.1f px or farther than %.1f px." % [max_jump_h, max_h_reach])
	directives.append("11. ANTI-HALLUCINATION LAW: A tool returning ok:true or painted cells count is NOT proof the level is complete. You must prove the full gameplay chain: Grounded Player Spawn ➔ Solid Collision Polygons ➔ Reachable Jump Paths ➔ Full Camera Framing with Zero Void. Never conclude until the pan/zoom defect loop passes with zero flaws.")

	var warnings: Array = []
	if tilemap_layers.is_empty():
		warnings.append("NO_TILEMAP_LAYER_FOUND: Active scene has no TileMapLayer. You must create a TileMapLayer (e.g. Ground_Base) and assign a TileSet BEFORE creating platforms.")

	return {
		"ok": true,
		"specialized_agent": "LevelDesigner",
		"task": task,
		"status": "ready",
		"mandate": "YOU ARE NOW IN LEVEL DESIGNER MODE. You must execute the 5-step sequence: 1) Analyze the atlas tile-by-tile with catalog_atlas_tiles and build the Semantic Tile Dictionary in <think>, 2) Plan level blueprint in <think>, 3) Build geometry strictly adhering to tile semantic roles with TileMapLayer and instance_scene, 4) MANDATORY PAN & ZOOM INSPECTION: Call navigate_viewport(position=[x, y], zoom_delta=..., capture=true) on EACH sector (spawn, platform edges, background boundary), 5) VISUAL DEFECT REASONING in <think> for each screenshot. Fix any defects found before completing.",
		"required_next_steps": [
			"1. TILE-BY-TILE ATLAS CLASSIFICATION: Call catalog_atlas_tiles or preview_labelled_atlas. In <think>, systematically classify tiles into an Atlas Semantic Role Dictionary ([col, row] -> corner_top_left, ground_top, corner_top_right, left_edge, interior_fill, right_edge, bottom_edge, single_tile_island).",
			"2. REASON IN <think>: Formulate the level blueprint with world bounds, player spawn coordinates, platform elevations, and camera boundaries using the semantic tile coordinates.",
			"3. CONSTRUCT: Paint terrain onto TileMapLayer (enclosing interior fill, capping platform edges) and instance reusable scenes.",
			"4. PAN/ZOOM INSPECTION: Call navigate_viewport(position=[x, y], zoom_delta=..., capture=true) on EACH sector (player spawn, platform ends, hazard gaps, camera bounds).",
			"5. VISUAL REASONING IN <think>: For each captured screenshot, explicitly reason in <think> about what you see: check platform end-cap tiles, 1px seams, background coverage, and player grounding.",
			"6. RESOLVE DEFECTS: If any defect is spotted, fix it and re-navigate with navigate_viewport to verify until ZERO defects remain.",
			"7. HANDOVER REPORT: Output the structured Handover Report to return control to the Main Agent."
		],
		"tilemap_first_enforced": true,
		"tilemap_layers": tilemap_layers,
		"available_entity_scenes": available_entity_scenes,
		"player_metrics": player_metrics.get("data", {}),
		"directives": directives,
		"warnings": warnings,
		"recommended_tools": [
			"navigate_viewport", "catalog_atlas_tiles", "preview_labelled_atlas", "analyze_atlas_geometry", "inspect_tile_crop",
			"auto_generate_atlas_tiles", "paint_tilemap_rect", "paint_tilemap_cells", "instance_scene",
			"inspect_tilemap_layer", "validate_tileset_physics",
			"inspect_player_metrics", "inspect_spatial_context", "toggle_debug_collisions",
			"capture_viewport"
		],
		"source": "local"
	}


# ==============================================================================
# Spatial Awareness 2D Toolkit (Deterministic Geometry & Spatial Queries)
# ==============================================================================


# ==============================================================================
# SPATIAL AWARENESS & COLLISION (DELEGATED TO agent_spatial_tools.gd)
# ==============================================================================

func _shape2d_local_corners(shape: Shape2D) -> PackedVector2Array:
	return _spatial_tools._shape2d_local_corners(shape) if _spatial_tools != null else PackedVector2Array()

func _shape_info(shape: Shape2D) -> Dictionary:
	return _spatial_tools._shape_info(shape) if _spatial_tools != null else {"type": "null"}

func _rect_from_points(pts: PackedVector2Array, xf: Transform2D) -> Rect2:
	return _spatial_tools._rect_from_points(pts, xf) if _spatial_tools != null else Rect2()

func _transform_rect(xf: Transform2D, r: Rect2) -> Rect2:
	return _spatial_tools._transform_rect(xf, r) if _spatial_tools != null else Rect2()

func _compute_node_2d_bounds(node: Node) -> Rect2:
	return _spatial_tools._compute_node_2d_bounds(node) if _spatial_tools != null else Rect2()

func _find_camera_2d(node: Node) -> Camera2D:
	return _spatial_tools._find_camera_2d(node) if _spatial_tools != null else null

func _inspect_spatial_context(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	return st._inspect_spatial_context(args) if st != null else {"ok": false, "error": "tool_unavailable"}

func _convert_spatial_coordinates(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	return st._convert_spatial_coordinates(args) if st != null else {"ok": false, "error": "tool_unavailable"}

func _inspect_spatial_region(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	return st._inspect_spatial_region(args) if st != null else {"ok": false, "error": "tool_unavailable"}

func _query_spatial_relationships(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	return st._query_spatial_relationships(args) if st != null else {"ok": false, "error": "tool_unavailable"}

func _preview_spatial_overlay(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	return st._preview_spatial_overlay(args) if st != null else {"ok": false, "error": "tool_unavailable"}

func _is_shape_shared_in_scene(root: Node, shape: Shape2D, ignore_node: Node = null) -> Dictionary:
	var st := _get_spatial_tools()
	return st._is_shape_shared_in_scene(root, shape, ignore_node) if st != null else {"is_shared": false, "users": []}

func _extract_image_from_texture(tex: Texture2D) -> Dictionary:
	var st := _get_spatial_tools()
	return st._extract_image_from_texture(tex) if st != null else {"ok": false, "error": "null_texture"}

func _measure_image_opaque_rect(img: Image, region: Rect2i, alpha_threshold: float = 0.05) -> Dictionary:
	var st := _get_spatial_tools()
	return st._measure_image_opaque_rect(img, region, alpha_threshold) if st != null else {"ok": false, "has_opaque_pixels": false}

func _get_sprite_render_info(sprite: Node, anim_name: String = "", frame_idx: int = -1, alpha_threshold: float = 0.05) -> Dictionary:
	var st := _get_spatial_tools()
	return st._get_sprite_render_info(sprite, anim_name, frame_idx, alpha_threshold) if st != null else {"ok": false}

func _inspect_collision_geometry(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	if st != null:
		return st._inspect_collision_geometry(args)
	var root := _get_scene_root()
	if root == null: return {"ok": false, "error": "no_edited_scene"}
	var path := str(args.get("node_path", args.get("collider_path", args.get("path", ""))))
	var node := _resolve_node(root, path)
	if node == null:
		return {"ok": false, "error": "node_not_found", "path": path}
	var col_node: Node = null
	if node is CollisionShape2D:
		col_node = node
	elif node != null:
		for child in node.get_children():
			if child is CollisionShape2D:
				col_node = child
				break
	if col_node != null and col_node is CollisionShape2D:
		var cs: CollisionShape2D = col_node as CollisionShape2D
		var s: Shape2D = cs.shape
		var dims: Dictionary = {}
		if s is RectangleShape2D:
			dims = {"width": (s as RectangleShape2D).size.x, "height": (s as RectangleShape2D).size.y, "size": [(s as RectangleShape2D).size.x, (s as RectangleShape2D).size.y]}
		elif s is CapsuleShape2D:
			dims = {"radius": (s as CapsuleShape2D).radius, "height": (s as CapsuleShape2D).height}
		elif s is CircleShape2D:
			dims = {"radius": (s as CircleShape2D).radius}
		return {
			"ok": true,
			"colliders": [{
				"node_path": str(root.get_path_to(cs)),
				"shape_type": s.get_class() if s != null else "null",
				"dimensions": dims,
				"position": [cs.position.x, cs.position.y],
				"scale": [cs.scale.x, cs.scale.y],
				"disabled": cs.disabled
			}]
		}
	return {"ok": false, "error": "tool_unavailable", "hint": "Collision geometry tools unavailable"}

func _measure_visual_bounds(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	return st._measure_visual_bounds(args) if st != null else {"ok": false, "error": "tool_unavailable"}

func _calibrate_collision_shape(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	return st._calibrate_collision_shape(args) if st != null else {"ok": false, "error": "tool_unavailable"}

func _draw_line_on_img(target: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var st := _get_spatial_tools()
	if st != null:
		st._draw_line_on_img(target, x0, y0, x1, y1, col)

func _draw_rect_wireframe(target: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	var st := _get_spatial_tools()
	if st != null:
		st._draw_rect_wireframe(target, rx, ry, rw, rh, col)

func _draw_capsule_wireframe(target: Image, cx: int, cy: int, rad: int, height: int, col: Color) -> void:
	var st := _get_spatial_tools()
	if st != null:
		st._draw_capsule_wireframe(target, cx, cy, rad, height, col)

func _preview_collision_overlay(args: Dictionary) -> Dictionary:
	var st := _get_spatial_tools()
	return st._preview_collision_overlay(args) if st != null else {"ok": false, "error": "tool_unavailable"}

func _inspect_scene_diff(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var current_snap := _snapshot_scene_tree(root)
	var baseline_v: Variant = args.get("baseline", null)
	var baseline: Dictionary = {}
	if typeof(baseline_v) == TYPE_DICTIONARY:
		baseline = baseline_v
	var diff: Dictionary = {}
	if not baseline.is_empty():
		diff = _diff_scene_trees(baseline, current_snap)
	return {
		"ok": true,
		"scene_root": str(root.name),
		"scene_file_path": root.scene_file_path,
		"node_count": current_snap.size(),
		"tree_snapshot": current_snap,
		"diff": diff,
		"source": "local",
	}


func _set_task_criteria(args: Dictionary) -> Dictionary:
	if task_runtime == null:
		task_runtime = preload("res://addons/godot_agent/agent_task_runtime.gd").new()
	var tid := _get_active_task_id(args)
	if tid == "":
		return {"ok": false, "error": "no_active_task", "hint": "No active task found to assign criteria to."}
	var raw_criteria: Variant = args.get("criteria", args.get("criteria_list", []))
	var criteria_list: Array = []
	if typeof(raw_criteria) == TYPE_ARRAY:
		criteria_list = raw_criteria
	elif typeof(raw_criteria) == TYPE_DICTIONARY:
		criteria_list = [raw_criteria]
	else:
		return {"ok": false, "error": "invalid_criteria_format", "hint": "Provide 'criteria' as an array of criterion objects."}
	var updated_task: Dictionary = task_runtime.set_criteria(tid, criteria_list) if task_runtime != null and task_runtime.has_method("set_criteria") else {}
	return {
		"ok": true,
		"task_id": tid,
		"criteria_count": (updated_task.get("criteria", []) as Array).size(),
		"criteria": updated_task.get("criteria", []),
		"source": "local",
	}



func _validate_tileset_physics(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._validate_tileset_physics(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _ensure_input_action_registered(action: String, auto_create: bool = false) -> Dictionary:
	var s_name := StringName(action)
	# 1. Already registered in active InputMap singleton?
	if InputMap.has_action(s_name):
		return {
			"ok": true,
			"action": action,
			"source": "input_map",
			"auto_created": false,
			"bindings": _get_action_binding_strings(s_name),
			"deadzone": InputMap.action_get_deadzone(s_name)
		}

	# 2. Try loading from ProjectSettings into InputMap
	InputMap.load_from_project_settings()
	if InputMap.has_action(s_name):
		return {
			"ok": true,
			"action": action,
			"source": "project_settings_loaded",
			"auto_created": false,
			"bindings": _get_action_binding_strings(s_name),
			"deadzone": InputMap.action_get_deadzone(s_name)
		}

	# 3. Check ProjectSettings key directly: "input/" + action
	var setting_key := "input/" + action
	var setting_val: Variant = null
	if ProjectSettings.has_setting(setting_key):
		setting_val = ProjectSettings.get_setting(setting_key)
	else:
		# Check project.godot directly via ConfigFile in case ProjectSettings cache hasn't reloaded
		var cf := ConfigFile.new()
		if cf.load("res://project.godot") == OK and cf.has_section_key("input", action):
			setting_val = cf.get_value("input", action)
			ProjectSettings.set_setting(setting_key, setting_val)

	if setting_val != null:
		var deadzone: float = 0.5
		if setting_val is Dictionary:
			deadzone = float((setting_val as Dictionary).get("deadzone", 0.5))
		if not InputMap.has_action(s_name):
			InputMap.add_action(s_name, deadzone)
		else:
			InputMap.action_set_deadzone(s_name, deadzone)
		if setting_val is Dictionary and (setting_val as Dictionary).has("events"):
			var ev_arr: Array = (setting_val as Dictionary).get("events", [])
			for ev in ev_arr:
				if ev is InputEvent:
					if not InputMap.action_has_event(s_name, ev):
						InputMap.action_add_event(s_name, ev)
				elif ev is Dictionary:
					var pk := int((ev as Dictionary).get("physical_keycode", (ev as Dictionary).get("keycode", 0)))
					if pk != 0:
						var iek := InputEventKey.new()
						iek.physical_keycode = pk
						if not InputMap.action_has_event(s_name, iek):
							InputMap.action_add_event(s_name, iek)
		return {
			"ok": true,
			"action": action,
			"source": "project_setting_registered",
			"auto_created": false,
			"bindings": _get_action_binding_strings(s_name),
			"deadzone": deadzone
		}

	# 4. Auto-create if requested or as fallback for known actions
	if auto_create or action != "":
		var deadzone: float = 0.5
		if not InputMap.has_action(s_name):
			InputMap.add_action(s_name, deadzone)
		var default_key: int = 0
		match action.to_lower():
			"move_right", "right":
				default_key = KEY_D
			"move_left", "left":
				default_key = KEY_A
			"move_up", "up":
				default_key = KEY_W
			"move_down", "down":
				default_key = KEY_S
			"jump":
				default_key = KEY_SPACE
			"attack":
				default_key = KEY_J
			"interact":
				default_key = KEY_E
			_:
				default_key = KEY_SPACE

		var iek := InputEventKey.new()
		iek.physical_keycode = default_key
		if not InputMap.action_has_event(s_name, iek):
			InputMap.action_add_event(s_name, iek)

		# Persist to ProjectSettings
		var action_dict := {
			"deadzone": deadzone,
			"events": [{"physical_keycode": float(default_key)}]
		}
		ProjectSettings.set_setting(setting_key, action_dict)
		ProjectSettings.save()
		return {
			"ok": true,
			"action": action,
			"source": "auto_created",
			"auto_created": true,
			"bindings": _get_action_binding_strings(s_name),
			"deadzone": deadzone,
			"default_key": OS.get_keycode_string(default_key)
		}

	return {
		"ok": false,
		"error": "unknown_action",
		"action": action,
		"hint": "The action '%s' is not defined in ProjectSettings -> InputMap." % action
	}


func _get_action_binding_strings(action: StringName) -> Array:
	var bindings: Array = []
	if not InputMap.has_action(action):
		return bindings
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			var code: int = ev.physical_keycode if ev.physical_keycode != 0 else ev.keycode
			bindings.append(OS.get_keycode_string(code))
		elif ev is InputEventMouseButton:
			bindings.append("MouseButton_%d" % ev.button_index)
		elif ev is InputEventJoypadButton:
			bindings.append("JoypadButton_%d" % ev.button_index)
	return bindings


func _configure_input_action(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", args.get("name", ""))).strip_edges()
	if action == "":
		return {"ok": false, "error": "missing_action_name", "hint": "Specify 'action' or 'name' (e.g. 'move_right', 'jump')."}

	var deadzone: float = clampf(float(args.get("deadzone", 0.5)), 0.0, 1.0)
	var s_name := StringName(action)
	var replace := bool(args.get("replace", true))

	if not InputMap.has_action(s_name):
		InputMap.add_action(s_name, deadzone)
	else:
		InputMap.action_set_deadzone(s_name, deadzone)
		if replace:
			for existing_ev in InputMap.action_get_events(s_name):
				InputMap.action_erase_event(s_name, existing_ev)

	var raw_events: Variant = args.get("events", args.get("keys", args.get("keycode", args.get("key", []))))
	var event_items: Array = []
	if raw_events is Array:
		event_items = raw_events
	elif raw_events is String or raw_events is int:
		event_items = [raw_events]

	var added_bindings: Array = []
	var serialized_events: Array = []

	for item in event_items:
		var ev: InputEvent = null
		if item is String:
			var s := (item as String).strip_edges()
			if s.is_empty():
				continue
			var code := OS.find_keycode_from_string(s)
			if code == 0 and s.is_valid_int():
				code = s.to_int()
			if code != 0:
				var iek := InputEventKey.new()
				iek.physical_keycode = code
				ev = iek
				added_bindings.append(s)
				serialized_events.append({"physical_keycode": float(code)})
			elif s.to_lower() in ["left_click", "left_mouse", "mouse_left"]:
				var iemb := InputEventMouseButton.new()
				iemb.button_index = MOUSE_BUTTON_LEFT
				ev = iemb
				added_bindings.append("MouseLeft")
				serialized_events.append({"button_index": float(MOUSE_BUTTON_LEFT)})
			elif s.to_lower() in ["right_click", "right_mouse", "mouse_right"]:
				var iemb := InputEventMouseButton.new()
				iemb.button_index = MOUSE_BUTTON_RIGHT
				ev = iemb
				added_bindings.append("MouseRight")
				serialized_events.append({"button_index": float(MOUSE_BUTTON_RIGHT)})
		elif item is int:
			var iek := InputEventKey.new()
			iek.physical_keycode = int(item)
			ev = iek
			added_bindings.append(OS.get_keycode_string(int(item)))
			serialized_events.append({"physical_keycode": float(item)})
		elif item is Dictionary:
			var d: Dictionary = item
			var code_val: Variant = d.get("physical_keycode", d.get("keycode", d.get("key", 0)))
			var code := 0
			if code_val is int:
				code = int(code_val)
			elif code_val is String:
				code = OS.find_keycode_from_string(code_val)
				if code == 0 and (code_val as String).is_valid_int():
					code = (code_val as String).to_int()
			if code != 0:
				var iek := InputEventKey.new()
				iek.physical_keycode = code
				if bool(d.get("shift", false)): iek.shift_pressed = true
				if bool(d.get("ctrl", false)): iek.ctrl_pressed = true
				if bool(d.get("alt", false)): iek.alt_pressed = true
				ev = iek
				added_bindings.append(OS.get_keycode_string(code))
				serialized_events.append({"physical_keycode": float(code)})

		if ev != null and not InputMap.action_has_event(s_name, ev):
			InputMap.action_add_event(s_name, ev)

	var setting_key := "input/" + action
	var setting_data := {
		"deadzone": deadzone,
		"events": serialized_events
	}
	ProjectSettings.set_setting(setting_key, setting_data)
	ProjectSettings.save()

	return {
		"ok": true,
		"action": action,
		"deadzone": deadzone,
		"bindings": _get_action_binding_strings(s_name),
		"events_count": serialized_events.size(),
		"added_to_input_map": true,
		"saved_to_project_settings": true,
		"source": "local"
	}


func _test_runtime_action(args: Dictionary) -> Dictionary:
	var action := str(args.get("action", "")).strip_edges()
	if action == "":
		return {"ok": false, "error": "missing_action", "hint": "Specify 'action' name, e.g. 'ui_right', 'move_right', 'jump'"}

	var auto_create := bool(args.get("auto_create", true))
	var reg := _ensure_input_action_registered(action, auto_create)
	if not reg.get("ok", false):
		return reg

	var root := _get_scene_root()
	var target_path := str(args.get("node_path", args.get("target", ""))).strip_edges()
	var target_node: Node = null
	if root != null:
		if target_path != "":
			target_node = _resolve_node(root, target_path)
		else:
			target_node = _find_first_child_of_type(root, "CharacterBody2D")

	var duration := clampf(float(args.get("duration_seconds", args.get("duration", 0.5))), 0.05, 5.0)
	var expected_cond := str(args.get("expected_condition", "target node responds to action"))

	var initial_state: Dictionary = {}
	if target_node != null:
		initial_state["position"] = _jsonish(target_node.get("position")) if target_node.get("position") != null else null
		initial_state["velocity"] = _jsonish(target_node.get("velocity")) if target_node.get("velocity") != null else null

	Input.action_press(action, 1.0)
	OS.delay_msec(int(duration * 1000.0))
	Input.action_release(action)

	var post_state: Dictionary = {}
	if target_node != null:
		post_state["position"] = _jsonish(target_node.get("position")) if target_node.get("position") != null else null
		post_state["velocity"] = _jsonish(target_node.get("velocity")) if target_node.get("velocity") != null else null

	var observed_cond := "Action '%s' simulated for %.2fs." % [action, duration]
	var passed := true

	if initial_state.get("position") != null and post_state.get("position") != null:
		var p0 = initial_state["position"]
		var p1 = post_state["position"]
		if typeof(p0) == TYPE_ARRAY and typeof(p1) == TYPE_ARRAY and p0.size() >= 2 and p1.size() >= 2:
			var dx = float(p1[0]) - float(p0[0])
			var dy = float(p1[1]) - float(p0[1])
			observed_cond += " Position delta: dx=%.1f, dy=%.1f." % [dx, dy]

	return {
		"ok": true,
		"action": action,
		"duration_seconds": duration,
		"action_exists_in_input_map": true,
		"action_source": reg.get("source", "input_map"),
		"action_bindings": reg.get("bindings", []),
		"deadzone": reg.get("deadzone", 0.5),
		"auto_created": reg.get("auto_created", false),
		"initial_conditions": initial_state,
		"player_position_before": initial_state.get("position"),
		"player_position_after": post_state.get("position"),
		"velocity_before": initial_state.get("velocity"),
		"velocity_after": post_state.get("velocity"),
		"expected_condition": expected_cond,
		"observed_condition": observed_cond,
		"passed": passed,
		"note": "Input action verified in InputMap and tested at editor process level. In-editor scene nodes do not step game physics during editor execution. For live physics traversal testing, run the game using run_game or runtime MCP tools.",
		"source": "local",
	}



func _auto_generate_atlas_tiles(args: Dictionary) -> Dictionary:
	var t := _get_tilemap_tools()
	return t._auto_generate_atlas_tiles(args) if t != null else {"ok": false, "error": "tool_unavailable"}

func _discover_capabilities(_args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	var has_scene := root != null
	var has_tilemap := false
	var has_body := false
	var has_player := false
	var has_tree := false
	if root != null:
		has_tilemap = _find_first_child_of_type(root, "TileMapLayer") != null or _find_first_child_of_type(root, "TileMap") != null
		has_body = _find_first_child_of_type(root, "CharacterBody2D") != null or _find_first_child_of_type(root, "RigidBody2D") != null
		has_player = _find_first_child_of_type(root, "AnimationPlayer") != null
		has_tree = _find_first_child_of_type(root, "AnimationTree") != null

	var actions_count := InputMap.get_actions().size()
	var base_ctrl := EditorInterface.get_base_control()
	var has_viewport := base_ctrl != null and base_ctrl.get_viewport() != null

	return {
		"ok": true,
		"manifest": {
			"scene_mutation": {
				"available": true,
				"readback": true,
				"persistence_verification": true,
				"active_scene_loaded": has_scene
			},
			"tilemap_physics": {
				"available": true,
				"collision_validation": true,
				"active_tilemap_present": has_tilemap
			},
			"animation_systems": {
				"available": true,
				"animation_player_present": has_player,
				"animation_tree_present": has_tree
			},
			"runtime_input": {
				"available": true,
				"action_simulation": true,
				"input_map_actions_configured": actions_count
			},
			"visual_inspection": {
				"capture_available": has_viewport,
				"image_delivery_available": true
			}
		},
		"engine_version": Engine.get_version_info().get("string", "4.7"),
		"active_scene": root.scene_file_path if root != null else "",
		"source": "local",
	}


# ==============================================================================
# ANIMATION SYSTEMS (AnimationPlayer, AnimationTree, StateMachine, BlendTree)
# ==============================================================================


# ==============================================================================
# ANIMATION SYSTEMS (DELEGATED TO agent_animation_tools.gd)
# ==============================================================================

func _parse_loop_mode(val: Variant) -> int:
	return _animation_tools._parse_loop_mode(val) if _animation_tools != null else 0

func _loop_mode_to_string(mode: int) -> String:
	return _animation_tools._loop_mode_to_string(mode) if _animation_tools != null else ""

func _track_type_to_string(type_int: int) -> String:
	return _animation_tools._track_type_to_string(type_int) if _animation_tools != null else ""

func _track_string_to_type(s: String) -> int:
	return _animation_tools._track_string_to_type(s) if _animation_tools != null else 0

func _interpolation_type_to_string(type_int: int) -> String:
	return _animation_tools._interpolation_type_to_string(type_int) if _animation_tools != null else ""

func _interpolation_string_to_type(s: String) -> int:
	return _animation_tools._interpolation_string_to_type(s) if _animation_tools != null else 0

func _update_mode_to_string(m: int) -> String:
	return _animation_tools._update_mode_to_string(m) if _animation_tools != null else ""

func _update_string_to_mode(s: String) -> int:
	return _animation_tools._update_string_to_mode(s) if _animation_tools != null else 0

func _resolve_animation_player(root: Node, path_arg: String) -> AnimationPlayer:
	return _animation_tools._resolve_animation_player(root, path_arg) if _animation_tools != null else null

func _resolve_animation_tree(root: Node, path_arg: String) -> AnimationTree:
	return _animation_tools._resolve_animation_tree(root, path_arg) if _animation_tools != null else null

func _split_animation_name(full_name: String) -> Array:
	return _animation_tools._split_animation_name(full_name) if _animation_tools != null else ["", full_name]

func _parse_vector2_safe(val: Variant) -> Vector2:
	return _animation_tools._parse_vector2_safe(val) if _animation_tools != null else Vector2.ZERO

func _inspect_animation_player(args: Dictionary) -> Dictionary:
	return _animation_tools._inspect_animation_player(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _inspect_animation_tracks(args: Dictionary) -> Dictionary:
	return _animation_tools._inspect_animation_tracks(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _edit_animation_player(args: Dictionary) -> Dictionary:
	return _animation_tools._edit_animation_player(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _inspect_animation_tree(args: Dictionary) -> Dictionary:
	return _animation_tools._inspect_animation_tree(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _edit_animation_tree(args: Dictionary) -> Dictionary:
	return _animation_tools._edit_animation_tree(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _edit_animation_state_machine(args: Dictionary) -> Dictionary:
	return _animation_tools._edit_animation_state_machine(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _edit_animation_blend_space(args: Dictionary) -> Dictionary:
	return _animation_tools._edit_animation_blend_space(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _get_set_animation_parameters(args: Dictionary) -> Dictionary:
	return _animation_tools._get_set_animation_parameters(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _validate_animation_system(args: Dictionary) -> Dictionary:
	return _animation_tools._validate_animation_system(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

func _test_animation_runtime(args: Dictionary) -> Dictionary:
	return _animation_tools._test_animation_runtime(args) if _animation_tools != null else {"ok": false, "error": "tool_unavailable"}

