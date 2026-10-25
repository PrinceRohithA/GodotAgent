@tool
extends RefCounted
## Specialized modular tool handler for Spatial Awareness and Collision Calibration in GodotAgent.

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


