@tool
extends RefCounted
## Durable, project-scoped foreground task state. user:// is per Godot project.

const STORE_PATH := "user://godot_agent/tasks.json"
const ACTIVE_STATES := ["planned", "running", "needs_confirmation", "needs_user"]
const READ_ONLY_TOOLS := [
	"inspect_project", "inspect_scene", "inspect_node", "list_files", "read_script",
	"get_diagnostics", "get_output_errors", "settings_get", "list_history", "web_search",
	"search_mcp_tools", "playtest_wait", "capture_viewport", "navigate_viewport",
	"inspect_asset_image", "inspect_scene_diff", "validate_tileset_physics",
	"measure_visual_bounds", "inspect_collision_geometry", "query_spatial_relationships",
	"inspect_spatial_context", "inspect_spatial_region", "convert_spatial_coordinates",
	"preview_spatial_overlay", "preview_collision_overlay", "inspect_tilemap_layer",
	"inspect_player_metrics", "test_runtime_action", "discover_capabilities",
	"inspect_animation_player", "inspect_animation_tracks", "inspect_animation_tree",
	"set_task_criteria", "invoke_level_designer", "list_tool_bundles", "unpack_tool_bundle",
	"pack_tool_bundle", "select_mcp_profile", "activate_mcp_tools"
]
const VERIFICATION_TOOLS := [
	"inspect_project", "inspect_scene", "inspect_node", "get_diagnostics", "get_output_errors",
	"read_script", "playtest_wait", "capture_viewport", "navigate_viewport",
	"inspect_scene_diff", "validate_tileset_physics", "measure_visual_bounds",
	"inspect_collision_geometry", "query_spatial_relationships", "inspect_spatial_context",
	"inspect_spatial_region", "inspect_tilemap_layer", "inspect_player_metrics",
	"preview_spatial_overlay", "preview_collision_overlay", "godot_runtime_run_and_capture"
]

static func is_read_only_tool(name: String) -> bool:
	if READ_ONLY_TOOLS.has(name):
		return true
	if name in ["set_task_criteria", "invoke_level_designer", "list_tool_bundles", "unpack_tool_bundle", "pack_tool_bundle", "select_mcp_profile", "activate_mcp_tools", "search_mcp_tools", "godot_health_check", "godot_describe_class"]:
		return true
	if name.begins_with("godot_inspection_") or name.begins_with("godot_project_get_") or name.begins_with("godot_project_search_") or name.begins_with("godot_project_resolve_") or name.begins_with("godot_scripts_read") or name.begins_with("godot_scripts_list") or name.begins_with("godot_scripts_get_") or name.begins_with("godot_analysis_") or name.begins_with("godot_runtime_capture_") or name.begins_with("godot_runtime_get_") or name.begins_with("godot_runtime_read_") or name.begins_with("godot_runtime_find_") or name.begins_with("godot_runtime_tree") or name.begins_with("godot_runtime_node_") or name.begins_with("godot_runtime_run_and_capture") or name.begins_with("godot_tilemap_get_") or name.begins_with("godot_tilemap_layers") or name.begins_with("godot_tilemap_tileset_inspect") or name.begins_with("godot_tilemap_tileset_atlas_inspect") or name.begins_with("godot_export_") or name.begins_with("godot_list_") or name.begins_with("godot_get_"):
		return true
	return false

static func is_verification_tool(name: String) -> bool:
	if VERIFICATION_TOOLS.has(name):
		return true
	if name in ["capture_viewport", "navigate_viewport", "inspect_asset_image", "get_output_errors", "get_diagnostics", "inspect_scene", "inspect_node", "inspect_project", "inspect_scene_diff", "validate_tileset_physics", "inspect_tilemap_layer", "inspect_player_metrics", "inspect_collision_geometry", "measure_visual_bounds", "query_spatial_relationships", "inspect_spatial_context", "inspect_spatial_region", "preview_spatial_overlay", "preview_collision_overlay", "godot_runtime_run_and_capture"]:
		return true
	if name.begins_with("godot_inspection_") or name.begins_with("godot_runtime_") or name.begins_with("godot_testing_") or name.begins_with("godot_profiling_") or name.begins_with("godot_analysis_") or name.begins_with("godot_spatial_observe"):
		return true
	return false

var tasks: Dictionary = {}

func _init() -> void:
	_load()
	for id in tasks:
		var task: Dictionary = tasks[id]
		task["session_started_at"] = 0.0
		if str(task.get("status", "")) in ACTIVE_STATES:
			task["status"] = "paused"
			task["blocker"] = "Editor restarted; resume explicitly."
			task["updated_at"] = Time.get_unix_time_from_system()
	_save()

