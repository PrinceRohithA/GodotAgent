@tool
class_name MCPSpatialObserve
extends RefCounted
## Canonical SpatialObject builder (editor + runtime). Never invents bounds.
##
## Geometry sources (hard rule):
##   Sprite2D → get_rect(); Control → get_rect(); CollisionShape2D → Shape2D where
##   supported; CollisionPolygon2D / Polygon2D → polygon; else unavailable.

const Coerce := preload("./type_coerce.gd")


static func build_spatial_object(
	node: Node,
	scene_root: Node,
	include: Dictionary,
	path_override: String = ""
) -> Dictionary:
	var path := path_override
	if path.is_empty():
		if scene_root != null and (node == scene_root or scene_root.is_ancestor_of(node)):
			path = _relative_or_abs(node, scene_root)
		else:
			path = str(node.get_path()) if node.is_inside_tree() else String(node.name)
	var parent_path := ""
	if node.get_parent() != null:
		var p: Node = node.get_parent()
		if scene_root != null and (p == scene_root or scene_root.is_ancestor_of(p)):
			parent_path = _relative_or_abs(p, scene_root)
		elif p.is_inside_tree():
			parent_path = str(p.get_path())
		else:
			parent_path = String(p.name)

	var obj: Dictionary = {
		"path": path,
		"type": node.get_class(),
		"parent": parent_path,
	}

	if bool(include.get("transform", true)):
		obj["transform"] = _build_transform(node)

	var want_bounds := bool(include.get("bounds", true))
	if want_bounds or bool(include.get("visual", false)):
		var geom := _build_geometry(node)
		obj["geometry"] = geom
		if bool(include.get("visual", false)):
			obj["visual"] = _build_visual(node, geom)

	if bool(include.get("collision", false)):
		obj["collision"] = _build_collision(node)

	if bool(include.get("runtime", false)):
		obj["runtime"] = _build_runtime(node)

	return obj


static func walk_spatial(
	root: Node,
	scene_root: Node,
	depth: int,
	include: Dictionary,
	type_filter: Array,
	path_filter: String,
	use_absolute_paths: bool = false
) -> Array:
	var out: Array = []
	_walk(root, scene_root, depth, 0, include, type_filter, path_filter, use_absolute_paths, out)
	return out


static func _walk(
	node: Node,
	scene_root: Node,
	max_depth: int,
	cur: int,
	include: Dictionary,
	type_filter: Array,
	path_filter: String,
	use_absolute_paths: bool,
	out: Array
) -> void:
	var path := str(node.get_path()) if use_absolute_paths and node.is_inside_tree() else _relative_or_abs(node, scene_root)
	var type_ok := type_filter.is_empty() or type_filter.has(node.get_class())
	var path_ok := path_filter.is_empty() or path.contains(path_filter) or path.matchn("*" + path_filter + "*")
	if type_ok and path_ok:
		var path_arg := path if use_absolute_paths else ""
		out.append(build_spatial_object(node, scene_root, include, path_arg if use_absolute_paths else ""))
	if max_depth >= 0 and cur >= max_depth:
		return
	for child in node.get_children():
		if child is Node:
			_walk(child, scene_root, max_depth, cur + 1, include, type_filter, path_filter, use_absolute_paths, out)


static func viewport_info(viewport: Viewport) -> Dictionary:
	if viewport == null:
		return {}
	var size := viewport.get_visible_rect().size
	return {"width": int(size.x), "height": int(size.y)}


