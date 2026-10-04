@tool
class_name MCPTileSetHandlers
extends RefCounted
## Domain handler: tileset (TileSet / TileData / AtlasSource / ScenesCollection).
##
## TileMapLayer-first: new TileSet gameplay ops accept TileMapLayer or .tres.
## Deprecated TileMap remains readable as a TileSet target for one compat cycle.

var _router: MCPCommandRouter


func _init(router: MCPCommandRouter) -> void:
	_router = router


func register(handlers: Dictionary) -> void:
	handlers["cmd_add_tileset_atlas_source"] = _cmd_add_tileset_atlas_source
	handlers["cmd_create_tile"] = _cmd_create_tile
	handlers["cmd_create_tileset"] = _cmd_create_tileset
	handlers["cmd_tileset_inspect"] = _cmd_tileset_inspect
	handlers["cmd_tileset_atlas_inspect"] = _cmd_tileset_atlas_inspect
	handlers["cmd_get_tile_data"] = _cmd_get_tile_data
	handlers["cmd_add_tileset_physics_layer"] = _cmd_add_tileset_physics_layer
	handlers["cmd_set_tile_collision"] = _cmd_set_tile_collision
	handlers["cmd_clear_tile_collision"] = _cmd_clear_tile_collision
	handlers["cmd_add_tileset_custom_data_layer"] = _cmd_add_tileset_custom_data_layer
	handlers["cmd_set_tile_custom_data"] = _cmd_set_tile_custom_data
	handlers["cmd_add_tileset_terrain_set"] = _cmd_add_tileset_terrain_set
	handlers["cmd_add_tileset_terrain"] = _cmd_add_tileset_terrain
	handlers["cmd_set_tile_terrain"] = _cmd_set_tile_terrain
	handlers["cmd_tileset_add_pattern"] = _cmd_tileset_add_pattern
	handlers["cmd_create_alternative_tile"] = _cmd_create_alternative_tile
	handlers["cmd_set_tile_animation"] = _cmd_set_tile_animation
	handlers["cmd_add_tileset_navigation_layer"] = _cmd_add_tileset_navigation_layer
	handlers["cmd_set_tile_navigation"] = _cmd_set_tile_navigation
	handlers["cmd_add_tileset_occlusion_layer"] = _cmd_add_tileset_occlusion_layer
	handlers["cmd_set_tile_occlusion"] = _cmd_set_tile_occlusion
	handlers["cmd_add_tileset_scenes_collection_source"] = _cmd_add_tileset_scenes_collection_source
	handlers["cmd_create_scene_tile"] = _cmd_create_scene_tile
	handlers["cmd_set_tile_constant_velocity"] = _cmd_set_tile_constant_velocity


# -- create / atlas / tile ---------------------------------------------------

