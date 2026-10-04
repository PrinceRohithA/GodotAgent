@tool
class_name MCPAuthoringAudit
extends RefCounted
## Dual-layer authoring enforcement: track MCP scene/settings touches and
## refuse play when ``.tscn`` / ``.scn`` / ``project.godot`` advanced on disk
## without a matching MCP authoring op (host Write bypass).

const PROJECT_GODOT := "res://project.godot"

## path → modified_time recorded at session start (or first ensure_baseline).
var _baseline: Dictionary = {}
## path → modified_time after last MCP authoring touch.
var _mcp_touch: Dictionary = {}
var _baseline_ready: bool = false


func ensure_baseline() -> void:
	if _baseline_ready:
		return
	_baseline.clear()
	_collect_protected_paths("res://", _baseline)
	if FileAccess.file_exists(PROJECT_GODOT):
		_baseline[PROJECT_GODOT] = FileAccess.get_modified_time(PROJECT_GODOT)
	_baseline_ready = true


func reset_session() -> void:
	_baseline.clear()
	_mcp_touch.clear()
	_baseline_ready = false
	ensure_baseline()


func record_mcp_touch(path: String) -> void:
	if path.is_empty():
		return
	ensure_baseline()
	var normalized := PROJECT_GODOT if path == "project.godot" else path
	if FileAccess.file_exists(normalized):
		_mcp_touch[normalized] = FileAccess.get_modified_time(normalized)
	else:
		_mcp_touch[normalized] = int(Time.get_unix_time_from_system())


func record_project_settings_touch() -> void:
	record_mcp_touch(PROJECT_GODOT)


func is_protected_path(path: String) -> bool:
	if path.ends_with(".tscn") or path.ends_with(".scn"):
		return true
	if path == PROJECT_GODOT or path.ends_with("/project.godot"):
		return true
	return false


func protected_write_refusal(path: String) -> String:
	if not is_protected_path(path):
		return ""
	if path.ends_with(".tscn") or path.ends_with(".scn"):
		return (
			"Raw writes to .tscn/.scn are forbidden. Use godot_scene_edit_create_scene, "
			+ "godot_scene_edit_create_node, godot_scene_edit_attach_script, then "
			+ "godot_scene_edit_save_scene (or instance_scene / extract_scene for prefabs)."
		)
	return (
		"Raw writes to project.godot are forbidden. Use godot_project_set_setting "
		+ "and godot_input_map_* tools."
	)


## Returns empty Dictionary when OK; otherwise a fail body from the router.
func audit_for_play(router: Object) -> Dictionary:
	ensure_baseline()
	var offenders: Array = []
	var current: Dictionary = {}
	_collect_protected_paths("res://", current)
	if FileAccess.file_exists(PROJECT_GODOT):
		current[PROJECT_GODOT] = FileAccess.get_modified_time(PROJECT_GODOT)
	for path in current.keys():
		var now_mtime: int = int(current[path])
		var base_mtime: int = int(_baseline.get(path, 0))
		var mcp_mtime: int = int(_mcp_touch.get(path, -1))
		if mcp_mtime >= 0:
			if now_mtime > mcp_mtime + 1:
				offenders.append(path)
			continue
		if not _baseline.has(path) or now_mtime > base_mtime:
			offenders.append(path)
	if offenders.is_empty():
		return {}
	var listed := ", ".join(offenders.slice(0, mini(8, offenders.size())))
	if offenders.size() > 8:
		listed += " (+%d more)" % (offenders.size() - 8)
	return router._fail(
		"PRECONDITION_FAILED",
		(
			"raw_scene_or_settings_edit: disk changes to scene/settings files without MCP "
			+ "authoring ops: %s. Use scene_edit / project / input_map tools, then retry play."
			% listed
		),
		"raw_scene_or_settings_edit",
	)


func _skip_dir(path: String) -> bool:
	return path.begins_with("res://addons") or path.begins_with("res://.godot")


func _collect_protected_paths(directory: String, out: Dictionary) -> void:
	var dir := DirAccess.open(directory)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if not name.begins_with("."):
			var full := directory.path_join(name)
			if dir.current_is_dir():
				if not _skip_dir(full):
					_collect_protected_paths(full, out)
			elif name.ends_with(".tscn") or name.ends_with(".scn"):
				out[full] = FileAccess.get_modified_time(full)
		name = dir.get_next()
	dir.list_dir_end()
