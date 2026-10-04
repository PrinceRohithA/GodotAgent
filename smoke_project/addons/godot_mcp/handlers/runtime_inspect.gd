@tool
class_name MCPRuntimeInspectHandlers
extends RefCounted
## Domain handler: runtime inspect.
##
## Registered by the router on _init().  Each handler receives params dict and
## returns a response body (without id) via the router's _ok / _fail builders.

var _router: MCPCommandRouter


func _init(router: MCPCommandRouter) -> void:
	_router = router


func register(handlers: Dictionary) -> void:
	handlers["cmd_find_ui_elements"] = _cmd_find_ui_elements
	handlers["cmd_get_property_samples"] = _cmd_get_property_samples
	handlers["cmd_monitor_property"] = _cmd_monitor_property
	handlers["cmd_read_property"] = _cmd_read_property
	handlers["cmd_runtime_tree"] = _cmd_runtime_tree
	handlers["cmd_runtime_node_inspect"] = _cmd_runtime_node_inspect
	handlers["cmd_write_property"] = _cmd_write_property


# -- handlers ----------------------------------------------------------------

func _cmd_monitor_property(params: Dictionary) -> Dictionary:
	var guard := _router._require_live_probe()
	if not guard["ok"]:
		return guard
	var node_path := str(params.get("node_path", ""))
	var property := str(params.get("property", ""))
	if node_path.is_empty() or property.is_empty():
		return _router._fail("VALIDATION_ERROR", "'node_path' and 'property' are required.")
	var samples := clampi(int(params.get("samples", 30)), 1, 300)
	# #536 push-on-change sampling defaults on; the probe dedupes unchanged values
	# (epsilon-tolerant for floats) unless the caller pins the legacy behavior.
	var on_change_only := bool(params.get("on_change_only", true))
	var epsilon := float(params.get("epsilon", 0.0001))
	_router._debugger.clear_property_samples()  # drop any prior capture so get_ reflects this one
	_router._debugger.send_to_probe("godot_mcp:monitor_property", [{
		"node_path": node_path, "property": property, "samples": samples,
		"on_change_only": on_change_only, "epsilon": epsilon,
	}])
	return _router._ok({
		"monitoring": true, "node_path": node_path, "property": property, "samples": samples,
		"on_change_only": on_change_only, "epsilon": epsilon,
	})



func _cmd_get_property_samples(_params: Dictionary) -> Dictionary:
	if _router._debugger == null or not _router._debugger.is_connected_to_probe():
		return _router._ok({"ready": false, "connected": false, "samples": []})
	var payload: Variant = _router._debugger.get_property_samples()
	if payload == null:
		# #459: the monitor is registered but no sample batch has landed yet.
		return _router._ok({
			"ready": false, "connected": true, "samples": [], "reason": "capture_pending",
		})
	var result: Dictionary = (payload as Dictionary).duplicate()
	result["connected"] = true
	return _router._ok(result)



# #571: dedicated one-shot read — reads the live value NOW via the probe's
# read_property message and never touches the monitor slot, so a one-shot
# assert (assert_node_state) cannot replace a running monitor_property capture.
# Same request_id + poll pattern as find_ui_elements: the reply lands in the
# debugger cache on a later frame via _capture; the caller polls until ready.
func _cmd_read_property(params: Dictionary) -> Dictionary:
	var guard := _router._require_live_probe()
	if not guard["ok"]:
		return guard
	var node_path := str(params.get("node_path", ""))
	var property := str(params.get("property", ""))
	if node_path.is_empty() or property.is_empty():
		return _router._fail("VALIDATION_ERROR", "'node_path' and 'property' are required.")
	var request_id := str(params.get("request_id", ""))
	if request_id.is_empty():
		return _router._fail("VALIDATION_ERROR", "'request_id' is required.")
	if _router._debugger.get_pending_read_request() != request_id:
		_router._debugger.begin_read_request(request_id)
		_router._debugger.send_to_probe("godot_mcp:read_property", [{
			"node_path": node_path, "property": property, "request_id": request_id,
		}])
	var payload: Variant = _router._debugger.get_read_property()
	# Qodo review (#575): belt-and-braces id match — the cache is already gated
	# on the pending request_id in _capture; re-verify here so a stale reply can
	# never be served as this request's result.
	if payload is Dictionary and (payload as Dictionary).get("request_id") == request_id:
		return _router._ok(payload)
	# #459: dispatched to the probe; the reply lands on a later frame.
	return _router._ok({"ready": false, "reason": "read_pending"})