func _cmd_create_tileset(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", ""))
	var save_path := str(params.get("save_path", ""))
	if node_path.is_empty() and save_path.is_empty():
		return _router._fail("VALIDATION_ERROR", "Provide 'node_path' to assign the TileSet and/or 'save_path' to save it as a .tres.")
	var size_res := _router._parse_vec2i(params.get("tile_size", [16, 16]), "tile_size")
	if not size_res["ok"]:
		return size_res
	var tile_size: Vector2i = size_res["value"]
	if tile_size.x <= 0 or tile_size.y <= 0:
		return _router._fail("VALIDATION_ERROR", "'tile_size' components must be positive.")
	var tileset := TileSet.new()
	tileset.tile_size = tile_size
	var persistence := {"ok": true}
	var deprecated_tilemap := false
	if not save_path.is_empty():
		if not save_path.begins_with("res://"):
			return _router._fail("VALIDATION_ERROR", "save_path must be a res:// path.")
		var saved := _save_tileset_file(tileset, save_path)
		if not saved["ok"]:
			return saved
		tileset.take_over_path(save_path)
	if not node_path.is_empty():
		var found := _router._resolve(node_path)
		if not found["ok"]:
			return found
		var node: Node = found["node"]
		if not (node is TileMapLayer or node is TileMap):
			return _router._fail("VALIDATION_ERROR", "Node is not a TileMapLayer (preferred) or TileMap.")
		if node is TileMap:
			deprecated_tilemap = true
		var prev: TileSet = node.tile_set
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Create TileSet on %s" % node.name)
		ur.add_do_property(node, "tile_set", tileset)
		ur.add_do_reference(tileset)
		ur.add_undo_property(node, "tile_set", prev)
		if prev != null:
			ur.add_undo_reference(prev)
		ur.commit_action()
		persistence = _router._helpers.persistent_target(node)
	var body := {
		"node_path": node_path,
		"tileset_path": save_path,
		"tile_size": [tile_size.x, tile_size.y],
		"created": true,
	}
	if deprecated_tilemap:
		body["deprecated_tilemap"] = true
		body["migration_hint"] = "Prefer sibling TileMapLayer nodes sharing one TileSet."
	return _router._ok(_router._helpers.with_persistence(body, persistence))


func _cmd_add_tileset_atlas_source(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var texture_path := str(params.get("texture_path", ""))
	if texture_path.is_empty():
		return _router._fail("VALIDATION_ERROR", "'texture_path' must be the path to an imported Texture2D (e.g. res://art/tiles.png).")
	if not ResourceLoader.exists(texture_path):
		return _router._fail("RESOURCE_NOT_FOUND", "No resource at '%s'. Import the texture into the project first." % texture_path)
	var tex_res: Resource = ResourceLoader.load(texture_path)
	if not (tex_res is Texture2D):
		return _router._fail("VALIDATION_ERROR", "'%s' is not a Texture2D." % texture_path)
	var region_res := _router._parse_vec2i(params.get("region_size", [16, 16]), "region_size")
	if not region_res["ok"]:
		return region_res
	var region: Vector2i = region_res["value"]
	if region.x <= 0 or region.y <= 0:
		return _router._fail("VALIDATION_ERROR", "'region_size' components must be positive.")
	var margins_res := _router._parse_vec2i(params.get("margins", [0, 0]), "margins")
	if not margins_res["ok"]:
		return margins_res
	var separation_res := _router._parse_vec2i(params.get("separation", [0, 0]), "separation")
	if not separation_res["ok"]:
		return separation_res
	var requested: Variant = params.get("source_id")
	var source_id := int(requested) if requested != null else tileset.get_next_source_id()
	if source_id < 0:
		return _router._fail("VALIDATION_ERROR", "'source_id' must be non-negative.")
	if tileset.has_source(source_id):
		return _router._fail("VALIDATION_ERROR", "Source id %d already exists in the TileSet." % source_id)
	var source := TileSetAtlasSource.new()
	source.texture = tex_res as Texture2D
	source.texture_region_size = region
	source.margins = margins_res["value"]
	source.separation = separation_res["value"]
	if resolved["backing"] == "node":
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Add atlas source to TileSet")
		ur.add_do_method(tileset, "add_source", source, source_id)
		ur.add_do_reference(source)
		ur.add_undo_method(tileset, "remove_source", source_id)
		ur.commit_action()
	else:
		tileset.add_source(source, source_id)
		var saved := _save_tileset_file(tileset, resolved["path"])
		if not saved["ok"]:
			return saved
	var persistence: Dictionary = _router._helpers.resource_persistence(resolved["node"], [tileset]) if resolved["backing"] == "node" else {"ok": true}
	var body := {
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": source_id,
		"texture_path": texture_path,
		"region_size": [region.x, region.y],
	}
	if resolved.get("deprecated_tilemap", false):
		body["deprecated_tilemap"] = true
	return _router._ok(_router._helpers.with_persistence(body, persistence))


func _cmd_create_tile(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var source_id := int(params.get("source_id", -1))
	if not tileset.has_source(source_id):
		return _router._fail("VALIDATION_ERROR", "No source with id %d; add one with add_tileset_atlas_source." % source_id, "source_id")
	var source_obj: Object = tileset.get_source(source_id)
	if not (source_obj is TileSetAtlasSource):
		return _router._fail("VALIDATION_ERROR", "Source %d is not a TileSetAtlasSource." % source_id)
	var source: TileSetAtlasSource = source_obj
	var coords_res := _router._parse_vec2i(params.get("atlas_coords"), "atlas_coords")
	if not coords_res["ok"]:
		return coords_res
	var coords: Vector2i = coords_res["value"]
	var size_res := _router._parse_vec2i(params.get("size", [1, 1]), "size")
	if not size_res["ok"]:
		return size_res
	var size: Vector2i = size_res["value"]
	if size.x <= 0 or size.y <= 0:
		return _router._fail("VALIDATION_ERROR", "'size' components must be positive.")
	if not source.has_room_for_tile(coords, size, 1, Vector2i.ZERO, 1):
		return _router._fail("VALIDATION_ERROR", "No room for a tile at %v size %v (out of the atlas grid or overlapping an existing tile)." % [coords, size])
	if resolved["backing"] == "node":
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Create tile %v" % coords)
		ur.add_do_method(source, "create_tile", coords, size)
		ur.add_undo_method(source, "remove_tile", coords)
		ur.commit_action()
	else:
		source.create_tile(coords, size)
		var saved := _save_tileset_file(tileset, resolved["path"])
		if not saved["ok"]:
			return saved
	var persistence: Dictionary = _router._helpers.resource_persistence(resolved["node"], [source, tileset]) if resolved["backing"] == "node" else {"ok": true}
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": source_id,
		"atlas_coords": [coords.x, coords.y],
		"size": [size.x, size.y],
	}, persistence))


# -- INSPECT / VERIFY --------------------------------------------------------