func create(goal: String, agent_config: Dictionary = {}) -> Dictionary:
	var id := "task_%d_%d" % [Time.get_unix_time_from_system(), Time.get_ticks_msec() % 100000]
	var now := Time.get_unix_time_from_system()
	var task := {
		"id": id, "goal": goal, "status": "planned", "plan": [], "current_step": 0,
		"evidence": [], "changes": [], "failures": [], "blocker": "", "summary": "", "confirmation_token": "",
		"tags": {"files": [], "nodes": [], "tools": [], "outcome": ""}, "verification_pending": false,
		"criteria": [],
		"created_at": now, "updated_at": now, "started_at": now,
		"active_seconds": 0.0, "session_started_at": 0.0,
		"tool_calls": 0, "llm_rounds": 0,
		"budget": {"max_minutes": int(agent_config.get("task_max_minutes", 0)), "max_tool_calls": int(agent_config.get("task_max_tool_calls", 0)), "max_llm_rounds": int(agent_config.get("task_max_llm_rounds", 0))},
	}
	tasks[id] = task
	_save()
	return task.duplicate(true)

func get_task(id: String) -> Dictionary:
	var v: Variant = tasks.get(id, {})
	return v.duplicate(true) if typeof(v) == TYPE_DICTIONARY else {}

func list_tasks() -> Array:
	var out: Array = []
	for id in tasks: out.append(get_task(str(id)))
	out.sort_custom(func(a, b): return float(a.get("updated_at", 0)) > float(b.get("updated_at", 0)))
	return out

func set_plan(id: String, plan: Array) -> Dictionary:
	return _update(id, {"plan": plan, "status": "running", "blocker": "", "session_started_at": Time.get_unix_time_from_system()})

func set_criteria(id: String, criteria_list: Array) -> Dictionary:
	var t := get_task(id)
	if t.is_empty():
		t = create("Task " + id, {})
		t["id"] = id
		tasks[id] = t
	var cleaned: Array = []
	for c in criteria_list:
		if typeof(c) == TYPE_DICTIONARY:
			var cd: Dictionary = c
			var cid := str(cd.get("id", "crit_%d" % (cleaned.size() + 1)))
			cleaned.append({
				"id": cid,
				"description": str(cd.get("description", cd.get("name", cid))),
				"required_evidence": cd.get("required_evidence", []),
				"evidence_gathered": cd.get("evidence_gathered", []),
				"status": str(cd.get("status", "pending")),
				"uncertainty": str(cd.get("uncertainty", "")),
			})
	t["criteria"] = cleaned
	return _replace(id, t)

func update_criterion(id: String, criterion_id: String, status: String, evidence_item: Dictionary = {}, uncertainty: String = "") -> Dictionary:
	var t := get_task(id)
	if t.is_empty():
		t = create("Task " + id, {})
		t["id"] = id
		tasks[id] = t
	var criteria: Array = t.get("criteria", [])
	var found := false
	for i in criteria.size():
		var c: Dictionary = criteria[i]
		if str(c.get("id", "")) == criterion_id:
			c["status"] = status
			if not evidence_item.is_empty():
				var ev: Array = c.get("evidence_gathered", [])
				ev.append(evidence_item)
				c["evidence_gathered"] = ev
			if uncertainty != "":
				c["uncertainty"] = uncertainty
			criteria[i] = c
			found = true
			break
	if not found:
		criteria.append({
			"id": criterion_id,
			"description": criterion_id,
			"required_evidence": [],
			"evidence_gathered": [evidence_item] if not evidence_item.is_empty() else [],
			"status": status,
			"uncertainty": uncertainty,
		})
	t["criteria"] = criteria
	return _replace(id, t)

func get_criteria(id: String) -> Array:
	var t := get_task(id)
	return t.get("criteria", [])

func get_unverified_criteria(id: String) -> Array:
	var t := get_task(id)
	if not bool(t.get("verification_pending", false)):
		return []
	var criteria: Array = t.get("criteria", [])
	var unverified: Array = []
	for c in criteria:
		var st := str((c as Dictionary).get("status", "pending"))
		if st != "passed":
			unverified.append(c)
	return unverified

func set_status(id: String, status: String, blocker: String = "", summary: String = "") -> Dictionary:
	var patch := {"status": status, "blocker": blocker}
	if summary != "": patch["summary"] = summary
	var t := get_task(id)
	var now := Time.get_unix_time_from_system()
	var session_start := float(t.get("session_started_at", 0.0))
	var active_sec := float(t.get("active_seconds", 0.0))
	if status == "running":
		patch["session_started_at"] = now
		if str(t.get("status", "")) == "budget_exhausted":
			patch["active_seconds"] = 0.0
	else:
		if session_start > 0.0:
			active_sec += maxf(0.0, now - session_start)
			patch["active_seconds"] = active_sec
		patch["session_started_at"] = 0.0
	if status in ["succeeded", "failed", "cancelled", "budget_exhausted"]:
		patch["confirmation_token"] = ""
		var tags: Dictionary = t.get("tags", {})
		tags["outcome"] = status
		patch["tags"] = tags
	return _update(id, patch)

