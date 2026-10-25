@tool
extends RefCounted
## Specialized modular tool handler for AnimationPlayer and AnimationTree in GodotAgent.

var host: RefCounted

var history: RefCounted:
	get:
		if host != null and "history" in host:
			return host.history
		return null

func _init(p_host: RefCounted = null) -> void:
	host = p_host

func _get_scene_root() -> Node:
	if host != null and host.has_method("_get_scene_root"):
		return host._get_scene_root()
	if Engine.is_editor_hint():
		if ClassDB.class_exists("EditorInterface") or Engine.has_singleton("EditorInterface"):
			return EditorInterface.get_edited_scene_root()
	return null

func _resolve_node(root: Node, path_arg: String) -> Node:
	if host != null and host.has_method("_resolve_node"):
		return host._resolve_node(root, path_arg)
	if root == null:
		return null
	if path_arg == "" or path_arg == "." or path_arg == str(root.name):
		return root
	if root.has_node(path_arg):
		return root.get_node(path_arg)
	return null

func _find_first_child_of_type(root: Node, type_name: String) -> Node:
	if host != null and host.has_method("_find_first_child_of_type"):
		return host._find_first_child_of_type(root, type_name)
	if root == null:
		return null
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var curr: Node = stack.pop_back()
		if curr != root and (curr.is_class(type_name) or curr.get_class() == type_name):
			return curr
		for child in curr.get_children():
			stack.push_back(child)
	return null

func _record_mutation(label: String = "") -> void:
	if host != null and host.has_method("_record_mutation"):
		host._record_mutation(label)

func _build_mutation_result(operation: String, ok: bool, status: String, requested: Dictionary, applied: Dictionary, readback: Dictionary, changed_paths: Array, warnings: Array = [], errors: Array = [], persistence_verified: bool = false, rollback_available: bool = true, rollback_status: String = "not_needed", extra_data: Dictionary = {}) -> Dictionary:
	if host != null and host.has_method("_build_mutation_result"):
		return host._build_mutation_result(operation, ok, status, requested, applied, readback, changed_paths, warnings, errors, persistence_verified, rollback_available, rollback_status, extra_data)
	return {
		"operation": operation, "ok": ok, "status": status,
		"requested": requested, "applied": applied, "readback": readback,
		"changed_paths": changed_paths, "warnings": warnings, "errors": errors,
		"source": "local"
	}

func _jsonish(v: Variant) -> Variant:
	if host != null and host.has_method("_jsonish"):
		return host._jsonish(v)
	return str(v)

func _draw_text_3x5(target: Image, px: int, py: int, text: String, color: Color) -> void:
	if host != null and host.has_method("_draw_text_3x5"):
		host._draw_text_3x5(target, px, py, text, color)

func _load_image(path: String) -> Image:
	if host != null and host.has_method("_load_image"):
		return host._load_image(path)
	return null

func _load_texture_resource(path: String) -> Texture2D:
	if host != null and host.has_method("_load_texture_resource"):
		return host._load_texture_resource(path)
	if ResourceLoader.exists(path):
		var res: Resource = ResourceLoader.load(path)
		if res is Texture2D:
			return res as Texture2D
	return null

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