func _cmd_tileset_inspect(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var sources: Array = []
	for i in tileset.get_source_count():
		var sid: int = tileset.get_source_id(i)
		var src: TileSetSource = tileset.get_source(sid)
		var entry: Dictionary = {
			"source_id": sid,
			"type": src.get_class(),
			"tiles_count": src.get_tiles_count(),
		}
		if src is TileSetAtlasSource:
			var atlas: TileSetAtlasSource = src
			entry["is_atlas"] = true
			var tex_path := ""
			if atlas.texture != null:
				tex_path = str(atlas.texture.resource_path)
			entry["texture_path"] = tex_path
			entry["texture_region_size"] = [atlas.texture_region_size.x, atlas.texture_region_size.y]
		elif src is TileSetScenesCollectionSource:
			entry["is_scenes_collection"] = true
		sources.append(entry)
	var physics: Array = []
	for i in tileset.get_physics_layers_count():
		physics.append({
			"index": i,
			"collision_layer": tileset.get_physics_layer_collision_layer(i),
			"collision_mask": tileset.get_physics_layer_collision_mask(i),
		})
	var custom_data: Array = []
	for i in tileset.get_custom_data_layers_count():
		custom_data.append({
			"index": i,
			"name": tileset.get_custom_data_layer_name(i),
			"type": int(tileset.get_custom_data_layer_type(i)),
		})
	var terrains: Array = []
	for s in tileset.get_terrain_sets_count():
		var set_terrains: Array = []
		for t in tileset.get_terrains_count(s):
			var col: Color = tileset.get_terrain_color(s, t)
			set_terrains.append({
				"index": t,
				"name": tileset.get_terrain_name(s, t),
				"color": [col.r, col.g, col.b, col.a],
			})
		terrains.append({
			"terrain_set": s,
			"mode": int(tileset.get_terrain_set_mode(s)),
			"terrains": set_terrains,
		})
	var navigation: Array = []
	for i in tileset.get_navigation_layers_count():
		navigation.append({
			"index": i,
			"layers": int(tileset.get_navigation_layer_layers(i)),
		})
	var occlusion: Array = []
	for i in tileset.get_occlusion_layers_count():
		occlusion.append({
			"index": i,
			"light_mask": int(tileset.get_occlusion_layer_light_mask(i)),
			"sdf_collision": bool(tileset.get_occlusion_layer_sdf_collision(i)),
		})
	var body := {
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"tile_size": [tileset.tile_size.x, tileset.tile_size.y],
		"sources": sources,
		"physics_layers": physics,
		"custom_data_layers": custom_data,
		"terrain_sets": terrains,
		"navigation_layers": navigation,
		"occlusion_layers": occlusion,
		"patterns_count": tileset.get_patterns_count(),
	}
	if resolved.get("deprecated_tilemap", false):
		body["deprecated_tilemap"] = true
	return _router._ok(body)


func _cmd_tileset_atlas_inspect(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var source_id := int(params.get("source_id", 0))
	if not tileset.has_source(source_id):
		return _router._fail("VALIDATION_ERROR", "No source with id %d." % source_id, "source_id")
	var source_obj: Object = tileset.get_source(source_id)
	if not (source_obj is TileSetAtlasSource):
		return _router._fail("VALIDATION_ERROR", "Source %d is not a TileSetAtlasSource." % source_id)
	var atlas: TileSetAtlasSource = source_obj
	var tiles: Array = []
	for i in atlas.get_tiles_count():
		var coords: Vector2i = atlas.get_tile_id(i)
		var alts: Array = []
		for a in atlas.get_alternative_tiles_count(coords):
			var alt_id: int = atlas.get_alternative_tile_id(coords, a)
			var anim := {
				"alternative_tile": alt_id,
				"animation_columns": atlas.get_tile_animation_columns(coords) if alt_id == 0 else 0,
				"animation_frames_count": atlas.get_tile_animation_frames_count(coords) if alt_id == 0 else 1,
				"animation_speed": atlas.get_tile_animation_speed(coords) if alt_id == 0 else 1.0,
				"animation_mode": atlas.get_tile_animation_mode(coords) if alt_id == 0 else 0,
			}
			alts.append(anim)
		tiles.append({
			"atlas_coords": [coords.x, coords.y],
			"size_in_atlas": [atlas.get_tile_size_in_atlas(coords).x, atlas.get_tile_size_in_atlas(coords).y],
			"alternatives": alts,
		})
	var tex_size := Vector2i.ZERO
	if atlas.texture:
		tex_size = atlas.texture.get_size()
	var grid := Vector2i.ZERO
	if atlas.texture_region_size.x > 0 and atlas.texture_region_size.y > 0 and atlas.texture:
		var usable := tex_size - atlas.margins
		grid = Vector2i(
			maxi(0, int((usable.x + atlas.separation.x) / float(atlas.texture_region_size.x + atlas.separation.x))),
			maxi(0, int((usable.y + atlas.separation.y) / float(atlas.texture_region_size.y + atlas.separation.y)))
		)
	return _router._ok({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": source_id,
		"texture_path": atlas.texture.resource_path if atlas.texture else "",
		"texture_size": [tex_size.x, tex_size.y],
		"texture_region_size": [atlas.texture_region_size.x, atlas.texture_region_size.y],
		"margins": [atlas.margins.x, atlas.margins.y],
		"separation": [atlas.separation.x, atlas.separation.y],
		"atlas_grid": [grid.x, grid.y],
		"tiles_count": tiles.size(),
		"tiles": tiles,
	})


func _cmd_get_tile_data(params: Dictionary) -> Dictionary:
	var tile := _resolve_tile_data(params)
	if not tile["ok"]:
		return tile
	var tileset: TileSet = tile["tileset"]
	var td: TileData = tile["tile_data"]
	var physics: Array = []
	for layer_id in tileset.get_physics_layers_count():
		var polys: Array = []
		for pi in td.get_collision_polygons_count(layer_id):
			var pts: PackedVector2Array = td.get_collision_polygon_points(layer_id, pi)
			var pts_arr: Array = []
			for p in pts:
				pts_arr.append([p.x, p.y])
			polys.append({
				"index": pi,
				"points": pts_arr,
				"one_way": td.is_collision_polygon_one_way(layer_id, pi),
				"one_way_margin": td.get_collision_polygon_one_way_margin(layer_id, pi),
			})
		var vel: Vector2 = td.get_constant_linear_velocity(layer_id)
		physics.append({
			"physics_layer": layer_id,
			"polygons": polys,
			"constant_linear_velocity": [vel.x, vel.y],
			"constant_angular_velocity": td.get_constant_angular_velocity(layer_id),
		})
	var custom: Dictionary = {}
	for i in tileset.get_custom_data_layers_count():
		var lname := tileset.get_custom_data_layer_name(i)
		custom[lname] = td.get_custom_data_by_layer_id(i)
	var peering: Array = []
	if td.terrain_set >= 0:
		for bit in range(16):
			if td.is_valid_terrain_peering_bit(bit):
				peering.append({"peering_bit": bit, "terrain": td.get_terrain_peering_bit(bit)})
	var navigation: Array = []
	for i in tileset.get_navigation_layers_count():
		var nav: NavigationPolygon = td.get_navigation_polygon(i)
		var outline_count := 0
		if nav != null:
			outline_count = nav.get_outline_count()
		navigation.append({"navigation_layer": i, "has_polygon": nav != null, "outline_count": outline_count})
	var occlusion: Array = []
	for i in tileset.get_occlusion_layers_count():
		var count := td.get_occluder_polygons_count(i)
		occlusion.append({"occlusion_layer": i, "polygons_count": count})
	return _router._ok({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": int(params.get("source_id", 0)),
		"atlas_coords": [tile["atlas_coords"].x, tile["atlas_coords"].y],
		"alternative_tile": int(params.get("alternative_tile", 0)),
		"physics": physics,
		"custom_data": custom,
		"terrain_set": td.terrain_set,
		"terrain": td.terrain,
		"terrain_peering": peering,
		"navigation": navigation,
		"occlusion": occlusion,
		"flip_h": td.flip_h,
		"flip_v": td.flip_v,
		"transpose": td.transpose,
	})


# -- Phase 1 physics / collision ---------------------------------------------

func _cmd_add_tileset_physics_layer(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var collision_layer := int(params.get("collision_layer", 1))
	var collision_mask := int(params.get("collision_mask", 1))
	var before := tileset.get_physics_layers_count()
	if resolved["backing"] == "node":
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Add TileSet physics layer")
		ur.add_do_method(tileset, "add_physics_layer", -1)
		ur.add_do_method(self, "_apply_physics_layer_bits", tileset, before, collision_layer, collision_mask)
		ur.add_undo_method(tileset, "remove_physics_layer", before)
		ur.commit_action()
	else:
		tileset.add_physics_layer(-1)
		tileset.set_physics_layer_collision_layer(before, collision_layer)
		tileset.set_physics_layer_collision_mask(before, collision_mask)
		var saved := _save_tileset_file(tileset, resolved["path"])
		if not saved["ok"]:
			return saved
	var persistence: Dictionary = _router._helpers.resource_persistence(resolved["node"], [tileset]) if resolved["backing"] == "node" else {"ok": true}
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"physics_layer": before,
		"collision_layer": collision_layer,
		"collision_mask": collision_mask,
		"physics_layers_count": tileset.get_physics_layers_count(),
	}, persistence))


