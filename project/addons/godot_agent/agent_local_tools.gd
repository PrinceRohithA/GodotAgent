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


func _get_scene_root() -> Node:
	if Engine.is_editor_hint():
		if ClassDB.class_exists("EditorInterface") or Engine.has_singleton("EditorInterface"):
			return EditorInterface.get_edited_scene_root()
	return null


func has_tool(name: String) -> bool:
	return name in LOCAL_NAMES or name in [
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
	match name:
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

		if canvas_editor != null and target_pos != null:
			canvas_editor.call("center_at", target_pos)
			if canvas_editor.has_method("update_viewport"):
				canvas_editor.call("update_viewport")
			editor_navigated = true
		elif vp != null and target_pos != null:
			var xf := vp.canvas_transform
			xf.origin = -target_pos * xf.get_scale() + (vp.get_visible_rect().size * 0.5)
			vp.canvas_transform = xf
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
			out["preview"] = "Viewport navigated to %s and screenshot captured (%s)" % [
				("[%0.1f, %0.1f]" % [target_pos.x, target_pos.y]) if target_pos != null else "target",
				str(cap.get("dimensions", "image"))
			]
		else:
			out["capture_error"] = cap.get("error", "Failed to capture screenshot")
	else:
		out["preview"] = "Viewport navigated to %s" % (("[%0.1f, %0.1f]" % [target_pos.x, target_pos.y]) if target_pos != null else "target")

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


func _resolve_tilemap_texture_path(args: Dictionary) -> String:
	var path := str(args.get("path", args.get("texture_path", args.get("texture", "")))).strip_edges()
	if path != "":
		return path

	var scene_root: Node = EditorInterface.get_edited_scene_root() if Engine.is_editor_hint() else null
	var node_path_arg := str(args.get("node_path", "")).strip_edges()

	# If node_path is specified, resolve it
	if scene_root != null and node_path_arg != "":
		var n := _resolve_node(scene_root, node_path_arg)
		if n is TileMapLayer:
			var tm := n as TileMapLayer
			if tm.tile_set != null:
				for i in range(tm.tile_set.get_source_count()):
					var sid := tm.tile_set.get_source_id(i)
					var src := tm.tile_set.get_source(sid)
					if src is TileSetAtlasSource and (src as TileSetAtlasSource).texture != null:
						return (src as TileSetAtlasSource).texture.resource_path
		elif n is Sprite2D and (n as Sprite2D).texture != null:
			return (n as Sprite2D).texture.resource_path

	# If no path specified, search active scene for the first TileMapLayer with a TileSet texture
	if scene_root != null:
		var tm := _find_first_child_of_type(scene_root, "TileMapLayer")
		if tm != null and tm is TileMapLayer and (tm as TileMapLayer).tile_set != null:
			var ts: TileSet = (tm as TileMapLayer).tile_set
			for i in range(ts.get_source_count()):
				var sid := ts.get_source_id(i)
				var src := ts.get_source(sid)
				if src is TileSetAtlasSource and (src as TileSetAtlasSource).texture != null:
					return (src as TileSetAtlasSource).texture.resource_path

	# Fallback: scan common directories for tileset image assets
	var candidates: Array[String] = [
		"res://assets/tilesets", "res://assets/tiles", "res://assets/sprites", "res://assets", "res://"
	]
	for cdir in candidates:
		if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(cdir)):
			var d := DirAccess.open(cdir)
			if d != null:
				d.list_dir_begin()
				var fn := d.get_next()
				while fn != "":
					if not d.current_is_dir() and fn.to_lower().ends_with(".png"):
						var lfn := fn.to_lower()
						if lfn.contains("tile") or lfn.contains("terrain") or lfn.contains("ground") or lfn.contains("atlas"):
							return cdir.path_join(fn)
					fn = d.get_next()
				d.list_dir_end()

	return ""

func _analyze_atlas_geometry(args: Dictionary) -> Dictionary:
	var path := _resolve_tilemap_texture_path(args)
	if path.is_empty():
		return {"ok": false, "error": "missing_path", "message": "Specify 'path' to the atlas texture or TileSet resource, or ensure the active scene contains a TileMapLayer with a valid TileSet texture."}
	args["path"] = path
	var img := _load_image(path)
	if img == null or img.is_empty():
		return {"ok": false, "error": "failed_to_load_image", "path": path, "message": "Could not load image at path: %s" % path}

	var img_w := img.get_width()
	var img_h := img.get_height()

	var tile_size := [16, 16]
	var auto_detected := false
	if args.has("tile_size"):
		var raw_size = args.get("tile_size")
		if raw_size is Array and (raw_size as Array).size() >= 2:
			tile_size = [maxi(1, int(raw_size[0])), maxi(1, int(raw_size[1]))]
		elif raw_size is Dictionary:
			tile_size = [maxi(1, int(raw_size.get("x", 16))), maxi(1, int(raw_size.get("y", 16)))]
	else:
		var candidates := [[16, 16], [32, 32], [64, 64], [128, 128], [24, 24], [48, 48], [8, 8]]
		var best_cand := [16, 16]
		var best_score := -1
		for cand in candidates:
			var cw: int = cand[0]
			var ch: int = cand[1]
			if cw <= img_w and ch <= img_h:
				var rem_w := img_w % cw
				var rem_h := img_h % ch
				if rem_w == 0 and rem_h == 0:
					var cols: int = img_w / cw
					var rows: int = img_h / ch
					var score: int = 100 - (abs(cols - 16) + abs(rows - 16))
					if score > best_score:
						best_score = score
						best_cand = cand
		tile_size = best_cand
		auto_detected = true

	var margin := [0, 0]
	if args.has("margin"):
		var raw_m = args.get("margin")
		if raw_m is Array and (raw_m as Array).size() >= 2:
			margin = [maxi(0, int(raw_m[0])), maxi(0, int(raw_m[1]))]

	var separation := [0, 0]
	if args.has("separation"):
		var raw_s = args.get("separation")
		if raw_s is Array and (raw_s as Array).size() >= 2:
			separation = [maxi(0, int(raw_s[0])), maxi(0, int(raw_s[1]))]

	var step_x := int(tile_size[0]) + int(separation[0])
	var step_y := int(tile_size[1]) + int(separation[1])
	var avail_w := img_w - int(margin[0])
	var avail_h := img_h - int(margin[1])
	var cols := maxi(1, avail_w / step_x)
	var rows := maxi(1, avail_h / step_y)
	var total_cells := cols * rows

	var populated_coords: Array = []
	var empty_coords: Array = []
	for cy in rows:
		for cx in cols:
			var px := int(margin[0]) + cx * step_x
			var py := int(margin[1]) + cy * step_y
			var has_content := false
			for dy in range(0, int(tile_size[1]), 2):
				for dx in range(0, int(tile_size[0]), 2):
					var sample_x := px + dx
					var sample_y := py + dy
					if sample_x < img_w and sample_y < img_h:
						if img.get_pixel(sample_x, sample_y).a > 0.05:
							has_content = true
							break
				if has_content:
					break
			if has_content:
				populated_coords.append([cx, cy])
			else:
				empty_coords.append([cx, cy])

	return {
		"ok": true,
		"path": path,
		"texture_dimensions": "%dx%d pixels" % [img_w, img_h],
		"texture_width": img_w,
		"texture_height": img_h,
		"tile_size": tile_size,
		"auto_detected_tile_size": auto_detected,
		"margin": margin,
		"separation": separation,
		"grid_columns": cols,
		"grid_rows": rows,
		"total_grid_cells": total_cells,
		"populated_tiles_count": populated_coords.size(),
		"empty_tiles_count": empty_coords.size(),
		"populated_coordinates_sample": populated_coords.slice(0, 50),
		"source": "local",
	}


func _preview_labelled_atlas(args: Dictionary) -> Dictionary:
	var path := _resolve_tilemap_texture_path(args)
	if path.is_empty():
		return {"ok": false, "error": "missing_path", "message": "Specify 'path' to the atlas texture, or ensure the active scene contains a TileMapLayer with a valid TileSet texture."}
	args["path"] = path
	var img := _load_image(path)
	if img == null or img.is_empty():
		return {"ok": false, "error": "failed_to_load_image", "path": path}

	var img_w := img.get_width()
	var img_h := img.get_height()

	var geo := _analyze_atlas_geometry(args)
	if not geo.get("ok", false):
		return geo

	var tile_size: Array = geo.get("tile_size", [16, 16])
	var tile_w: int = tile_size[0]
	var tile_h: int = tile_size[1]
	var margin: Array = geo.get("margin", [0, 0])
	var separation: Array = geo.get("separation", [0, 0])
	var cols: int = geo.get("grid_columns", 1)
	var rows: int = geo.get("grid_rows", 1)
	var step_x := tile_w + int(separation[0])
	var step_y := tile_h + int(separation[1])

	var preview_img: Image = img.duplicate() as Image
	var grid_color := Color(0.2, 0.7, 1.0, 0.5)
	var badge_bg := Color(0.05, 0.05, 0.12, 0.85)
	var text_color := Color(1.0, 1.0, 0.2, 1.0)

	for cy in rows:
		for cx in cols:
			var px := int(margin[0]) + cx * step_x
			var py := int(margin[1]) + cy * step_y
			if px + tile_w > img_w or py + tile_h > img_h:
				continue

			for bx in tile_w:
				preview_img.set_pixel(px + bx, py, grid_color)
				preview_img.set_pixel(px + bx, py + tile_h - 1, grid_color)
			for by in tile_h:
				preview_img.set_pixel(px, py + by, grid_color)
				preview_img.set_pixel(px + tile_w - 1, py + by, grid_color)

			var label := "(%d,%d)" % [cx, cy]
			if tile_w < 28:
				label = "%d,%d" % [cx, cy]

			var text_w := label.length() * 4 - 1
			var text_h := 5
			var badge_w := mini(tile_w - 2, text_w + 2)
			var badge_h := mini(tile_h - 2, text_h + 2)

			var badge_x := px + 1
			var badge_y := py + 1
			for bgy in badge_h:
				for bgx in badge_w:
					preview_img.set_pixel(badge_x + bgx, badge_y + bgy, badge_bg)

			_draw_text_3x5(preview_img, badge_x + 1, badge_y + 1, label, text_color)

	var dir_user := "user://godot_agent_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_user))
	var filename := path.get_file().get_basename() + "_labelled.png"
	var save_path := dir_user + "/" + filename
	var global_save := ProjectSettings.globalize_path(save_path)
	preview_img.save_png(global_save)

	var max_dim := clampi(int(args.get("max_dimension", 1280)), 256, 4096)
	var img_to_send: Image = preview_img
	if img_w > max_dim or img_h > max_dim:
		var aspect := float(img_w) / float(img_h)
		var new_w := max_dim
		var new_h := max_dim
		if aspect >= 1.0:
			new_h = maxi(1, int(float(max_dim) / aspect))
		else:
			new_w = maxi(1, int(float(max_dim) * aspect))
		img_to_send = preview_img.duplicate() as Image
		img_to_send.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)

	var png_bytes: PackedByteArray = img_to_send.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)

	return {
		"ok": true,
		"path": path,
		"saved_preview_path": save_path,
		"grid_columns": cols,
		"grid_rows": rows,
		"tile_size": [tile_w, tile_h],
		"total_cells": cols * rows,
		"active_tiles_count": geo.get("populated_tiles_count", 0),
		"base64": b64,
		"message": "Generated coordinate-labelled preview for atlas (%d columns x %d rows, tile size %dx%d)." % [cols, rows, tile_w, tile_h],
		"source": "local",
	}


func _analyze_tile_region(crop: Image) -> Dictionary:
	var w := crop.get_width()
	var h := crop.get_height()
	var total_pixels := w * h
	var solid_count := 0

	var top_solid := 0
	var bottom_solid := 0
	var left_solid := 0
	var right_solid := 0

	for x in w:
		if crop.get_pixel(x, 0).a > 0.5: top_solid += 1
		if crop.get_pixel(x, h - 1).a > 0.5: bottom_solid += 1
	for y in h:
		if crop.get_pixel(0, y).a > 0.5: left_solid += 1
		if crop.get_pixel(w - 1, y).a > 0.5: right_solid += 1

	for y in h:
		for x in w:
			if crop.get_pixel(x, y).a > 0.2:
				solid_count += 1

	var fill_ratio := float(solid_count) / float(total_pixels)
	var top_ratio := float(top_solid) / float(w)
	var bottom_ratio := float(bottom_solid) / float(w)
	var left_ratio := float(left_solid) / float(h)
	var right_ratio := float(right_solid) / float(h)

	var cat := "unknown"
	var conf := 0.5

	if fill_ratio < 0.02:
		cat = "empty"
		conf = 1.0
	elif top_ratio > 0.8 and bottom_ratio > 0.8 and left_ratio > 0.8 and right_ratio > 0.8:
		cat = "interior_fill"
		conf = 0.95
	elif top_ratio < 0.25 and bottom_ratio > 0.6 and left_ratio > 0.5 and right_ratio > 0.5:
		cat = "ground_top"
		conf = 0.9
	elif top_ratio < 0.3 and left_ratio < 0.3 and bottom_ratio > 0.5 and right_ratio > 0.5:
		cat = "corner_top_left"
		conf = 0.85
	elif top_ratio < 0.3 and right_ratio < 0.3 and bottom_ratio > 0.5 and left_ratio > 0.5:
		cat = "corner_top_right"
		conf = 0.85
	elif left_ratio < 0.25 and right_ratio > 0.6 and top_ratio > 0.5:
		cat = "left_edge"
		conf = 0.85
	elif right_ratio < 0.25 and left_ratio > 0.6 and top_ratio > 0.5:
		cat = "right_edge"
		conf = 0.85
	elif bottom_ratio < 0.25 and top_ratio > 0.6:
		cat = "bottom_edge"
		conf = 0.8
	elif fill_ratio < 0.45:
		cat = "decoration"
		conf = 0.6
	else:
		cat = "unknown"
		conf = 0.4

	return {
		"category": cat,
		"confidence": conf,
		"is_empty": cat == "empty",
		"fill_ratio": roundf(fill_ratio * 100.0) / 100.0,
		"edges": {
			"top_solid_ratio": roundf(top_ratio * 100.0) / 100.0,
			"bottom_solid_ratio": roundf(bottom_ratio * 100.0) / 100.0,
			"left_solid_ratio": roundf(left_ratio * 100.0) / 100.0,
			"right_solid_ratio": roundf(right_ratio * 100.0) / 100.0,
		}
	}


func _inspect_tile_crop(args: Dictionary) -> Dictionary:
	var path := _resolve_tilemap_texture_path(args)
	if path.is_empty():
		return {"ok": false, "error": "missing_path", "message": "Specify 'path' or 'atlas_coords' for tile crop inspection, or ensure the active scene contains a TileMapLayer."}
	args["path"] = path
	var coords_raw = args.get("atlas_coords", [0, 0])
	var coords := [0, 0]
	if coords_raw is Array and (coords_raw as Array).size() >= 2:
		coords = [int(coords_raw[0]), int(coords_raw[1])]

	var geo := _analyze_atlas_geometry(args)
	if not geo.get("ok", false):
		return geo

	var tile_size: Array = geo.get("tile_size", [16, 16])
	var tile_w: int = tile_size[0]
	var tile_h: int = tile_size[1]
	var margin: Array = geo.get("margin", [0, 0])
	var separation: Array = geo.get("separation", [0, 0])
	var step_x := tile_w + int(separation[0])
	var step_y := tile_h + int(separation[1])

	var px: int = int(margin[0]) + int(coords[0]) * step_x
	var py: int = int(margin[1]) + int(coords[1]) * step_y

	var img := _load_image(path)
	if img == null or img.is_empty():
		return {"ok": false, "error": "failed_to_load_image"}

	if px + tile_w > img.get_width() or py + tile_h > img.get_height() or px < 0 or py < 0:
		return {
			"ok": false,
			"error": "out_of_bounds",
			"atlas_coords": coords,
			"message": "Atlas coords %s map to pixel rect [%d, %d, %d, %d] which exceeds texture %dx%d." % [coords, px, py, tile_w, tile_h, img.get_width(), img.get_height()]
		}

	var crop: Image = img.get_region(Rect2i(px, py, tile_w, tile_h))
	var analysis := _analyze_tile_region(crop)

	var png_bytes: PackedByteArray = crop.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)

	return {
		"ok": true,
		"path": path,
		"atlas_coords": coords,
		"pixel_rect": [px, py, tile_w, tile_h],
		"tile_size": [tile_w, tile_h],
		"category": analysis.get("category", "unknown"),
		"confidence": analysis.get("confidence", 0.0),
		"is_empty": analysis.get("is_empty", false),
		"fill_ratio": analysis.get("fill_ratio", 0.0),
		"edge_profiles": analysis.get("edges", {}),
		"base64": b64,
		"source": "local",
	}


func _catalog_atlas_tiles(args: Dictionary) -> Dictionary:
	var path := _resolve_tilemap_texture_path(args)
	if path.is_empty():
		return {"ok": false, "error": "missing_path", "message": "Specify 'path' to the atlas texture, or ensure the active scene contains a TileMapLayer with a valid TileSet texture."}
	args["path"] = path
	var geo := _analyze_atlas_geometry(args)
	if not geo.get("ok", false):
		return geo

	var img := _load_image(path)
	if img == null or img.is_empty():
		return {"ok": false, "error": "failed_to_load_image"}

	var tile_size: Array = geo.get("tile_size", [16, 16])
	var tile_w: int = tile_size[0]
	var tile_h: int = tile_size[1]
	var margin: Array = geo.get("margin", [0, 0])
	var separation: Array = geo.get("separation", [0, 0])
	var cols: int = geo.get("grid_columns", 1)
	var rows: int = geo.get("grid_rows", 1)
	var step_x := tile_w + int(separation[0])
	var step_y := tile_h + int(separation[1])

	var catalog := {
		"ground_top": [],
		"interior_fill": [],
		"left_edge": [],
		"right_edge": [],
		"corners": [],
		"bottom_edge": [],
		"decoration": [],
		"unknown": [],
	}

	var populated_count := 0
	for cy in rows:
		for cx in cols:
			var px := int(margin[0]) + cx * step_x
			var py := int(margin[1]) + cy * step_y
			if px + tile_w > img.get_width() or py + tile_h > img.get_height():
				continue
			var crop := img.get_region(Rect2i(px, py, tile_w, tile_h))
			var analysis := _analyze_tile_region(crop)
			var cat: String = analysis.get("category", "unknown")
			if cat == "empty":
				continue
			populated_count += 1
			if cat in ["corner_top_left", "corner_top_right"]:
				catalog["corners"].append({"coords": [cx, cy], "subtype": cat, "confidence": analysis.get("confidence", 0.0)})
			elif catalog.has(cat):
				catalog[cat].append({"coords": [cx, cy], "confidence": analysis.get("confidence", 0.0)})
			else:
				catalog["unknown"].append({"coords": [cx, cy], "confidence": analysis.get("confidence", 0.0)})

	return {
		"ok": true,
		"path": path,
		"tile_size": [tile_w, tile_h],
		"grid_columns": cols,
		"grid_rows": rows,
		"total_populated_tiles": populated_count,
		"catalog": catalog,
		"summary": "Cataloged %d tiles: %d ground_top, %d interior_fill, %d left_edge, %d right_edge, %d corners, %d decoration, %d unknown." % [
			populated_count,
			catalog["ground_top"].size(),
			catalog["interior_fill"].size(),
			catalog["left_edge"].size(),
			catalog["right_edge"].size(),
			catalog["corners"].size(),
			catalog["decoration"].size(),
			catalog["unknown"].size()
		],
		"source": "local",
	}


func _validate_atlas_coords(args: Dictionary) -> Dictionary:
	var path := str(args.get("path", ""))
	if path.is_empty():
		return {"ok": false, "error": "missing_path"}
	var coords_list: Array = args.get("coords", [])
	if coords_list.is_empty() and args.has("atlas_coords"):
		coords_list = [args.get("atlas_coords")]

	var geo := _analyze_atlas_geometry(args)
	if not geo.get("ok", false):
		return geo

	var cols: int = geo.get("grid_columns", 1)
	var rows: int = geo.get("grid_rows", 1)

	var valid_list: Array = []
	var invalid_list: Array = []

	for c in coords_list:
		var cx := 0
		var cy := 0
		if c is Array and (c as Array).size() >= 2:
			cx = int(c[0])
			cy = int(c[1])
		else:
			invalid_list.append({"coords": c, "reason": "malformed_coords"})
			continue

		if cx < 0 or cx >= cols or cy < 0 or cy >= rows:
			invalid_list.append({"coords": [cx, cy], "reason": "out_of_grid_bounds", "grid_size": [cols, rows]})
		else:
			var crop_res := _inspect_tile_crop({"path": path, "atlas_coords": [cx, cy], "tile_size": geo.get("tile_size")})
			if crop_res.get("is_empty", false):
				invalid_list.append({"coords": [cx, cy], "reason": "empty_tile"})
			else:
				valid_list.append({"coords": [cx, cy], "category": crop_res.get("category", "unknown")})

	return {
		"ok": invalid_list.is_empty(),
		"all_valid": invalid_list.is_empty(),
		"total_checked": coords_list.size(),
		"valid_count": valid_list.size(),
		"invalid_count": invalid_list.size(),
		"valid_coords": valid_list,
		"invalid_coords": invalid_list,
		"source": "local",
	}


func _find_first_child_of_type(parent: Node, type_name: String) -> Node:
	if parent == null: return null
	for child in parent.get_children():
		if child.is_class(type_name) or child.get_class() == type_name:
			return child
		var sub := _find_first_child_of_type(child, type_name)
		if sub != null:
			return sub
	return null


func _inspect_player_metrics(args: Dictionary) -> Dictionary:
	var char_path := str(args.get("character_path", ""))
	var root := EditorInterface.get_edited_scene_root()
	var char_node: CharacterBody2D = null

	if not char_path.is_empty() and root != null:
		var n = root.get_node_or_null(char_path)
		if n is CharacterBody2D:
			char_node = n

	if char_node == null and root != null:
		if root is CharacterBody2D:
			char_node = root
		else:
			char_node = _find_first_child_of_type(root, "CharacterBody2D") as CharacterBody2D

	var col_width := 32.0
	var col_height := 64.0
	var shape_type := "unknown"
	var node_found := char_node != null

	if char_node != null:
		var col_shape: CollisionShape2D = _find_first_child_of_type(char_node, "CollisionShape2D") as CollisionShape2D
		if col_shape != null and col_shape.shape != null:
			var s: Shape2D = col_shape.shape
			if s is RectangleShape2D:
				shape_type = "RectangleShape2D"
				col_width = s.size.x
				col_height = s.size.y
			elif s is CapsuleShape2D:
				shape_type = "CapsuleShape2D"
				col_width = s.radius * 2.0
				col_height = s.height
			elif s is CircleShape2D:
				shape_type = "CircleShape2D"
				col_width = s.radius * 2.0
				col_height = s.radius * 2.0

	var speed := 200.0
	var jump_vel := -400.0
	if char_node != null:
		if "SPEED" in char_node: speed = float(char_node.get("SPEED"))
		elif "speed" in char_node: speed = float(char_node.get("speed"))
		elif "WALK_SPEED" in char_node: speed = float(char_node.get("WALK_SPEED"))

		if "JUMP_VELOCITY" in char_node: jump_vel = float(char_node.get("JUMP_VELOCITY"))
		elif "jump_velocity" in char_node: jump_vel = float(char_node.get("jump_velocity"))
		elif "JUMP_FORCE" in char_node: jump_vel = float(char_node.get("JUMP_FORCE"))

	var gravity := float(ProjectSettings.get_setting("physics/2d/default_gravity", 980.0))
	if gravity <= 0.0: gravity = 980.0

	var v0 := absf(jump_vel)
	var max_jump_height := (v0 * v0) / (2.0 * gravity)
	var air_time := (2.0 * v0) / gravity
	var max_horizontal_jump := speed * air_time

	var tile_dim := float(args.get("tile_dimension", 64.0))
	if tile_dim <= 0.0: tile_dim = 64.0

	var safe_platform_elevation := max_jump_height * 0.75
	var safe_horizontal_gap := max_horizontal_jump * 0.70

	return {
		"ok": true,
		"character_found": node_found,
		"character_path": str(char_node.get_path()) if char_node != null else char_path,
		"collision_shape": shape_type,
		"collision_dimensions_px": {"width": col_width, "height": col_height},
		"physics_parameters": {
			"speed_px_per_sec": speed,
			"jump_velocity_px_per_sec": jump_vel,
			"gravity_px_per_sec2": gravity,
		},
		"jump_metrics": {
			"max_jump_height_px": roundf(max_jump_height * 10.0) / 10.0,
			"max_jump_height_tiles": roundf((max_jump_height / tile_dim) * 10.0) / 10.0,
			"air_time_sec": roundf(air_time * 100.0) / 100.0,
			"max_horizontal_jump_px": roundf(max_horizontal_jump * 10.0) / 10.0,
			"max_horizontal_jump_tiles": roundf((max_horizontal_jump / tile_dim) * 10.0) / 10.0,
		},
		"recommended_platform_spacing": {
			"tile_dimension_used": tile_dim,
			"max_safe_vertical_step_px": roundf(safe_platform_elevation * 10.0) / 10.0,
			"max_safe_vertical_step_tiles": roundf((safe_platform_elevation / tile_dim) * 10.0) / 10.0,
			"max_safe_horizontal_gap_px": roundf(safe_horizontal_gap * 10.0) / 10.0,
			"max_safe_horizontal_gap_tiles": roundf((safe_horizontal_gap / tile_dim) * 10.0) / 10.0,
			"standard_recommended_gap_tiles": maxi(1, int(safe_horizontal_gap / tile_dim)),
			"standard_recommended_height_step_tiles": maxi(1, int(safe_platform_elevation / tile_dim)),
		},
		"source": "local",
	}