func set_confirmation(id: String, token: String, detail: String) -> Dictionary:
	return _update(id, {"status": "needs_confirmation", "confirmation_token": token, "blocker": detail})

func record_llm_round(id: String) -> Dictionary:
	var t := get_task(id)
	if t.is_empty():
		return {}
	t["llm_rounds"] = int(t.get("llm_rounds", 0)) + 1
	return _replace(id, t)

func record_tool(id: String, name: String, result: Dictionary) -> Dictionary:
	var t := get_task(id)
	if t.is_empty():
		return {}
	t["tool_calls"] = int(t.get("tool_calls", 0)) + 1
	var evidence: Array = t.get("evidence", [])
	evidence.append({"ts": Time.get_unix_time_from_system(), "tool": name, "ok": bool(result.get("ok", false)), "result": JSON.stringify(result).substr(0, 1600)})
	if evidence.size() > 40: evidence.pop_front()
	t["evidence"] = evidence
	var tags: Dictionary = t.get("tags", {})
	var tools: Array = tags.get("tools", [])
	if not tools.has(name): tools.append(name)
	tags["tools"] = tools
	var args: Dictionary = result.get("args", {}) if typeof(result.get("args", {})) == TYPE_DICTIONARY else {}
	for key in ["path", "file_path", "scene_path"]:
		var resource := str(args.get(key, ""))
		if resource != "": _append_tag(tags, "files", resource)
	var node_path := str(args.get("node_path", args.get("path", "")))
	if node_path.begins_with("/"): _append_tag(tags, "nodes", node_path)
	t["tags"] = tags
	if bool(result.get("ok", false)) and not (READ_ONLY_TOOLS.has(name) or is_read_only_tool(name)):
		t["verification_pending"] = true
	var postcond_ok := bool(result.get("postconditions_verified", true))
	var st_val := str(result.get("status", ""))
	if st_val in ["partially_applied", "failed", "rejected"] or not postcond_ok:
		t["verification_pending"] = true
	if bool(result.get("ok", false)) and (VERIFICATION_TOOLS.has(name) or is_verification_tool(name)):
		t["verification_pending"] = false
	if bool(result.get("ok", false)):
		var plan: Array = t.get("plan", [])
		t["current_step"] = mini(int(t.get("current_step", 0)) + 1, maxi(0, plan.size() - 1))
	else:
		var failures: Array = t.get("failures", [])
		failures.append({"tool": name, "error": str(result.get("error", "failed"))})
		if failures.size() > 10: failures.pop_front()
		t["failures"] = failures
	return _replace(id, t)

func can_succeed(id: String) -> bool:
	var task := get_task(id)
	if task.is_empty():
		return false
	return not bool(task.get("verification_pending", false))

func _append_tag(tags: Dictionary, key: String, value: String) -> void:
	var values: Array = tags.get(key, [])
	if not values.has(value): values.append(value)
	tags[key] = values

func budget_exhausted(id: String) -> String:
	var t := get_task(id)
	if t.is_empty():
		return "missing_task"
	var budget: Dictionary = t.get("budget", {})
	var max_tools := int(budget.get("max_tool_calls", 0))
	if max_tools > 0 and int(t.get("tool_calls", 0)) >= max_tools: return "tool_call_budget"
	var max_rounds := int(budget.get("max_llm_rounds", 0))
	if max_rounds > 0 and int(t.get("llm_rounds", 0)) >= max_rounds: return "llm_round_budget"
	# Time budget completely disabled: tasks are never interrupted by elapsed time.
	return ""

func _update(id: String, patch: Dictionary) -> Dictionary:
	var t := get_task(id)
	if t.is_empty():
		return {}
	for key in patch: t[key] = patch[key]
	return _replace(id, t)

func _replace(id: String, task: Dictionary) -> Dictionary:
	task["updated_at"] = Time.get_unix_time_from_system()
	tasks[id] = task
	_save()
	return task.duplicate(true)

func _load() -> void:
	if not FileAccess.file_exists(STORE_PATH): return
	var f := FileAccess.open(STORE_PATH, FileAccess.READ)
	if f == null: return
	var parsed: Variant = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY: tasks = parsed

func _save() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(STORE_PATH.get_base_dir()))
	var f := FileAccess.open(STORE_PATH, FileAccess.WRITE)
	if f != null: f.store_string(JSON.stringify(tasks)); f.close()