func _apply_physics_layer_bits(tileset: TileSet, index: int, collision_layer: int, collision_mask: int) -> void:
	if index < 0 or index >= tileset.get_physics_layers_count():
		return
	tileset.set_physics_layer_collision_layer(index, collision_layer)
	tileset.set_physics_layer_collision_mask(index, collision_mask)


func _cmd_set_tile_collision(params: Dictionary) -> Dictionary:
	var tile := _resolve_tile_data(params)
	if not tile["ok"]:
		return tile
	var tileset: TileSet = tile["tileset"]
	var td: TileData = tile["tile_data"]
	var physics_layer := int(params.get("physics_layer", 0))
	if physics_layer < 0 or physics_layer >= tileset.get_physics_layers_count():
		return _router._fail(
			"VALIDATION_ERROR",
			"physics_layer %d out of range; call add_tileset_physics_layer first (count=%d)." % [physics_layer, tileset.get_physics_layers_count()],
			"physics_layer"
		)
	var points := _collision_points_from_params(params, tileset.tile_size)
	if not points["ok"]:
		return points
	var packed: PackedVector2Array = points["points"]
	var one_way := bool(params.get("one_way", false))
	var one_way_margin := float(params.get("one_way_margin", 1.0))
	# Replace polygons on this physics layer with a single polygon.
	td.set_collision_polygons_count(physics_layer, 0)
	td.add_collision_polygon(physics_layer)
	td.set_collision_polygon_points(physics_layer, 0, packed)
	td.set_collision_polygon_one_way(physics_layer, 0, one_way)
	td.set_collision_polygon_one_way_margin(physics_layer, 0, one_way_margin)
	var persist := _persist_tileset_mutation(tile)
	if not persist["ok"]:
		return persist
	var pts_out: Array = []
	for p in packed:
		pts_out.append([p.x, p.y])
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": int(params.get("source_id", 0)),
		"atlas_coords": [tile["atlas_coords"].x, tile["atlas_coords"].y],
		"alternative_tile": int(params.get("alternative_tile", 0)),
		"physics_layer": physics_layer,
		"shape": str(params.get("shape", "points" if params.has("points") else "full_rect")),
		"points": pts_out,
		"one_way": one_way,
		"one_way_margin": one_way_margin,
		"polygons_count": td.get_collision_polygons_count(physics_layer),
	}, persist.get("persistence", {"ok": true})))


func _cmd_clear_tile_collision(params: Dictionary) -> Dictionary:
	var tile := _resolve_tile_data(params)
	if not tile["ok"]:
		return tile
	var tileset: TileSet = tile["tileset"]
	var td: TileData = tile["tile_data"]
	var physics_layer := int(params.get("physics_layer", 0))
	if physics_layer < 0 or physics_layer >= tileset.get_physics_layers_count():
		return _router._fail("VALIDATION_ERROR", "physics_layer %d out of range." % physics_layer, "physics_layer")
	td.set_collision_polygons_count(physics_layer, 0)
	var persist := _persist_tileset_mutation(tile)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": int(params.get("source_id", 0)),
		"atlas_coords": [tile["atlas_coords"].x, tile["atlas_coords"].y],
		"physics_layer": physics_layer,
		"cleared": true,
		"polygons_count": 0,
	}, persist.get("persistence", {"ok": true})))


