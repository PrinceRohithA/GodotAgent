@tool
class_name MCPSpriteFramesHandlers
extends RefCounted
## Domain handler: SpriteFrames bulk authoring (GodotAgent).
##
## One MCP call → full SpriteFrames with multiple animations from a spritesheet.

var _router: MCPCommandRouter


func _init(router: MCPCommandRouter) -> void:
	_router = router


func register(handlers: Dictionary) -> void:
	handlers["cmd_create_sprite_frames"] = _cmd_create_sprite_frames


func _cmd_create_sprite_frames(params: Dictionary) -> Dictionary:
	var texture_path := str(params.get("texture", params.get("texture_path", "")))
	if texture_path.is_empty():
		return _router._fail("VALIDATION_ERROR", "'texture' (res:// path) is required.")
	if not ResourceLoader.exists(texture_path):
		return _router._fail("RESOURCE_NOT_FOUND", "No resource at '%s'." % texture_path)
	var tex_res: Resource = ResourceLoader.load(texture_path)
	if not (tex_res is Texture2D):
		return _router._fail("VALIDATION_ERROR", "'%s' is not a Texture2D." % texture_path)
	var texture: Texture2D = tex_res

	var size_raw: Variant = params.get("frame_size", [16, 16])
	if not (size_raw is Array) or (size_raw as Array).size() < 2:
		return _router._fail("VALIDATION_ERROR", "'frame_size' must be [w, h].")
	var frame_w := int(size_raw[0])
	var frame_h := int(size_raw[1])
	if frame_w <= 0 or frame_h <= 0:
		return _router._fail("VALIDATION_ERROR", "'frame_size' components must be positive.")

	var anims_raw: Variant = params.get("animations", {})
	if not (anims_raw is Dictionary) or (anims_raw as Dictionary).is_empty():
		return _router._fail("VALIDATION_ERROR", "'animations' must be a non-empty object.")

	var frames := SpriteFrames.new()
	# Remove default empty animation if present.
	if frames.has_animation("default"):
		frames.remove_animation("default")

	var anim_summaries: Array = []
	var anims: Dictionary = anims_raw
	for anim_name_v in anims.keys():
		var anim_name := str(anim_name_v)
		var spec: Variant = anims[anim_name_v]
		if not (spec is Dictionary):
			return _router._fail("VALIDATION_ERROR", "animations['%s'] must be an object." % anim_name)
		var sd: Dictionary = spec
		var cell_list: Array = []
		if sd.has("frames") and sd.get("frames") is Array:
			for cell in sd.get("frames"):
				if not (cell is Array) or (cell as Array).size() < 2:
					return _router._fail(
						"VALIDATION_ERROR",
						"animations['%s'].frames entries must be [col, row]." % anim_name
					)
				cell_list.append(Vector2i(int(cell[0]), int(cell[1])))
		elif sd.has("row"):
			var row := int(sd.get("row"))
			var count := int(sd.get("frames", 0))
			if count <= 0:
				return _router._fail(
					"VALIDATION_ERROR",
					"animations['%s'] row layout requires frames (count) > 0." % anim_name
				)
			for col in range(count):
				cell_list.append(Vector2i(col, row))
		else:
			return _router._fail(
				"VALIDATION_ERROR",
				"animations['%s'] needs 'row'+frames count or explicit frames:[[x,y],...]." % anim_name
			)
		if cell_list.is_empty():
			return _router._fail("VALIDATION_ERROR", "animations['%s'] produced zero frames." % anim_name)

		var fps := float(sd.get("fps", 5.0))
		var loop := bool(sd.get("loop", true))
		if frames.has_animation(anim_name):
			frames.remove_animation(anim_name)
		frames.add_animation(anim_name)
		frames.set_animation_speed(anim_name, fps)
		frames.set_animation_loop(anim_name, loop)
		for cell_v in cell_list:
			var cell: Vector2i = cell_v
			var atlas := AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(cell.x * frame_w, cell.y * frame_h, frame_w, frame_h)
			frames.add_frame(anim_name, atlas)
		anim_summaries.append({
			"name": anim_name,
			"frames": cell_list.size(),
			"fps": fps,
			"loop": loop,
		})

	var save_path := str(params.get("save_path", ""))
	var changes: Array = []
	if not save_path.is_empty():
		if not save_path.begins_with("res://"):
			return _router._fail("VALIDATION_ERROR", "save_path must be a res:// path.")
		var err := ResourceSaver.save(frames, save_path)
		if err != OK:
			return _router._fail("INTERNAL_ERROR", "Failed to save SpriteFrames to '%s' (error %d)." % [save_path, err])
		frames.take_over_path(save_path)
		EditorInterface.get_resource_filesystem().update_file(save_path)
		changes.append(save_path)

	var assign_to := str(params.get("assign_to", ""))
	var assigned := ""
	if not assign_to.is_empty():
		var found := _router._resolve(assign_to)
		if not found["ok"]:
			return found
		var node: Node = found["node"]
		if not (node is AnimatedSprite2D) and not (node is AnimatedSprite3D):
			return _router._fail(
				"VALIDATION_ERROR",
				"assign_to must be an AnimatedSprite2D/AnimatedSprite3D (got %s)." % node.get_class()
			)
		var prev = node.sprite_frames
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("Assign SpriteFrames to %s" % node.name)
		ur.add_do_property(node, "sprite_frames", frames)
		ur.add_do_reference(frames)
		ur.add_undo_property(node, "sprite_frames", prev)
		if prev != null:
			ur.add_undo_reference(prev)
		ur.commit_action()
		assigned = assign_to
		changes.append(assign_to)

	var anim_names: Array = []
	for summary in anim_summaries:
		anim_names.append(summary["name"])
	return _router._ok({
		"success": true,
		"created": anim_summaries.size(),
		"modified": 1 if not assigned.is_empty() else 0,
		"failed": 0,
		"changes": changes,
		"animations": anim_summaries,
		"animation_names": anim_names,
		"texture": texture_path,
		"frame_size": [frame_w, frame_h],
		"save_path": save_path,
		"assign_to": assigned,
		"resource_path": frames.resource_path,
	})