func _cmd_find_ui_elements(params: Dictionary) -> Dictionary:
	var guard := _router._require_live_probe()
	if not guard["ok"]:
		return guard
	# Each tool invocation carries a stable request_id (constant across its poll loop). We
	# dispatch the (expensive) full-Control scan to the probe exactly once per request_id
	# and match the cached result by that id — so repeated polls don't re-scan, and reusing
	# identical filters can't return a prior request's stale result.
	var request_id := str(params.get("request_id", ""))
	var payload: Variant = _router._debugger.get_ui_elements()
	if payload is Dictionary and (payload as Dictionary).get("request_id") == request_id:
		return _router._ok({"ready": true, "elements": (payload as Dictionary).get("elements", [])})
	if _router._debugger.get_pending_ui_request() != request_id:
		_router._debugger.begin_ui_request(request_id)
		_router._debugger.send_to_probe("godot_mcp:find_ui", [{
			"name_contains": str(params.get("name_contains", "")),
			"class_filter": str(params.get("class_filter", "")),
			"visible_only": bool(params.get("visible_only", false)),
			"request_id": request_id,
		}])
	# #459: the scan is dispatched to the probe and runs over the next frames.
	return _router._ok({"ready": false, "elements": [], "reason": "scan_in_flight"})


func _cmd_runtime_tree(params: Dictionary) -> Dictionary:
	var guard := _router._require_live_probe()
	if not guard["ok"]:
		return guard
	# request_id poll: do not reuse the warm scene_tree cache from probe ready —
	# that overwrote filtered runtime_tree replies historically.
	var request_id := str(params.get("request_id", ""))
	if request_id.is_empty():
		return _router._fail("VALIDATION_ERROR", "'request_id' is required.")
	if _router._debugger.get_pending_runtime_tree_request() != request_id:
		_router._debugger.begin_runtime_tree_request(request_id)
		_router._debugger.send_to_probe("godot_mcp:runtime_tree", [{
			"request_id": request_id,
			"root": str(params.get("root", "/root")),
			"depth": int(params.get("depth", 32)),
			"type_filter": params.get("type_filter", []),
			"path_filter": str(params.get("path_filter", "")),
		}])
	var cached: Variant = _router._debugger.get_runtime_tree()
	if cached is Dictionary and str((cached as Dictionary).get("request_id", "")) == request_id:
		return _router._ok({
			"ready": true,
			"connected": true,
			"playing": EditorInterface.is_playing_scene(),
			"tree": (cached as Dictionary).get("tree"),
			"request_id": request_id,
		})
	return _router._ok({
		"ready": false,
		"connected": true,
		"tree": null,
		"reason": "tree_pending",
		"request_id": request_id,
	})


func _cmd_runtime_node_inspect(params: Dictionary) -> Dictionary:
	var guard := _router._require_live_probe()
	if not guard["ok"]:
		return guard
	var path := str(params.get("path", params.get("node_path", "")))
	if path.is_empty():
		return _router._fail("VALIDATION_ERROR", "'path' is required.")
	var request_id := str(params.get("request_id", ""))
	if request_id.is_empty():
		return _router._fail("VALIDATION_ERROR", "'request_id' is required.")
	if _router._debugger.get_pending_runtime_node_request() != request_id:
		_router._debugger.begin_runtime_node_request(request_id)
		_router._debugger.send_to_probe("godot_mcp:runtime_node_inspect", [{
			"request_id": request_id,
			"path": path,
			"include": params.get("include", ["properties", "transform", "children"]),
		}])
	var cached: Variant = _router._debugger.get_runtime_node_inspect()
	if cached is Dictionary and str((cached as Dictionary).get("request_id", "")) == request_id:
		return _router._ok(cached)
	return _router._ok({"ready": false, "reason": "inspect_pending", "path": path})


func _cmd_write_property(params: Dictionary) -> Dictionary:
	var guard := _router._require_live_probe()
	if not guard["ok"]:
		return guard
	var node_path := str(params.get("node_path", params.get("path", "")))
	var property := str(params.get("property", ""))
	if node_path.is_empty() or property.is_empty():
		return _router._fail("VALIDATION_ERROR", "'node_path' and 'property' are required.")
	if not params.has("value"):
		return _router._fail("VALIDATION_ERROR", "'value' is required.")
	var request_id := str(params.get("request_id", "x"))
	_router._debugger.send_to_probe("godot_mcp:write_property", [{
		"request_id": request_id,
		"node_path": node_path,
		"property": property,
		"value": params.get("value"),
	}])
	# Fire-and-acknowledge: probe replies sync in same capture turn when possible;
	# for honesty report accepted and let agent re-read.
	return _router._ok({
		"accepted": true,
		"path": node_path,
		"property": property,
		"hint": "Re-read with runtime_get_property / read_property to verify.",
	})