# -- Phase 2 custom data / terrain / patterns / alts -------------------------

func _cmd_add_tileset_custom_data_layer(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var layer_name := str(params.get("name", ""))
	if layer_name.is_empty():
		return _router._fail("VALIDATION_ERROR", "'name' is required for a custom data layer.")
	# TYPE_* constants — default TYPE_INT (2), also accept string type names.
	var type_id := _parse_variant_type(params.get("type", "int"))
	if type_id < 0:
		return _router._fail("VALIDATION_ERROR", "Unsupported custom data type; use int/float/string/bool.")
	var index := tileset.get_custom_data_layers_count()
	tileset.add_custom_data_layer(-1)
	tileset.set_custom_data_layer_name(index, layer_name)
	tileset.set_custom_data_layer_type(index, type_id)
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"layer_index": index,
		"name": layer_name,
		"type": type_id,
	}, persist.get("persistence", {"ok": true})))


func _cmd_set_tile_custom_data(params: Dictionary) -> Dictionary:
	var tile := _resolve_tile_data(params)
	if not tile["ok"]:
		return tile
	var td: TileData = tile["tile_data"]
	var layer_name := str(params.get("name", ""))
	if layer_name.is_empty():
		return _router._fail("VALIDATION_ERROR", "'name' of custom data layer is required.")
	if not td.has_custom_data(layer_name) and tile["tileset"].get_custom_data_layer_by_name(layer_name) < 0:
		return _router._fail("VALIDATION_ERROR", "No custom data layer named '%s'; add it first." % layer_name, "name")
	if not params.has("value"):
		return _router._fail("VALIDATION_ERROR", "'value' is required.")
	td.set_custom_data(layer_name, params.get("value"))
	var persist := _persist_tileset_mutation(tile)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": int(params.get("source_id", 0)),
		"atlas_coords": [tile["atlas_coords"].x, tile["atlas_coords"].y],
		"name": layer_name,
		"value": params.get("value"),
	}, persist.get("persistence", {"ok": true})))


func _cmd_add_tileset_terrain_set(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var mode := int(params.get("mode", TileSet.TERRAIN_MODE_MATCH_CORNERS_AND_SIDES))
	var index := tileset.get_terrain_sets_count()
	tileset.add_terrain_set(-1)
	tileset.set_terrain_set_mode(index, mode)
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"terrain_set": index,
		"mode": mode,
	}, persist.get("persistence", {"ok": true})))


func _cmd_add_tileset_terrain(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var terrain_set := int(params.get("terrain_set", 0))
	if terrain_set < 0 or terrain_set >= tileset.get_terrain_sets_count():
		return _router._fail("TERRAIN_NOT_CONFIGURED", "terrain_set %d does not exist; call add_tileset_terrain_set first." % terrain_set)
	var name := str(params.get("name", "terrain_%d" % tileset.get_terrains_count(terrain_set)))
	var index := tileset.get_terrains_count(terrain_set)
	tileset.add_terrain(terrain_set, -1)
	tileset.set_terrain_name(terrain_set, index, name)
	if params.has("color"):
		var c: Variant = params.get("color")
		if c is Array and (c as Array).size() >= 3:
			var arr: Array = c
			var col := Color(float(arr[0]), float(arr[1]), float(arr[2]), float(arr[3]) if arr.size() > 3 else 1.0)
			tileset.set_terrain_color(terrain_set, index, col)
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"terrain_set": terrain_set,
		"terrain": index,
		"name": name,
	}, persist.get("persistence", {"ok": true})))


func _cmd_set_tile_terrain(params: Dictionary) -> Dictionary:
	var tile := _resolve_tile_data(params)
	if not tile["ok"]:
		return tile
	var tileset: TileSet = tile["tileset"]
	var td: TileData = tile["tile_data"]
	var terrain_set := int(params.get("terrain_set", 0))
	var terrain := int(params.get("terrain", 0))
	if terrain_set < 0 or terrain_set >= tileset.get_terrain_sets_count():
		return _router._fail("TERRAIN_NOT_CONFIGURED", "terrain_set %d is not configured." % terrain_set)
	if terrain < 0 or terrain >= tileset.get_terrains_count(terrain_set):
		return _router._fail("TERRAIN_NOT_CONFIGURED", "terrain %d missing in set %d." % [terrain, terrain_set])
	td.terrain_set = terrain_set
	td.terrain = terrain
	var peering: Variant = params.get("peering_bits", [])
	if peering is Array:
		for entry in peering:
			if entry is Dictionary:
				var bit := int(entry.get("peering_bit", -1))
				var t := int(entry.get("terrain", terrain))
				if bit >= 0 and td.is_valid_terrain_peering_bit(bit):
					td.set_terrain_peering_bit(bit, t)
	var persist := _persist_tileset_mutation(tile)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": int(params.get("source_id", 0)),
		"atlas_coords": [tile["atlas_coords"].x, tile["atlas_coords"].y],
		"terrain_set": terrain_set,
		"terrain": terrain,
	}, persist.get("persistence", {"ok": true})))