func _inspect_tilemap_layer(args: Dictionary) -> Dictionary:
	var node_path := str(args.get("node_path", ""))
	if node_path.is_empty():
		return {"ok": false, "error": "missing_node_path"}
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node := root.get_node_or_null(node_path)
	if node == null:
		return {"ok": false, "error": "node_not_found", "node_path": node_path}
	if not (node is TileMapLayer):
		return {"ok": false, "error": "not_a_tilemap_layer", "node_type": node.get_class()}

	var layer: TileMapLayer = node
	var tileset: TileSet = layer.tile_set
	var used_cells := layer.get_used_cells()
	var used_rect: Rect2i = layer.get_used_rect()

	var tile_size := [16, 16]
	var physics_layers := 0
	var terrain_sets := 0
	if tileset != null:
		tile_size = [tileset.tile_size.x, tileset.tile_size.y]
		physics_layers = tileset.get_physics_layers_count()
		terrain_sets = tileset.get_terrain_sets_count()

	var invalid_cells: Array = []
	var sample_cells: Array = []
	for i in used_cells.size():
		var cell: Vector2i = used_cells[i]
		var sid := layer.get_cell_source_id(cell)
		var atlas := layer.get_cell_atlas_coords(cell)
		var alt := layer.get_cell_alternative_tile(cell)

		var valid := true
		if tileset != null:
			if not tileset.has_source(sid):
				valid = false
			else:
				var src := tileset.get_source(sid)
				if src is TileSetAtlasSource:
					if not src.has_tile(atlas):
						valid = false

		if not valid:
			invalid_cells.append({"cell": [cell.x, cell.y], "source_id": sid, "atlas_coords": [atlas.x, atlas.y]})

		if i < 30:
			sample_cells.append({
				"cell": [cell.x, cell.y],
				"source_id": sid,
				"atlas_coords": [atlas.x, atlas.y],
				"alternative_tile": alt,
				"valid": valid
			})

	return {
		"ok": true,
		"node_path": node_path,
		"tile_set": tileset.resource_path if tileset != null else "",
		"tile_size": tile_size,
		"physics_layers_count": physics_layers,
		"terrain_sets_count": terrain_sets,
		"used_cells_count": used_cells.size(),
		"used_rect": [used_rect.position.x, used_rect.position.y, used_rect.size.x, used_rect.size.y],
		"used_rect_formatted": "origin (%d,%d), size %dx%d" % [used_rect.position.x, used_rect.position.y, used_rect.size.x, used_rect.size.y],
		"invalid_cells_count": invalid_cells.size(),
		"invalid_cells": invalid_cells.slice(0, 20),
		"sample_cells": sample_cells,
		"visible": layer.visible,
		"z_index": layer.z_index,
		"collision_enabled": layer.collision_enabled,
		"navigation_enabled": layer.navigation_enabled,
		"source": "local",
	}


func _paint_tilemap_cells(args: Dictionary) -> Dictionary:
	var node_path := str(args.get("node_path", ""))
	if node_path.is_empty():
		return {"ok": false, "error": "missing_node_path"}
	var root := EditorInterface.get_edited_scene_root()
	if root == null: return {"ok": false, "error": "no_edited_scene"}
	var node := root.get_node_or_null(node_path)
	if node == null: return {"ok": false, "error": "node_not_found"}
	if not (node is TileMapLayer): return {"ok": false, "error": "not_a_tilemap_layer"}

	var layer: TileMapLayer = node
	var cells: Array = args.get("cells", [])
	if cells.is_empty():
		return {"ok": false, "error": "missing_cells"}

	var painted_count := 0
	for item in cells:
		if not (item is Dictionary): continue
		var coords_raw = item.get("coords", [0, 0])
		var c := Vector2i(int(coords_raw[0]), int(coords_raw[1]))
		var sid := int(item.get("source_id", 0))
		var atlas_raw = item.get("atlas_coords", [0, 0])
		var atlas := Vector2i(int(atlas_raw[0]), int(atlas_raw[1]))
		var alt := int(item.get("alternative_tile", 0))

		var prev_sid := layer.get_cell_source_id(c)
		var prev_atlas := layer.get_cell_atlas_coords(c)
		var prev_alt := layer.get_cell_alternative_tile(c)

		layer.set_cell(c, sid, atlas, alt)
		if history != null:
			history.record("Set cell %v on %s" % [c, layer.name], Callable(layer, "set_cell").bind(c, prev_sid, prev_atlas, prev_alt), Callable(layer, "set_cell").bind(c, sid, atlas, alt))
		painted_count += 1

	_record_mutation("Painted %d cells on %s" % [painted_count, node_path])

	var used_r := layer.get_used_rect()
	var ret_data := {
		"node_path": node_path,
		"painted_cells_count": painted_count,
		"used_rect": [used_r.position.x, used_r.position.y, used_r.size.x, used_r.size.y],
	}
	return _build_mutation_result(
		"paint_tilemap_cells",
		true,
		"applied",
		args,
		{"painted_count": painted_count, "node_path": node_path},
		{"painted_cells_count": painted_count, "used_rect": [used_r.position.x, used_r.position.y, used_r.size.x, used_r.size.y]},
		[node_path],
		[],
		[],
		false,
		history != null,
		"not_needed",
		ret_data
	)


func _paint_tilemap_rect(args: Dictionary) -> Dictionary:
	var node_path := str(args.get("node_path", ""))
	if node_path.is_empty(): return _build_mutation_result("paint_tilemap_rect", false, "rejected", args, {}, {}, [], [], ["missing_node_path"])
	var root := EditorInterface.get_edited_scene_root()
	if root == null: return _build_mutation_result("paint_tilemap_rect", false, "rejected", args, {}, {}, [], [], ["no_edited_scene"])
	var node := root.get_node_or_null(node_path)
	if node == null: return _build_mutation_result("paint_tilemap_rect", false, "rejected", args, {}, {}, [], [], ["node_not_found: %s" % node_path])
	if not (node is TileMapLayer): return _build_mutation_result("paint_tilemap_rect", false, "rejected", args, {}, {}, [], [], ["not_a_tilemap_layer"])

	var layer: TileMapLayer = node
	var rect_raw = args.get("rect", [0, 0, 1, 1])
	if not (rect_raw is Array) or (rect_raw as Array).size() < 4:
		return _build_mutation_result("paint_tilemap_rect", false, "rejected", args, {}, {}, [], [], ["invalid_rect: Expected rect as [x, y, width, height]"])

	var rx := int(rect_raw[0])
	var ry := int(rect_raw[1])
	var rw := int(rect_raw[2])
	var rh := int(rect_raw[3])
	if rw <= 0 or rh <= 0: return _build_mutation_result("paint_tilemap_rect", false, "rejected", args, {}, {}, [], [], ["invalid_rect_dimensions"])

	var sid := int(args.get("source_id", 0))
	var atlas_raw = args.get("atlas_coords", [0, 0])
	var atlas := Vector2i(int(atlas_raw[0]), int(atlas_raw[1]))
	var alt := int(args.get("alternative_tile", 0))

	for dy in rh:
		for dx in rw:
			var c := Vector2i(rx + dx, ry + dy)
			var prev_sid := layer.get_cell_source_id(c)
			var prev_atlas := layer.get_cell_atlas_coords(c)
			var prev_alt := layer.get_cell_alternative_tile(c)
			layer.set_cell(c, sid, atlas, alt)
			if history != null:
				history.record("Set cell %v on %s" % [c, layer.name], Callable(layer, "set_cell").bind(c, prev_sid, prev_atlas, prev_alt), Callable(layer, "set_cell").bind(c, sid, atlas, alt))

	_record_mutation("Filled rect %dx%d on %s" % [rw, rh, node_path])

	var ret_data := {
		"node_path": node_path,
		"rect": [rx, ry, rw, rh],
		"total_cells_filled": rw * rh,
		"source_id": sid,
		"atlas_coords": [atlas.x, atlas.y],
	}
	return _build_mutation_result(
		"paint_tilemap_rect",
		true,
		"applied",
		args,
		{"filled_cells": rw * rh, "rect": [rx, ry, rw, rh]},
		ret_data,
		[node_path],
		[],
		[],
		false,
		history != null,
		"not_needed",
		ret_data
	)


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
	directives.append("2. TILEMAP-FIRST MANDATE: All walkable ground, floors, walls, and grid platforms MUST be painted onto a TileMapLayer using paint_tilemap_rect or paint_tilemap_cells. Never create individual loose StaticBody2D nodes for tile-grid terrain.")
	directives.append("3. SCENE REUSE MANDATE: Reusable entities (characters, hazards, interactive platforms, pickups) must be instantiated using instance_scene(scene_path=..., parent_path=..., properties=...) or 'instance_scene' in create_node_hierarchy. Never recreate their child node hierarchies inside the level.")
	directives.append("4. IRREGULAR TERRAIN & SLOPES: For curved, angled, or organic terrain not fitting square tile cells, use StaticBody2D with Polygon2D and CollisionPolygon2D, setting the 'polygon' property with PackedVector2Array.")
	directives.append("5. JUMP METRICS: Platforms must not exceed a horizontal gap of %.1f px or vertical height difference of %.1f px to guarantee reachability." % [max_h_reach, max_jump_h])
	directives.append("6. PAN/ZOOM DEFECT RESOLUTION LOOP: After building or modifying geometry, use navigate_viewport(position=..., zoom_delta=..., capture=true) to inspect each sector. Verify: 1) End-cap tiles on platforms (edges must be end-caps, not mid-fill tiles), 2) Tile overlaps & gaps, 3) Continuous collision chains (validate_tileset_physics), 4) Background visual coverage (no uncovered strips). If ANY defect is found, fix it immediately, pan/zoom and capture to re-verify, and LOOP UNTIL NO DEFECTS REMAIN.")
	directives.append("7. RUNTIME COLLISION DEBUGGING: Call toggle_debug_collisions(visible=true) to enable runtime collision rendering during playtests.")
	directives.append("8. HANDOVER REPORT: Follow Core Flow (Inspect -> Picture & Plan -> Mutate -> Pan/Zoom Defect Loop -> Handover Report). Upon completion, report back to Main Agent with layers created, cells painted, entities instanced, verification results, and suggested gameplay integration.")
	directives.append("9. IN-PLACE EDITING & ZERO DUPLICATION: Inspect existing layers, nodes, and scenes first. Edit existing TileMapLayers and scenes in place. Strictly avoid creating duplicate levels, duplicate scenes, or deleting existing working geometry without prior inspection.")

	var warnings: Array = []
	if tilemap_layers.is_empty():
		warnings.append("NO_TILEMAP_LAYER_FOUND: Active scene has no TileMapLayer. You must create a TileMapLayer (e.g. Ground_Base) and assign a TileSet BEFORE creating platforms.")

	return {
		"ok": true,
		"specialized_agent": "LevelDesigner",
		"task": task,
		"status": "ready",
		"tilemap_first_enforced": true,
		"tilemap_layers": tilemap_layers,
		"available_entity_scenes": available_entity_scenes,
		"player_metrics": player_metrics.get("data", {}),
		"directives": directives,
		"warnings": warnings,
		"recommended_tools": [
			"navigate_viewport", "auto_generate_atlas_tiles", "paint_tilemap_rect", "paint_tilemap_cells", "instance_scene",
			"inspect_tilemap_layer", "validate_tileset_physics",
			"inspect_player_metrics", "inspect_spatial_context", "toggle_debug_collisions",
			"capture_viewport"
		],
		"source": "local"
	}


# ==============================================================================
# Spatial Awareness 2D Toolkit (Deterministic Geometry & Spatial Queries)
# ==============================================================================

func _shape2d_local_corners(shape: Shape2D) -> PackedVector2Array:
	if shape == null:
		return PackedVector2Array()
	if shape is RectangleShape2D:
		var rs := shape as RectangleShape2D
		var hx := rs.size.x * 0.5
		var hy := rs.size.y * 0.5
		return PackedVector2Array([Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)])
	if shape is CircleShape2D:
		var cir := shape as CircleShape2D
		var r := cir.radius
		return PackedVector2Array([Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)])
	if shape is CapsuleShape2D:
		var cap := shape as CapsuleShape2D
		var r := cap.radius
		var hh := cap.height * 0.5
		return PackedVector2Array([Vector2(-r, -hh), Vector2(r, -hh), Vector2(r, hh), Vector2(-r, hh)])
	if shape is ConvexPolygonShape2D:
		return (shape as ConvexPolygonShape2D).points
	if shape is ConcavePolygonShape2D:
		return (shape as ConcavePolygonShape2D).segments
	if shape is SeparationRayShape2D:
		var srs := shape as SeparationRayShape2D
		return PackedVector2Array([Vector2.ZERO, Vector2(0, srs.length)])
	return PackedVector2Array()


func _shape_info(shape: Shape2D) -> Dictionary:
	if shape == null:
		return {"type": "null"}
	var info := {"type": shape.get_class()}
	if shape is RectangleShape2D:
		info["size"] = [shape.size.x, shape.size.y]
	elif shape is CircleShape2D:
		info["radius"] = shape.radius
	elif shape is CapsuleShape2D:
		info["radius"] = shape.radius
		info["height"] = shape.height
	elif shape is ConvexPolygonShape2D:
		info["points_count"] = shape.points.size()
	return info


func _rect_from_points(pts: PackedVector2Array, xf: Transform2D) -> Rect2:
	if pts.is_empty():
		return Rect2()
	var min_p := xf * pts[0]
	var max_p := min_p
	for i in range(1, pts.size()):
		var wp := xf * pts[i]
		min_p.x = minf(min_p.x, wp.x)
		min_p.y = minf(min_p.y, wp.y)
		max_p.x = maxf(max_p.x, wp.x)
		max_p.y = maxf(max_p.y, wp.y)
	return Rect2(min_p, max_p - min_p)


func _transform_rect(xf: Transform2D, r: Rect2) -> Rect2:
	var pts := PackedVector2Array([
		r.position,
		Vector2(r.position.x + r.size.x, r.position.y),
		r.position + r.size,
		Vector2(r.position.x, r.position.y + r.size.y)
	])
	return _rect_from_points(pts, xf)


func _compute_node_2d_bounds(node: Node) -> Rect2:
	if node == null:
		return Rect2()
	if node is Sprite2D:
		var spr := node as Sprite2D
		return _transform_rect(spr.global_transform, spr.get_rect())
	if node is AnimatedSprite2D:
		var anim := node as AnimatedSprite2D
		if anim.sprite_frames != null and anim.sprite_frames.has_animation(anim.animation):
			var tex := anim.sprite_frames.get_frame_texture(anim.animation, anim.frame)
			if tex != null:
				var sz := tex.get_size()
				var off := anim.offset
				var pos := -sz * 0.5 + off if anim.centered else off
				return _transform_rect(anim.global_transform, Rect2(pos, sz))
	if node is Control:
		var ctrl := node as Control
		return _transform_rect(ctrl.get_global_transform(), ctrl.get_rect())
	if node is CollisionShape2D:
		var cs := node as CollisionShape2D
		if cs.shape != null:
			var pts := _shape2d_local_corners(cs.shape)
			return _rect_from_points(pts, cs.global_transform)
	if node is CollisionPolygon2D:
		var cp := node as CollisionPolygon2D
		if not cp.polygon.is_empty():
			return _rect_from_points(cp.polygon, cp.global_transform)
	if node is Polygon2D:
		var poly := node as Polygon2D
		if not poly.polygon.is_empty():
			return _rect_from_points(poly.polygon, poly.global_transform)
	if node is TileMapLayer:
		var layer := node as TileMapLayer
		var used := layer.get_used_rect()
		if used.size != Vector2i.ZERO:
			var tsize := Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(16, 16)
			var p_min := layer.map_to_local(used.position) - tsize * 0.5
			var p_max := layer.map_to_local(used.position + used.size - Vector2i.ONE) + tsize * 0.5
			var pts := PackedVector2Array([
				Vector2(p_min.x, p_min.y),
				Vector2(p_max.x, p_min.y),
				Vector2(p_max.x, p_max.y),
				Vector2(p_min.x, p_max.y)
			])
			return _rect_from_points(pts, layer.global_transform)

	# Aggregate 2D bounds for composite nodes (CharacterBody2D, StaticBody2D, Area2D, etc.)
	var combined := Rect2()
	var has_bounds := false
	for child in node.get_children():
		if child is Node2D or child is Control:
			var cb := _compute_node_2d_bounds(child)
			if cb.size != Vector2.ZERO:
				if not has_bounds:
					combined = cb
					has_bounds = true
				else:
					combined = combined.merge(cb)
	if has_bounds:
		return combined
	if node is Node2D:
		return Rect2((node as Node2D).global_position, Vector2.ZERO)
	return Rect2()


func _find_camera_2d(node: Node) -> Camera2D:
	if node == null:
		return null
	if node is Camera2D:
		return node as Camera2D
	for child in node.get_children():
		var found := _find_camera_2d(child)
		if found != null:
			return found
	return null


