@tool
class_name MCPTileMapHandlers
extends RefCounted
## Domain handler: tilemap (TileMapLayer-first).
##
## New mutating ops require TileMapLayer. Deprecated TileMap remains read/compat
## for paint/clear/get for one cycle (responses include deprecated_tilemap).

const _TILEMAP_FILL_LIMIT := 16384  # max cells per fill_rect / batch

var _router: MCPCommandRouter


func _init(router: MCPCommandRouter) -> void:
	_router = router


func register(handlers: Dictionary) -> void:
	handlers["cmd_tilemap_clear"] = _cmd_tilemap_clear
	handlers["cmd_tilemap_fill_rect"] = _cmd_tilemap_fill_rect
	handlers["cmd_tilemap_get_cell"] = _cmd_tilemap_get_cell
	handlers["cmd_tilemap_get_used_cells"] = _cmd_tilemap_get_used_cells
	handlers["cmd_tilemap_layers"] = _cmd_tilemap_layers
	handlers["cmd_tilemap_set_cell"] = _cmd_tilemap_set_cell
	handlers["cmd_tilemap_set_cells_batch"] = _cmd_tilemap_set_cells_batch
	handlers["cmd_tilemap_layer_set_physics"] = _cmd_tilemap_layer_set_physics
	handlers["cmd_tilemap_set_terrain"] = _cmd_tilemap_set_terrain
	handlers["cmd_tilemap_set_pattern"] = _cmd_tilemap_set_pattern
	handlers["cmd_tilemap_layer_set_navigation"] = _cmd_tilemap_layer_set_navigation
	handlers["cmd_tilemap_layer_set_kinematic"] = _cmd_tilemap_layer_set_kinematic


# -- paint / read (compat TileMap) -------------------------------------------

func _cmd_tilemap_set_cell(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), int(params.get("layer", 0)), false)
	if not found["ok"]:
		return found
	var node: Node = found["node"]
	var layer := int(params.get("layer", 0))
	var coords_res := _router._parse_vec2i(params.get("coords"), "coords")
	if not coords_res["ok"]:
		return coords_res
	var atlas_res := _router._parse_vec2i(params.get("atlas_coords", [0, 0]), "atlas_coords")
	if not atlas_res["ok"]:
		return atlas_res
	var coords: Vector2i = coords_res["value"]
	var source_id := int(params.get("source_id", -1))
	var atlas: Vector2i = atlas_res["value"]
	var alt := int(params.get("alternative_tile", 0))
	var prev := _read_tile_cell(node, layer, coords)
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set tile %v" % coords)
	ur.add_do_method(self, "_apply_tile_cell", node, layer, coords, source_id, atlas, alt)
	ur.add_undo_method(
		self, "_apply_tile_cell", node, layer, coords,
		prev["source_id"], prev["atlas_coords"], prev["alternative_tile"]
	)
	ur.commit_action()
	var body := {
		"node_path": str(params.get("node_path")),
		"coords": [coords.x, coords.y],
		"source_id": source_id,
		"layer": layer,
	}
	_stamp_deprecated(body, found)
	return _router._ok(_router._helpers.with_persistence(body, _router._helpers.persistent_target(node)))