func _cmd_tileset_add_pattern(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var cells: Variant = params.get("cells", [])
	if not (cells is Array) or (cells as Array).is_empty():
		return _router._fail("VALIDATION_ERROR", "'cells' must be a non-empty array of {coords, source_id, atlas_coords, alternative_tile}.")
	var pattern := TileMapPattern.new()
	for cell in cells:
		if not (cell is Dictionary):
			return _router._fail("VALIDATION_ERROR", "Each cell must be a dictionary.")
		var coords_res := _router._parse_vec2i(cell.get("coords"), "coords")
		if not coords_res["ok"]:
			return coords_res
		var atlas_res := _router._parse_vec2i(cell.get("atlas_coords", [0, 0]), "atlas_coords")
		if not atlas_res["ok"]:
			return atlas_res
		pattern.set_cell(
			coords_res["value"],
			int(cell.get("source_id", 0)),
			atlas_res["value"],
			int(cell.get("alternative_tile", 0))
		)
	var index := tileset.add_pattern(pattern, -1)
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"pattern_index": index,
		"cells": (cells as Array).size(),
		"patterns_count": tileset.get_patterns_count(),
	}, persist.get("persistence", {"ok": true})))


func _cmd_create_alternative_tile(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var source_id := int(params.get("source_id", 0))
	var atlas := _require_atlas(tileset, source_id)
	if not atlas["ok"]:
		return atlas
	var source: TileSetAtlasSource = atlas["source"]
	var coords_res := _router._parse_vec2i(params.get("atlas_coords"), "atlas_coords")
	if not coords_res["ok"]:
		return coords_res
	var coords: Vector2i = coords_res["value"]
	if not source.has_tile(coords):
		return _router._fail("VALIDATION_ERROR", "No tile at %v." % coords)
	var alt_id := source.create_alternative_tile(coords, int(params.get("alternative_tile_id", -1)))
	var td: TileData = source.get_tile_data(coords, alt_id)
	if params.has("flip_h"):
		td.flip_h = bool(params.get("flip_h"))
	if params.has("flip_v"):
		td.flip_v = bool(params.get("flip_v"))
	if params.has("transpose"):
		td.transpose = bool(params.get("transpose"))
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": source_id,
		"atlas_coords": [coords.x, coords.y],
		"alternative_tile": alt_id,
	}, persist.get("persistence", {"ok": true})))


func _cmd_set_tile_animation(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var source_id := int(params.get("source_id", 0))
	var atlas := _require_atlas(tileset, source_id)
	if not atlas["ok"]:
		return atlas
	var source: TileSetAtlasSource = atlas["source"]
	var coords_res := _router._parse_vec2i(params.get("atlas_coords"), "atlas_coords")
	if not coords_res["ok"]:
		return coords_res
	var coords: Vector2i = coords_res["value"]
	if not source.has_tile(coords):
		return _router._fail("VALIDATION_ERROR", "No tile at %v." % coords)
	var frames := int(params.get("frames_count", 1))
	var columns := int(params.get("columns", 0))
	var speed := float(params.get("speed", 1.0))
	var mode := int(params.get("mode", TileSetAtlasSource.TILE_ANIMATION_MODE_DEFAULT))
	source.set_tile_animation_frames_count(coords, maxi(1, frames))
	source.set_tile_animation_columns(coords, maxi(0, columns))
	source.set_tile_animation_speed(coords, speed)
	source.set_tile_animation_mode(coords, mode)
	if params.has("frame_duration"):
		var dur := float(params.get("frame_duration"))
		for i in source.get_tile_animation_frames_count(coords):
			source.set_tile_animation_frame_duration(coords, i, dur)
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": source_id,
		"atlas_coords": [coords.x, coords.y],
		"frames_count": source.get_tile_animation_frames_count(coords),
		"columns": source.get_tile_animation_columns(coords),
		"speed": source.get_tile_animation_speed(coords),
		"mode": source.get_tile_animation_mode(coords),
	}, persist.get("persistence", {"ok": true})))


# -- Phase 3 tracks ----------------------------------------------------------

func _cmd_add_tileset_navigation_layer(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var index := tileset.get_navigation_layers_count()
	tileset.add_navigation_layer(-1)
	if params.has("layers"):
		tileset.set_navigation_layer_layers(index, int(params.get("layers")))
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"navigation_layer": index,
	}, persist.get("persistence", {"ok": true})))


func _cmd_set_tile_navigation(params: Dictionary) -> Dictionary:
	var tile := _resolve_tile_data(params)
	if not tile["ok"]:
		return tile
	var tileset: TileSet = tile["tileset"]
	var td: TileData = tile["tile_data"]
	var layer_id := int(params.get("navigation_layer", 0))
	if layer_id < 0 or layer_id >= tileset.get_navigation_layers_count():
		return _router._fail("VALIDATION_ERROR", "navigation_layer %d not configured." % layer_id)
	var points := _points_array_from_params(params, tileset.tile_size)
	if not points["ok"]:
		return points
	var nav := NavigationPolygon.new()
	nav.add_outline(points["points"])
	nav.make_polygons_from_outlines()
	td.set_navigation_polygon(layer_id, nav)
	var persist := _persist_tileset_mutation(tile)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": int(params.get("source_id", 0)),
		"atlas_coords": [tile["atlas_coords"].x, tile["atlas_coords"].y],
		"navigation_layer": layer_id,
		"outline_points": _pack_to_arrays(points["points"]),
	}, persist.get("persistence", {"ok": true})))


func _cmd_add_tileset_occlusion_layer(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var index := tileset.get_occlusion_layers_count()
	tileset.add_occlusion_layer(-1)
	if params.has("light_mask"):
		tileset.set_occlusion_layer_light_mask(index, int(params.get("light_mask")))
	if params.has("sdf_collision"):
		tileset.set_occlusion_layer_sdf_collision(index, bool(params.get("sdf_collision")))
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"occlusion_layer": index,
	}, persist.get("persistence", {"ok": true})))