static func camera_info(from_node: Node) -> Dictionary:
	if from_node == null:
		return {}
	# Prefer Camera2D in subtree / viewport.
	var cam2d: Camera2D = null
	if from_node is Camera2D:
		cam2d = from_node
	else:
		cam2d = from_node.get_viewport().get_camera_2d() if from_node.is_inside_tree() else null
	if cam2d != null:
		return {
			"type": "Camera2D",
			"position": {"x": cam2d.global_position.x, "y": cam2d.global_position.y},
			"rotation": cam2d.global_rotation,
			"zoom": {"x": cam2d.zoom.x, "y": cam2d.zoom.y},
			"transform": Coerce.to_json(cam2d.global_transform),
		}
	var cam3d: Camera3D = null
	if from_node is Camera3D:
		cam3d = from_node
	elif from_node.is_inside_tree():
		cam3d = from_node.get_viewport().get_camera_3d()
	if cam3d != null:
		return {
			"type": "Camera3D",
			"position": {
				"x": cam3d.global_position.x,
				"y": cam3d.global_position.y,
				"z": cam3d.global_position.z,
			},
			"transform": Coerce.to_json(cam3d.global_transform),
		}
	return {}


static func include_flags(raw: Variant) -> Dictionary:
	var flags := {
		"transform": true,
		"bounds": true,
		"visual": false,
		"collision": false,
		"runtime": false,
	}
	if raw is Array:
		for item in raw:
			var key := str(item)
			if flags.has(key):
				flags[key] = true
		# If caller listed includes, only enable listed + transform default when named.
		if not (raw as Array).is_empty():
			flags = {
				"transform": (raw as Array).has("transform"),
				"bounds": (raw as Array).has("bounds"),
				"visual": (raw as Array).has("visual"),
				"collision": (raw as Array).has("collision"),
				"runtime": (raw as Array).has("runtime"),
			}
			if not flags["transform"] and not flags["bounds"] and not flags["visual"] \
					and not flags["collision"] and not flags["runtime"]:
				flags["transform"] = true
				flags["bounds"] = true
	return flags


# -- transform ---------------------------------------------------------------

static func _build_transform(node: Node) -> Dictionary:
	if node is Node2D:
		var n2: Node2D = node
		return {
			"local": {
				"position": [n2.position.x, n2.position.y],
				"rotation": n2.rotation,
				"scale": [n2.scale.x, n2.scale.y],
				"skew": n2.skew,
				"transform": Coerce.to_json(n2.transform),
			},
			"global": {
				"position": [n2.global_position.x, n2.global_position.y],
				"rotation": n2.global_rotation,
				"scale": [n2.global_scale.x, n2.global_scale.y],
				"transform": Coerce.to_json(n2.global_transform),
			},
		}
	if node is Control:
		var c: Control = node
		var gp := c.global_position
		return {
			"local": {
				"position": [c.position.x, c.position.y],
				"rotation": c.rotation,
				"scale": [c.scale.x, c.scale.y],
				"transform": Coerce.to_json(c.get_transform()),
			},
			"global": {
				"position": [gp.x, gp.y],
				"rotation": c.rotation,  # Control has no separate global_rotation in all versions
				"scale": [c.scale.x, c.scale.y],
				"transform": Coerce.to_json(c.get_global_transform()),
			},
		}
	if node is Node3D:
		var n3: Node3D = node
		# Prefer transform decomposition — Node3D.global_scale is not a Vector3
		# property in all 4.x builds (can resolve as Callable).
		var p_l: Vector3 = n3.position
		var r_l: Vector3 = n3.rotation
		var s_l: Vector3 = n3.scale
		var p_g: Vector3 = n3.global_position
		var r_g: Vector3 = n3.global_rotation
		var s_g: Vector3 = n3.global_transform.basis.get_scale()
		var pos_l: Array = [p_l.x, p_l.y, p_l.z]
		var rot_l: Array = [r_l.x, r_l.y, r_l.z]
		var scl_l: Array = [s_l.x, s_l.y, s_l.z]
		var pos_g: Array = [p_g.x, p_g.y, p_g.z]
		var rot_g: Array = [r_g.x, r_g.y, r_g.z]
		var scl_g: Array = [s_g.x, s_g.y, s_g.z]
		var xf_l: Variant = Coerce.to_json(n3.transform)
		var xf_g: Variant = Coerce.to_json(n3.global_transform)
		return {
			"local": {
				"position": pos_l,
				"rotation": rot_l,
				"scale": scl_l,
				"transform": xf_l,
			},
			"global": {
				"position": pos_g,
				"rotation": rot_g,
				"scale": scl_g,
				"transform": xf_g,
			},
		}
	return {}