func _cmd_tilemap_fill_rect(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), int(params.get("layer", 0)), false)
	if not found["ok"]:
		return found
	var node: Node = found["node"]
	var layer := int(params.get("layer", 0))
	var raw_rect: Variant = params.get("rect")
	if not (raw_rect is Array) or (raw_rect as Array).size() != 4:
		return _router._fail("VALIDATION_ERROR", "'rect' must be [x, y, w, h].")
	var width := int(raw_rect[2])
	var height := int(raw_rect[3])
	if width <= 0 or height <= 0:
		return _router._fail("VALIDATION_ERROR", "rect width and height must be positive.")
	if width * height > _TILEMAP_FILL_LIMIT:
		return _router._fail("VALIDATION_ERROR", "Fill region %dx%d exceeds the %d-cell limit; fill smaller rects." % [width, height, _TILEMAP_FILL_LIMIT])
	var atlas_res := _router._parse_vec2i(params.get("atlas_coords", [0, 0]), "atlas_coords")
	if not atlas_res["ok"]:
		return atlas_res
	var origin := Vector2i(int(raw_rect[0]), int(raw_rect[1]))
	var source_id := int(params.get("source_id", -1))
	var atlas: Vector2i = atlas_res["value"]
	var alt := int(params.get("alternative_tile", 0))
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Fill tiles %dx%d" % [width, height])
	var count := 0
	for dy in height:
		for dx in width:
			var coords := origin + Vector2i(dx, dy)
			var prev := _read_tile_cell(node, layer, coords)
			ur.add_do_method(self, "_apply_tile_cell", node, layer, coords, source_id, atlas, alt)
			ur.add_undo_method(
				self, "_apply_tile_cell", node, layer, coords,
				prev["source_id"], prev["atlas_coords"], prev["alternative_tile"]
			)
			count += 1
	ur.commit_action()
	var body := {
		"node_path": str(params.get("node_path")),
		"rect": [origin.x, origin.y, width, height],
		"cells": count,
		"layer": layer,
	}
	_stamp_deprecated(body, found)
	return _router._ok(_router._helpers.with_persistence(body, _router._helpers.persistent_target(node)))


func _cmd_tilemap_set_cells_batch(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), int(params.get("layer", 0)), true)
	if not found["ok"]:
		return found
	var node: Node = found["node"]
	var layer := int(params.get("layer", 0))
	var cells: Variant = params.get("cells", [])
	if not (cells is Array) or (cells as Array).is_empty():
		return _router._fail("VALIDATION_ERROR", "'cells' must be a non-empty array of {coords, source_id, atlas_coords, alternative_tile}.")
	if (cells as Array).size() > _TILEMAP_FILL_LIMIT:
		return _router._fail("VALIDATION_ERROR", "Batch of %d exceeds the %d-cell limit." % [(cells as Array).size(), _TILEMAP_FILL_LIMIT])
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set tiles batch (%d)" % (cells as Array).size())
	var count := 0
	for cell in cells:
		if not (cell is Dictionary):
			return _router._fail("VALIDATION_ERROR", "Each batch cell must be a dictionary.")
		var coords_res := _router._parse_vec2i(cell.get("coords"), "coords")
		if not coords_res["ok"]:
			return coords_res
		var atlas_res := _router._parse_vec2i(cell.get("atlas_coords", [0, 0]), "atlas_coords")
		if not atlas_res["ok"]:
			return atlas_res
		var coords: Vector2i = coords_res["value"]
		var source_id := int(cell.get("source_id", -1))
		var atlas: Vector2i = atlas_res["value"]
		var alt := int(cell.get("alternative_tile", 0))
		var prev := _read_tile_cell(node, layer, coords)
		ur.add_do_method(self, "_apply_tile_cell", node, layer, coords, source_id, atlas, alt)
		ur.add_undo_method(
			self, "_apply_tile_cell", node, layer, coords,
			prev["source_id"], prev["atlas_coords"], prev["alternative_tile"]
		)
		count += 1
	ur.commit_action()
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path")),
		"cells": count,
		"layer": layer,
	}, _router._helpers.persistent_target(node)))


func _cmd_tilemap_get_cell(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), int(params.get("layer", 0)), false)
	if not found["ok"]:
		return found
	var node: Node = found["node"]
	var layer := int(params.get("layer", 0))
	var coords_res := _router._parse_vec2i(params.get("coords"), "coords")
	if not coords_res["ok"]:
		return coords_res
	var coords: Vector2i = coords_res["value"]
	var cell := _read_tile_cell(node, layer, coords)
	var atlas: Vector2i = cell["atlas_coords"]
	var body := {
		"node_path": str(params.get("node_path")),
		"coords": [coords.x, coords.y],
		"source_id": cell["source_id"],
		"atlas_coords": [atlas.x, atlas.y],
		"alternative_tile": cell["alternative_tile"],
		"empty": cell["source_id"] == -1,
	}
	_stamp_deprecated(body, found)
	return _router._ok(body)