func _cmd_set_tile_occlusion(params: Dictionary) -> Dictionary:
	var tile := _resolve_tile_data(params)
	if not tile["ok"]:
		return tile
	var tileset: TileSet = tile["tileset"]
	var td: TileData = tile["tile_data"]
	var layer_id := int(params.get("occlusion_layer", 0))
	if layer_id < 0 or layer_id >= tileset.get_occlusion_layers_count():
		return _router._fail("VALIDATION_ERROR", "occlusion_layer %d not configured." % layer_id)
	var points := _points_array_from_params(params, tileset.tile_size)
	if not points["ok"]:
		return points
	var occ := OccluderPolygon2D.new()
	occ.polygon = points["points"]
	td.set_occluder_polygons_count(layer_id, 0)
	td.add_occluder_polygon(layer_id)
	td.set_occluder_polygon(layer_id, 0, occ)
	var persist := _persist_tileset_mutation(tile)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": int(params.get("source_id", 0)),
		"atlas_coords": [tile["atlas_coords"].x, tile["atlas_coords"].y],
		"occlusion_layer": layer_id,
		"points": _pack_to_arrays(points["points"]),
	}, persist.get("persistence", {"ok": true})))


func _cmd_add_tileset_scenes_collection_source(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var requested: Variant = params.get("source_id")
	var source_id := int(requested) if requested != null else tileset.get_next_source_id()
	if tileset.has_source(source_id):
		return _router._fail("VALIDATION_ERROR", "Source id %d already exists." % source_id)
	var source := TileSetScenesCollectionSource.new()
	if resolved["backing"] == "node":
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Add scenes collection source")
		ur.add_do_method(tileset, "add_source", source, source_id)
		ur.add_do_reference(source)
		ur.add_undo_method(tileset, "remove_source", source_id)
		ur.commit_action()
	else:
		tileset.add_source(source, source_id)
		var saved := _save_tileset_file(tileset, resolved["path"])
		if not saved["ok"]:
			return saved
	var persistence: Dictionary = _router._helpers.resource_persistence(resolved["node"], [tileset]) if resolved["backing"] == "node" else {"ok": true}
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": source_id,
		"type": "TileSetScenesCollectionSource",
	}, persistence))


func _cmd_create_scene_tile(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var source_id := int(params.get("source_id", -1))
	if not tileset.has_source(source_id):
		return _router._fail("VALIDATION_ERROR", "No source id %d." % source_id)
	var source_obj: Object = tileset.get_source(source_id)
	if not (source_obj is TileSetScenesCollectionSource):
		return _router._fail("VALIDATION_ERROR", "Source %d is not a TileSetScenesCollectionSource." % source_id)
	var source: TileSetScenesCollectionSource = source_obj
	var scene_path := str(params.get("scene_path", ""))
	if scene_path.is_empty() or not ResourceLoader.exists(scene_path):
		return _router._fail("RESOURCE_NOT_FOUND", "scene_path must be an existing PackedScene res:// path.")
	var packed: Resource = ResourceLoader.load(scene_path)
	if not (packed is PackedScene):
		return _router._fail("VALIDATION_ERROR", "'%s' is not a PackedScene." % scene_path)
	var id_override := int(params.get("scene_tile_id", -1))
	var scene_tile_id := source.create_scene_tile(packed as PackedScene, id_override)
	var persist := _persist_resolved(resolved)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": source_id,
		"scene_tile_id": scene_tile_id,
		"scene_path": scene_path,
	}, persist.get("persistence", {"ok": true})))


func _cmd_set_tile_constant_velocity(params: Dictionary) -> Dictionary:
	var tile := _resolve_tile_data(params)
	if not tile["ok"]:
		return tile
	var tileset: TileSet = tile["tileset"]
	var td: TileData = tile["tile_data"]
	var physics_layer := int(params.get("physics_layer", 0))
	if physics_layer < 0 or physics_layer >= tileset.get_physics_layers_count():
		return _router._fail("VALIDATION_ERROR", "physics_layer %d not configured." % physics_layer)
	var vel_res := _router._parse_vec2i(params.get("linear_velocity", [0, 0]), "linear_velocity")
	# Accept float vec via array of numbers
	var linear := Vector2.ZERO
	var raw_v: Variant = params.get("linear_velocity", [0, 0])
	if raw_v is Array and (raw_v as Array).size() >= 2:
		linear = Vector2(float(raw_v[0]), float(raw_v[1]))
	elif vel_res["ok"]:
		var vi: Vector2i = vel_res["value"]
		linear = Vector2(vi.x, vi.y)
	td.set_constant_linear_velocity(physics_layer, linear)
	if params.has("angular_velocity"):
		td.set_constant_angular_velocity(physics_layer, float(params.get("angular_velocity")))
	var persist := _persist_tileset_mutation(tile)
	if not persist["ok"]:
		return persist
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path", "")),
		"tileset_path": str(params.get("tileset_path", "")),
		"source_id": int(params.get("source_id", 0)),
		"atlas_coords": [tile["atlas_coords"].x, tile["atlas_coords"].y],
		"physics_layer": physics_layer,
		"linear_velocity": [linear.x, linear.y],
		"angular_velocity": td.get_constant_angular_velocity(physics_layer),
	}, persist.get("persistence", {"ok": true})))


# -- helpers -----------------------------------------------------------------

