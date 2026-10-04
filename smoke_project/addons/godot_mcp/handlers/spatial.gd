@tool
class_name MCPSpatialHandlers
extends RefCounted
## Domain handler: spatial observation (editor + runtime).

const Spatial := preload("../spatial_observe.gd")

var _router: MCPCommandRouter


func _init(router: MCPCommandRouter) -> void:
	_router = router


func register(handlers: Dictionary) -> void:
	handlers["cmd_spatial_observe"] = _cmd_spatial_observe


func _cmd_spatial_observe(params: Dictionary) -> Dictionary:
	var scope := str(params.get("scope", "editor")).to_lower()
	if scope == "runtime":
		return _observe_runtime(params)
	return _observe_editor(params)


func _observe_editor(params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _router._fail("PRECONDITION_FAILED", "No scene is open.", "active_scene")
	var root_path := str(params.get("root", "."))
	var found := _router._resolve(root_path)
	if not found["ok"]:
		return found
	var start: Node = found["node"]
	var depth := int(params.get("depth", 3))
	var include := Spatial.include_flags(params.get("include", ["transform", "bounds"]))
	var type_filter: Array = params.get("type_filter", [])
	if not (type_filter is Array):
		type_filter = []
	var path_filter := str(params.get("path_filter", ""))
	var objects := Spatial.walk_spatial(
		start, root, depth, include, type_filter, path_filter, false
	)
	var vp := EditorInterface.get_editor_viewport_2d()
	var viewport := Spatial.viewport_info(vp if vp else root.get_viewport())
	var camera := Spatial.camera_info(start)
	var body := {
		"scope": "editor",
		"root": root_path,
		"depth": depth,
		"viewport": viewport,
		"camera": camera,
		"objects": objects,
		"count": objects.size(),
		"screenshot": null,
	}
	if bool(params.get("screenshot", false)):
		# Caller can also use editor screenshot tools; keep null unless a grab is wired.
		body["screenshot_hint"] = "use godot_editor_capture_screenshot for editor pixels"
	return _router._ok(body)


func _observe_runtime(params: Dictionary) -> Dictionary:
	var guard := _router._require_live_probe()
	if not guard["ok"]:
		return guard
	var request_id := str(params.get("request_id", ""))
	if request_id.is_empty():
		return _router._fail("VALIDATION_ERROR", "'request_id' is required for runtime scope.")
	var payload := {
		"request_id": request_id,
		"root": str(params.get("root", "/root")),
		"depth": int(params.get("depth", 3)),
		"include": params.get("include", ["transform", "bounds"]),
		"type_filter": params.get("type_filter", []),
		"path_filter": str(params.get("path_filter", "")),
	}
	if _router._debugger.get_pending_spatial_request() != request_id:
		_router._debugger.begin_spatial_request(request_id)
		_router._debugger.send_to_probe("godot_mcp:spatial_observe", [payload])
	var cached: Variant = _router._debugger.get_spatial_observe()
	if cached is Dictionary and str((cached as Dictionary).get("request_id", "")) == request_id:
		var result: Dictionary = (cached as Dictionary).duplicate()
		result["scope"] = "runtime"
		if bool(params.get("screenshot", false)):
			result["screenshot_hint"] = "use godot_runtime_capture_game_screenshot last"
		return _router._ok(result)
	return _router._ok({"ready": false, "reason": "spatial_pending", "scope": "runtime"})