func _cmd_tilemap_get_used_cells(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), int(params.get("layer", 0)), false)
	if not found["ok"]:
		return found
	var node: Node = found["node"]
	var layer := int(params.get("layer", 0))
	var cells: Array = []
	for coords in _used_cells(node, layer):
		var cell := _read_tile_cell(node, layer, coords)
		var atlas: Vector2i = cell["atlas_coords"]
		cells.append({
			"coords": [coords.x, coords.y],
			"source_id": cell["source_id"],
			"atlas_coords": [atlas.x, atlas.y],
			"alternative_tile": cell["alternative_tile"],
		})
	var body := {
		"node_path": str(params.get("node_path")),
		"layer": layer,
		"count": cells.size(),
		"cells": cells,
	}
	_stamp_deprecated(body, found)
	return _router._ok(body)


func _cmd_tilemap_clear(params: Dictionary) -> Dictionary:
	var requested_layer: Variant = params.get("layer")
	var layer := int(requested_layer) if requested_layer != null else 0
	var found := _resolve_tilemap(params.get("node_path", ""), layer, false)
	if not found["ok"]:
		return found
	var node: Node = found["node"]
	var used: Array = _used_cells(node, layer)
	if used.size() > _TILEMAP_FILL_LIMIT:
		return _router._fail("VALIDATION_ERROR", "Layer has %d cells, over the %d-cell undoable-clear limit; clear smaller regions with fill_rect (source_id=-1)." % [used.size(), _TILEMAP_FILL_LIMIT])
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Clear tiles")
	ur.add_do_method(self, "_clear_tile_layer", node, layer)
	for coords in used:
		var prev := _read_tile_cell(node, layer, coords)
		ur.add_undo_method(
			self, "_apply_tile_cell", node, layer, coords,
			prev["source_id"], prev["atlas_coords"], prev["alternative_tile"]
		)
	ur.commit_action()
	var result_layer: Variant = null if node is TileMapLayer else layer
	var body := {
		"node_path": str(params.get("node_path")),
		"layer": result_layer,
		"cleared": used.size(),
	}
	_stamp_deprecated(body, found)
	return _router._ok(_router._helpers.with_persistence(body, _router._helpers.persistent_target(node)))


func _cmd_tilemap_layers(params: Dictionary) -> Dictionary:
	var found := _router._resolve(params.get("node_path", ""))
	if not found["ok"]:
		return found
	var node: Node = found["node"]
	var layers: Array = []
	if node is TileMapLayer:
		var layer_node: TileMapLayer = node
		layers.append({
			"index": 0,
			"name": String(node.name),
			"enabled": layer_node.enabled,
			"collision_enabled": layer_node.collision_enabled,
			"navigation_enabled": layer_node.navigation_enabled,
			"use_kinematic_bodies": layer_node.use_kinematic_bodies,
		})
	elif node is TileMap:
		for i in node.get_layers_count():
			layers.append({
				"index": i,
				"name": node.get_layer_name(i),
				"enabled": node.is_layer_enabled(i),
			})
	else:
		return _router._fail("VALIDATION_ERROR", "Node is not a TileMapLayer/TileMap. Prefer sibling TileMapLayer nodes.")
	var body := {
		"node_path": str(params.get("node_path")),
		"node_type": node.get_class(),
		"layers": layers,
	}
	if node is TileMap:
		body["deprecated_tilemap"] = true
		body["migration_hint"] = "Use sibling TileMapLayer nodes (Ground/Decor/Foreground/Hazards) sharing one TileSet."
	return _router._ok(body)


