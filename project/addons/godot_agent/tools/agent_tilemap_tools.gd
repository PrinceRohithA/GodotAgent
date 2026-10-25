@tool
extends RefCounted
## Specialized modular tool handler for TileMapLayer and Atlas Toolkit in GodotAgent.

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


