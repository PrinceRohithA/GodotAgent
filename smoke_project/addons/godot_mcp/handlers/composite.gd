@tool
class_name MCPCompositeHandlers
extends RefCounted
const Coerce := preload("../type_coerce.gd")
## Domain handler: composite/macro tools (issue #154).
##
## Each handler collapses a multi-step scene edit into ONE UndoRedo action and a
## single bridge round-trip. Registered by the router on _init().

const Inspect := preload("../scene_inspect.gd")

var _router: MCPCommandRouter


func _init(router: MCPCommandRouter) -> void:
	_router = router


func register(handlers: Dictionary) -> void:
	handlers["cmd_compose_node"] = _cmd_compose_node
	handlers["cmd_batch_create_nodes"] = _cmd_batch_create_nodes
	handlers["cmd_apply_node_edits"] = _cmd_apply_node_edits
	handlers["cmd_nodes_create_batch"] = _cmd_nodes_create_batch
	handlers["cmd_nodes_edit_batch"] = _cmd_nodes_edit_batch


# -- helpers -----------------------------------------------------------------

## Instantiate `node_type`, set `name`, apply `properties`, attach `script_path` —
## all directly on the fresh (detached) instance before it enters the tree.
## Returns {"node": Node, "properties_set": Array} on success, or a structured
## error Dictionary (carrying "ok": false) which the caller forwards as-is.
func _build_node(
	node_type: String, node_name: String, properties: Dictionary, script_path: String
) -> Dictionary:
	if not ClassDB.class_exists(node_type) or not ClassDB.can_instantiate(node_type):
		return _router._fail(
			"VALIDATION_ERROR", "Unknown or non-instantiable node type '%s'." % node_type
		)
	var node: Node = ClassDB.instantiate(node_type)
	node.name = node_name
	var set_names: Array = []
	for prop in properties:
		var prop_name := str(prop)
		var prop_type := _router._helpers.property_type(node, prop_name)
		if prop_type == -1:
			node.free()
			return _router._fail(
				"VALIDATION_ERROR", "'%s' has no property '%s'." % [node_type, prop_name]
			)
		node.set(prop_name, Coerce.from_json(properties[prop], prop_type))
		set_names.append(prop_name)
	if not script_path.is_empty():
		if not ResourceLoader.exists(script_path):
			node.free()
			return _router._fail("RESOURCE_NOT_FOUND", "No script at '%s'." % script_path)
		var script: Variant = load(script_path)
		if not (script is Script):
			node.free()
			return _router._fail("VALIDATION_ERROR", "'%s' is not a script resource." % script_path)
		node.set_script(script)
	return {"node": node, "properties_set": set_names}


func _maybe_save(params: Dictionary) -> bool:
	if not bool(params.get("save", false)):
		return false
	return EditorInterface.save_scene() == OK


# -- handlers ----------------------------------------------------------------