# -- Phase 1 layer physics ---------------------------------------------------

func _cmd_tilemap_layer_set_physics(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), 0, true)
	if not found["ok"]:
		return found
	var node: TileMapLayer = found["node"]
	var collision_enabled := bool(params.get("collision_enabled", true))
	var prev := node.collision_enabled
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set TileMapLayer collision_enabled")
	ur.add_do_property(node, "collision_enabled", collision_enabled)
	ur.add_undo_property(node, "collision_enabled", prev)
	ur.commit_action()
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path")),
		"collision_enabled": collision_enabled,
	}, _router._helpers.persistent_target(node)))


# -- Phase 2 terrain paint / patterns ----------------------------------------

func _cmd_tilemap_set_terrain(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), int(params.get("layer", 0)), true)
	if not found["ok"]:
		return found
	var node: TileMapLayer = found["node"]
	var tileset: TileSet = node.tile_set
	if tileset == null:
		return _router._fail("TERRAIN_NOT_CONFIGURED", "TileMapLayer has no tile_set.")
	var terrain_set := int(params.get("terrain_set", 0))
	var terrain := int(params.get("terrain", 0))
	if terrain_set < 0 or terrain_set >= tileset.get_terrain_sets_count():
		return _router._fail("TERRAIN_NOT_CONFIGURED", "terrain_set %d is not configured on the TileSet." % terrain_set)
	if terrain < 0 or terrain >= tileset.get_terrains_count(terrain_set):
		return _router._fail("TERRAIN_NOT_CONFIGURED", "terrain %d missing in set %d." % [terrain, terrain_set])
	var cells_raw: Variant = params.get("cells", [])
	if not (cells_raw is Array) or (cells_raw as Array).is_empty():
		return _router._fail("VALIDATION_ERROR", "'cells' must be a non-empty array of [x,y] or {coords:[x,y]}.")
	var cells: Array[Vector2i] = []
	for item in cells_raw:
		var coords_val: Variant = item.get("coords") if item is Dictionary else item
		var coords_res := _router._parse_vec2i(coords_val, "coords")
		if not coords_res["ok"]:
			return coords_res
		cells.append(coords_res["value"])
	var mode := str(params.get("mode", "connect"))
	var ignore_empty := bool(params.get("ignore_empty_terrains", true))
	if mode == "path":
		node.set_cells_terrain_path(cells, terrain_set, terrain, ignore_empty)
	else:
		node.set_cells_terrain_connect(cells, terrain_set, terrain, ignore_empty)
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path")),
		"terrain_set": terrain_set,
		"terrain": terrain,
		"mode": mode,
		"cells": cells.size(),
	}, _router._helpers.persistent_target(node)))


func _cmd_tilemap_set_pattern(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), 0, true)
	if not found["ok"]:
		return found
	var node: TileMapLayer = found["node"]
	var tileset: TileSet = node.tile_set
	if tileset == null:
		return _router._fail("VALIDATION_ERROR", "TileMapLayer has no tile_set.")
	var pattern_index := int(params.get("pattern_index", 0))
	if pattern_index < 0 or pattern_index >= tileset.get_patterns_count():
		return _router._fail("VALIDATION_ERROR", "pattern_index %d out of range (patterns_count=%d)." % [pattern_index, tileset.get_patterns_count()])
	var pos_res := _router._parse_vec2i(params.get("position", [0, 0]), "position")
	if not pos_res["ok"]:
		return pos_res
	var pattern: TileMapPattern = tileset.get_pattern(pattern_index)
	node.set_pattern(pos_res["value"], pattern)
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path")),
		"pattern_index": pattern_index,
		"position": [pos_res["value"].x, pos_res["value"].y],
	}, _router._helpers.persistent_target(node)))


# -- Phase 3 layer flags -----------------------------------------------------