# -- geometry ----------------------------------------------------------------

static func _build_geometry(node: Node) -> Dictionary:
	var local_corners: PackedVector2Array = PackedVector2Array()
	var source := ""
	var xform := Transform2D.IDENTITY

	if node is Sprite2D:
		var spr: Sprite2D = node
		var r := spr.get_rect()
		local_corners = _rect_corners(r)
		source = "Sprite2D.get_rect"
		xform = spr.global_transform
	elif node is Control:
		var ctrl: Control = node
		var r2 := ctrl.get_rect()
		local_corners = _rect_corners(r2)
		source = "Control.get_rect"
		xform = ctrl.get_global_transform()
	elif node is CollisionShape2D:
		var cs: CollisionShape2D = node
		var derived := _shape2d_local_corners(cs.shape)
		if derived.is_empty():
			return {
				"available": false,
				"reason": "unsupported_shape",
				"shape_type": cs.shape.get_class() if cs.shape else "null",
			}
		local_corners = derived
		source = "CollisionShape2D.shape"
		xform = cs.global_transform
	elif node is CollisionPolygon2D:
		var cp: CollisionPolygon2D = node
		if cp.polygon.is_empty():
			return {"available": false, "reason": "empty_polygon"}
		local_corners = cp.polygon
		source = "CollisionPolygon2D.polygon"
		xform = cp.global_transform
	elif node is Polygon2D:
		var poly: Polygon2D = node
		if poly.polygon.is_empty():
			return {"available": false, "reason": "empty_polygon"}
		local_corners = poly.polygon
		source = "Polygon2D.polygon"
		xform = poly.global_transform
	else:
		# Transform-capable nodes without geometry still report unavailable.
		return {"available": false, "reason": "unsupported_type"}

	var world: PackedVector2Array = PackedVector2Array()
	for p in local_corners:
		world.append(xform * p)
	var local_aabb := _aabb_from_points(local_corners)
	var global_aabb := _aabb_from_points(world)
	var pivot := xform.origin
	var center := Vector2(
		global_aabb.x + global_aabb.width * 0.5,
		global_aabb.y + global_aabb.height * 0.5
	)
	return {
		"available": true,
		"source": source,
		"pivot": [pivot.x, pivot.y],
		"center": [center.x, center.y],
		"local_aabb": local_aabb,
		"global_aabb": global_aabb,
		"world_corners": _points_to_arrays(world),
	}


static func _shape2d_local_corners(shape: Shape2D) -> PackedVector2Array:
	if shape == null:
		return PackedVector2Array()
	if shape is RectangleShape2D:
		var rs: RectangleShape2D = shape
		var hx := rs.size.x * 0.5
		var hy := rs.size.y * 0.5
		return PackedVector2Array([
			Vector2(-hx, -hy), Vector2(hx, -hy), Vector2(hx, hy), Vector2(-hx, hy)
		])
	if shape is CircleShape2D:
		var cir: CircleShape2D = shape
		var r := cir.radius
		# Axis-aligned extents of circle (corners of AABB in local space).
		return PackedVector2Array([
			Vector2(-r, -r), Vector2(r, -r), Vector2(r, r), Vector2(-r, r)
		])
	if shape is CapsuleShape2D:
		var cap: CapsuleShape2D = shape
		var hx2 := cap.radius
		var hy2 := cap.height * 0.5 + cap.radius
		return PackedVector2Array([
			Vector2(-hx2, -hy2), Vector2(hx2, -hy2), Vector2(hx2, hy2), Vector2(-hx2, hy2)
		])
	if shape is ConvexPolygonShape2D:
		return (shape as ConvexPolygonShape2D).points
	if shape is ConcavePolygonShape2D:
		# Segments packed; approximate via all points.
		var segs: PackedVector2Array = (shape as ConcavePolygonShape2D).segments
		return segs
	return PackedVector2Array()