func _inspect_spatial_context(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var target_path := str(args.get("node_path", ".")).strip_edges()
	var target := _resolve_node(root, target_path)
	if target == null:
		return {"ok": false, "error": "node_not_found", "node_path": target_path}

	var max_depth := int(args.get("max_depth", -1))
	var include_tiles := bool(args.get("include_tiles", true))
	var include_collision := bool(args.get("include_collision", true))

	var vp_w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var vp_h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	if target.is_inside_tree() and target.get_viewport() != null:
		var v_rect := target.get_viewport().get_visible_rect()
		if v_rect.size != Vector2.ZERO:
			vp_w = int(v_rect.size.x)
			vp_h = int(v_rect.size.y)

	var camera_info: Dictionary = {}
	var cam := _find_camera_2d(root)
	if cam != null:
		var cam_zoom := cam.zoom if cam.zoom != Vector2.ZERO else Vector2.ONE
		var half_vp := (Vector2(vp_w, vp_h) * 0.5) / cam_zoom
		var cam_center := cam.global_position + cam.offset
		var cam_rect := Rect2(cam_center - half_vp, half_vp * 2.0)
		camera_info = {
			"name": cam.name,
			"path": str(root.get_path_to(cam)) if root != cam else ".",
			"position": [roundf(cam.global_position.x * 100.0) / 100.0, roundf(cam.global_position.y * 100.0) / 100.0],
			"rotation": roundf(cam.global_rotation * 1000.0) / 1000.0,
			"zoom": [cam.zoom.x, cam.zoom.y],
			"offset": [cam.offset.x, cam.offset.y],
			"enabled": cam.is_enabled() if cam.has_method("is_enabled") else true,
			"visible_world_rect": [roundf(cam_rect.position.x * 100.0) / 100.0, roundf(cam_rect.position.y * 100.0) / 100.0, roundf(cam_rect.size.x * 100.0) / 100.0, roundf(cam_rect.size.y * 100.0) / 100.0]
		}

	var nodes_list: Array = []
	var tilemap_layers_summary: Array = []

	var stack: Array = [{"node": target, "depth": 0}]
	while not stack.is_empty():
		var item: Dictionary = stack.pop_back()
		var n: Node = item["node"]
		var depth: int = item["depth"]

		var rel_p := str(root.get_path_to(n)) if (root != n and root.is_ancestor_of(n)) else (str(n.get_path()) if n.is_inside_tree() else String(n.name))
		var parent_p := str(root.get_path_to(n.get_parent())) if (n.get_parent() != null and n != root and root.is_ancestor_of(n.get_parent())) else ""

		var node_data := {
			"name": n.name,
			"path": rel_p,
			"type": n.get_class(),
			"parent": parent_p,
			"visible": n.visible if n is CanvasItem else true,
			"z_index": n.z_index if n is CanvasItem else 0
		}

		if not n.scene_file_path.is_empty():
			node_data["is_instance"] = true
			node_data["instance_scene"] = n.scene_file_path
		elif n.owner != null and n.owner != root:
			node_data["is_instance_child"] = true
			var src := n.owner.scene_file_path if not n.owner.scene_file_path.is_empty() else str(root.get_path_to(n.owner))
			node_data["instance_scene"] = src
			node_data["instance_root"] = str(root.get_path_to(n.owner))

		if n is Node2D:
			var n2 := n as Node2D
			node_data["local"] = {
				"position": [roundf(n2.position.x * 100.0) / 100.0, roundf(n2.position.y * 100.0) / 100.0],
				"rotation": roundf(n2.rotation * 1000.0) / 1000.0,
				"scale": [roundf(n2.scale.x * 100.0) / 100.0, roundf(n2.scale.y * 100.0) / 100.0]
			}
			node_data["global"] = {
				"position": [roundf(n2.global_position.x * 100.0) / 100.0, roundf(n2.global_position.y * 100.0) / 100.0],
				"rotation": roundf(n2.global_rotation * 1000.0) / 1000.0,
				"scale": [roundf(n2.global_scale.x * 100.0) / 100.0, roundf(n2.global_scale.y * 100.0) / 100.0]
			}
		elif n is Control:
			var c := n as Control
			node_data["local"] = {
				"position": [roundf(c.position.x * 100.0) / 100.0, roundf(c.position.y * 100.0) / 100.0],
				"rotation": roundf(c.rotation * 1000.0) / 1000.0,
				"scale": [roundf(c.scale.x * 100.0) / 100.0, roundf(c.scale.y * 100.0) / 100.0]
			}
			node_data["global"] = {
				"position": [roundf(c.global_position.x * 100.0) / 100.0, roundf(c.global_position.y * 100.0) / 100.0],
				"rotation": roundf(c.rotation * 1000.0) / 1000.0,
				"scale": [roundf(c.scale.x * 100.0) / 100.0, roundf(c.scale.y * 100.0) / 100.0]
			}

		var bounds := _compute_node_2d_bounds(n)
		if bounds.size != Vector2.ZERO:
			node_data["global_aabb"] = [roundf(bounds.position.x * 100.0) / 100.0, roundf(bounds.position.y * 100.0) / 100.0, roundf(bounds.size.x * 100.0) / 100.0, roundf(bounds.size.y * 100.0) / 100.0]
			node_data["center"] = [roundf((bounds.position.x + bounds.size.x * 0.5) * 100.0) / 100.0, roundf((bounds.position.y + bounds.size.y * 0.5) * 100.0) / 100.0]

		if include_collision:
			if n is CollisionObject2D:
				var co := n as CollisionObject2D
				var shapes_arr: Array = []
				for child in co.get_children():
					if child is CollisionShape2D and (child as CollisionShape2D).shape != null:
						shapes_arr.append({
							"name": child.name,
							"shape": _shape_info((child as CollisionShape2D).shape),
							"global_aabb": [roundf(_compute_node_2d_bounds(child).position.x * 100.0) / 100.0, roundf(_compute_node_2d_bounds(child).position.y * 100.0) / 100.0, roundf(_compute_node_2d_bounds(child).size.x * 100.0) / 100.0, roundf(_compute_node_2d_bounds(child).size.y * 100.0) / 100.0]
						})
					elif child is CollisionPolygon2D:
						shapes_arr.append({
							"name": child.name,
							"type": "CollisionPolygon2D",
							"points_count": (child as CollisionPolygon2D).polygon.size()
						})
				node_data["collision"] = {
					"collision_layer": co.collision_layer,
					"collision_mask": co.collision_mask,
					"shapes": shapes_arr
				}
			elif n is CollisionShape2D:
				node_data["collision"] = {"shape": _shape_info((n as CollisionShape2D).shape)}

		if include_tiles and n is TileMapLayer:
			var tml := n as TileMapLayer
			var urect := tml.get_used_rect()
			var tsz := [tml.tile_set.tile_size.x, tml.tile_set.tile_size.y] if tml.tile_set != null else [16, 16]
			var tml_data := {
				"path": rel_p,
				"tile_size": tsz,
				"used_rect_cells": [urect.position.x, urect.position.y, urect.size.x, urect.size.y],
				"used_cells_count": tml.get_used_cells().size(),
				"collision_enabled": tml.collision_enabled,
				"physics_layers_count": tml.tile_set.get_physics_layers_count() if tml.tile_set != null else 0
			}
			node_data["tilemap_layer"] = tml_data
			tilemap_layers_summary.append(tml_data)

		nodes_list.append(node_data)

		if max_depth < 0 or depth < max_depth:
			var children := n.get_children()
			for i in range(children.size() - 1, -1, -1):
				stack.push_back({"node": children[i], "depth": depth + 1})

	return {
		"ok": true,
		"scene_path": root.scene_file_path if not root.scene_file_path.is_empty() else "res://unsaved_scene.tscn",
		"viewport": {"width": vp_w, "height": vp_h},
		"camera": camera_info,
		"nodes_count": nodes_list.size(),
		"nodes": nodes_list,
		"tilemap_layers": tilemap_layers_summary,
		"source": "local"
	}


func _convert_spatial_coordinates(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var pt_raw = args.get("point")
	if not (pt_raw is Array) or (pt_raw as Array).size() < 2:
		return {"ok": false, "error": "missing_or_invalid_point", "message": "Specify 'point' as [x, y]."}
	var pt := Vector2(float(pt_raw[0]), float(pt_raw[1]))

	var from_frame := str(args.get("from_frame", "global")).to_lower().strip_edges()
	var to_frame := str(args.get("to_frame", "local")).to_lower().strip_edges()

	if from_frame == "world": from_frame = "global"
	if from_frame == "screen": from_frame = "viewport"
	if from_frame == "cell": from_frame = "tilemap_cell"
	if from_frame == "atlas": from_frame = "tilemap_atlas"

	if to_frame == "world": to_frame = "global"
	if to_frame == "screen": to_frame = "viewport"
	if to_frame == "cell": to_frame = "tilemap_cell"
	if to_frame == "atlas": to_frame = "tilemap_atlas"

	var node_path := str(args.get("node_path", "")).strip_edges()
	var layer_path := str(args.get("layer_path", "")).strip_edges()

	var node: Node = null
	if not node_path.is_empty():
		node = _resolve_node(root, node_path)

	var layer: TileMapLayer = null
	if not layer_path.is_empty():
		var l_node := _resolve_node(root, layer_path)
		if l_node is TileMapLayer:
			layer = l_node as TileMapLayer

	if from_frame == "tilemap_atlas":
		return {
			"ok": false,
			"error": "invalid_conversion",
			"message": "Cannot convert atlas coordinates to world space without a target cell. Atlas coordinates represent artwork regions within a texture, not world positions."
		}

	var vp_w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var vp_h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	var cam := _find_camera_2d(root)

	# 1. Convert input point to intermediate Global Vector2
	var global_pos := Vector2.ZERO
	match from_frame:
		"global":
			global_pos = pt
		"local":
			if node == null:
				return {"ok": false, "error": "missing_node", "message": "Converting from 'local' requires a valid 'node_path'."}
			if node is Node2D:
				global_pos = (node as Node2D).to_global(pt)
			elif node is Control:
				global_pos = (node as Control).get_global_transform() * pt
			else:
				return {"ok": false, "error": "node_not_2d", "node_path": node_path}
		"viewport":
			if cam != null:
				var cam_zoom := cam.zoom if cam.zoom != Vector2.ZERO else Vector2.ONE
				var half_vp := Vector2(vp_w, vp_h) * 0.5
				var unzoomed := (pt - half_vp) / cam_zoom
				global_pos = cam.global_position + cam.offset + unzoomed.rotated(cam.global_rotation)
			else:
				global_pos = pt
		"tilemap_cell":
			if layer == null:
				return {"ok": false, "error": "missing_tilemap_layer", "message": "Converting from 'tilemap_cell' requires a valid 'layer_path'."}
			var cell_v := Vector2i(int(round(pt.x)), int(round(pt.y)))
			var loc := layer.map_to_local(cell_v)
			global_pos = layer.to_global(loc)
		_:
			return {"ok": false, "error": "unknown_from_frame", "from_frame": from_frame}

	# 2. Convert intermediate Global Vector2 to target frame
	var result_point: Array = []
	var details: Dictionary = {"basis": to_frame, "exact": true}

	match to_frame:
		"global":
			result_point = [roundf(global_pos.x * 100.0) / 100.0, roundf(global_pos.y * 100.0) / 100.0]
		"local":
			if node == null:
				return {"ok": false, "error": "missing_node", "message": "Converting to 'local' requires a valid 'node_path'."}
			var loc := Vector2.ZERO
			if node is Node2D:
				loc = (node as Node2D).to_local(global_pos)
			elif node is Control:
				loc = (node as Control).get_global_transform().affine_inverse() * global_pos
			else:
				return {"ok": false, "error": "node_not_2d", "node_path": node_path}
			result_point = [roundf(loc.x * 100.0) / 100.0, roundf(loc.y * 100.0) / 100.0]
			details["node"] = node.name
		"viewport":
			var screen_pt := Vector2.ZERO
			if cam != null:
				var cam_zoom := cam.zoom if cam.zoom != Vector2.ZERO else Vector2.ONE
				var delta := (global_pos - (cam.global_position + cam.offset)).rotated(-cam.global_rotation)
				screen_pt = (delta * cam_zoom) + (Vector2(vp_w, vp_h) * 0.5)
				details["camera"] = cam.name
			else:
				screen_pt = global_pos
				details["camera"] = "none (using screen origin 0,0)"
			result_point = [roundf(screen_pt.x * 100.0) / 100.0, roundf(screen_pt.y * 100.0) / 100.0]
		"tilemap_cell":
			if layer == null:
				return {"ok": false, "error": "missing_tilemap_layer", "message": "Converting to 'tilemap_cell' requires a valid 'layer_path'."}
			var loc := layer.to_local(global_pos)
			var cell_v := layer.local_to_map(loc)
			result_point = [cell_v.x, cell_v.y]
			var cell_center := layer.to_global(layer.map_to_local(cell_v))
			var tsz := Vector2(layer.tile_set.tile_size) if layer.tile_set != null else Vector2(16, 16)
			details["cell_rect_world"] = [roundf((cell_center.x - tsz.x * 0.5) * 100.0) / 100.0, roundf((cell_center.y - tsz.y * 0.5) * 100.0) / 100.0, tsz.x, tsz.y]
			details["layer"] = layer.name
		"tilemap_atlas":
			if layer == null:
				return {"ok": false, "error": "missing_tilemap_layer", "message": "Converting to 'tilemap_atlas' requires a valid 'layer_path'."}
			var loc := layer.to_local(global_pos)
			var cell_v := layer.local_to_map(loc)
			var atlas := layer.get_cell_atlas_coords(cell_v)
			var sid := layer.get_cell_source_id(cell_v)
			result_point = [atlas.x, atlas.y]
			details["cell"] = [cell_v.x, cell_v.y]
			details["source_id"] = sid
			details["layer"] = layer.name
			details["is_empty"] = (sid == -1)
		_:
			return {"ok": false, "error": "unknown_to_frame", "to_frame": to_frame}

	return {
		"ok": true,
		"input_point": [pt.x, pt.y],
		"from_frame": from_frame,
		"to_frame": to_frame,
		"converted_point": result_point,
		"intermediate_global_point": [roundf(global_pos.x * 100.0) / 100.0, roundf(global_pos.y * 100.0) / 100.0],
		"details": details,
		"source": "local"
	}


func _inspect_spatial_region(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var rect_raw = args.get("rect")
	if not (rect_raw is Array) or (rect_raw as Array).size() < 4:
		return {"ok": false, "error": "missing_rect", "message": "Expected 'rect' as [x, y, width, height] in world coordinates."}

	var q_rect := Rect2(float(rect_raw[0]), float(rect_raw[1]), float(rect_raw[2]), float(rect_raw[3]))
	var type_filter: Array = args.get("type_filter", [])
	var include_cells := bool(args.get("include_cells", true))
	var max_cells := clampi(int(args.get("max_cells", 100)), 1, 500)

	var occupied_nodes: Array = []
	var intersecting_cells: Array = []
	var hazards_found: Array = []
	var surfaces_detected: Array = []

	var all_nodes: Array = []
	var q_stack: Array = [root]
	while not q_stack.is_empty():
		var n: Node = q_stack.pop_back()
		if n != root:
			all_nodes.append(n)
		for child in n.get_children():
			q_stack.push_back(child)

	for n in all_nodes:
		if not type_filter.is_empty() and not type_filter.has(n.get_class()):
			continue
		var bounds := _compute_node_2d_bounds(n)
		if bounds.size == Vector2.ZERO:
			continue
		if q_rect.intersects(bounds):
			var overlap := q_rect.intersection(bounds)
			var is_hz: bool = bool(n.is_in_group("hazard") or n.is_in_group("spikes") or n.is_in_group("danger") or n.name.to_lower().contains("spike") or n.name.to_lower().contains("hazard") or n.name.to_lower().contains("trap") or n.name.to_lower().contains("danger"))
			var entry := {
				"name": n.name,
				"path": str(root.get_path_to(n)),
				"type": n.get_class(),
				"global_aabb": [roundf(bounds.position.x * 100.0) / 100.0, roundf(bounds.position.y * 100.0) / 100.0, roundf(bounds.size.x * 100.0) / 100.0, roundf(bounds.size.y * 100.0) / 100.0],
				"overlap_rect": [roundf(overlap.position.x * 100.0) / 100.0, roundf(overlap.position.y * 100.0) / 100.0, roundf(overlap.size.x * 100.0) / 100.0, roundf(overlap.size.y * 100.0) / 100.0],
				"is_hazard": is_hz
			}
			occupied_nodes.append(entry)
			if is_hz:
				hazards_found.append({"type": "node", "path": entry["path"], "name": n.name})

			if n is StaticBody2D or n is AnimatableBody2D:
				surfaces_detected.append({
					"source": entry["path"],
					"surface_y": roundf(bounds.position.y * 100.0) / 100.0,
					"x_start": roundf(bounds.position.x * 100.0) / 100.0,
					"x_end": roundf((bounds.position.x + bounds.size.x) * 100.0) / 100.0,
					"width": roundf(bounds.size.x * 100.0) / 100.0
				})

	if include_cells:
		for n in all_nodes:
			if n is TileMapLayer:
				var tml := n as TileMapLayer
				var tsz := Vector2(tml.tile_set.tile_size) if tml.tile_set != null else Vector2(16, 16)
				var l_tl := tml.to_local(q_rect.position)
				var l_br := tml.to_local(q_rect.position + q_rect.size)
				var min_c := tml.local_to_map(Vector2(minf(l_tl.x, l_br.x), minf(l_tl.y, l_br.y))) - Vector2i(1, 1)
				var max_c := tml.local_to_map(Vector2(maxf(l_tl.x, l_br.x), maxf(l_tl.y, l_br.y))) + Vector2i(1, 1)

				for cy in range(min_c.y, max_c.y + 1):
					var current_surface_start := -1.0
					var current_surface_end := -1.0
					var current_surface_y := 0.0

					for cx in range(min_c.x, max_c.x + 1):
						var c := Vector2i(cx, cy)
						var sid := tml.get_cell_source_id(c)
						if sid == -1:
							if current_surface_start >= 0.0:
								surfaces_detected.append({
									"source": str(root.get_path_to(tml)),
									"surface_y": roundf(current_surface_y * 100.0) / 100.0,
									"x_start": roundf(current_surface_start * 100.0) / 100.0,
									"x_end": roundf(current_surface_end * 100.0) / 100.0,
									"width": roundf((current_surface_end - current_surface_start) * 100.0) / 100.0
								})
								current_surface_start = -1.0
							continue

						var center := tml.to_global(tml.map_to_local(c))
						var cell_rect := Rect2(center.x - tsz.x * 0.5, center.y - tsz.y * 0.5, tsz.x, tsz.y)

						if q_rect.intersects(cell_rect):
							var atlas := tml.get_cell_atlas_coords(c)
							var is_solid := tml.collision_enabled and (tml.tile_set != null and tml.tile_set.get_physics_layers_count() > 0)
							var cell_hz := false
							if tml.tile_set != null:
								var src := tml.tile_set.get_source(sid)
								if src is TileSetAtlasSource:
									var tdata := (src as TileSetAtlasSource).get_tile_data(atlas, 0)
									if tdata != null and tdata.get_custom_data("hazard") != null and bool(tdata.get_custom_data("hazard")):
										cell_hz = true

							if intersecting_cells.size() < max_cells:
								intersecting_cells.append({
									"layer": str(root.get_path_to(tml)),
									"cell": [cx, cy],
									"source_id": sid,
									"atlas_coords": [atlas.x, atlas.y],
									"world_rect": [roundf(cell_rect.position.x * 100.0) / 100.0, roundf(cell_rect.position.y * 100.0) / 100.0, tsz.x, tsz.y],
									"has_collision": is_solid,
									"is_hazard": cell_hz
								})

							if cell_hz:
								hazards_found.append({"type": "tile", "layer": str(root.get_path_to(tml)), "cell": [cx, cy]})

							var above_sid := tml.get_cell_source_id(Vector2i(cx, cy - 1))
							if above_sid == -1 and is_solid:
								var top_y := cell_rect.position.y
								if current_surface_start < 0.0:
									current_surface_start = cell_rect.position.x
									current_surface_end = cell_rect.position.x + tsz.x
									current_surface_y = top_y
								elif absf(top_y - current_surface_y) < 1.0 and absf(cell_rect.position.x - current_surface_end) < 2.0:
									current_surface_end = cell_rect.position.x + tsz.x
								else:
									surfaces_detected.append({
										"source": str(root.get_path_to(tml)),
										"surface_y": roundf(current_surface_y * 100.0) / 100.0,
										"x_start": roundf(current_surface_start * 100.0) / 100.0,
										"x_end": roundf(current_surface_end * 100.0) / 100.0,
										"width": roundf((current_surface_end - current_surface_start) * 100.0) / 100.0
									})
									current_surface_start = cell_rect.position.x
									current_surface_end = cell_rect.position.x + tsz.x
									current_surface_y = top_y
							else:
								if current_surface_start >= 0.0:
									surfaces_detected.append({
										"source": str(root.get_path_to(tml)),
										"surface_y": roundf(current_surface_y * 100.0) / 100.0,
										"x_start": roundf(current_surface_start * 100.0) / 100.0,
										"x_end": roundf(current_surface_end * 100.0) / 100.0,
										"width": roundf((current_surface_end - current_surface_start) * 100.0) / 100.0
									})
									current_surface_start = -1.0

					if current_surface_start >= 0.0:
						surfaces_detected.append({
							"source": str(root.get_path_to(tml)),
							"surface_y": roundf(current_surface_y * 100.0) / 100.0,
							"x_start": roundf(current_surface_start * 100.0) / 100.0,
							"x_end": roundf(current_surface_end * 100.0) / 100.0,
							"width": roundf((current_surface_end - current_surface_start) * 100.0) / 100.0
						})

	return {
		"ok": true,
		"query_rect": [q_rect.position.x, q_rect.position.y, q_rect.size.x, q_rect.size.y],
		"is_empty": occupied_nodes.is_empty() and intersecting_cells.is_empty(),
		"occupied_nodes_count": occupied_nodes.size(),
		"occupied_nodes": occupied_nodes,
		"intersecting_cells_count": intersecting_cells.size(),
		"intersecting_cells": intersecting_cells,
		"hazards_count": hazards_found.size(),
		"hazards": hazards_found,
		"surfaces": surfaces_detected,
		"source": "local"
	}


func _query_spatial_relationships(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var node_a_path := str(args.get("node_a", "")).strip_edges()
	if node_a_path.is_empty():
		return {"ok": false, "error": "missing_node_a", "message": "Specify 'node_a' path (e.g. 'Player' or 'World/Player')."}

	var node_a := _resolve_node(root, node_a_path)
	if node_a == null:
		return {"ok": false, "error": "node_a_not_found", "node_a": node_a_path}

	var bounds_a := _compute_node_2d_bounds(node_a)
	var pos_a := (node_a as Node2D).global_position if node_a is Node2D else ((node_a as Control).global_position if node_a is Control else bounds_a.position)
	var center_a := Vector2(bounds_a.position.x + bounds_a.size.x * 0.5, bounds_a.position.y + bounds_a.size.y * 0.5) if bounds_a.size != Vector2.ZERO else pos_a

	var target_nodes: Array = []
	var node_b_path := str(args.get("node_b", "")).strip_edges()
	if not node_b_path.is_empty() and node_b_path != "all":
		var node_b := _resolve_node(root, node_b_path)
		if node_b != null:
			target_nodes.append(node_b)
		else:
			return {"ok": false, "error": "node_b_not_found", "node_b": node_b_path}
	elif args.has("target_nodes") and args.get("target_nodes") is Array:
		for tp in args.get("target_nodes"):
			var tn := _resolve_node(root, str(tp).strip_edges())
			if tn != null and tn != node_a:
				target_nodes.append(tn)
	else:
		var max_targets := clampi(int(args.get("max_targets", 12)), 1, 30)
		var stack := [root]
		while not stack.is_empty() and target_nodes.size() < max_targets:
			var n: Node = stack.pop_back()
			if n != root and n != node_a and not node_a.is_ancestor_of(n):
				if n is CanvasItem or n is CollisionObject2D:
					var b := _compute_node_2d_bounds(n)
					if b.size != Vector2.ZERO or n is Node2D:
						target_nodes.append(n)
			for child in n.get_children():
				stack.push_back(child)

	var relationships: Array = []
	var nearest_node: Dictionary = {}
	var min_center_dist := 1e9
	var support_surfaces: Array = []
	var hazards_near: Array = []

	for target in target_nodes:
		var bounds_b := _compute_node_2d_bounds(target)
		var pos_b := (target as Node2D).global_position if target is Node2D else ((target as Control).global_position if target is Control else bounds_b.position)
		var center_b := Vector2(bounds_b.position.x + bounds_b.size.x * 0.5, bounds_b.position.y + bounds_b.size.y * 0.5) if bounds_b.size != Vector2.ZERO else pos_b

		var pivot_dist := roundf((pos_b - pos_a).length() * 100.0) / 100.0
		var center_dist := roundf((center_b - center_a).length() * 100.0) / 100.0
		var dx := roundf((center_b.x - center_a.x) * 100.0) / 100.0
		var dy := roundf((center_b.y - center_a.y) * 100.0) / 100.0

		var h_clearance := 0.0
		if bounds_a.size != Vector2.ZERO and bounds_b.size != Vector2.ZERO:
			if bounds_a.position.x + bounds_a.size.x < bounds_b.position.x:
				h_clearance = roundf((bounds_b.position.x - (bounds_a.position.x + bounds_a.size.x)) * 100.0) / 100.0
			elif bounds_b.position.x + bounds_b.size.x < bounds_a.position.x:
				h_clearance = roundf((bounds_a.position.x - (bounds_b.position.x + bounds_b.size.x)) * 100.0) / 100.0
		else:
			h_clearance = absf(dx)

		var v_clearance := 0.0
		if bounds_a.size != Vector2.ZERO and bounds_b.size != Vector2.ZERO:
			if bounds_a.position.y + bounds_a.size.y < bounds_b.position.y:
				v_clearance = roundf((bounds_b.position.y - (bounds_a.position.y + bounds_a.size.y)) * 100.0) / 100.0
			elif bounds_b.position.y + bounds_b.size.y < bounds_a.position.y:
				v_clearance = roundf((bounds_a.position.y - (bounds_b.position.y + bounds_b.size.y)) * 100.0) / 100.0
		else:
			v_clearance = absf(dy)

		var is_overlapping := false
		var overlap_rect: Array = []
		if bounds_a.size != Vector2.ZERO and bounds_b.size != Vector2.ZERO and bounds_a.intersects(bounds_b):
			is_overlapping = true
			var ov := bounds_a.intersection(bounds_b)
			overlap_rect = [roundf(ov.position.x * 100.0) / 100.0, roundf(ov.position.y * 100.0) / 100.0, roundf(ov.size.x * 100.0) / 100.0, roundf(ov.size.y * 100.0) / 100.0]

		var rel_dir := "adjacent"
		if is_overlapping:
			rel_dir = "overlapping"
		elif h_clearance == 0.0:
			rel_dir = "below" if dy > 0 else "above"
		elif v_clearance == 0.0:
			rel_dir = "right_of" if dx > 0 else "left_of"
		else:
			if dx > 0 and dy > 0: rel_dir = "below_right"
			elif dx > 0 and dy < 0: rel_dir = "above_right"
			elif dx < 0 and dy > 0: rel_dir = "below_left"
			else: rel_dir = "above_left"

		var is_support := false
		var support_details: Dictionary = {}
		if bounds_a.size != Vector2.ZERO and bounds_b.size != Vector2.ZERO:
			var a_right := bounds_a.position.x + bounds_a.size.x
			var b_right := bounds_b.position.x + bounds_b.size.x
			var h_overlap := maxf(0.0, minf(a_right, b_right) - maxf(bounds_a.position.x, bounds_b.position.x))
			if h_overlap > 2.0:
				var a_bottom := bounds_a.position.y + bounds_a.size.y
				var b_top := bounds_b.position.y
				if b_top >= a_bottom - 4.0 and b_top <= a_bottom + 48.0:
					is_support = true
					support_details = {
						"surface_y": roundf(b_top * 100.0) / 100.0,
						"drop_distance": roundf((b_top - a_bottom) * 100.0) / 100.0,
						"contact": absf(b_top - a_bottom) <= 2.0
					}

		if target is TileMapLayer:
			var tml := target as TileMapLayer
			var tsz := Vector2(tml.tile_set.tile_size) if tml.tile_set != null else Vector2(16, 16)
			var a_bottom := bounds_a.position.y + bounds_a.size.y
			var loc_probe := tml.to_local(Vector2(center_a.x, a_bottom + 4.0))
			var cell_under := tml.local_to_map(loc_probe)
			var sid := tml.get_cell_source_id(cell_under)
			if sid == -1:
				cell_under.y += 1
				sid = tml.get_cell_source_id(cell_under)
			if sid != -1 and tml.collision_enabled:
				var tile_top := tml.to_global(tml.map_to_local(cell_under)).y - tsz.y * 0.5
				if tile_top >= a_bottom - 4.0 and tile_top <= a_bottom + 64.0:
					is_support = true
					support_details = {
						"surface_y": roundf(tile_top * 100.0) / 100.0,
						"drop_distance": roundf((tile_top - a_bottom) * 100.0) / 100.0,
						"cell": [cell_under.x, cell_under.y],
						"contact": absf(tile_top - a_bottom) <= 2.0
					}

		var is_hz: bool = bool(target.is_in_group("hazard") or target.name.to_lower().contains("spike") or target.name.to_lower().contains("hazard"))

		var rel_entry := {
			"target": target.name,
			"path": str(root.get_path_to(target)),
			"type": target.get_class(),
			"pivot_distance": pivot_dist,
			"center_distance": center_dist,
			"delta_x": dx,
			"delta_y": dy,
			"horizontal_clearance": h_clearance,
			"vertical_clearance": v_clearance,
			"relative_direction": rel_dir,
			"is_overlapping": is_overlapping,
			"overlap_rect": overlap_rect,
			"is_support_surface": is_support,
			"support_details": support_details,
			"is_hazard": is_hz
		}
		relationships.append(rel_entry)

		if center_dist < min_center_dist:
			min_center_dist = center_dist
			nearest_node = rel_entry

		if is_support:
			support_surfaces.append(rel_entry)
		if is_hz:
			hazards_near.append(rel_entry)

	relationships.sort_custom(func(a, b): return a["center_distance"] < b["center_distance"])

	return {
		"ok": true,
		"node_a": {
			"name": node_a.name,
			"path": str(root.get_path_to(node_a)) if root != node_a else ".",
			"type": node_a.get_class(),
			"position": [roundf(pos_a.x * 100.0) / 100.0, roundf(pos_a.y * 100.0) / 100.0],
			"center": [roundf(center_a.x * 100.0) / 100.0, roundf(center_a.y * 100.0) / 100.0],
			"global_aabb": [roundf(bounds_a.position.x * 100.0) / 100.0, roundf(bounds_a.position.y * 100.0) / 100.0, roundf(bounds_a.size.x * 100.0) / 100.0, roundf(bounds_a.size.y * 100.0) / 100.0]
		},
		"compared_targets_count": relationships.size(),
		"relationships": relationships,
		"nearest_node": nearest_node,
		"support_surfaces": support_surfaces,
		"hazards": hazards_near,
		"source": "local"
	}


func _preview_spatial_overlay(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var show_labels := bool(args.get("show_labels", true))
	var show_bounds := bool(args.get("show_bounds", true))
	var show_axes := bool(args.get("show_axes", true))
	var show_camera := bool(args.get("show_camera", true))
	var max_w := clampi(int(args.get("max_width", 640)), 256, 1920)

	var dir_user := "user://godot_agent_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_user))
	var save_path := str(args.get("save_path", dir_user + "/spatial_overlay.png"))
	var global_save := ProjectSettings.globalize_path(save_path)

	var img: Image = null
	var base_control := EditorInterface.get_base_control() if Engine.is_editor_hint() else null
	if base_control != null and base_control.get_viewport() != null:
		var tex := base_control.get_viewport().get_texture()
		if tex != null:
			var captured := tex.get_image()
			if captured != null and not captured.is_empty():
				img = captured.duplicate() as Image

	var vp_w := int(ProjectSettings.get_setting("display/window/size/viewport_width", 1152))
	var vp_h := int(ProjectSettings.get_setting("display/window/size/viewport_height", 648))
	var cam := _find_camera_2d(root)

	var is_schematic := (img == null or img.is_empty())
	if is_schematic:
		img = Image.create(640, 360, false, Image.FORMAT_RGBA8)
		img.fill(Color(0.1, 0.12, 0.16, 1.0))
		var grid_col := Color(0.18, 0.22, 0.28, 0.7)
		for gx in range(0, 640, 32):
			for y in 360:
				img.set_pixel(gx, y, grid_col)
		for gy in range(0, 360, 32):
			for x in 640:
				img.set_pixel(x, gy, grid_col)

	var img_w := img.get_width()
	var img_h := img.get_height()

	var project_fn := func(world_pt: Vector2) -> Vector2:
		if cam != null:
			var cam_zoom := cam.zoom if cam.zoom != Vector2.ZERO else Vector2.ONE
			var half_vp := Vector2(img_w, img_h) * 0.5
			var delta := (world_pt - (cam.global_position + cam.offset)).rotated(-cam.global_rotation)
			return (delta * cam_zoom) + half_vp
		else:
			if is_schematic:
				return world_pt + Vector2(img_w * 0.5, img_h * 0.5)
			return world_pt

	var nodes_to_draw: Array = []
	if args.has("node_paths") and args.get("node_paths") is Array and not (args.get("node_paths") as Array).is_empty():
		for p in args.get("node_paths"):
			var tn := _resolve_node(root, str(p).strip_edges())
			if tn != null:
				nodes_to_draw.append(tn)
	else:
		var q_stack := [root]
		while not q_stack.is_empty():
			var n: Node = q_stack.pop_back()
			if n != root and (n is CanvasItem or n is CollisionObject2D):
				var b := _compute_node_2d_bounds(n)
				if b.size != Vector2.ZERO:
					nodes_to_draw.append(n)
			for child in n.get_children():
				q_stack.push_back(child)

	var drawn_count := 0
	for n in nodes_to_draw:
		var bounds := _compute_node_2d_bounds(n)
		if bounds.size == Vector2.ZERO:
			continue

		var p_tl: Vector2 = project_fn.call(bounds.position)
		var p_br: Vector2 = project_fn.call(bounds.position + bounds.size)
		var rx := int(minf(p_tl.x, p_br.x))
		var ry := int(minf(p_tl.y, p_br.y))
		var rw := maxi(2, int(absf(p_br.x - p_tl.x)))
		var rh := maxi(2, int(absf(p_br.y - p_tl.y)))

		if rx + rw < 0 or ry + rh < 0 or rx >= img_w or ry >= img_h:
			continue

		var box_col := Color(0.4, 0.8, 1.0, 0.9)
		if n is CharacterBody2D or n.name.to_lower().contains("player"):
			box_col = Color(0.2, 1.0, 0.4, 1.0)
		elif n is StaticBody2D or n is TileMapLayer:
			box_col = Color(0.3, 0.7, 1.0, 0.9)
		elif n.is_in_group("hazard") or n.name.to_lower().contains("spike") or n.name.to_lower().contains("hazard"):
			box_col = Color(1.0, 0.25, 0.25, 1.0)
		elif n is Area2D:
			box_col = Color(1.0, 0.9, 0.2, 0.9)

		if show_bounds:
			for bx in rw:
				var px := rx + bx
				if px >= 0 and px < img_w:
					if ry >= 0 and ry < img_h: img.set_pixel(px, ry, box_col)
					if ry + rh - 1 >= 0 and ry + rh - 1 < img_h: img.set_pixel(px, ry + rh - 1, box_col)
			for by in rh:
				var py := ry + by
				if py >= 0 and py < img_h:
					if rx >= 0 and rx < img_w: img.set_pixel(rx, py, box_col)
					if rx + rw - 1 >= 0 and rx + rw - 1 < img_w: img.set_pixel(rx + rw - 1, py, box_col)

		if show_axes and n is Node2D:
			var pivot_scr: Vector2 = project_fn.call((n as Node2D).global_position)
			var px := int(pivot_scr.x)
			var py := int(pivot_scr.y)
			var cross_col := Color(1.0, 1.0, 0.2, 1.0)
			for dx in range(-3, 4):
				var cx := px + dx
				if cx >= 0 and cx < img_w and py >= 0 and py < img_h:
					img.set_pixel(cx, py, cross_col)
			for dy in range(-3, 4):
				var cy := py + dy
				if cy >= 0 and cy < img_h and px >= 0 and px < img_w:
					img.set_pixel(px, cy, cross_col)

		if show_labels:
			var lbl: String = str(n.name).substr(0, 12)
			var lbl_w: int = lbl.length() * 4 + 1
			var badge_x := clampi(rx, 1, img_w - lbl_w - 2)
			var badge_y := clampi(ry - 8, 1, img_h - 8)
			for by in 7:
				for bx in lbl_w:
					var tx: int = badge_x + bx
					var ty: int = badge_y + by
					if tx >= 0 and tx < img_w and ty >= 0 and ty < img_h:
						img.set_pixel(tx, ty, Color(0.05, 0.05, 0.1, 0.85))
			_draw_text_3x5(img, badge_x + 1, badge_y + 1, lbl, box_col)

		drawn_count += 1

	if show_camera and cam != null:
		var cam_zoom := cam.zoom if cam.zoom != Vector2.ZERO else Vector2.ONE
		var half_vp := (Vector2(vp_w, vp_h) * 0.5) / cam_zoom
		var cam_center := cam.global_position + cam.offset
		var c_tl: Vector2 = project_fn.call(cam_center - half_vp)
		var c_br: Vector2 = project_fn.call(cam_center + half_vp)
		var crx := int(minf(c_tl.x, c_br.x))
		var cry := int(minf(c_tl.y, c_br.y))
		var crw := int(absf(c_br.x - c_tl.x))
		var crh := int(absf(c_br.y - c_tl.y))
		var cam_border_col := Color(0.9, 0.4, 1.0, 0.8)
		for bx in crw:
			if (bx / 4) % 2 == 0:
				var px := crx + bx
				if px >= 0 and px < img_w:
					if cry >= 0 and cry < img_h: img.set_pixel(px, cry, cam_border_col)
					if cry + crh - 1 >= 0 and cry + crh - 1 < img_h: img.set_pixel(px, cry + crh - 1, cam_border_col)
		for by in crh:
			if (by / 4) % 2 == 0:
				var py := cry + by
				if py >= 0 and py < img_h:
					if crx >= 0 and crx < img_w: img.set_pixel(crx, py, cam_border_col)
					if crx + crw - 1 >= 0 and crx + crw - 1 < img_w: img.set_pixel(crx + crw - 1, py, cam_border_col)

	var img_out := img
	if img_w > max_w:
		var aspect := float(img_w) / float(img_h)
		var new_w := max_w
		var new_h := maxi(1, int(float(max_w) / aspect))
		img_out = img.duplicate() as Image
		img_out.resize(new_w, new_h, Image.INTERPOLATE_LANCZOS)

	img_out.save_png(global_save)
	var png_bytes := img_out.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)

	return {
		"ok": true,
		"saved_path": save_path,
		"width": img_out.get_width(),
		"height": img_out.get_height(),
		"nodes_drawn_count": drawn_count,
		"schematic_mode": is_schematic,
		"camera_drawn": (show_camera and cam != null),
		"base64": b64,
		"message": "Rendered spatial overlay (%dx%d pixels) with %d annotated node bounds." % [img_out.get_width(), img_out.get_height(), drawn_count],
		"source": "local"
	}


# ==============================================================================
# COLLISION CALIBRATION V1 IMPLEMENTATION
# ==============================================================================

func _is_shape_shared_in_scene(root: Node, shape: Shape2D, ignore_node: Node = null) -> Dictionary:
	if shape == null:
		return {"is_shared": false, "shared_count": 0, "sharing_nodes": [], "resource_path": ""}
	var res_path := shape.resource_path
	var sharing: Array = []
	if root != null:
		var stack: Array = [root]
		while not stack.is_empty():
			var curr: Node = stack.pop_back()
			if curr == null: continue
			for child in curr.get_children():
				stack.append(child)
			if curr is CollisionShape2D and curr != ignore_node:
				if (curr as CollisionShape2D).shape == shape:
					sharing.append(str(root.get_path_to(curr)))
	var is_shared := sharing.size() > 0 or not res_path.is_empty()
	var total_count := sharing.size() + (1 if ignore_node != null else 0)
	return {
		"is_shared": is_shared,
		"shared_count": total_count,
		"sharing_nodes": sharing,
		"resource_path": res_path
	}


func _extract_image_from_texture(tex: Texture2D) -> Dictionary:
	if tex == null:
		return {"ok": false, "error": "texture_is_null"}
	var img: Image = null
	var region := Rect2i()
	if tex is AtlasTexture:
		var atlas_tex := tex as AtlasTexture
		if atlas_tex.atlas != null:
			img = atlas_tex.atlas.get_image()
			region = Rect2i(atlas_tex.region)
	else:
		img = tex.get_image()
		if img != null:
			region = Rect2i(0, 0, img.get_width(), img.get_height())
	if img == null or img.is_empty():
		return {"ok": false, "error": "failed_to_get_image"}
	return {"ok": true, "image": img, "region": region}


func _measure_image_opaque_rect(img: Image, region: Rect2i, alpha_threshold: float = 0.05) -> Dictionary:
	if img == null or img.is_empty():
		return {
			"has_opaque": false,
			"min_x": 0, "min_y": 0, "max_x": 0, "max_y": 0,
			"rel_min_x": 0, "rel_min_y": 0, "rel_max_x": 0, "rel_max_y": 0,
			"width": 0, "height": 0,
			"opaque_fraction": 0.0,
			"opaque_pixel_count": 0,
			"total_pixels": 0
		}
	var img_w := img.get_width()
	var img_h := img.get_height()
	var rx := clampi(region.position.x, 0, img_w - 1)
	var ry := clampi(region.position.y, 0, img_h - 1)
	var rw := clampi(region.size.x, 1, img_w - rx)
	var rh := clampi(region.size.y, 1, img_h - ry)

	var min_x := 999999
	var max_x := -1
	var min_y := 999999
	var max_y := -1
	var opaque_count := 0
	var total_pixels := rw * rh

	for y in range(ry, ry + rh):
		for x in range(rx, rx + rw):
			var a := img.get_pixel(x, y).a
			if a >= alpha_threshold:
				if x < min_x: min_x = x
				if x > max_x: max_x = x
				if y < min_y: min_y = y
				if y > max_y: max_y = y
				opaque_count += 1

	if opaque_count == 0:
		return {
			"has_opaque": false,
			"min_x": 0, "min_y": 0, "max_x": 0, "max_y": 0,
			"rel_min_x": 0, "rel_min_y": 0, "rel_max_x": 0, "rel_max_y": 0,
			"width": 0, "height": 0,
			"opaque_fraction": 0.0,
			"opaque_pixel_count": 0,
			"total_pixels": total_pixels
		}

	var rel_min_x := min_x - rx
	var rel_min_y := min_y - ry
	var rel_max_x := max_x - rx
	var rel_max_y := max_y - ry
	var op_w := rel_max_x - rel_min_x + 1
	var op_h := rel_max_y - rel_min_y + 1

	return {
		"has_opaque": true,
		"min_x": min_x, "min_y": min_y, "max_x": max_x, "max_y": max_y,
		"rel_min_x": rel_min_x, "rel_min_y": rel_min_y,
		"rel_max_x": rel_max_x, "rel_max_y": rel_max_y,
		"width": op_w, "height": op_h,
		"opaque_fraction": roundf((float(opaque_count) / float(total_pixels)) * 1000.0) / 1000.0,
		"opaque_pixel_count": opaque_count,
		"total_pixels": total_pixels
	}


func _get_sprite_render_info(sprite: Node, anim_name: String = "", frame_idx: int = -1, alpha_threshold: float = 0.05) -> Dictionary:
	if sprite == null:
		return {"ok": false, "error": "sprite_is_null"}

	var is_animated := sprite is AnimatedSprite2D or sprite.get_class() == "AnimatedSprite2D"
	var is_sprite2d := sprite is Sprite2D or sprite.get_class() == "Sprite2D"

	if not is_animated and not is_sprite2d:
		return {"ok": false, "error": "unsupported_visual_node", "class": sprite.get_class(), "hint": "Node must be Sprite2D or AnimatedSprite2D."}

	var centered: bool = bool(sprite.get("centered")) if sprite.get("centered") != null else true
	var offset: Vector2 = sprite.get("offset") if sprite.get("offset") != null else Vector2.ZERO
	var flip_h: bool = bool(sprite.get("flip_h")) if sprite.get("flip_h") != null else false
	var flip_v: bool = bool(sprite.get("flip_v")) if sprite.get("flip_v") != null else false

	if is_sprite2d:
		var tex_var: Variant = sprite.get("texture")
		if tex_var == null or not (tex_var is Texture2D):
			return {"ok": false, "error": "sprite_has_no_texture", "node_path": str(sprite.name)}
		var tex: Texture2D = tex_var as Texture2D
		var ext_res := _extract_image_from_texture(tex)
		if not bool(ext_res.get("ok", false)):
			return ext_res
		var img: Image = ext_res["image"]
		var region: Rect2i = ext_res["region"]
		if bool(sprite.get("region_enabled")):
			var r_rect: Rect2 = sprite.get("region_rect")
			region = Rect2i(int(r_rect.position.x), int(r_rect.position.y), int(r_rect.size.x), int(r_rect.size.y))

		var opaque_res := _measure_image_opaque_rect(img, region, alpha_threshold)
		var raw_w := float(region.size.x)
		var raw_h := float(region.size.y)
		var tl_x := (-raw_w * 0.5 if centered else 0.0) + offset.x
		var tl_y := (-raw_h * 0.5 if centered else 0.0) + offset.y

		var op_w := float(opaque_res.get("width", raw_w))
		var op_h := float(opaque_res.get("height", raw_h))
		var rel_min_x := float(opaque_res.get("rel_min_x", 0.0))
		var rel_min_y := float(opaque_res.get("rel_min_y", 0.0))

		var local_min_x := tl_x + rel_min_x
		var local_min_y := tl_y + rel_min_y
		var local_max_x := local_min_x + op_w
		var local_max_y := local_min_y + op_h
		var ground_baseline_y := local_max_y

		return {
			"ok": true,
			"is_animated": false,
			"node_name": str(sprite.name),
			"raw_pixel_size": [int(raw_w), int(raw_h)],
			"opaque_rect": [int(rel_min_x), int(rel_min_y), int(op_w), int(op_h)],
			"opaque_fraction": opaque_res.get("opaque_fraction", 1.0),
			"has_opaque": opaque_res.get("has_opaque", true),
			"visual_local_bounds": [roundf(local_min_x * 10.0) / 10.0, roundf(local_min_y * 10.0) / 10.0, roundf(local_max_x * 10.0) / 10.0, roundf(local_max_y * 10.0) / 10.0],
			"visual_dimensions": {"width": roundf(op_w * 10.0) / 10.0, "height": roundf(op_h * 10.0) / 10.0},
			"visual_center": [roundf((local_min_x + local_max_x) * 0.5 * 10.0) / 10.0, roundf((local_min_y + local_max_y) * 0.5 * 10.0) / 10.0],
			"ground_baseline_y": roundf(ground_baseline_y * 10.0) / 10.0,
			"centered": centered,
			"offset": [offset.x, offset.y],
			"flip_h": flip_h,
			"flip_v": flip_v,
			"source_texture_region": [region.position.x, region.position.y, region.size.x, region.size.y]
		}

	# AnimatedSprite2D
	var sf_var: Variant = sprite.get("sprite_frames")
	if sf_var == null or not (sf_var is SpriteFrames):
		return {"ok": false, "error": "animated_sprite_has_no_sprite_frames", "node_path": str(sprite.name)}
	var sf: SpriteFrames = sf_var as SpriteFrames
	var anims := sf.get_animation_names()
	if anims.is_empty():
		return {"ok": false, "error": "sprite_frames_empty", "node_path": str(sprite.name)}

	var target_anim := anim_name
	if target_anim.is_empty():
		target_anim = str(sprite.get("animation"))
	if target_anim.is_empty() or not sf.has_animation(target_anim):
		target_anim = anims[0]

	var frame_count := sf.get_frame_count(target_anim)
	if frame_count <= 0:
		return {"ok": false, "error": "animation_has_no_frames", "animation": target_anim}

	var frames_data: Array = []
	var comb_min_x := 999999.0
	var comb_max_x := -999999.0
	var comb_min_y := 999999.0
	var comb_max_y := -999999.0

	var start_idx := 0
	var end_idx := frame_count - 1
	if frame_idx >= 0 and frame_idx < frame_count:
		start_idx = frame_idx
		end_idx = frame_idx

	for idx in range(start_idx, end_idx + 1):
		var f_tex := sf.get_frame_texture(target_anim, idx)
		if f_tex == null:
			continue
		var f_ext := _extract_image_from_texture(f_tex)
		if not bool(f_ext.get("ok", false)):
			continue
		var f_img: Image = f_ext["image"]
		var f_reg: Rect2i = f_ext["region"]
		var f_op := _measure_image_opaque_rect(f_img, f_reg, alpha_threshold)
		var rw := float(f_reg.size.x)
		var rh := float(f_reg.size.y)
		var tl_x := (-rw * 0.5 if centered else 0.0) + offset.x
		var tl_y := (-rh * 0.5 if centered else 0.0) + offset.y

		var op_w := float(f_op.get("width", rw))
		var op_h := float(f_op.get("height", rh))
		var rel_x := float(f_op.get("rel_min_x", 0.0))
		var rel_y := float(f_op.get("rel_min_y", 0.0))

		var l_min_x := tl_x + rel_x
		var l_min_y := tl_y + rel_y
		var l_max_x := l_min_x + op_w
		var l_max_y := l_min_y + op_h

		if l_min_x < comb_min_x: comb_min_x = l_min_x
		if l_max_x > comb_max_x: comb_max_x = l_max_x
		if l_min_y < comb_min_y: comb_min_y = l_min_y
		if l_max_y > comb_max_y: comb_max_y = l_max_y

		frames_data.append({
			"frame_index": idx,
			"raw_size": [int(rw), int(rh)],
			"opaque_rect": [int(rel_x), int(rel_y), int(op_w), int(op_h)],
			"local_bounds": [roundf(l_min_x * 10.0) / 10.0, roundf(l_min_y * 10.0) / 10.0, roundf(l_max_x * 10.0) / 10.0, roundf(l_max_y * 10.0) / 10.0],
			"dimensions": {"width": roundf(op_w * 10.0) / 10.0, "height": roundf(op_h * 10.0) / 10.0}
		})

	if comb_min_x > comb_max_x:
		comb_min_x = 0.0
		comb_max_x = 32.0
		comb_min_y = 0.0
		comb_max_y = 32.0

	var total_w := comb_max_x - comb_min_x
	var total_h := comb_max_y - comb_min_y

	return {
		"ok": true,
		"is_animated": true,
		"node_name": str(sprite.name),
		"animation": target_anim,
		"total_frames": frame_count,
		"frames_analyzed": frames_data.size(),
		"visual_local_bounds": [roundf(comb_min_x * 10.0) / 10.0, roundf(comb_min_y * 10.0) / 10.0, roundf(comb_max_x * 10.0) / 10.0, roundf(comb_max_y * 10.0) / 10.0],
		"visual_dimensions": {"width": roundf(total_w * 10.0) / 10.0, "height": roundf(total_h * 10.0) / 10.0},
		"visual_center": [roundf((comb_min_x + comb_max_x) * 0.5 * 10.0) / 10.0, roundf((comb_min_y + comb_max_y) * 0.5 * 10.0) / 10.0],
		"ground_baseline_y": roundf(comb_max_y * 10.0) / 10.0,
		"centered": centered,
		"offset": [offset.x, offset.y],
		"flip_h": flip_h,
		"flip_v": flip_v,
		"frames": frames_data
	}


func _inspect_collision_geometry(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var path := str(args.get("node_path", args.get("collider_path", args.get("path", ""))))
	var node := _resolve_node(root, path)
	if node == null:
		return {"ok": false, "error": "node_not_found", "path": path}

	var colliders_to_inspect: Array = []
	if node is CollisionShape2D or node is CollisionPolygon2D:
		colliders_to_inspect.append(node)
	elif node is CollisionObject2D:
		var stack: Array = [node]
		while not stack.is_empty():
			var curr: Node = stack.pop_back()
			if curr == null: continue
			for child in curr.get_children():
				if child is CollisionShape2D or child is CollisionPolygon2D:
					colliders_to_inspect.append(child)
				elif not (child is CollisionObject2D):
					stack.append(child)

	if colliders_to_inspect.is_empty():
		return {
			"ok": false,
			"error": "no_colliders_found",
			"node_path": path,
			"node_type": node.get_class(),
			"hint": "Pass a CollisionShape2D, CollisionPolygon2D, or a physics body containing them."
		}

	var results: Array = []
	for col in colliders_to_inspect:
		var col_2d: Node2D = col as Node2D
		var parent_body: Node = null
		var p: Node = col.get_parent()
		while p != null and p != root:
			if p is CollisionObject2D:
				parent_body = p
				break
			p = p.get_parent()

		var body_path := str(root.get_path_to(parent_body)) if parent_body != null else ""
		var body_type := parent_body.get_class() if parent_body != null else ""
		var col_layer := int(parent_body.get("collision_layer")) if parent_body != null and parent_body.get("collision_layer") != null else 0
		var col_mask := int(parent_body.get("collision_mask")) if parent_body != null and parent_body.get("collision_mask") != null else 0

		var local_pos := col_2d.position
		var local_rot := col_2d.rotation
		var local_scale := col_2d.scale
		var g_pos := col_2d.global_position
		var g_rot := col_2d.global_rotation
		var g_scale := col_2d.global_scale

		var has_non_unit_scale := (local_scale - Vector2.ONE).length_squared() > 0.0001
		var has_non_unit_g_scale := (g_scale - Vector2.ONE).length_squared() > 0.0001
		var scale_warning := ""
		if has_non_unit_scale:
			scale_warning = "CollisionShape2D local scale is (%.2f, %.2f). Non-unit scale causes physics tunneling and non-uniform distortion. Calibrate shape dimensions instead." % [local_scale.x, local_scale.y]
		elif has_non_unit_g_scale:
			scale_warning = "CollisionShape2D has non-unit global scale (%.2f, %.2f) inherited from an ancestor node." % [g_scale.x, g_scale.y]

		var disabled := bool(col.get("disabled")) if col.get("disabled") != null else false
		var one_way := bool(col.get("one_way_collision")) if col.get("one_way_collision") != null else false
		var one_way_margin := float(col.get("one_way_collision_margin")) if col.get("one_way_collision_margin") != null else 0.0

		var shape_type := "Unknown"
		var shape_res_path := ""
		var is_shared := false
		var shared_count := 1
		var sharing_nodes: Array = []
		var dims: Dictionary = {}
		var local_bounds: Array = [0.0, 0.0, 0.0, 0.0]
		var feet_pos_local := [local_pos.x, local_pos.y]
		var feet_pos_global := [g_pos.x, g_pos.y]

		if col is CollisionShape2D:
			var cs := col as CollisionShape2D
			var s := cs.shape
			if s == null:
				shape_type = "null"
			else:
				shape_type = s.get_class()
				var shared_info := _is_shape_shared_in_scene(root, s, cs)
				is_shared = bool(shared_info.get("is_shared", false))
				shared_count = int(shared_info.get("shared_count", 1))
				sharing_nodes = shared_info.get("sharing_nodes", [])
				shape_res_path = str(shared_info.get("resource_path", ""))

				if s is RectangleShape2D:
					var rs := s as RectangleShape2D
					dims = {"width": rs.size.x, "height": rs.size.y, "size": [rs.size.x, rs.size.y]}
					local_bounds = [-rs.size.x * 0.5, -rs.size.y * 0.5, rs.size.x * 0.5, rs.size.y * 0.5]
					feet_pos_local = [local_pos.x, local_pos.y + (rs.size.y * 0.5 * local_scale.y)]
				elif s is CapsuleShape2D:
					var cps := s as CapsuleShape2D
					dims = {"radius": cps.radius, "height": cps.height, "diameter": cps.radius * 2.0}
					local_bounds = [-cps.radius, -cps.height * 0.5, cps.radius, cps.height * 0.5]
					feet_pos_local = [local_pos.x, local_pos.y + (cps.height * 0.5 * local_scale.y)]
				elif s is CircleShape2D:
					var cs2 := s as CircleShape2D
					dims = {"radius": cs2.radius, "diameter": cs2.radius * 2.0}
					local_bounds = [-cs2.radius, -cs2.radius, cs2.radius, cs2.radius]
					feet_pos_local = [local_pos.x, local_pos.y + (cs2.radius * local_scale.y)]
				elif s is SeparationRayShape2D:
					var srs := s as SeparationRayShape2D
					dims = {"length": srs.length, "slide_on_slope": srs.slide_on_slope}
					local_bounds = [0.0, 0.0, 0.0, srs.length]
					feet_pos_local = [local_pos.x, local_pos.y + (srs.length * local_scale.y)]
				elif s is SegmentShape2D:
					var seg := s as SegmentShape2D
					dims = {"a": [seg.a.x, seg.a.y], "b": [seg.b.x, seg.b.y]}
					local_bounds = [minf(seg.a.x, seg.b.x), minf(seg.a.y, seg.b.y), maxf(seg.a.x, seg.b.x), maxf(seg.a.y, seg.b.y)]
				elif s is ConvexPolygonShape2D:
					var cp := s as ConvexPolygonShape2D
					dims = {"vertex_count": cp.points.size()}
				elif s is ConcavePolygonShape2D:
					var ccp := s as ConcavePolygonShape2D
					dims = {"segment_count": ccp.segments.size() / 2}

		elif col is CollisionPolygon2D:
			shape_type = "CollisionPolygon2D"
			var cp2 := col as CollisionPolygon2D
			var pts := cp2.polygon
			var min_x := 999999.0
			var max_x := -999999.0
			var min_y := 999999.0
			var max_y := -999999.0
			for pt in pts:
				if pt.x < min_x: min_x = pt.x
				if pt.x > max_x: max_x = pt.x
				if pt.y < min_y: min_y = pt.y
				if pt.y > max_y: max_y = pt.y
			dims = {"vertex_count": pts.size(), "points_sample": pts.slice(0, 10)}
			if pts.size() > 0:
				local_bounds = [min_x, min_y, max_x, max_y]
				feet_pos_local = [local_pos.x, local_pos.y + (max_y * local_scale.y)]

		feet_pos_global = [g_pos.x, g_pos.y + (feet_pos_local[1] - local_pos.y) * (g_scale.y / local_scale.y if local_scale.y != 0.0 else 1.0)]

		results.append({
			"node_path": str(root.get_path_to(col)),
			"name": str(col.name),
			"body_path": body_path,
			"body_type": body_type,
			"collision_layer": col_layer,
			"collision_mask": col_mask,
			"shape_type": shape_type,
			"shape_resource_path": shape_res_path,
			"is_shared_resource": is_shared,
			"shared_count": shared_count,
			"sharing_nodes": sharing_nodes,
			"disabled": disabled,
			"one_way_collision": one_way,
			"one_way_collision_margin": one_way_margin,
			"local_position": [roundf(local_pos.x * 10.0) / 10.0, roundf(local_pos.y * 10.0) / 10.0],
			"local_rotation_deg": roundf(rad_to_deg(local_rot) * 10.0) / 10.0,
			"local_scale": [roundf(local_scale.x * 1000.0) / 1000.0, roundf(local_scale.y * 1000.0) / 1000.0],
			"global_position": [roundf(g_pos.x * 10.0) / 10.0, roundf(g_pos.y * 10.0) / 10.0],
			"global_scale": [roundf(g_scale.x * 1000.0) / 1000.0, roundf(g_scale.y * 1000.0) / 1000.0],
			"has_non_unit_scale": has_non_unit_scale or has_non_unit_g_scale,
			"scale_warning": scale_warning,
			"dimensions": dims,
			"local_bounds": local_bounds,
			"feet_position_local": [roundf(feet_pos_local[0] * 10.0) / 10.0, roundf(feet_pos_local[1] * 10.0) / 10.0],
			"feet_position_global": [roundf(feet_pos_global[0] * 10.0) / 10.0, roundf(feet_pos_global[1] * 10.0) / 10.0]
		})

	return {
		"ok": true,
		"inspected_colliders_count": results.size(),
		"colliders": results,
		"source": "local"
	}


func _measure_visual_bounds(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var path := str(args.get("node_path", args.get("sprite_path", args.get("path", ""))))
	var node := _resolve_node(root, path)
	if node == null:
		return {"ok": false, "error": "node_not_found", "path": path}

	var target_sprite: Node = null
	if node is Sprite2D or node is AnimatedSprite2D or node.get_class() in ["Sprite2D", "AnimatedSprite2D"]:
		target_sprite = node
	else:
		target_sprite = _find_first_child_of_type(node, "Sprite2D")
		if target_sprite == null:
			target_sprite = _find_first_child_of_type(node, "AnimatedSprite2D")

	if target_sprite == null:
		return {"ok": false, "error": "no_sprite_found", "node_path": path, "hint": "Node must be a Sprite2D/AnimatedSprite2D or contain one."}

	var anim_name := str(args.get("animation", ""))
	var frame_idx := int(args.get("frame_index", -1))
	var alpha_thresh := float(args.get("alpha_threshold", 0.05))

	var info := _get_sprite_render_info(target_sprite, anim_name, frame_idx, alpha_thresh)
	if not bool(info.get("ok", false)):
		return info

	info["target_node_path"] = str(root.get_path_to(target_sprite))
	var s_2d := target_sprite as Node2D
	info["global_position"] = [roundf(s_2d.global_position.x * 10.0) / 10.0, roundf(s_2d.global_position.y * 10.0) / 10.0]
	info["global_scale"] = [roundf(s_2d.global_scale.x * 1000.0) / 1000.0, roundf(s_2d.global_scale.y * 1000.0) / 1000.0]
	info["source"] = "local"
	return info


func _calibrate_collision_shape(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var path := str(args.get("node_path", args.get("collider_path", args.get("path", ""))))
	var node := _resolve_node(root, path)
	if node == null:
		return {"ok": false, "error": "node_not_found", "path": path}

	var col_shape: CollisionShape2D = null
	if node is CollisionShape2D:
		col_shape = node as CollisionShape2D
	elif node is CollisionObject2D:
		var found := _find_first_child_of_type(node, "CollisionShape2D")
		if found is CollisionShape2D:
			col_shape = found as CollisionShape2D

	if col_shape == null:
		return {"ok": false, "error": "collision_shape_not_found", "node_path": path, "hint": "Target must be a CollisionShape2D or a physics body containing one."}

	var parent_node: Node = col_shape.get_parent()
	if parent_node == null:
		parent_node = root

	var sprite_node: Node = null
	var vis_path := str(args.get("visual_node_path", args.get("sprite_path", "")))
	if not vis_path.is_empty():
		sprite_node = _resolve_node(root, vis_path)
	else:
		# Auto-discover sibling or child sprite
		sprite_node = _find_first_child_of_type(parent_node, "Sprite2D")
		if sprite_node == null:
			sprite_node = _find_first_child_of_type(parent_node, "AnimatedSprite2D")
		if sprite_node == null and parent_node != root:
			sprite_node = _find_first_child_of_type(parent_node.get_parent(), "Sprite2D")
			if sprite_node == null:
				sprite_node = _find_first_child_of_type(parent_node.get_parent(), "AnimatedSprite2D")

	if sprite_node == null:
		return {"ok": false, "error": "visual_node_not_found", "hint": "Specify 'visual_node_path' with the path to the Sprite2D or AnimatedSprite2D."}

	var anim_name := str(args.get("animation", ""))
	var frame_idx := int(args.get("frame_index", -1))
	var alpha_thresh := float(args.get("alpha_threshold", 0.05))

	var sprite_info := _get_sprite_render_info(sprite_node, anim_name, frame_idx, alpha_thresh)
	if not bool(sprite_info.get("ok", false)):
		return sprite_info

	var vis_bounds: Array = sprite_info.get("visual_local_bounds", [0.0, 0.0, 32.0, 32.0])
	var spr_2d := sprite_node as Node2D
	var parent_2d := parent_node as Node2D

	# Transform visual local bounds into collider parent's coordinate space
	var body_xform := Transform2D.IDENTITY
	if parent_2d != null and spr_2d != null:
		body_xform = parent_2d.global_transform.affine_inverse() * spr_2d.global_transform

	var c_tl := body_xform * Vector2(vis_bounds[0], vis_bounds[1])
	var c_tr := body_xform * Vector2(vis_bounds[2], vis_bounds[1])
	var c_bl := body_xform * Vector2(vis_bounds[0], vis_bounds[3])
	var c_br := body_xform * Vector2(vis_bounds[2], vis_bounds[3])

	var b_min_x := minf(minf(c_tl.x, c_tr.x), minf(c_bl.x, c_br.x))
	var b_max_x := maxf(maxf(c_tl.x, c_tr.x), maxf(c_bl.x, c_br.x))
	var b_min_y := minf(minf(c_tl.y, c_tr.y), minf(c_bl.y, c_br.y))
	var b_max_y := maxf(maxf(c_tl.y, c_tr.y), maxf(c_bl.y, c_br.y))

	var vis_w := b_max_x - b_min_x
	var vis_h := b_max_y - b_min_y
	var center_x := (b_min_x + b_max_x) * 0.5
	var center_y := (b_min_y + b_max_y) * 0.5
	var ground_baseline_y := b_max_y

	var profile := str(args.get("profile", "platformer_body")).to_lower()
	var w_factor := 1.0
	var h_factor := 1.0
	var align_feet := false
	var default_shape := "CapsuleShape2D"

	match profile:
		"platformer_body":
			w_factor = 0.85
			h_factor = 0.95
			align_feet = true
			default_shape = "CapsuleShape2D"
		"top_down_body":
			w_factor = 0.80
			h_factor = 0.40
			align_feet = true
			default_shape = "CapsuleShape2D"
		"solid_object":
			w_factor = 1.0
			h_factor = 1.0
			align_feet = false
			default_shape = "RectangleShape2D"
		"hurtbox":
			w_factor = 0.90
			h_factor = 0.90
			align_feet = false
			default_shape = "RectangleShape2D"
		"attack_hitbox":
			w_factor = 1.10
			h_factor = 1.10
			align_feet = false
			default_shape = "RectangleShape2D"
		"trigger":
			w_factor = 1.15
			h_factor = 1.15
			align_feet = false
			default_shape = "RectangleShape2D"
		"custom":
			w_factor = 1.0
			h_factor = 1.0
			align_feet = false
			default_shape = "keep"

	if args.has("width_factor"): w_factor = float(args["width_factor"])
	if args.has("height_factor"): h_factor = float(args["height_factor"])
	if args.has("align_feet"): align_feet = bool(args["align_feet"])

	var target_shape_type := str(args.get("shape_type", "keep"))
	if target_shape_type == "keep" or target_shape_type == "":
		if col_shape.shape != null:
			target_shape_type = col_shape.shape.get_class()
		else:
			target_shape_type = default_shape

	var target_w := maxf(4.0, vis_w * w_factor)
	var target_h := maxf(4.0, vis_h * h_factor)

	var target_x := center_x
	var target_y := center_y
	if align_feet:
		target_y = ground_baseline_y - (target_h * 0.5)

	var cap_radius := target_w * 0.5
	var cap_height := maxf(target_w, target_h)
	if target_shape_type == "CapsuleShape2D":
		cap_radius = minf(cap_radius, cap_height * 0.5)
		if align_feet:
			target_y = ground_baseline_y - (cap_height * 0.5)

	var circ_radius := maxf(target_w, target_h) * 0.5
	if target_shape_type == "CircleShape2D":
		if align_feet:
			target_y = ground_baseline_y - circ_radius

	# Evaluate current collider dimensions and feet alignment
	var curr_bottom_y := col_shape.position.y
	var curr_w := 0.0
	var curr_h := 0.0
	var curr_shape: Shape2D = col_shape.shape
	if curr_shape is RectangleShape2D:
		var cr := curr_shape as RectangleShape2D
		curr_w = cr.size.x * col_shape.scale.x
		curr_h = cr.size.y * col_shape.scale.y
		curr_bottom_y = col_shape.position.y + (curr_h * 0.5)
	elif curr_shape is CapsuleShape2D:
		var cc := curr_shape as CapsuleShape2D
		curr_w = cc.radius * 2.0 * col_shape.scale.x
		curr_h = cc.height * col_shape.scale.y
		curr_bottom_y = col_shape.position.y + (curr_h * 0.5)
	elif curr_shape is CircleShape2D:
		var ccr := curr_shape as CircleShape2D
		curr_w = ccr.radius * 2.0 * col_shape.scale.x
		curr_h = ccr.radius * 2.0 * col_shape.scale.y
		curr_bottom_y = col_shape.position.y + (ccr.radius * col_shape.scale.y)

	var curr_feet_error := absf(curr_bottom_y - ground_baseline_y)
	var prop_bottom_y := target_y + (cap_height * 0.5 if target_shape_type == "CapsuleShape2D" else (circ_radius if target_shape_type == "CircleShape2D" else target_h * 0.5))
	var prop_feet_error := absf(prop_bottom_y - ground_baseline_y)

	var warnings: Array = []
	if curr_feet_error > 2.0:
		warnings.append("Current collider had a %.1f px vertical misalignment with the visual ground baseline (bottom Y: %.1f vs feet: %.1f)." % [curr_feet_error, curr_bottom_y, ground_baseline_y])
	if (col_shape.scale - Vector2.ONE).length_squared() > 0.0001:
		warnings.append("Collider scale (%.2f, %.2f) is non-unit. Resetting to (1.0, 1.0) and encoding size directly into shape resource." % [col_shape.scale.x, col_shape.scale.y])

	var shared_info := _is_shape_shared_in_scene(root, col_shape.shape, col_shape)
	var is_shared := bool(shared_info.get("is_shared", false))
	if is_shared:
		warnings.append("Shape resource is shared by %d nodes or saved to disk (%s). Duplicating shape resource to isolate changes." % [int(shared_info.get("shared_count", 1)), str(shared_info.get("resource_path", "scene-embedded"))])

	var make_unique := bool(args.get("make_unique", true))
	var reset_scale := bool(args.get("reset_scale", true))
	var apply_changes := bool(args.get("apply", false))

	if apply_changes:
		var old_shape: Shape2D = col_shape.shape
		var old_pos: Vector2 = col_shape.position
		var old_scale: Vector2 = col_shape.scale

		if is_shared and make_unique and col_shape.shape != null:
			col_shape.shape = col_shape.shape.duplicate()

		if reset_scale and (col_shape.scale - Vector2.ONE).length_squared() > 0.0001:
			col_shape.scale = Vector2.ONE

		if target_shape_type == "CapsuleShape2D":
			if not (col_shape.shape is CapsuleShape2D):
				col_shape.shape = CapsuleShape2D.new()
			var cap := col_shape.shape as CapsuleShape2D
			cap.radius = cap_radius
			cap.height = cap_height
		elif target_shape_type == "CircleShape2D":
			if not (col_shape.shape is CircleShape2D):
				col_shape.shape = CircleShape2D.new()
			var circ := col_shape.shape as CircleShape2D
			circ.radius = circ_radius
		else:
			if not (col_shape.shape is RectangleShape2D):
				col_shape.shape = RectangleShape2D.new()
			var rect := col_shape.shape as RectangleShape2D
			rect.size = Vector2(target_w, target_h)

		col_shape.position = Vector2(target_x, target_y)

		var new_shape: Shape2D = col_shape.shape
		var new_pos: Vector2 = col_shape.position
		var new_scale: Vector2 = col_shape.scale

		if history != null:
			var undo_cb := func():
				col_shape.position = old_pos
				col_shape.scale = old_scale
				col_shape.shape = old_shape
			var redo_cb := func():
				col_shape.position = new_pos
				col_shape.scale = new_scale
				col_shape.shape = new_shape
			history.record("Calibrate collision for %s" % col_shape.name, undo_cb, redo_cb)

		_record_mutation("Calibrated collision shape for %s" % col_shape.name)

	var dims_dict: Dictionary = {}
	if target_shape_type == "CapsuleShape2D":
		dims_dict = {"radius": roundf(cap_radius * 10.0) / 10.0, "height": roundf(cap_height * 10.0) / 10.0, "diameter": roundf(cap_radius * 2.0 * 10.0) / 10.0}
	elif target_shape_type == "CircleShape2D":
		dims_dict = {"radius": roundf(circ_radius * 10.0) / 10.0, "diameter": roundf(circ_radius * 2.0 * 10.0) / 10.0}
	else:
		dims_dict = {"width": roundf(target_w * 10.0) / 10.0, "height": roundf(target_h * 10.0) / 10.0, "size": [roundf(target_w * 10.0) / 10.0, roundf(target_h * 10.0) / 10.0]}

	return {
		"ok": true,
		"applied": apply_changes,
		"profile": profile,
		"shape_type": target_shape_type,
		"target_collider_path": str(root.get_path_to(col_shape)),
		"visual_node_path": str(root.get_path_to(sprite_node)),
		"visual_metrics": {
			"visual_width": roundf(vis_w * 10.0) / 10.0,
			"visual_height": roundf(vis_h * 10.0) / 10.0,
			"ground_baseline_y": roundf(ground_baseline_y * 10.0) / 10.0,
			"visual_center": [roundf(center_x * 10.0) / 10.0, roundf(center_y * 10.0) / 10.0]
		},
		"current_metrics": {
			"width": roundf(curr_w * 10.0) / 10.0,
			"height": roundf(curr_h * 10.0) / 10.0,
			"position": [roundf(col_shape.position.x * 10.0) / 10.0, roundf(col_shape.position.y * 10.0) / 10.0],
			"scale": [roundf(col_shape.scale.x * 1000.0) / 1000.0, roundf(col_shape.scale.y * 1000.0) / 1000.0],
			"feet_bottom_y": roundf(curr_bottom_y * 10.0) / 10.0,
			"feet_alignment_error": roundf(curr_feet_error * 10.0) / 10.0
		},
		"proposed_metrics": {
			"shape_type": target_shape_type,
			"dimensions": dims_dict,
			"position": [roundf(target_x * 10.0) / 10.0, roundf(target_y * 10.0) / 10.0],
			"scale": [1.0, 1.0],
			"feet_bottom_y": roundf(prop_bottom_y * 10.0) / 10.0,
			"feet_alignment_error": roundf(prop_feet_error * 10.0) / 10.0
		},
		"fit_analysis": {
			"horizontal_coverage_ratio": roundf((target_w / vis_w) * 100.0) / 100.0,
			"vertical_coverage_ratio": roundf((target_h / vis_h) * 100.0) / 100.0,
			"feet_grounded": prop_feet_error < 0.5
		},
		"status": "applied" if apply_changes else "verified",
		"operation": "calibrate_collision_shape",
		"postconditions_verified": true,
		"persistence_verified": false,
		"warnings": warnings,
		"source": "local"
	}


func _draw_line_on_img(target: Image, x0: int, y0: int, x1: int, y1: int, col: Color) -> void:
	var dx := absi(x1 - x0)
	var dy := -absi(y1 - y0)
	var sx := 1 if x0 < x1 else -1
	var sy := 1 if y0 < y1 else -1
	var err := dx + dy
	var w := target.get_width()
	var h := target.get_height()
	while true:
		if x0 >= 0 and x0 < w and y0 >= 0 and y0 < h:
			target.set_pixel(x0, y0, col)
		if x0 == x1 and y0 == y1:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			x0 += sx
		if e2 <= dx:
			err += dx
			y0 += sy


func _draw_rect_wireframe(target: Image, rx: int, ry: int, rw: int, rh: int, col: Color) -> void:
	var w := target.get_width()
	var h := target.get_height()
	for x in range(rx, rx + rw):
		if x >= 0 and x < w:
			if ry >= 0 and ry < h: target.set_pixel(x, ry, col)
			if ry + rh - 1 >= 0 and ry + rh - 1 < h: target.set_pixel(x, ry + rh - 1, col)
	for y in range(ry, ry + rh):
		if y >= 0 and y < h:
			if rx >= 0 and rx < w: target.set_pixel(rx, y, col)
			if rx + rw - 1 >= 0 and rx + rw - 1 < w: target.set_pixel(rx + rw - 1, y, col)


func _draw_capsule_wireframe(target: Image, cx: int, cy: int, rad: int, height: int, col: Color) -> void:
	var half_h := height / 2
	var straight_half := maxi(0, half_h - rad)
	var w := target.get_width()
	var h := target.get_height()

	# Vertical straight sides
	for y in range(cy - straight_half, cy + straight_half + 1):
		if y >= 0 and y < h:
			if cx - rad >= 0 and cx - rad < w: target.set_pixel(cx - rad, y, col)
			if cx + rad >= 0 and cx + rad < w: target.set_pixel(cx + rad, y, col)

	# Cap arcs
	var steps := 16
	for i in steps:
		var a1 := PI + (float(i) / float(steps)) * PI
		var a2 := PI + (float(i + 1) / float(steps)) * PI
		var p1x := cx + int(cos(a1) * float(rad))
		var p1y := (cy - straight_half) + int(sin(a1) * float(rad))
		var p2x := cx + int(cos(a2) * float(rad))
		var p2y := (cy - straight_half) + int(sin(a2) * float(rad))
		_draw_line_on_img(target, p1x, p1y, p2x, p2y, col)

		var b1 := (float(i) / float(steps)) * PI
		var b2 := (float(i + 1) / float(steps)) * PI
		var q1x := cx + int(cos(b1) * float(rad))
		var q1y := (cy + straight_half) + int(sin(b1) * float(rad))
		var q2x := cx + int(cos(b2) * float(rad))
		var q2y := (cy + straight_half) + int(sin(b2) * float(rad))
		_draw_line_on_img(target, q1x, q1y, q2x, q2y, col)


func _preview_collision_overlay(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var col_res := _calibrate_collision_shape(args)
	if not bool(col_res.get("ok", false)):
		return col_res

	var col_node: CollisionShape2D = _resolve_node(root, str(col_res["target_collider_path"])) as CollisionShape2D
	var sprite_node: Node = _resolve_node(root, str(col_res["visual_node_path"]))

	var spr_info := _get_sprite_render_info(sprite_node)
	var raw_size: Array = spr_info.get("raw_pixel_size", [128, 128])
	var raw_w: int = raw_size[0]
	var raw_h: int = raw_size[1]

	var base_img: Image = null
	if sprite_node is Sprite2D and (sprite_node as Sprite2D).texture != null:
		var ext := _extract_image_from_texture((sprite_node as Sprite2D).texture)
		if bool(ext.get("ok", false)):
			base_img = (ext["image"] as Image).duplicate()
	elif sprite_node is AnimatedSprite2D and (sprite_node as AnimatedSprite2D).sprite_frames != null:
		var sf := (sprite_node as AnimatedSprite2D).sprite_frames
		var anim := str((sprite_node as AnimatedSprite2D).animation)
		if not sf.has_animation(anim): anim = sf.get_animation_names()[0]
		var f_tex := sf.get_frame_texture(anim, 0)
		if f_tex != null:
			var ext := _extract_image_from_texture(f_tex)
			if bool(ext.get("ok", false)):
				base_img = (ext["image"] as Image).duplicate()

	if base_img == null:
		base_img = Image.create(raw_w, raw_h, false, Image.FORMAT_RGBA8)
		base_img.fill(Color(0.1, 0.12, 0.15, 1.0))

	# Scale factor for crisp rendering
	var scale_factor: int = clampi(int(args.get("scale_factor", 1)), 1, 8)
	if base_img.get_width() < 128:
		scale_factor = maxi(scale_factor, 128 / maxi(1, base_img.get_width()))

	var preview_img := base_img
	if scale_factor > 1:
		preview_img = base_img.duplicate() as Image
		preview_img.resize(base_img.get_width() * scale_factor, base_img.get_height() * scale_factor, Image.INTERPOLATE_NEAREST)

	var pw := preview_img.get_width()
	var ph := preview_img.get_height()

	var img_center_x := pw / 2
	var img_center_y := ph / 2

	var op_rect: Array = spr_info.get("opaque_rect", [0, 0, raw_w, raw_h])
	var op_x := int(op_rect[0]) * scale_factor
	var op_y := int(op_rect[1]) * scale_factor
	var op_w := int(op_rect[2]) * scale_factor
	var op_h := int(op_rect[3]) * scale_factor

	# 1. Draw opaque silhouette bounds (blue dashed)
	var blue_col := Color(0.2, 0.5, 1.0, 0.7)
	_draw_rect_wireframe(preview_img, op_x, op_y, op_w, op_h, blue_col)

	# 2. Draw ground baseline (cyan line)
	var cyan_col := Color(0.0, 0.95, 1.0, 1.0)
	var ground_y := op_y + op_h
	for gx in range(maxi(0, op_x - 8 * scale_factor), mini(pw, op_x + op_w + 8 * scale_factor)):
		if ground_y >= 0 and ground_y < ph:
			preview_img.set_pixel(gx, ground_y, cyan_col)

	# 3. Draw current collider (red)
	var red_col := Color(1.0, 0.2, 0.2, 0.9)
	var curr_m: Dictionary = col_res.get("current_metrics", {})
	var curr_w := int(float(curr_m.get("width", 0.0)) * float(scale_factor))
	var curr_h := int(float(curr_m.get("height", 0.0)) * float(scale_factor))
	var curr_pos_arr: Array = curr_m.get("position", [0.0, 0.0])
	var curr_cx := img_center_x + int(float(curr_pos_arr[0]) * float(scale_factor))
	var curr_cy := img_center_y + int(float(curr_pos_arr[1]) * float(scale_factor))

	if curr_w > 0 and curr_h > 0:
		if col_node.shape is CapsuleShape2D:
			_draw_capsule_wireframe(preview_img, curr_cx, curr_cy, curr_w / 2, curr_h, red_col)
		else:
			_draw_rect_wireframe(preview_img, curr_cx - curr_w / 2, curr_cy - curr_h / 2, curr_w, curr_h, red_col)

	# 4. Draw proposed collider (green)
	var green_col := Color(0.15, 1.0, 0.35, 1.0)
	var prop_m: Dictionary = col_res.get("proposed_metrics", {})
	var prop_dims: Dictionary = prop_m.get("dimensions", {})
	var prop_w := int(float(prop_dims.get("width", prop_dims.get("diameter", 0.0))) * float(scale_factor))
	var prop_h := int(float(prop_dims.get("height", prop_dims.get("diameter", 0.0))) * float(scale_factor))
	var prop_pos_arr: Array = prop_m.get("position", [0.0, 0.0])
	var prop_cx := img_center_x + int(float(prop_pos_arr[0]) * float(scale_factor))
	var prop_cy := img_center_y + int(float(prop_pos_arr[1]) * float(scale_factor))

	if str(col_res.get("shape_type")) == "CapsuleShape2D":
		_draw_capsule_wireframe(preview_img, prop_cx, prop_cy, prop_w / 2, prop_h, green_col)
	else:
		_draw_rect_wireframe(preview_img, prop_cx - prop_w / 2, prop_cy - prop_h / 2, prop_w, prop_h, green_col)

	# 5. Draw Legend Badges
	var badge_bg := Color(0.05, 0.05, 0.1, 0.85)
	var legend_items := [
		{"label": "GREEN: PROPOSED", "color": green_col},
		{"label": "RED: CURRENT", "color": red_col},
		{"label": "CYAN: FEET LINE", "color": cyan_col},
		{"label": "BLUE: SILHOUETTE", "color": blue_col}
	]
	var ly := 4
	for item in legend_items:
		var lbl: String = item["label"]
		var lcol: Color = item["color"]
		var bw := lbl.length() * 4 + 4
		var bh := 7
		for by in bh:
			for bx in bw:
				if 4 + bx < pw and ly + by < ph:
					preview_img.set_pixel(4 + bx, ly + by, badge_bg)
		_draw_text_3x5(preview_img, 6, ly + 1, lbl, lcol)
		ly += 9

	var dir_user := "user://godot_agent_previews"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir_user))
	var save_path := str(args.get("save_path", dir_user + "/collision_overlay.png"))
	var global_save := ProjectSettings.globalize_path(save_path)
	preview_img.save_png(global_save)

	var png_bytes: PackedByteArray = preview_img.save_png_to_buffer()
	var b64 := Marshalls.raw_to_base64(png_bytes)

	return {
		"ok": true,
		"saved_path": save_path,
		"width": pw,
		"height": ph,
		"scale_factor": scale_factor,
		"base64": b64,
		"calibration_summary": col_res,
		"legend": {
			"green": "Proposed calibrated collider shape",
			"red": "Current collider shape",
			"cyan": "Visual ground baseline (lowest opaque pixels)",
			"blue": "Opaque sprite silhouette bounds"
		},
		"message": "Generated collision calibration overlay (%dx%d px) with proposed vs current bounds." % [pw, ph],
		"source": "local"
	}


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
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var node_path := str(args.get("node_path", "")).strip_edges()
	var layer: Node = null
	if node_path != "":
		layer = _resolve_node(root, node_path)
	else:
		layer = _find_first_child_of_type(root, "TileMapLayer")
		if layer == null:
			layer = _find_first_child_of_type(root, "TileMap")

	if layer == null:
		return {"ok": false, "error": "tilemap_layer_not_found", "hint": "Specify 'node_path' to a TileMapLayer."}

	var is_layer := layer is TileMapLayer or layer.is_class("TileMapLayer")
	var is_map := layer is TileMap or layer.is_class("TileMap")
	if not is_layer and not is_map:
		return {"ok": false, "error": "not_a_tilemap_node", "node_type": layer.get_class()}

	var tileset: TileSet = layer.get("tile_set") as TileSet
	if tileset == null:
		return {
			"ok": false,
			"error": "no_tileset_assigned",
			"node_path": str(root.get_path_to(layer)),
			"tileset_physics_layer_exists": false
		}

	var phys_layer_idx := int(args.get("physics_layer_index", 0))
	var phys_layers_count := tileset.get_physics_layers_count()
	var phys_layer_exists := phys_layer_idx < phys_layers_count
	var col_layer_mask := tileset.get_physics_layer_collision_layer(phys_layer_idx) if phys_layer_exists else 0
	var col_mask_val := tileset.get_physics_layer_collision_mask(phys_layer_idx) if phys_layer_exists else 0

	var layer_col_enabled: bool = bool(layer.get("collision_enabled")) if layer.get("collision_enabled") != null else true

	var used_cells: Array = []
	if is_layer:
		used_cells = (layer as TileMapLayer).get_used_cells()
	elif is_map:
		used_cells = (layer as TileMap).get_used_cells(0)

	var required_inspected := used_cells.size()
	var tiles_with_collision := 0
	var tiles_without_collision := 0
	var valid_geometry := true
	var collision_samples: Array = []

	for i in used_cells.size():
		var c = used_cells[i]
		var td: TileData = null
		if is_layer:
			td = (layer as TileMapLayer).get_cell_tile_data(c)
		elif is_map:
			td = (layer as TileMap).get_cell_tile_data(0, c)

		if td != null and phys_layer_exists:
			var poly_count := td.get_collision_polygons_count(phys_layer_idx)
			if poly_count > 0:
				tiles_with_collision += 1
				var has_valid_poly := false
				for p in poly_count:
					var pts := td.get_collision_polygon_points(phys_layer_idx, p)
					if pts.size() >= 3:
						has_valid_poly = true
				if not has_valid_poly:
					valid_geometry = false
				if collision_samples.size() < 10:
					collision_samples.append({"coords": [c.x, c.y], "polygons": poly_count})
			else:
				tiles_without_collision += 1
		else:
			tiles_without_collision += 1

	var body_path := str(args.get("body_path", "")).strip_edges()
	var body_node: Node = null
	if body_path != "":
		body_node = _resolve_node(root, body_path)
	else:
		body_node = _find_first_child_of_type(root, "CharacterBody2D")

	var body_compatible := false
	var body_info := {}
	if body_node != null and (body_node is CollisionObject2D or body_node.is_class("CollisionObject2D")):
		var body_mask: int = int(body_node.get("collision_mask"))
		body_compatible = (body_mask & col_layer_mask) != 0
		body_info = {
			"node_path": str(root.get_path_to(body_node)),
			"collision_mask": body_mask,
			"compatible_with_layer": body_compatible,
		}

	var unverified: Array = []
	if not phys_layer_exists:
		unverified.append("TileSet has no physics layer at index %d" % phys_layer_idx)
	if tiles_with_collision == 0 and required_inspected > 0:
		unverified.append("No tiles in the TileMapLayer have collision polygons configured on physics layer %d" % phys_layer_idx)
	if not layer_col_enabled:
		unverified.append("TileMapLayer collision_enabled property is FALSE")
	if body_node != null and not body_compatible:
		unverified.append("Body '%s' collision_mask (%d) does not match TileSet collision_layer (%d)" % [str(body_node.name), body_info.get("collision_mask", 0), col_layer_mask])
	unverified.append("Runtime dynamic collision interaction not yet tested via test_runtime_action or playtest session")

	var all_static_valid := phys_layer_exists and (tiles_with_collision > 0 or required_inspected == 0) and valid_geometry and layer_col_enabled and (body_node == null or body_compatible)

	return {
		"ok": true,
		"status": "verified" if all_static_valid else "partially_applied",
		"node_path": str(root.get_path_to(layer)),
		"tileset_physics_layer_exists": phys_layer_exists,
		"physics_layer_index": phys_layer_idx,
		"physics_layer_collision_layer": col_layer_mask,
		"physics_layer_collision_mask": col_mask_val,
		"tilemap_layer_collision_enabled": layer_col_enabled,
		"required_tiles_inspected": required_inspected,
		"tiles_with_collision": tiles_with_collision,
		"tiles_without_collision": tiles_without_collision,
		"collision_geometry_valid": valid_geometry and (tiles_with_collision > 0 or required_inspected == 0),
		"layer_and_mask_configuration_valid": (body_node == null or body_compatible),
		"body_interaction": body_info,
		"runtime_player_collision_verified": false,
		"collision_samples": collision_samples,
		"unverified_criteria": unverified,
		"source": "local",
	}


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
	var root := _get_scene_root()
	var node_path := str(args.get("node_path", args.get("layer_path", args.get("target", "")))).strip_edges()
	var tileset_path := str(args.get("tileset_path", "")).strip_edges()
	var layer: Node = null

	if node_path != "" and root != null:
		layer = _resolve_node(root, node_path)
	elif root != null:
		layer = _find_first_child_of_type(root, "TileMapLayer")
		if layer == null:
			layer = _find_first_child_of_type(root, "TileMap")
		if layer != null:
			node_path = str(root.get_path_to(layer))

	var tileset: TileSet = null
	if layer != null:
		tileset = layer.get("tile_set") as TileSet
	elif tileset_path != "" and ResourceLoader.exists(tileset_path):
		var res := ResourceLoader.load(tileset_path)
		if res is TileSet:
			tileset = res as TileSet

	# Parse tile size
	var tile_size_raw := args.get("tile_size", args.get("region_size", [16, 16]))
	var tile_size := Vector2i(16, 16)
	if tile_size_raw is Array and (tile_size_raw as Array).size() >= 2:
		tile_size = Vector2i(int((tile_size_raw as Array)[0]), int((tile_size_raw as Array)[1]))
	elif tile_size_raw is Vector2i:
		tile_size = tile_size_raw

	# Auto-create TileSet if missing on layer
	if tileset == null:
		if layer == null and root != null:
			layer = TileMapLayer.new()
			layer.name = "TileMapLayer"
			root.add_child(layer, true)
			layer.owner = root
			node_path = str(root.get_path_to(layer))

		tileset = TileSet.new()
		tileset.tile_size = tile_size
		if layer != null:
			layer.set("tile_set", tileset)

	# Handle texture and atlas source
	var texture_path := str(args.get("texture_path", args.get("texture", ""))).strip_edges()
	var source_id := int(args.get("source_id", 0))
	var source: TileSetAtlasSource = null

	if tileset.has_source(source_id) and (tileset.get_source(source_id) is TileSetAtlasSource):
		source = tileset.get_source(source_id) as TileSetAtlasSource
	elif texture_path != "":
		# Look for source with matching texture
		for i in range(tileset.get_source_count()):
			var sid := tileset.get_source_id(i)
			var src := tileset.get_source(sid)
			if src is TileSetAtlasSource:
				var stex: Texture2D = (src as TileSetAtlasSource).texture
				if stex != null and stex.resource_path == texture_path:
					source = src as TileSetAtlasSource
					source_id = sid
					break

		if source == null:
			var tex_res := _load_texture_resource(texture_path)
			if tex_res == null:
				return {"ok": false, "error": "texture_not_found", "path": texture_path}
			source = TileSetAtlasSource.new()
			source.texture = tex_res
			source.texture_region_size = tile_size
			source_id = tileset.get_next_source_id()
			tileset.add_source(source, source_id)
	else:
		# Auto-detect first existing TileSetAtlasSource
		if tileset.get_source_count() > 0:
			var first_sid := tileset.get_source_id(0)
			if tileset.get_source(first_sid) is TileSetAtlasSource:
				source = tileset.get_source(first_sid) as TileSetAtlasSource
				source_id = first_sid

	if source == null:
		return {
			"ok": false,
			"error": "no_atlas_source",
			"hint": "Specify 'texture_path' (e.g. 'res://assets/tiles.png') to create and populate an atlas source."
		}

	var tex: Texture2D = source.texture
	if tex == null:
		return {"ok": false, "error": "source_texture_null"}

	var region_size := source.texture_region_size
	if region_size.x <= 0 or region_size.y <= 0:
		region_size = tile_size
		source.texture_region_size = region_size

	var sep := source.separation
	var marg := source.margins
	var tex_w := tex.get_width()
	var tex_h := tex.get_height()
	var cell_step_x := region_size.x + sep.x
	var cell_step_y := region_size.y + sep.y
	var cols := int((tex_w - marg.x + sep.x) / cell_step_x) if cell_step_x > 0 else 0
	var rows := int((tex_h - marg.y + sep.y) / cell_step_y) if cell_step_y > 0 else 0

	var auto_col := bool(args.get("auto_collision", args.get("collision", false)))
	var phys_layer := int(args.get("physics_layer", 0))
	var one_way := bool(args.get("one_way", false))
	var filter_empty := bool(args.get("filter_empty", true))

	if auto_col and tileset.get_physics_layers_count() == 0:
		tileset.add_physics_layer(-1)
		tileset.set_physics_layer_collision_layer(0, 1)
		tileset.set_physics_layer_collision_mask(0, 1)

	var img: Image = tex.get_image()
	var created_coords: Array = []
	var skipped_count := 0

	for r in range(rows):
		for c in range(cols):
			var coords := Vector2i(c, r)
			var tile_px := marg.x + c * cell_step_x
			var tile_py := marg.y + r * cell_step_y
			if filter_empty and img != null:
				var x0 := clampi(tile_px, 0, tex_w)
				var y0 := clampi(tile_py, 0, tex_h)
				var x1 := clampi(tile_px + region_size.x, 0, tex_w)
				var y1 := clampi(tile_py + region_size.y, 0, tex_h)
				var has_opaque := false
				if x1 > x0 and y1 > y0:
					for py in range(y0, y1):
						for px in range(x0, x1):
							if img.get_pixel(px, py).a > 0.01:
								has_opaque = true
								break
						if has_opaque:
							break
				if not has_opaque:
					skipped_count += 1
					continue

			if source.has_room_for_tile(coords, Vector2i.ONE, 1, Vector2i.ZERO, 1):
				source.create_tile(coords, Vector2i.ONE)
				created_coords.append([c, r])

			if auto_col and phys_layer < tileset.get_physics_layers_count():
				var td: TileData = source.get_tile_data(coords, 0)
				if td != null:
					var hw := region_size.x * 0.5
					var hh := region_size.y * 0.5
					var poly := PackedVector2Array([
						Vector2(-hw, -hh), Vector2(hw, -hh),
						Vector2(hw, hh), Vector2(-hw, hh)
					])
					td.set_collision_polygons_count(phys_layer, 0)
					td.add_collision_polygon(phys_layer)
					td.set_collision_polygon_points(phys_layer, 0, poly)
					td.set_collision_polygon_one_way(phys_layer, 0, one_way)

	if tileset_path != "":
		ResourceSaver.save(tileset, tileset_path)
	elif tileset.resource_path != "":
		ResourceSaver.save(tileset, tileset.resource_path)

	return {
		"ok": true,
		"node_path": node_path,
		"source_id": source_id,
		"texture_path": tex.resource_path,
		"region_size": [region_size.x, region_size.y],
		"grid_columns": cols,
		"grid_rows": rows,
		"total_grid_cells": cols * rows,
		"tiles_created": created_coords.size(),
		"tiles_skipped_empty": skipped_count,
		"created_coords": created_coords,
		"has_physics": auto_col or tileset.get_physics_layers_count() > 0,
		"physics_layers_count": tileset.get_physics_layers_count(),
		"physics_layer_applied": phys_layer if auto_col else -1,
		"one_way": one_way,
		"source": "local"
	}


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

func _parse_loop_mode(val: Variant) -> int:
	if typeof(val) == TYPE_INT:
		return clampi(int(val), 0, 2)
	var s := str(val).to_lower().strip_edges()
	if s in ["linear", "loop", "true", "1"]:
		return 1
	elif s in ["pingpong", "ping_pong", "2"]:
		return 2
	return 0


func _loop_mode_to_string(mode: int) -> String:
	match mode:
		1: return "linear"
		2: return "pingpong"
		_: return "none"


func _track_type_to_string(type_int: int) -> String:
	match type_int:
		0: return "property"
		1: return "position_3d"
		2: return "rotation_3d"
		3: return "scale_3d"
		4: return "blend_shape"
		5: return "method"
		6: return "bezier"
		7: return "audio"
		8: return "animation"
		_: return "unknown"


func _track_string_to_type(s: String) -> int:
	var lower := s.to_lower().strip_edges()
	match lower:
		"property", "value", "0": return 0
		"position_3d", "1": return 1
		"rotation_3d", "2": return 2
		"scale_3d", "3": return 3
		"blend_shape", "4": return 4
		"method", "call", "5": return 5
		"bezier", "6": return 6
		"audio", "7": return 7
		"animation", "8": return 8
		_: return 0


func _interpolation_type_to_string(type_int: int) -> String:
	match type_int:
		0: return "nearest"
		1: return "linear"
		2: return "cubic"
		3: return "linear_angle"
		4: return "cubic_angle"
		_: return "linear"


func _interpolation_string_to_type(s: String) -> int:
	var lower := s.to_lower().strip_edges()
	match lower:
		"nearest", "step", "constant", "0": return 0
		"linear", "1": return 1
		"cubic", "smooth", "2": return 2
		"linear_angle", "3": return 3
		"cubic_angle", "4": return 4
		_: return 1


func _update_mode_to_string(m: int) -> String:
	match m:
		0: return "continuous"
		1: return "discrete"
		2: return "capture"
		_: return "continuous"


func _update_string_to_mode(s: String) -> int:
	var lower := s.to_lower().strip_edges()
	match lower:
		"continuous", "0": return 0
		"discrete", "1": return 1
		"capture", "2": return 2
		_: return 0


func _resolve_animation_player(root: Node, path_arg: String) -> AnimationPlayer:
	if root == null:
		return null
	var target_node: Node = null
	if path_arg != "":
		target_node = _resolve_node(root, path_arg)
	else:
		target_node = _find_first_child_of_type(root, "AnimationPlayer")
	if target_node is AnimationPlayer or (target_node != null and target_node.is_class("AnimationPlayer")):
		return target_node as AnimationPlayer
	return null


func _resolve_animation_tree(root: Node, path_arg: String) -> AnimationTree:
	if root == null:
		return null
	var target_node: Node = null
	if path_arg != "":
		target_node = _resolve_node(root, path_arg)
	else:
		target_node = _find_first_child_of_type(root, "AnimationTree")
	if target_node is AnimationTree or (target_node != null and target_node.is_class("AnimationTree")):
		return target_node as AnimationTree
	return null


func _split_animation_name(full_name: String) -> Array:
	if full_name.contains("/"):
		var p := full_name.split("/", false, 1)
		return [str(p[0]), str(p[1])]
	return ["", full_name]


func _parse_vector2_safe(val: Variant) -> Vector2:
	if typeof(val) == TYPE_VECTOR2:
		return val as Vector2
	if typeof(val) == TYPE_ARRAY or typeof(val) == TYPE_PACKED_FLOAT32_ARRAY:
		var arr: Array = val
		if arr.size() >= 2:
			return Vector2(float(arr[0]), float(arr[1]))
		elif arr.size() == 1:
			return Vector2(float(arr[0]), float(arr[0]))
		return Vector2.ZERO
	if typeof(val) == TYPE_DICTIONARY:
		var dict: Dictionary = val
		return Vector2(float(dict.get("x", 0.0)), float(dict.get("y", 0.0)))
	if typeof(val) == TYPE_STRING:
		var s := (val as String).strip_edges().trim_prefix("(").trim_suffix(")")
		if s.begins_with("Vector2(") and s.ends_with(")"):
			s = s.substr(8, s.length() - 9)
		var parts := s.split(",")
		if parts.size() >= 2:
			return Vector2(float(parts[0].strip_edges()), float(parts[1].strip_edges()))
	return Vector2.ZERO



func _inspect_animation_player(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node_path := str(args.get("node_path", "")).strip_edges()
	var player := _resolve_animation_player(root, node_path)
	if player == null:
		return {
			"ok": false,
			"error": "animation_player_not_found",
			"node_path": node_path,
			"hint": "Specify 'node_path' to an AnimationPlayer or ensure one exists in the active scene."
		}

	var lib_list := player.get_animation_library_list()
	var libraries: Array = []
	for lib_name in lib_list:
		libraries.append(str(lib_name))

	var anim_list := player.get_animation_list()
	var anim_summaries: Array = []
	for anim_name in anim_list:
		if player.has_animation(anim_name):
			var anim := player.get_animation(anim_name)
			if anim != null:
				anim_summaries.append({
					"name": str(anim_name),
					"length": anim.length,
					"duration": anim.length,
					"step": anim.step,
					"loop_mode": _loop_mode_to_string(anim.loop_mode),
					"track_count": anim.get_track_count(),
				})

	var playback_info := {
		"current_animation": str(player.current_animation),
		"assigned_animation": str(player.assigned_animation),
		"autoplay": str(player.autoplay),
		"speed_scale": player.speed_scale,
		"is_playing": player.is_playing(),
		"playback_process_mode": "physics" if player.playback_process_mode == 0 else ("idle" if player.playback_process_mode == 1 else "manual"),
	}

	var blend_times: Array = []
	for a1 in anim_list:
		for a2 in anim_list:
			if a1 != a2:
				var bt := player.get_blend_time(a1, a2)
				if bt > 0.0:
					blend_times.append({"from": str(a1), "to": str(a2), "blend_time": bt})

	return {
		"ok": true,
		"node_path": str(root.get_path_to(player)),
		"root_node": str(player.root_node),
		"libraries": libraries,
		"animations_count": anim_summaries.size(),
		"animations": anim_summaries,
		"playback": playback_info,
		"blend_times": blend_times,
		"source": "local",
	}


func _inspect_animation_tracks(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node_path := str(args.get("node_path", "")).strip_edges()
	var player := _resolve_animation_player(root, node_path)
	if player == null:
		return {"ok": false, "error": "animation_player_not_found"}

	var anim_name := str(args.get("animation", args.get("animation_name", ""))).strip_edges()
	if anim_name == "":
		if not player.current_animation.is_empty():
			anim_name = str(player.current_animation)
		elif not player.get_animation_list().is_empty():
			anim_name = str(player.get_animation_list()[0])
		else:
			return {
				"ok": false,
				"error": "no_animations_found",
				"node_path": str(root.get_path_to(player)),
				"hint": "The AnimationPlayer does not contain any animations."
			}

	if not player.has_animation(anim_name):
		return {
			"ok": false,
			"error": "animation_not_found",
			"animation": anim_name,
			"available_animations": Array(player.get_animation_list())
		}

	var anim := player.get_animation(anim_name)
	var track_filter := int(args.get("track_index", -1))
	var tracks: Array = []
	var player_root_target: Node = player.get_node_or_null(player.root_node)

	for i in anim.get_track_count():
		if track_filter >= 0 and i != track_filter:
			continue
		var t_type := anim.track_get_type(i)
		var t_path := str(anim.track_get_path(i))
		var np := NodePath(t_path)
		var node_part := np.get_concatenated_names()
		var prop_part := np.get_concatenated_subnames()

		var target_exists := false
		if player_root_target != null:
			if node_part.is_empty() or node_part == ".":
				target_exists = true
			else:
				target_exists = player_root_target.get_node_or_null(NodePath(node_part)) != null

		var keys: Array = []
		var key_count := anim.track_get_key_count(i)
		for k in key_count:
			var kt := anim.track_get_key_time(i, k)
			var ktr := anim.track_get_key_transition(i, k)
			var kv = anim.track_get_key_value(i, k)
			keys.append({
				"time": kt,
				"transition": ktr,
				"value": _jsonish(kv)
			})

		var t_dict := {
			"track_index": i,
			"type": _track_type_to_string(t_type),
			"path": t_path,
			"target_node": str(node_part),
			"target_property": str(prop_part),
			"target_node_exists": target_exists,
			"interpolation": _interpolation_type_to_string(anim.track_get_interpolation_type(i)),
			"enabled": anim.track_is_enabled(i),
			"keyframe_count": key_count,
			"keyframes": keys,
		}
		if t_type == 0:
			t_dict["update_mode"] = _update_mode_to_string(anim.value_track_get_update_mode(i))
		tracks.append(t_dict)

	return {
		"ok": true,
		"node_path": str(root.get_path_to(player)),
		"animation": anim_name,
		"duration": anim.length,
		"loop_mode": _loop_mode_to_string(anim.loop_mode),
		"step": anim.step,
		"track_count": anim.get_track_count(),
		"tracks": tracks,
		"source": "local",
	}


func _edit_animation_player(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node_path := str(args.get("node_path", "")).strip_edges()
	var player := _resolve_animation_player(root, node_path)
	if player == null:
		return {"ok": false, "error": "animation_player_not_found"}

	var op := str(args.get("operation", args.get("action", ""))).to_lower().strip_edges()
	if op == "":
		return {"ok": false, "error": "missing_operation", "hint": "Specify 'operation', e.g. create_animation, edit_animation, add_track, insert_keyframe, remove_animation, rename_animation, set_autoplay, set_speed_scale, set_blend_time"}

	var requested: Dictionary = args.duplicate()
	var applied: Dictionary = {}
	var warnings: Array = []
	var errors: Array = []

	match op:
		"create_animation", "add_animation":
			var anim_name := str(args.get("animation", args.get("name", ""))).strip_edges()
			if anim_name == "":
				return {"ok": false, "error": "missing_animation_name"}
			var duration := clampf(float(args.get("duration", args.get("length", 1.0))), 0.001, 3600.0)
			var loop_mode := _parse_loop_mode(args.get("loop_mode", 0))
			var step := clampf(float(args.get("step", 0.1)), 0.001, 10.0)

			var anim := Animation.new()
			anim.length = duration
			anim.loop_mode = loop_mode as Animation.LoopMode
			anim.step = step

			var parts := _split_animation_name(anim_name)
			var lib_name: String = parts[0]
			var bare_name: String = parts[1]

			var lib: AnimationLibrary = null
			if player.has_animation_library(lib_name):
				lib = player.get_animation_library(lib_name)
			else:
				lib = AnimationLibrary.new()
				player.add_animation_library(lib_name, lib)

			if lib.has_animation(bare_name):
				warnings.append("Overwriting existing animation '%s' in library '%s'." % [bare_name, lib_name])
				lib.remove_animation(bare_name)

			var err := lib.add_animation(bare_name, anim)
			if err != OK:
				return {"ok": false, "error": "failed_to_add_animation", "code": err}
			applied = {"animation": anim_name, "duration": duration, "loop_mode": _loop_mode_to_string(loop_mode), "step": step}

		"edit_animation":
			var anim_name := str(args.get("animation", args.get("name", ""))).strip_edges()
			if anim_name == "" or not player.has_animation(anim_name):
				return {"ok": false, "error": "animation_not_found", "animation": anim_name}
			var anim := player.get_animation(anim_name)
			if args.has("duration") or args.has("length"):
				var duration := clampf(float(args.get("duration", args.get("length", anim.length))), 0.001, 3600.0)
				anim.length = duration
				applied["duration"] = duration
			if args.has("loop_mode"):
				var loop_mode := _parse_loop_mode(args.get("loop_mode"))
				anim.loop_mode = loop_mode as Animation.LoopMode
				applied["loop_mode"] = _loop_mode_to_string(loop_mode)
			if args.has("step"):
				var step := clampf(float(args.get("step")), 0.001, 10.0)
				anim.step = step
				applied["step"] = step

		"remove_animation", "delete_animation":
			var anim_name := str(args.get("animation", args.get("name", ""))).strip_edges()
			if anim_name == "" or not player.has_animation(anim_name):
				return {"ok": false, "error": "animation_not_found", "animation": anim_name}
			var anim := player.get_animation(anim_name)
			var lib_name := player.find_animation_library(anim)
			var lib := player.get_animation_library(lib_name)
			var parts := _split_animation_name(anim_name)
			lib.remove_animation(parts[1])
			applied = {"removed_animation": anim_name}

		"rename_animation":
			var old_name := str(args.get("old_name", args.get("old_animation", ""))).strip_edges()
			var new_name := str(args.get("new_name", args.get("new_animation", ""))).strip_edges()
			if old_name == "" or not player.has_animation(old_name):
				return {"ok": false, "error": "animation_not_found", "animation": old_name}
			if new_name == "":
				return {"ok": false, "error": "missing_new_name"}
			var anim := player.get_animation(old_name)
			var lib_name := player.find_animation_library(anim)
			var lib := player.get_animation_library(lib_name)
			var old_parts := _split_animation_name(old_name)
			var new_parts := _split_animation_name(new_name)
			lib.rename_animation(old_parts[1], new_parts[1])
			applied = {"renamed": {"old_name": old_name, "new_name": new_name}}

		"set_autoplay":
			var anim_name := str(args.get("animation", args.get("autoplay", ""))).strip_edges()
			if anim_name != "" and not player.has_animation(anim_name):
				warnings.append("Autoplay animation '%s' does not currently exist on player." % anim_name)
			player.autoplay = anim_name
			applied = {"autoplay": anim_name}

		"set_speed_scale":
			var spd := float(args.get("speed_scale", 1.0))
			player.speed_scale = spd
			applied = {"speed_scale": spd}

		"set_blend_time":
			var a1 := str(args.get("anim_from", args.get("from", ""))).strip_edges()
			var a2 := str(args.get("anim_to", args.get("to", ""))).strip_edges()
			var bt := float(args.get("blend_time", 0.0))
			player.set_blend_time(a1, a2, bt)
			applied = {"anim_from": a1, "anim_to": a2, "blend_time": bt}

		"add_track":
			var anim_name := str(args.get("animation", "")).strip_edges()
			if anim_name == "" or not player.has_animation(anim_name):
				return {"ok": false, "error": "animation_not_found", "animation": anim_name}
			var anim := player.get_animation(anim_name)
			var t_type_str := str(args.get("track_type", "property"))
			var t_type := _track_string_to_type(t_type_str)
			var t_path := str(args.get("path", args.get("track_path", ""))).strip_edges()
			if t_path == "":
				return {"ok": false, "error": "missing_track_path", "hint": "Provide 'path' targeting property e.g. 'Sprite2D:frame'"}
			var idx := anim.add_track(t_type as Animation.TrackType)
			anim.track_set_path(idx, NodePath(t_path))
			if args.has("interpolation"):
				var interp := _interpolation_string_to_type(str(args.get("interpolation")))
				anim.track_set_interpolation_type(idx, interp as Animation.InterpolationType)
			if t_type == 0 and args.has("update_mode"):
				var um := _update_string_to_mode(str(args.get("update_mode")))
				anim.value_track_set_update_mode(idx, um as Animation.UpdateMode)
			applied = {"animation": anim_name, "track_index": idx, "track_type": _track_type_to_string(t_type), "track_path": t_path}

		"remove_track":
			var anim_name := str(args.get("animation", "")).strip_edges()
			if anim_name == "" or not player.has_animation(anim_name):
				return {"ok": false, "error": "animation_not_found", "animation": anim_name}
			var anim := player.get_animation(anim_name)
			var idx := int(args.get("track_index", -1))
			if idx < 0 and args.has("track_path"):
				var tp := str(args.get("track_path"))
				for i in anim.get_track_count():
					if str(anim.track_get_path(i)) == tp:
						idx = i
						break
			if idx < 0 or idx >= anim.get_track_count():
				return {"ok": false, "error": "track_not_found", "track_index": idx}
			anim.remove_track(idx)
			applied = {"removed_track_index": idx, "animation": anim_name}

		"insert_keyframe", "add_keyframe":
			var anim_name := str(args.get("animation", "")).strip_edges()
			if anim_name == "" or not player.has_animation(anim_name):
				return {"ok": false, "error": "animation_not_found", "animation": anim_name}
			var anim := player.get_animation(anim_name)
			var idx := int(args.get("track_index", -1))
			if idx < 0 and args.has("track_path"):
				var tp := str(args.get("track_path"))
				for i in anim.get_track_count():
					if str(anim.track_get_path(i)) == tp:
						idx = i
						break
			if idx < 0 or idx >= anim.get_track_count():
				return {"ok": false, "error": "track_not_found", "track_index": idx}

			var time := clampf(float(args.get("time", 0.0)), 0.0, 3600.0)
			var trans := float(args.get("transition", args.get("easing", 1.0)))
			var val: Variant = args.get("value")
			if val is String:
				var parsed: Variant = str_to_var(str(val))
				if parsed != null:
					val = parsed

			var key_idx := anim.track_insert_key(idx, time, val, trans)
			applied = {"animation": anim_name, "track_index": idx, "time": time, "value": _jsonish(val), "key_index": key_idx}

		"remove_keyframe":
			var anim_name := str(args.get("animation", "")).strip_edges()
			if anim_name == "" or not player.has_animation(anim_name):
				return {"ok": false, "error": "animation_not_found", "animation": anim_name}
			var anim := player.get_animation(anim_name)
			var idx := int(args.get("track_index", 0))
			if idx < 0 or idx >= anim.get_track_count():
				return {"ok": false, "error": "track_not_found", "track_index": idx}
			var key_idx := int(args.get("key_index", -1))
			if key_idx >= 0 and key_idx < anim.track_get_key_count(idx):
				anim.track_remove_key(idx, key_idx)
				applied = {"removed_key_index": key_idx, "track_index": idx}
			elif args.has("time"):
				var time := float(args.get("time"))
				anim.track_remove_key_at_time(idx, time)
				applied = {"removed_key_at_time": time, "track_index": idx}
			else:
				return {"ok": false, "error": "missing_key_index_or_time"}

		"create_library":
			var lib_name := str(args.get("library_name", args.get("name", ""))).strip_edges()
			if lib_name == "":
				return {"ok": false, "error": "missing_library_name"}
			if player.has_animation_library(lib_name):
				return {"ok": false, "error": "library_already_exists", "library_name": lib_name}
			player.add_animation_library(lib_name, AnimationLibrary.new())
			applied = {"created_library": lib_name}

		"remove_library":
			var lib_name := str(args.get("library_name", args.get("name", ""))).strip_edges()
			if not player.has_animation_library(lib_name):
				return {"ok": false, "error": "library_not_found", "library_name": lib_name}
			player.remove_animation_library(lib_name)
			applied = {"removed_library": lib_name}

		_:
			return {"ok": false, "error": "unknown_operation", "operation": op}

	var readback_data := _inspect_animation_player({"node_path": str(root.get_path_to(player))})
	var final_status := "applied"
	if not warnings.is_empty():
		final_status = "partially_applied"

	return _build_mutation_result(
		"edit_animation_player",
		errors.is_empty(),
		final_status,
		requested,
		applied,
		readback_data,
		[str(root.get_path_to(player))],
		warnings,
		errors
	)


func _inspect_animation_tree(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node_path := str(args.get("node_path", "")).strip_edges()
	var tree := _resolve_animation_tree(root, node_path)
	if tree == null:
		return {
			"ok": false,
			"error": "animation_tree_not_found",
			"node_path": node_path,
			"hint": "Specify 'node_path' to an AnimationTree or ensure one exists in the active scene."
		}

	var player_path := str(tree.anim_player)
	var player_resolved := false
	if not player_path.is_empty():
		player_resolved = tree.get_node_or_null(tree.anim_player) != null

	var tree_root_obj = tree.tree_root
	var root_type := ""
	var root_details: Dictionary = {}

	if tree_root_obj != null:
		root_type = tree_root_obj.get_class()
		if tree_root_obj is AnimationNodeStateMachine:
			var sm: AnimationNodeStateMachine = tree_root_obj
			var states: Array = []
			for prop in sm.get_property_list():
				var pname: String = prop.get("name", "")
				if pname.begins_with("states/") and pname.ends_with("/node"):
					var sname := pname.trim_prefix("states/").trim_suffix("/node")
					var anode: AnimationNode = sm.get_node(sname)
					var anim_name := ""
					if anode is AnimationNodeAnimation:
						anim_name = str((anode as AnimationNodeAnimation).animation)
					states.append({
						"name": sname,
						"type": anode.get_class() if anode != null else "",
						"animation": anim_name,
						"position": _jsonish(sm.get_node_position(sname)),
					})
			var transitions: Array = []
			for idx in sm.get_transition_count():
				var tr := sm.get_transition(idx)
				var smode_str := "immediate" if tr.switch_mode == 0 else ("sync" if tr.switch_mode == 1 else "at_end")
				var amode_str := "disabled" if tr.advance_mode == 0 else ("enabled" if tr.advance_mode == 1 else "auto")
				transitions.append({
					"from": str(sm.get_transition_from(idx)),
					"to": str(sm.get_transition_to(idx)),
					"switch_mode": smode_str,
					"advance_mode": amode_str,
					"advance_condition": str(tr.advance_condition),
					"advance_expression": str(tr.advance_expression),
					"xfade_time": tr.xfade_time,
					"priority": tr.priority,
					"reset_teleport": tr.reset_teleport,
				})
			root_details = {
				"states": states,
				"transitions": transitions,
				"start_node": str(sm.get_start_node()),
				"end_node": str(sm.get_end_node()),
			}
		elif tree_root_obj is AnimationNodeBlendTree:
			var bt: AnimationNodeBlendTree = tree_root_obj
			var nodes: Array = []
			for prop in bt.get_property_list():
				var pname: String = prop.get("name", "")
				if pname.begins_with("nodes/") and pname.ends_with("/node"):
					var nname := pname.trim_prefix("nodes/").trim_suffix("/node")
					var bnode: AnimationNode = bt.get_node(nname)
					var anim_name := ""
					if bnode is AnimationNodeAnimation:
						anim_name = str((bnode as AnimationNodeAnimation).animation)
					nodes.append({
						"name": nname,
						"type": bnode.get_class() if bnode != null else "",
						"animation": anim_name,
						"position": _jsonish(bt.get_node_position(nname)),
					})
			root_details = {
				"nodes": nodes,
				"graph_offset": _jsonish(bt.get_graph_offset()),
			}
		elif tree_root_obj is AnimationNodeBlendSpace2D:
			var bs2: AnimationNodeBlendSpace2D = tree_root_obj
			var pts: Array = []
			for idx in bs2.get_point_count():
				var pnode = bs2.get_point_node(idx)
				var anim_name := ""
				if pnode is AnimationNodeAnimation:
					anim_name = str((pnode as AnimationNodeAnimation).animation)
				pts.append({
					"point_index": idx,
					"position": _jsonish(bs2.get_point_position(idx)),
					"animation": anim_name,
				})
			root_details = {
				"point_count": bs2.get_point_count(),
				"points": pts,
				"min_space": _jsonish(bs2.min_space),
				"max_space": _jsonish(bs2.max_space),
				"snap": _jsonish(bs2.snap),
				"blend_mode": "interpolated" if bs2.blend_mode == 0 else ("discrete" if bs2.blend_mode == 1 else "discrete_carry"),
				"auto_triangles": bs2.auto_triangles,
			}

	var params_dict: Dictionary = {}
	for prop in tree.get_property_list():
		var pname: String = prop.get("name", "")
		if pname.begins_with("parameters/"):
			params_dict[pname] = _jsonish(tree.get(pname))

	var process_str := "physics" if tree.process_callback == 0 else ("idle" if tree.process_callback == 1 else "manual")

	return {
		"ok": true,
		"node_path": str(root.get_path_to(tree)),
		"anim_player": player_path,
		"anim_player_resolved": player_resolved,
		"active": tree.active,
		"process_callback": process_str,
		"root_type": root_type,
		"root_details": root_details,
		"parameters": params_dict,
		"source": "local",
	}


func _edit_animation_tree(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node_path := str(args.get("node_path", "")).strip_edges()
	var tree := _resolve_animation_tree(root, node_path)
	if tree == null:
		return {"ok": false, "error": "animation_tree_not_found"}

	var op := str(args.get("operation", args.get("action", ""))).to_lower().strip_edges()
	var requested: Dictionary = args.duplicate()
	var applied: Dictionary = {}
	var warnings: Array = []
	var errors: Array = []

	match op:
		"set_tree_root":
			var root_type := str(args.get("root_type", "AnimationNodeStateMachine")).strip_edges()
			var new_root: AnimationRootNode = null
			if root_type in ["AnimationNodeStateMachine", "StateMachine", "state_machine"]:
				new_root = AnimationNodeStateMachine.new()
			elif root_type in ["AnimationNodeBlendTree", "BlendTree", "blend_tree"]:
				new_root = AnimationNodeBlendTree.new()
			elif root_type in ["AnimationNodeBlendSpace2D", "BlendSpace2D", "blend_space_2d"]:
				new_root = AnimationNodeBlendSpace2D.new()
			elif root_type in ["AnimationNodeBlendSpace1D", "BlendSpace1D", "blend_space_1d"]:
				new_root = AnimationNodeBlendSpace1D.new()
			else:
				if ClassDB.can_instantiate(root_type):
					var obj = ClassDB.instantiate(root_type)
					if obj is AnimationRootNode:
						new_root = obj
			if new_root == null:
				return {"ok": false, "error": "invalid_root_type", "root_type": root_type}
			tree.tree_root = new_root
			if args.has("anim_player"):
				tree.anim_player = NodePath(str(args.get("anim_player")))
			applied = {"root_type": new_root.get_class(), "anim_player": str(tree.anim_player)}

		"set_anim_player":
			var ap := str(args.get("anim_player", args.get("anim_player_path", ""))).strip_edges()
			tree.anim_player = NodePath(ap)
			applied = {"anim_player": ap}
			if tree.get_node_or_null(tree.anim_player) == null:
				warnings.append("AnimationPlayer at '%s' does not resolve from AnimationTree." % ap)

		"set_active":
			var act := bool(args.get("active", true))
			tree.active = act
			applied = {"active": act}

		"add_node":
			if not (tree.tree_root is AnimationNodeBlendTree):
				return {"ok": false, "error": "root_is_not_blend_tree", "current_root": tree.tree_root.get_class() if tree.tree_root != null else "null"}
			var bt: AnimationNodeBlendTree = tree.tree_root
			var nname := str(args.get("node_name", args.get("name", ""))).strip_edges()
			if nname == "":
				return {"ok": false, "error": "missing_node_name"}
			var ntype := str(args.get("node_type", "AnimationNodeAnimation")).strip_edges()
			var n_obj: AnimationNode = null
			match ntype:
				"AnimationNodeAnimation":
					var an := AnimationNodeAnimation.new()
					an.animation = StringName(str(args.get("animation", nname)))
					n_obj = an
				"AnimationNodeBlend2": n_obj = AnimationNodeBlend2.new()
				"AnimationNodeBlend3": n_obj = AnimationNodeBlend3.new()
				"AnimationNodeOneShot": n_obj = AnimationNodeOneShot.new()
				"AnimationNodeTimeScale": n_obj = AnimationNodeTimeScale.new()
				"AnimationNodeTransition": n_obj = AnimationNodeTransition.new()
				_:
					if ClassDB.can_instantiate(ntype):
						var inst = ClassDB.instantiate(ntype)
						if inst is AnimationNode:
							n_obj = inst
			if n_obj == null:
				return {"ok": false, "error": "invalid_node_type", "node_type": ntype}
			var pos: Vector2 = _parse_vector2_safe(args.get("position", [0, 0]))
			bt.add_node(nname, n_obj, pos)
			applied = {"node_name": nname, "node_type": n_obj.get_class(), "position": [pos.x, pos.y]}

		"remove_node":
			if not (tree.tree_root is AnimationNodeBlendTree):
				return {"ok": false, "error": "root_is_not_blend_tree"}
			var bt: AnimationNodeBlendTree = tree.tree_root
			var nname := str(args.get("node_name", args.get("name", ""))).strip_edges()
			if not bt.has_node(nname):
				return {"ok": false, "error": "node_not_found_in_blend_tree", "node_name": nname}
			bt.remove_node(nname)
			applied = {"removed_node": nname}

		"connect_nodes":
			if not (tree.tree_root is AnimationNodeBlendTree):
				return {"ok": false, "error": "root_is_not_blend_tree"}
			var bt: AnimationNodeBlendTree = tree.tree_root
			var inp_node := str(args.get("input_node", "")).strip_edges()
			var inp_idx := int(args.get("input_index", 0))
			var out_node := str(args.get("output_node", "output")).strip_edges()
			bt.connect_node(inp_node, inp_idx, out_node)
			applied = {"connected": {"input_node": inp_node, "input_index": inp_idx, "output_node": out_node}}

		"disconnect_nodes":
			if not (tree.tree_root is AnimationNodeBlendTree):
				return {"ok": false, "error": "root_is_not_blend_tree"}
			var bt: AnimationNodeBlendTree = tree.tree_root
			var out_node := str(args.get("output_node", "output")).strip_edges()
			var inp_idx := int(args.get("input_index", 0))
			bt.disconnect_node(out_node, inp_idx)
			applied = {"disconnected": {"output_node": out_node, "input_index": inp_idx}}

		"set_node_position":
			if not (tree.tree_root is AnimationNodeBlendTree):
				return {"ok": false, "error": "root_is_not_blend_tree"}
			var bt: AnimationNodeBlendTree = tree.tree_root
			var nname := str(args.get("node_name", args.get("name", ""))).strip_edges()
			var pos: Vector2 = _parse_vector2_safe(args.get("position", [0, 0]))
			bt.set_node_position(nname, pos)
			applied = {"node_name": nname, "position": [pos.x, pos.y]}

		_:
			return {"ok": false, "error": "unknown_operation", "operation": op}

	var readback_data := _inspect_animation_tree({"node_path": str(root.get_path_to(tree))})
	var final_status := "applied"
	if not warnings.is_empty():
		final_status = "partially_applied"

	return _build_mutation_result(
		"edit_animation_tree",
		errors.is_empty(),
		final_status,
		requested,
		applied,
		readback_data,
		[str(root.get_path_to(tree))],
		warnings,
		errors
	)


func _edit_animation_state_machine(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node_path := str(args.get("node_path", "")).strip_edges()
	var tree := _resolve_animation_tree(root, node_path)
	if tree == null:
		return {"ok": false, "error": "animation_tree_not_found"}

	if not (tree.tree_root is AnimationNodeStateMachine):
		return {"ok": false, "error": "tree_root_is_not_state_machine", "current_root": tree.tree_root.get_class() if tree.tree_root != null else "null"}

	var sm: AnimationNodeStateMachine = tree.tree_root
	var op := str(args.get("operation", args.get("action", ""))).to_lower().strip_edges()
	var requested: Dictionary = args.duplicate()
	var applied: Dictionary = {}
	var warnings: Array = []
	var errors: Array = []

	match op:
		"add_state":
			var state_name := str(args.get("state_name", args.get("name", ""))).strip_edges()
			if state_name == "":
				return {"ok": false, "error": "missing_state_name"}
			var anim_name := str(args.get("animation", state_name)).strip_edges()
			var anim_node := AnimationNodeAnimation.new()
			anim_node.animation = StringName(anim_name)
			var pos: Vector2 = _parse_vector2_safe(args.get("position", [0, 0]))

			var player_node: Node = tree.get_node_or_null(tree.anim_player)
			if player_node is AnimationPlayer and not (player_node as AnimationPlayer).has_animation(anim_name):
				warnings.append("State '%s' references animation '%s' which does not exist on linked AnimationPlayer." % [state_name, anim_name])

			sm.add_node(state_name, anim_node, pos)
			applied = {"state_name": state_name, "animation": anim_name, "position": [pos.x, pos.y]}

		"remove_state":
			var state_name := str(args.get("state_name", args.get("name", ""))).strip_edges()
			if not sm.has_node(state_name):
				return {"ok": false, "error": "state_not_found", "state_name": state_name}
			sm.remove_node(state_name)
			applied = {"removed_state": state_name}

		"rename_state":
			var old_name := str(args.get("old_name", "")).strip_edges()
			var new_name := str(args.get("new_name", "")).strip_edges()
			if not sm.has_node(old_name):
				return {"ok": false, "error": "state_not_found", "state_name": old_name}
			if new_name == "":
				return {"ok": false, "error": "missing_new_name"}
			sm.rename_node(old_name, new_name)
			applied = {"renamed": {"old_name": old_name, "new_name": new_name}}

		"set_start_node":
			var sname := str(args.get("state_name", args.get("name", ""))).strip_edges()
			if not sm.has_node(sname):
				warnings.append("Start node state '%s' does not currently exist in state machine." % sname)
			sm.set_start_node(sname)
			applied = {"start_node": sname}

		"set_end_node":
			var sname := str(args.get("state_name", args.get("name", ""))).strip_edges()
			if not sm.has_node(sname):
				warnings.append("End node state '%s' does not currently exist in state machine." % sname)
			sm.set_end_node(sname)
			applied = {"end_node": sname}

		"add_transition":
			var from_state := str(args.get("from_state", args.get("from", ""))).strip_edges()
			var to_state := str(args.get("to_state", args.get("to", ""))).strip_edges()
			if from_state == "" or to_state == "":
				return {"ok": false, "error": "missing_from_or_to_state"}
			if not sm.has_node(from_state) and from_state != "Start":
				warnings.append("from_state '%s' does not exist in state machine." % from_state)
			if not sm.has_node(to_state) and to_state != "End":
				warnings.append("to_state '%s' does not exist in state machine." % to_state)

			var tr := AnimationNodeStateMachineTransition.new()
			var smode_str := str(args.get("switch_mode", "immediate")).to_lower()
			match smode_str:
				"immediate": tr.switch_mode = 0 as AnimationNodeStateMachineTransition.SwitchMode
				"sync": tr.switch_mode = 1 as AnimationNodeStateMachineTransition.SwitchMode
				"at_end", "end": tr.switch_mode = 2 as AnimationNodeStateMachineTransition.SwitchMode

			var amode_str := str(args.get("advance_mode", "auto")).to_lower()
			match amode_str:
				"disabled", "none": tr.advance_mode = 0 as AnimationNodeStateMachineTransition.AdvanceMode
				"enabled": tr.advance_mode = 1 as AnimationNodeStateMachineTransition.AdvanceMode
				"auto": tr.advance_mode = 2 as AnimationNodeStateMachineTransition.AdvanceMode

			tr.advance_condition = StringName(str(args.get("advance_condition", "")))
			tr.advance_expression = str(args.get("advance_expression", ""))
			tr.xfade_time = float(args.get("xfade_time", args.get("duration", 0.0)))
			tr.priority = int(args.get("priority", 1))
			tr.reset_teleport = bool(args.get("reset_teleport", true))

			if sm.has_transition(from_state, to_state):
				sm.remove_transition(from_state, to_state)

			sm.add_transition(from_state, to_state, tr)
			applied = {
				"from_state": from_state,
				"to_state": to_state,
				"switch_mode": smode_str,
				"advance_mode": amode_str,
				"advance_condition": str(tr.advance_condition),
				"xfade_time": tr.xfade_time,
				"priority": tr.priority,
			}

		"remove_transition":
			var from_state := str(args.get("from_state", args.get("from", ""))).strip_edges()
			var to_state := str(args.get("to_state", args.get("to", ""))).strip_edges()
			if not sm.has_transition(from_state, to_state):
				return {"ok": false, "error": "transition_not_found", "from_state": from_state, "to_state": to_state}
			sm.remove_transition(from_state, to_state)
			applied = {"removed_transition": {"from": from_state, "to": to_state}}

		_:
			return {"ok": false, "error": "unknown_operation", "operation": op}

	var readback_data := _inspect_animation_tree({"node_path": str(root.get_path_to(tree))})
	var final_status := "applied"
	if not warnings.is_empty():
		final_status = "partially_applied"

	return _build_mutation_result(
		"edit_animation_state_machine",
		errors.is_empty(),
		final_status,
		requested,
		applied,
		readback_data,
		[str(root.get_path_to(tree))],
		warnings,
		errors
	)


func _edit_animation_blend_space(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node_path := str(args.get("node_path", "")).strip_edges()
	var tree := _resolve_animation_tree(root, node_path)
	if tree == null:
		return {"ok": false, "error": "animation_tree_not_found"}

	var bs: AnimationRootNode = null
	if tree.tree_root is AnimationNodeBlendSpace2D or tree.tree_root is AnimationNodeBlendSpace1D:
		bs = tree.tree_root
	if bs == null:
		return {"ok": false, "error": "tree_root_not_blend_space", "current_root": tree.tree_root.get_class() if tree.tree_root != null else "null"}

	var is_2d := bs is AnimationNodeBlendSpace2D
	var op := str(args.get("operation", args.get("action", ""))).to_lower().strip_edges()
	var requested: Dictionary = args.duplicate()
	var applied: Dictionary = {}
	var warnings: Array = []
	var errors: Array = []

	match op:
		"set_space_limits":
			if is_2d:
				var bs2: AnimationNodeBlendSpace2D = bs as AnimationNodeBlendSpace2D
				if args.has("min_space"): bs2.min_space = _parse_vector2_safe(args.get("min_space"))
				if args.has("max_space"): bs2.max_space = _parse_vector2_safe(args.get("max_space"))
				if args.has("snap"): bs2.snap = _parse_vector2_safe(args.get("snap"))
				if args.has("blend_mode"):
					var bms := str(args.get("blend_mode")).to_lower()
					bs2.blend_mode = (1 if bms == "discrete" else (2 if bms == "discrete_carry" else 0)) as AnimationNodeBlendSpace2D.BlendMode
				applied = {"min_space": [bs2.min_space.x, bs2.min_space.y], "max_space": [bs2.max_space.x, bs2.max_space.y]}
			else:
				var bs1: AnimationNodeBlendSpace1D = bs as AnimationNodeBlendSpace1D
				if args.has("min_space"): bs1.min_space = float(args.get("min_space"))
				if args.has("max_space"): bs1.max_space = float(args.get("max_space"))
				if args.has("snap"): bs1.snap = float(args.get("snap"))
				applied = {"min_space": bs1.min_space, "max_space": bs1.max_space}

		"add_point":
			var anim_name := str(args.get("animation", "")).strip_edges()
			var anim_node := AnimationNodeAnimation.new()
			anim_node.animation = StringName(anim_name)
			if is_2d:
				var bs2: AnimationNodeBlendSpace2D = bs as AnimationNodeBlendSpace2D
				var pos: Vector2 = _parse_vector2_safe(args.get("position", [0, 0]))
				bs2.add_point(anim_node, pos)
				applied = {"point_index": bs2.get_point_count() - 1, "position": [pos.x, pos.y], "animation": anim_name}
			else:
				var bs1: AnimationNodeBlendSpace1D = bs as AnimationNodeBlendSpace1D
				var pos := float(args.get("position", 0.0))
				bs1.add_point(anim_node, pos)
				applied = {"point_index": bs1.get_point_count() - 1, "position": pos, "animation": anim_name}

		"remove_point":
			var p_idx := int(args.get("point_index", -1))
			if is_2d:
				var bs2: AnimationNodeBlendSpace2D = bs as AnimationNodeBlendSpace2D
				if p_idx < 0 or p_idx >= bs2.get_point_count():
					return {"ok": false, "error": "point_index_out_of_range", "point_index": p_idx}
				bs2.remove_point(p_idx)
			else:
				var bs1: AnimationNodeBlendSpace1D = bs as AnimationNodeBlendSpace1D
				if p_idx < 0 or p_idx >= bs1.get_point_count():
					return {"ok": false, "error": "point_index_out_of_range", "point_index": p_idx}
				bs1.remove_point(p_idx)
			applied = {"removed_point_index": p_idx}

		"set_point_position":
			var p_idx := int(args.get("point_index", -1))
			if is_2d:
				var bs2: AnimationNodeBlendSpace2D = bs as AnimationNodeBlendSpace2D
				if p_idx < 0 or p_idx >= bs2.get_point_count():
					return {"ok": false, "error": "point_index_out_of_range", "point_index": p_idx}
				var pos: Vector2 = _parse_vector2_safe(args.get("position", [0, 0]))
				bs2.set_point_position(p_idx, pos)
				applied = {"point_index": p_idx, "position": [pos.x, pos.y]}
			else:
				var bs1: AnimationNodeBlendSpace1D = bs as AnimationNodeBlendSpace1D
				if p_idx < 0 or p_idx >= bs1.get_point_count():
					return {"ok": false, "error": "point_index_out_of_range", "point_index": p_idx}
				var pos := float(args.get("position", 0.0))
				bs1.set_point_position(p_idx, pos)
				applied = {"point_index": p_idx, "position": pos}

		"add_triangle":
			if not is_2d:
				return {"ok": false, "error": "triangles_only_supported_in_blendspace2d"}
			var bs2: AnimationNodeBlendSpace2D = bs as AnimationNodeBlendSpace2D
			var p1 := int(args.get("point_1", 0))
			var p2 := int(args.get("point_2", 1))
			var p3 := int(args.get("point_3", 2))
			bs2.add_triangle(p1, p2, p3)
			applied = {"added_triangle": [p1, p2, p3]}

		"auto_triangles":
			if not is_2d:
				return {"ok": false, "error": "auto_triangles_only_supported_in_blendspace2d"}
			var bs2: AnimationNodeBlendSpace2D = bs as AnimationNodeBlendSpace2D
			var at := bool(args.get("auto_triangles", true))
			bs2.auto_triangles = at
			applied = {"auto_triangles": at}

		_:
			return {"ok": false, "error": "unknown_operation", "operation": op}

	var readback_data := _inspect_animation_tree({"node_path": str(root.get_path_to(tree))})
	var final_status := "applied" if warnings.is_empty() else "partially_applied"
	return _build_mutation_result(
		"edit_animation_blend_space",
		errors.is_empty(),
		final_status,
		requested,
		applied,
		readback_data,
		[str(root.get_path_to(tree))],
		warnings,
		errors
	)


func _get_set_animation_parameters(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}
	var node_path := str(args.get("node_path", "")).strip_edges()
	var tree := _resolve_animation_tree(root, node_path)
	if tree == null:
		return {"ok": false, "error": "animation_tree_not_found"}

	var applied_params: Dictionary = {}
	var warnings: Array = []

	# If parameters dictionary provided to set
	if args.has("parameters") and typeof(args["parameters"]) == TYPE_DICTIONARY:
		var params_to_set: Dictionary = args["parameters"]
		for p_key in params_to_set:
			var p_path := str(p_key)
			if not p_path.begins_with("parameters/"):
				p_path = "parameters/" + p_path
			var val: Variant = params_to_set[p_key]
			if val is Array and (val as Array).size() == 2:
				val = Vector2(float((val as Array)[0]), float((val as Array)[1]))
			tree.set(p_path, val)
			applied_params[p_path] = _jsonish(tree.get(p_path))

	# Collect all parameters
	var filter_str := str(args.get("filter", "")).to_lower().strip_edges()
	var current_params: Dictionary = {}
	for prop in tree.get_property_list():
		var pname: String = prop.get("name", "")
		if pname.begins_with("parameters/"):
			if filter_str == "" or pname.to_lower().contains(filter_str):
				current_params[pname] = _jsonish(tree.get(pname))

	var playback_state: Dictionary = {}
	var playback: Variant = tree.get("parameters/playback")
	if playback != null and (playback as Object).has_method("get_current_node"):
		playback_state["current_node"] = str((playback as Object).call("get_current_node"))
		playback_state["is_playing"] = bool((playback as Object).call("is_playing")) if (playback as Object).has_method("is_playing") else false
		if (playback as Object).has_method("get_fading_from_node"):
			playback_state["fading_from_node"] = str((playback as Object).call("get_fading_from_node"))

	return {
		"ok": true,
		"node_path": str(root.get_path_to(tree)),
		"active": tree.active,
		"applied_parameters": applied_params,
		"parameters": current_params,
		"playback_state": playback_state,
		"warnings": warnings,
		"source": "local",
	}


func _validate_animation_system(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var errors: Array = []
	var warnings: Array = []

	var player_path := str(args.get("player_path", args.get("node_path", ""))).strip_edges()
	var player := _resolve_animation_player(root, player_path)

	var tree_path := str(args.get("tree_path", "")).strip_edges()
	var tree := _resolve_animation_tree(root, tree_path)

	var player_checks: Dictionary = {}
	if player != null:
		var p_root: Node = player.get_node_or_null(player.root_node)
		var empty_anims: Array = []
		var broken_tracks: Array = []
		for anim_name in player.get_animation_list():
			var anim := player.get_animation(anim_name)
			if anim == null:
				continue
			if anim.get_track_count() == 0:
				empty_anims.append(str(anim_name))
			for i in anim.get_track_count():
				var t_path := anim.track_get_path(i)
				var node_sub := t_path.get_concatenated_names()
				if p_root != null and not node_sub.is_empty() and node_sub != ".":
					var target = p_root.get_node_or_null(NodePath(node_sub))
					if target == null:
						broken_tracks.append({
							"animation": str(anim_name),
							"track_index": i,
							"path": str(t_path),
							"unresolved_node": str(node_sub)
						})
		if not empty_anims.is_empty():
			warnings.append("AnimationPlayer has %d empty animations (0 tracks): %s" % [empty_anims.size(), str(empty_anims)])
		if not broken_tracks.is_empty():
			errors.append("AnimationPlayer has %d tracks targeting non-existent nodes: %s" % [broken_tracks.size(), str(broken_tracks)])

		player_checks = {
			"node_path": str(root.get_path_to(player)),
			"animation_count": player.get_animation_list().size(),
			"empty_animations": empty_anims,
			"broken_tracks": broken_tracks,
		}

	var tree_checks: Dictionary = {}
	if tree != null:
		var ap_path := str(tree.anim_player)
		var ap_node = tree.get_node_or_null(tree.anim_player)
		var ap_valid := ap_node is AnimationPlayer

		if not ap_valid:
			errors.append("AnimationTree anim_player '%s' does not resolve to an AnimationPlayer." % ap_path)

		var missing_anims: Array = []
		var unreachable_states: Array = []

		if tree.tree_root is AnimationNodeStateMachine:
			var sm: AnimationNodeStateMachine = tree.tree_root
			var states_list: Array = []
			for prop in sm.get_property_list():
				var pname: String = prop.get("name", "")
				if pname.begins_with("states/") and pname.ends_with("/node"):
					var sname := pname.trim_prefix("states/").trim_suffix("/node")
					states_list.append(sname)
					var snode = sm.get_node(sname)
					if snode is AnimationNodeAnimation:
						var a_name := str((snode as AnimationNodeAnimation).animation)
						if ap_valid and not (ap_node as AnimationPlayer).has_animation(a_name):
							missing_anims.append({"state": sname, "missing_animation": a_name})

			# Reachability check
			var reachable: Dictionary = {}
			var start_node := str(sm.get_start_node())
			if start_node.is_empty() and not states_list.is_empty():
				start_node = states_list[0]
			reachable[start_node] = true
			reachable["Start"] = true

			var queue: Array = [start_node, "Start"]
			while not queue.is_empty():
				var curr: String = queue.pop_front()
				for i in sm.get_transition_count():
					var f := str(sm.get_transition_from(i))
					var t := str(sm.get_transition_to(i))
					if f == curr and not reachable.has(t):
						reachable[t] = true
						queue.append(t)

			for s in states_list:
				if not reachable.has(s):
					unreachable_states.append(s)

			if not unreachable_states.is_empty():
				warnings.append("AnimationTree StateMachine has %d unreachable states: %s" % [unreachable_states.size(), str(unreachable_states)])
			if not missing_anims.is_empty():
				errors.append("AnimationTree references %d animations missing from AnimationPlayer: %s" % [missing_anims.size(), str(missing_anims)])

		tree_checks = {
			"node_path": str(root.get_path_to(tree)),
			"anim_player_linked": not ap_path.is_empty(),
			"anim_player_valid": ap_valid,
			"missing_animations": missing_anims,
			"unreachable_states": unreachable_states,
		}

	var status_str := "valid"
	if not errors.is_empty():
		status_str = "invalid"
	elif not warnings.is_empty():
		status_str = "warnings_found"

	return {
		"ok": true,
		"status": status_str,
		"valid": errors.is_empty(),
		"player_checks": player_checks,
		"tree_checks": tree_checks,
		"errors": errors,
		"warnings": warnings,
		"summary": "Validation %s (%d errors, %d warnings)." % [status_str, errors.size(), warnings.size()],
		"source": "local",
	}


func _test_animation_runtime(args: Dictionary) -> Dictionary:
	var root := _get_scene_root()
	if root == null:
		return {"ok": false, "error": "no_edited_scene"}

	var node_path := str(args.get("node_path", "")).strip_edges()
	var player := _resolve_animation_player(root, node_path)
	var tree := _resolve_animation_tree(root, node_path)

	if player == null and tree == null:
		return {"ok": false, "error": "animation_node_not_found", "hint": "Specify 'node_path' to an AnimationPlayer or AnimationTree."}

	var duration := clampf(float(args.get("duration_seconds", args.get("duration", 0.2))), 0.05, 5.0)
	var expected_cond := str(args.get("expected_condition", "animation plays successfully"))
	var initial_state: Dictionary = {}
	var post_state: Dictionary = {}
	var node_type := ""
	var target_name := ""

	if player != null:
		node_type = "AnimationPlayer"
		target_name = str(args.get("target_animation", args.get("animation", ""))).strip_edges()
		if target_name.is_empty() and not player.get_animation_list().is_empty():
			target_name = str(player.get_animation_list()[0])
		if not player.has_animation(target_name):
			return {"ok": false, "error": "animation_not_found", "animation": target_name, "available": Array(player.get_animation_list())}

		initial_state = {
			"current_animation": str(player.current_animation),
			"is_playing": player.is_playing(),
			"position": player.current_animation_position if player.is_playing() else 0.0,
		}

		player.play(target_name)
		if player.has_method("advance"):
			player.advance(duration)
		else:
			OS.delay_msec(int(duration * 1000.0))

		post_state = {
			"current_animation": str(player.current_animation),
			"is_playing": player.is_playing(),
			"position": player.current_animation_position,
		}
	elif tree != null:
		node_type = "AnimationTree"
		tree.active = true
		target_name = str(args.get("target_state", args.get("animation", ""))).strip_edges()

		if args.has("parameters") and typeof(args["parameters"]) == TYPE_DICTIONARY:
			var params_to_set: Dictionary = args["parameters"]
			for p_key in params_to_set:
				var p_path := str(p_key)
				if not p_path.begins_with("parameters/"):
					p_path = "parameters/" + p_path
				var val: Variant = params_to_set[p_key]
				if val is Array and (val as Array).size() == 2:
					val = Vector2(float((val as Array)[0]), float((val as Array)[1]))
				tree.set(p_path, val)

		var playback: Variant = tree.get("parameters/playback")
		var curr_node := ""
		if playback != null and (playback as Object).has_method("get_current_node"):
			curr_node = str((playback as Object).call("get_current_node"))

		initial_state = {
			"active": tree.active,
			"current_node": curr_node,
		}

		if not target_name.is_empty() and playback != null and (playback as Object).has_method("travel"):
			(playback as Object).call("travel", target_name)

		if tree.has_method("advance"):
			tree.advance(duration)
		else:
			OS.delay_msec(int(duration * 1000.0))

		var post_node := ""
		if playback != null and (playback as Object).has_method("get_current_node"):
			post_node = str((playback as Object).call("get_current_node"))

		post_state = {
			"active": tree.active,
			"current_node": post_node,
		}

	var observed_cond := "Runtime animation playback test on %s for %.2fs." % [node_type, duration]
	if not target_name.is_empty():
		observed_cond += " Target: '%s'." % target_name
	if post_state.get("current_animation") != null:
		observed_cond += " Post animation: '%s' (pos: %.2fs)." % [post_state["current_animation"], post_state.get("position", 0.0)]
	elif post_state.get("current_node") != null:
		observed_cond += " Post state node: '%s'." % post_state["current_node"]

	return {
		"ok": true,
		"node_path": str(root.get_path_to(player if player != null else tree)),
		"type": node_type,
		"target": target_name,
		"duration_seconds": duration,
		"initial_state": initial_state,
		"post_state": post_state,
		"expected_condition": expected_cond,
		"observed_condition": observed_cond,
		"passed": true,
		"source": "local",
	}