func _cmd_compose_node(params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _router._fail("PRECONDITION_FAILED", "No scene is open.", "active_scene")
	var parent_found := _router._resolve(params.get("parent_path", "."))
	if not parent_found["ok"]:
		return parent_found
	var parent: Node = parent_found["node"]

	var built := _build_node(
		str(params.get("node_type", "")),
		str(params.get("name", "")),
		params.get("properties", {}),
		str(params.get("script_path", "")),
	)
	if built.has("ok"):
		return built  # structured error
	var node: Node = built["node"]

	# Children are parented to the new node before it enters the tree; freeing
	# `node` on a later error cascades to them, so no separate cleanup is needed.
	var child_names: Array = []
	var child_nodes: Array = []
	for child in params.get("children", []):
		var child_built := _build_node(
			str(child.get("node_type", "")),
			str(child.get("name", "")),
			child.get("properties", {}),
			str(child.get("script_path", "")),
		)
		if child_built.has("ok"):
			node.free()
			return child_built
		var child_node: Node = child_built["node"]
		node.add_child(child_node)
		child_nodes.append(child_node)

	# #477 (parent rule): a composed node under a non-editable instanced parent
	# (and its whole subtree) is lost on save. #528: one shared commit — the
	# N-child variant with whole-subtree ownership inside the same action (the
	# undo side removes the subtree root, which drops the whole subtree).
	var persistence := _router._helpers.persistent_target(parent)
	var paths: Array = _router._helpers.commit_add_children(
		parent, [node], "Compose %s" % node.name, true
	)
	var node_path: String = paths[0]

	for child_node in child_nodes:
		child_names.append(String(child_node.name))
	return _router._ok(_router._helpers.with_persistence({
		"node_path": node_path,
		"created": true,
		"children": child_names,
		"script_attached": not str(params.get("script_path", "")).is_empty(),
		"properties_set": built["properties_set"],
		"saved": _maybe_save(params),
	}, persistence))


func _cmd_batch_create_nodes(params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _router._fail("PRECONDITION_FAILED", "No scene is open.", "active_scene")
	var parent_found := _router._resolve(params.get("parent_path", "."))
	if not parent_found["ok"]:
		return parent_found
	var parent: Node = parent_found["node"]
	var node_type := str(params.get("node_type", ""))
	var names: Array = params.get("names", [])
	if names.is_empty():
		return _router._fail("VALIDATION_ERROR", "'names' must be a non-empty array.")
	var properties: Dictionary = params.get("properties", {})

	var nodes: Array = []
	for raw_name in names:
		var built := _build_node(node_type, str(raw_name), properties, "")
		if built.has("ok"):
			for created_node in nodes:
				created_node.free()
			return built
		nodes.append(built["node"])

	# #477 (parent rule): batch-created nodes under a non-editable instanced
	# parent are all lost on save — one verdict covers them (they share the
	# parent); a per-node verdict would repeat the same token.
	var persistence := _router._helpers.persistent_target(parent)
	# Dry-run defense-in-depth (PR #545 review): the MCP layer enforces preview
	# semantics (run_or_preview never sends this command with dry_run set), but
	# a raw envelope carrying dry_run: true must not mutate the tree either —
	# the batch_set_property handler honors the flag the same way.
	if bool(params.get("dry_run", false)):
		var planned: Array = []
		for node in nodes:
			planned.append(Inspect.relative_path(node, root))
		return _router._ok({
			"created": [],
			"count": planned.size(),
			"saved": false,
			"dry_run": true,
			"undoable": _router._helpers.undoable_for_count(names.size()),
			"hint": "" if _router._helpers.undoable_for_count(names.size()) else _router._helpers.undo_threshold_hint(names.size()),
		})
	# #523: batch creates share the UndoRedo threshold — the decision + hint
	# live on the router (one site), same honesty shape as batch_set_property.
	var undoable := _router._helpers.undoable_for_count(names.size())
	if not undoable:
		for node in nodes:
			parent.add_child(node)
			node.set_owner(root)
	else:
		# #528: one shared N-child commit (one undo action for the batch).
		_router._helpers.commit_add_children(parent, nodes, "Batch create %d %s" % [nodes.size(), node_type])

	var created: Array = []
	for node in nodes:
		created.append(Inspect.relative_path(node, root))
	return _router._ok(_router._helpers.with_persistence({
		"created": created,
		"count": created.size(),
		"saved": _maybe_save(params),
		"undoable": undoable,
		"hint": "" if undoable else _router._helpers.undo_threshold_hint(names.size()),
	}, persistence))


func _cmd_apply_node_edits(params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _router._fail("PRECONDITION_FAILED", "No scene is open.", "active_scene")
	var edits: Array = params.get("edits", [])
	if edits.is_empty():
		return _router._fail("VALIDATION_ERROR", "'edits' must be a non-empty array.")

	var to_apply: Array = []  # each: {node, property, value, old}
	var edited_paths: Array = []
	var skipped: Array = []
	var persistence: Array = []  # #477: one verdict per edited node (#528: shared helper)
	var verdict_nodes: Array = []
	var verdict_paths: Array = []
	for edit in edits:
		var found := _router._resolve(edit.get("node_path", ""))
		if not found["ok"]:
			return found  # a specific bad path is a hard error
		var node: Node = found["node"]
		var properties: Dictionary = edit.get("properties", {})
		var applied_any := false
		for prop in properties:
			var prop_name := str(prop)
			var prop_type := _router._helpers.property_type(node, prop_name)
			if prop_type == -1:
				skipped.append({
					"node_path": str(edit.get("node_path")),
					"property": prop_name,
					"reason": "no such property",
				})
				continue
			to_apply.append({
				"node": node,
				"property": prop_name,
				"value": Coerce.from_json(properties[prop], prop_type),
				"old": node.get(prop_name),
			})
			applied_any = true
		if applied_any:
			var node_path := Inspect.relative_path(node, root)
			edited_paths.append(node_path)
			# #477: each edited node gets its own verdict — one aggregate ok
			# must never hide a target the save drops. Stamped by the shared
			# helper (#528).
			verdict_nodes.append(node)
			verdict_paths.append(node_path)
	persistence = _router._helpers.persistence_entries(verdict_nodes, verdict_paths)

	# Dry-run defense-in-depth (PR #545 review): the MCP layer enforces preview
	# semantics (run_or_preview never sends this command with dry_run set), but
	# a raw envelope carrying dry_run: true must not mutate the tree either.
	if bool(params.get("dry_run", false)):
		return _router._ok({
			"edited": [],
			"skipped": skipped,
			"count": 0,
			"saved": false,
			"dry_run": true,
			"undoable": _router._helpers.undoable_for_count(to_apply.size()),
			"hint": "" if _router._helpers.undoable_for_count(to_apply.size()) else _router._helpers.undo_threshold_hint(to_apply.size(), "applies"),
			"persistence": persistence,
		})

	if not to_apply.is_empty():
		# #523: per-node property edits share the UndoRedo threshold — the
		# decision + hint live on the router (one site), same honesty shape as
		# batch_set_property.
		var undoable := _router._helpers.undoable_for_count(to_apply.size())
		if not undoable:
			for item in to_apply:
				item["node"].set(item["property"], item["value"])
		else:
			var undo_redo := EditorInterface.get_editor_undo_redo()
			undo_redo.create_action("Apply %d node edits" % to_apply.size())
			for item in to_apply:
				undo_redo.add_do_property(item["node"], item["property"], item["value"])
				undo_redo.add_undo_property(item["node"], item["property"], item["old"])
			undo_redo.commit_action()
		for item in to_apply:
			_router._helpers.invalidate_prop_cache(item["node"])

	return _router._ok({
		"edited": edited_paths,
		"skipped": skipped,
		"count": edited_paths.size(),
		"saved": _maybe_save(params),
		"undoable": _router._helpers.undoable_for_count(to_apply.size()),
		"hint": "" if _router._helpers.undoable_for_count(to_apply.size()) else _router._helpers.undo_threshold_hint(to_apply.size(), "applies"),
		"persistence": persistence,
	})


# -- bulk semantic tools (GodotAgent) ----------------------------------------

func _fail_at(index: int, code: String, hint: String, required: String = "") -> Dictionary:
	var body := _router._fail(code, hint, required)
	body["index"] = index
	body["success"] = false
	return body


## Heterogeneous create+props in one transactional batch.
## Spec: {type|node_type, name|node_name, parent|parent_path, properties?, script_path?}
func _cmd_nodes_create_batch(params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _router._fail("PRECONDITION_FAILED", "No scene is open.", "active_scene")
	var specs: Variant = params.get("nodes", [])
	if not (specs is Array) or (specs as Array).is_empty():
		return _router._fail("VALIDATION_ERROR", "'nodes' must be a non-empty array.")

	var built_entries: Array = []  # {node, parent, index, name}
	var seen_under_parent: Dictionary = {}  # parent_path -> Dictionary of names

	for i in range((specs as Array).size()):
		var spec: Variant = (specs as Array)[i]
		if not (spec is Dictionary):
			_free_built(built_entries)
			return _fail_at(i, "VALIDATION_ERROR", "nodes[%d] must be a dictionary." % i)
		var d: Dictionary = spec
		var node_type := str(d.get("type", d.get("node_type", "")))
		var node_name := str(d.get("name", d.get("node_name", "")))
		var parent_path := str(d.get("parent", d.get("parent_path", ".")))
		var properties: Dictionary = d.get("properties", {})
		var script_path := str(d.get("script_path", ""))
		if node_type.is_empty() or node_name.is_empty():
			_free_built(built_entries)
			return _fail_at(i, "VALIDATION_ERROR", "nodes[%d] requires type and name." % i)
		var parent_found := _router._resolve(parent_path)
		if not parent_found["ok"]:
			_free_built(built_entries)
			var err: Dictionary = parent_found
			err["index"] = i
			err["success"] = false
			if str(err.get("error", "")) == "RESOURCE_NOT_FOUND":
				err["error"] = "INVALID_PARENT"
			return err
		var parent: Node = parent_found["node"]
		if not seen_under_parent.has(parent_path):
			seen_under_parent[parent_path] = {}
		var name_set: Dictionary = seen_under_parent[parent_path]
		if name_set.has(node_name) or parent.has_node(NodePath(node_name)):
			_free_built(built_entries)
			return _fail_at(i, "VALIDATION_ERROR", "Duplicate name '%s' under parent '%s'." % [node_name, parent_path])
		name_set[node_name] = true
		var built := _build_node(node_type, node_name, properties, script_path)
		if built.has("ok"):
			_free_built(built_entries)
			var berr: Dictionary = built
			berr["index"] = i
			berr["success"] = false
			return berr
		built_entries.append({"node": built["node"], "parent": parent, "parent_path": parent_path, "index": i})

	var total := built_entries.size()
	var undoable := _router._helpers.undoable_for_count(total)
	var planned_paths: Array = []
	for entry in built_entries:
		var n: Node = entry["node"]
		var p: Node = entry["parent"]
		# Relative path as it will appear after parenting.
		var parent_rel := Inspect.relative_path(p, root)
		if parent_rel.is_empty() or parent_rel == ".":
			planned_paths.append(String(n.name))
		else:
			planned_paths.append("%s/%s" % [parent_rel, n.name])

	if bool(params.get("dry_run", false)):
		_free_built(built_entries)
		return _router._ok({
			"success": true,
			"created": 0,
			"modified": 0,
			"failed": 0,
			"changes": planned_paths,
			"count": planned_paths.size(),
			"dry_run": true,
			"undoable": undoable,
			"hint": "" if undoable else _router._helpers.undo_threshold_hint(total),
			"saved": false,
		})

	# Group by parent and commit.
	var by_parent: Dictionary = {}  # parent instance id -> {parent, nodes}
	for entry in built_entries:
		var p: Node = entry["parent"]
		var key := p.get_instance_id()
		if not by_parent.has(key):
			by_parent[key] = {"parent": p, "nodes": []}
		(by_parent[key]["nodes"] as Array).append(entry["node"])

	if undoable:
		var ur := EditorInterface.get_editor_undo_redo()
		ur.create_action("nodes_create_batch (%d)" % total)
		for key in by_parent:
			var group: Dictionary = by_parent[key]
			var parent: Node = group["parent"]
			for child in group["nodes"]:
				ur.add_do_method(parent, "add_child", child)
				ur.add_do_method(child, "set_owner", root)
				ur.add_do_reference(child)
				ur.add_undo_method(parent, "remove_child", child)
		ur.commit_action()
	else:
		for key in by_parent:
			var group2: Dictionary = by_parent[key]
			var parent2: Node = group2["parent"]
			for child2 in group2["nodes"]:
				parent2.add_child(child2)
				child2.set_owner(root)

	# VERIFY: paths resolve
	var changes: Array = []
	for path in planned_paths:
		var check := _router._resolve(path)
		if not check["ok"]:
			return _router._fail(
				"INTERNAL_ERROR",
				"Post-create verify failed for '%s' (tree may be inconsistent)." % path
			)
		changes.append(path)

	var first_parent: Node = built_entries[0]["parent"]
	var persistence := _router._helpers.persistent_target(first_parent)
	return _router._ok(_router._helpers.with_persistence({
		"success": true,
		"created": changes.size(),
		"modified": 0,
		"failed": 0,
		"changes": changes,
		"count": changes.size(),
		"dry_run": false,
		"undoable": undoable,
		"hint": "" if undoable else _router._helpers.undo_threshold_hint(total),
		"saved": _maybe_save(params),
	}, persistence))


func _free_built(built_entries: Array) -> void:
	for entry in built_entries:
		var node: Node = entry["node"]
		if is_instance_valid(node) and node.get_parent() == null:
			node.free()


## Bulk property edits: operations[{path, property, value}] (also accepts legacy edits[]).
func _cmd_nodes_edit_batch(params: Dictionary) -> Dictionary:
	var root := EditorInterface.get_edited_scene_root()
	if root == null:
		return _router._fail("PRECONDITION_FAILED", "No scene is open.", "active_scene")

	var edits: Array = []
	var operations: Variant = params.get("operations", null)
	if operations is Array and not (operations as Array).is_empty():
		# Group operations by path into properties dicts for apply logic.
		var by_path: Dictionary = {}
		for i in range((operations as Array).size()):
			var op: Variant = (operations as Array)[i]
			if not (op is Dictionary):
				return _fail_at(i, "VALIDATION_ERROR", "operations[%d] must be a dictionary." % i)
			var d: Dictionary = op
			var path := str(d.get("path", d.get("node_path", "")))
			var prop := str(d.get("property", ""))
			if path.is_empty() or prop.is_empty():
				return _fail_at(i, "VALIDATION_ERROR", "operations[%d] requires path and property." % i)
			if not d.has("value"):
				return _fail_at(i, "VALIDATION_ERROR", "operations[%d] requires value." % i)
			if not by_path.has(path):
				by_path[path] = {}
			(by_path[path] as Dictionary)[prop] = d.get("value")
		for path in by_path:
			edits.append({"node_path": path, "properties": by_path[path]})
	elif params.get("edits") is Array and not (params.get("edits") as Array).is_empty():
		edits = params.get("edits")
	else:
		return _router._fail("VALIDATION_ERROR", "Provide non-empty 'operations' or 'edits'.")

	var applied_params := params.duplicate()
	applied_params["edits"] = edits
	var result := _cmd_apply_node_edits(applied_params)
	if not result.get("ok", false):
		return result
	var body: Dictionary = result.get("result", {})
	var edited: Array = body.get("edited", [])
	var skipped: Array = body.get("skipped", [])
	return _router._ok({
		"success": true,
		"created": 0,
		"modified": int(body.get("count", edited.size())),
		"failed": 0,
		"changes": edited,
		"skipped": skipped,
		"count": int(body.get("count", edited.size())),
		"saved": body.get("saved", false),
		"dry_run": body.get("dry_run", false),
		"undoable": body.get("undoable", true),
		"hint": body.get("hint", ""),
		"persistence": body.get("persistence", []),
	})