static func _rect_corners(r: Rect2) -> PackedVector2Array:
	return PackedVector2Array([
		r.position,
		r.position + Vector2(r.size.x, 0),
		r.position + r.size,
		r.position + Vector2(0, r.size.y),
	])


static func _aabb_from_points(points: PackedVector2Array) -> Dictionary:
	if points.is_empty():
		return {"x": 0.0, "y": 0.0, "width": 0.0, "height": 0.0}
	var min_v := points[0]
	var max_v := points[0]
	for p in points:
		min_v.x = minf(min_v.x, p.x)
		min_v.y = minf(min_v.y, p.y)
		max_v.x = maxf(max_v.x, p.x)
		max_v.y = maxf(max_v.y, p.y)
	return {
		"x": min_v.x,
		"y": min_v.y,
		"width": max_v.x - min_v.x,
		"height": max_v.y - min_v.y,
	}


static func _points_to_arrays(points: PackedVector2Array) -> Array:
	var out: Array = []
	for p in points:
		out.append([p.x, p.y])
	return out


static func _build_visual(node: Node, geom: Dictionary) -> Dictionary:
	var vis: Dictionary = {"visible": true}
	if node is CanvasItem:
		var ci: CanvasItem = node
		vis["visible"] = ci.visible
		vis["z_index"] = ci.z_index
	if geom.get("available", false):
		vis["bounds"] = {
			"global_aabb": geom.get("global_aabb", {}),
			"world_corners": geom.get("world_corners", []),
		}
	return vis


static func _build_collision(node: Node) -> Dictionary:
	var shapes: Array = []
	# Self if collision shape/polygon.
	if node is CollisionShape2D or node is CollisionPolygon2D:
		var g := _build_geometry(node)
		shapes.append({
			"type": node.get_class(),
			"path": String(node.name),
			"global_aabb": g.get("global_aabb", {}),
			"world_corners": g.get("world_corners", []),
			"available": g.get("available", false),
		})
	# Children collision shapes (e.g. under StaticBody2D).
	for child in node.get_children():
		if child is CollisionShape2D or child is CollisionPolygon2D:
			var cg := _build_geometry(child)
			shapes.append({
				"type": child.get_class(),
				"path": String(child.name),
				"global_aabb": cg.get("global_aabb", {}),
				"world_corners": cg.get("world_corners", []),
				"available": cg.get("available", false),
				"reason": cg.get("reason", ""),
			})
	return {"shapes": shapes}


static func build_runtime_fields(node: Node) -> Dictionary:
	return _build_runtime(node)


static func _build_runtime(node: Node) -> Dictionary:
	var rt: Dictionary = {}
	if node is CharacterBody2D:
		var cb: CharacterBody2D = node
		rt["velocity"] = [cb.velocity.x, cb.velocity.y]
		rt["is_on_floor"] = cb.is_on_floor()
		rt["is_on_wall"] = cb.is_on_wall()
		rt["is_on_ceiling"] = cb.is_on_ceiling()
	elif node is RigidBody2D:
		var rb: RigidBody2D = node
		rt["linear_velocity"] = [rb.linear_velocity.x, rb.linear_velocity.y]
		rt["angular_velocity"] = rb.angular_velocity
	if node is AnimatedSprite2D:
		var anim: AnimatedSprite2D = node
		rt["animation"] = String(anim.animation)
		rt["frame"] = anim.frame
		rt["playing"] = anim.is_playing()
	if node is AnimationPlayer:
		var ap: AnimationPlayer = node
		rt["current_animation"] = ap.current_animation
		rt["is_playing"] = ap.is_playing()
	return rt


static func _relative_or_abs(node: Node, scene_root: Node) -> String:
	if scene_root == null:
		return str(node.get_path()) if node.is_inside_tree() else String(node.name)
	if node == scene_root:
		return "."
	return str(scene_root.get_path_to(node))