func _resolve_tileset(params: Dictionary) -> Dictionary:
	var node_path := str(params.get("node_path", ""))
	var tileset_path := str(params.get("tileset_path", ""))
	if not node_path.is_empty() and not tileset_path.is_empty():
		return _router._fail("VALIDATION_ERROR", "Pass only one of 'node_path' or 'tileset_path', not both.")
	if not node_path.is_empty():
		var found := _router._resolve(node_path)
		if not found["ok"]:
			return found
		var node: Node = found["node"]
		if not (node is TileMapLayer or node is TileMap):
			return _router._fail("VALIDATION_ERROR", "Node is not a TileMapLayer/TileMap.")
		var ts: TileSet = node.tile_set
		if ts == null:
			return _router._fail("VALIDATION_ERROR", "Node has no tile_set; create one first with create_tileset.", "tile_set")
		return {
			"ok": true,
			"tileset": ts,
			"backing": "node",
			"node": node,
			"deprecated_tilemap": node is TileMap,
		}
	if not tileset_path.is_empty():
		if not ResourceLoader.exists(tileset_path):
			return _router._fail("RESOURCE_NOT_FOUND", "No resource at '%s'." % tileset_path)
		var res: Resource = ResourceLoader.load(tileset_path)
		if not (res is TileSet):
			return _router._fail("VALIDATION_ERROR", "'%s' is not a TileSet." % tileset_path)
		return {"ok": true, "tileset": res, "backing": "file", "path": tileset_path, "deprecated_tilemap": false}
	return _router._fail("VALIDATION_ERROR", "Provide a 'node_path' (TileMapLayer preferred) or a 'tileset_path' (.tres).")


func _resolve_tile_data(params: Dictionary) -> Dictionary:
	var resolved := _resolve_tileset(params)
	if not resolved["ok"]:
		return resolved
	var tileset: TileSet = resolved["tileset"]
	var source_id := int(params.get("source_id", 0))
	var atlas := _require_atlas(tileset, source_id)
	if not atlas["ok"]:
		return atlas
	var source: TileSetAtlasSource = atlas["source"]
	var coords_res := _router._parse_vec2i(params.get("atlas_coords"), "atlas_coords")
	if not coords_res["ok"]:
		return coords_res
	var coords: Vector2i = coords_res["value"]
	if not source.has_tile(coords):
		return _router._fail("VALIDATION_ERROR", "No tile at atlas_coords %v in source %d." % [coords, source_id])
	var alt := int(params.get("alternative_tile", 0))
	var td: TileData = source.get_tile_data(coords, alt)
	if td == null:
		return _router._fail("VALIDATION_ERROR", "No TileData for %v alt %d." % [coords, alt])
	resolved["tile_data"] = td
	resolved["atlas_coords"] = coords
	resolved["source"] = source
	resolved["ok"] = true
	return resolved


func _require_atlas(tileset: TileSet, source_id: int) -> Dictionary:
	if not tileset.has_source(source_id):
		return _router._fail("VALIDATION_ERROR", "No source with id %d." % source_id, "source_id")
	var source_obj: Object = tileset.get_source(source_id)
	if not (source_obj is TileSetAtlasSource):
		return _router._fail("VALIDATION_ERROR", "Source %d is not a TileSetAtlasSource." % source_id)
	return {"ok": true, "source": source_obj}


func _collision_points_from_params(params: Dictionary, tile_size: Vector2i) -> Dictionary:
	return _points_array_from_params(params, tile_size)


func _points_array_from_params(params: Dictionary, tile_size: Vector2i) -> Dictionary:
	if params.has("points"):
		var raw: Variant = params.get("points")
		if not (raw is Array) or (raw as Array).size() < 3:
			return _router._fail("VALIDATION_ERROR", "'points' must be an array of at least 3 [x,y] pairs.")
		var packed := PackedVector2Array()
		for item in raw:
			if not (item is Array) or (item as Array).size() < 2:
				return _router._fail("VALIDATION_ERROR", "Each point must be [x, y].")
			packed.append(Vector2(float(item[0]), float(item[1])))
		return {"ok": true, "points": packed}
	# full_rect semantic convenience → centered tile-local polygon (Godot TileData convention).
	var shape := str(params.get("shape", "full_rect"))
	if shape != "full_rect":
		return _router._fail("VALIDATION_ERROR", "Unknown shape '%s'; use full_rect or provide points." % shape)
	var hw := tile_size.x * 0.5
	var hh := tile_size.y * 0.5
	var packed2 := PackedVector2Array([
		Vector2(-hw, -hh),
		Vector2(hw, -hh),
		Vector2(hw, hh),
		Vector2(-hw, hh),
	])
	return {"ok": true, "points": packed2}


func _pack_to_arrays(packed: PackedVector2Array) -> Array:
	var out: Array = []
	for p in packed:
		out.append([p.x, p.y])
	return out


func _parse_variant_type(raw: Variant) -> int:
	if raw is int:
		return int(raw)
	var name := str(raw).to_lower()
	match name:
		"bool", "boolean":
			return TYPE_BOOL
		"int", "integer":
			return TYPE_INT
		"float", "real", "double":
			return TYPE_FLOAT
		"string", "str":
			return TYPE_STRING
		_:
			return -1


func _persist_resolved(resolved: Dictionary) -> Dictionary:
	if resolved["backing"] == "file":
		var saved := _save_tileset_file(resolved["tileset"], resolved["path"])
		if not saved["ok"]:
			return saved
		return {"ok": true, "persistence": {"ok": true}}
	return {"ok": true, "persistence": _router._helpers.resource_persistence(resolved["node"], [resolved["tileset"]])}


func _persist_tileset_mutation(tile: Dictionary) -> Dictionary:
	return _persist_resolved(tile)


func _save_tileset_file(tileset: TileSet, path: String) -> Dictionary:
	var err := ResourceSaver.save(tileset, path)
	if err != OK:
		return _router._fail("INTERNAL_ERROR", "Failed to save TileSet to '%s' (error %d)." % [path, err])
	EditorInterface.get_resource_filesystem().update_file(path)
	return {"ok": true}