func _cmd_tilemap_layer_set_navigation(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), 0, true)
	if not found["ok"]:
		return found
	var node: TileMapLayer = found["node"]
	var enabled := bool(params.get("navigation_enabled", true))
	var prev := node.navigation_enabled
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set TileMapLayer navigation_enabled")
	ur.add_do_property(node, "navigation_enabled", enabled)
	ur.add_undo_property(node, "navigation_enabled", prev)
	ur.commit_action()
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path")),
		"navigation_enabled": enabled,
	}, _router._helpers.persistent_target(node)))


func _cmd_tilemap_layer_set_kinematic(params: Dictionary) -> Dictionary:
	var found := _resolve_tilemap(params.get("node_path", ""), 0, true)
	if not found["ok"]:
		return found
	var node: TileMapLayer = found["node"]
	var enabled := bool(params.get("use_kinematic_bodies", true))
	var prev := node.use_kinematic_bodies
	var ur := EditorInterface.get_editor_undo_redo()
	ur.create_action("Set TileMapLayer use_kinematic_bodies")
	ur.add_do_property(node, "use_kinematic_bodies", enabled)
	ur.add_undo_property(node, "use_kinematic_bodies", prev)
	ur.commit_action()
	return _router._ok(_router._helpers.with_persistence({
		"node_path": str(params.get("node_path")),
		"use_kinematic_bodies": enabled,
	}, _router._helpers.persistent_target(node)))


# -- resolve / apply ---------------------------------------------------------

func _resolve_tilemap(raw_path: Variant, layer: int, require_layer_node: bool) -> Dictionary:
	var found := _router._resolve(raw_path)
	if not found["ok"]:
		return found
	var node: Node = found["node"]
	if node is TileMapLayer:
		return {"ok": true, "node": node, "deprecated_tilemap": false}
	if node is TileMap:
		if require_layer_node:
			return _router._fail(
				"VALIDATION_ERROR",
				"Deprecated TileMap is read/compat only. Use a TileMapLayer node (Ground/Decor/Foreground/Hazards as siblings sharing one TileSet).",
				"node_path"
			)
		if layer < 0 or layer >= node.get_layers_count():
			return _router._fail("VALIDATION_ERROR", "Layer %d is out of range (0..%d)." % [layer, node.get_layers_count() - 1])
		return {"ok": true, "node": node, "deprecated_tilemap": true}
	return _router._fail("VALIDATION_ERROR", "Node is not a TileMapLayer (preferred) or TileMap.")


func _stamp_deprecated(body: Dictionary, found: Dictionary) -> void:
	if found.get("deprecated_tilemap", false):
		body["deprecated_tilemap"] = true
		body["migration_hint"] = "Prefer TileMapLayer siblings for new work."


func _apply_tile_cell(
	node: Node, layer: int, coords: Vector2i, source_id: int, atlas_coords: Vector2i, alternative_tile: int
) -> void:
	if node is TileMapLayer:
		node.set_cell(coords, source_id, atlas_coords, alternative_tile)
	else:
		node.set_cell(layer, coords, source_id, atlas_coords, alternative_tile)


func _clear_tile_layer(node: Node, layer: int) -> void:
	if node is TileMapLayer:
		node.clear()
	else:
		node.clear_layer(layer)


func _read_tile_cell(node: Node, layer: int, coords: Vector2i) -> Dictionary:
	if node is TileMapLayer:
		return {
			"source_id": node.get_cell_source_id(coords),
			"atlas_coords": node.get_cell_atlas_coords(coords),
			"alternative_tile": node.get_cell_alternative_tile(coords),
		}
	return {
		"source_id": node.get_cell_source_id(layer, coords),
		"atlas_coords": node.get_cell_atlas_coords(layer, coords),
		"alternative_tile": node.get_cell_alternative_tile(layer, coords),
	}


func _used_cells(node: Node, layer: int) -> Array:
	if node is TileMapLayer:
		return node.get_used_cells()
	return node.get_used_cells(layer)
