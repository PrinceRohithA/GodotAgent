@tool
extends AcceptDialog
## Skills manager: enable/disable, add, import skills.

var skills: RefCounted
var list: ItemList


func _ready() -> void:
	title = "Skills"
	size = Vector2(560, 420)
	min_size = Vector2(520, 360)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(v)
	list = ItemList.new()
	list.select_mode = ItemList.SELECT_MULTI
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(list)
	var h := HBoxContainer.new()
	var add := Button.new()
	add.text = "Add .md/.json"
	var reload := Button.new()
	reload.text = "Reload"
	var import_dir := Button.new()
	import_dir.text = "Open User Skills"
	h.add_child(add)
	h.add_child(reload)
	h.add_child(import_dir)
	v.add_child(h)
	add.pressed.connect(_add)
	reload.pressed.connect(_refresh)
	import_dir.pressed.connect(_open_dir)
	confirmed.connect(_apply)
	_refresh()


func _refresh() -> void:
	if skills == null:
		return
	list.clear()
	var all_v: Variant = skills.list_skills()
	var all: Array = all_v if typeof(all_v) == TYPE_ARRAY else []
	var active_v: Variant = skills.get_active_ids()
	var active: Array = active_v if typeof(active_v) == TYPE_ARRAY else []
	for s in all:
		if typeof(s) != TYPE_DICTIONARY:
			continue
		var sd: Dictionary = s
		var idx := list.add_item(str(sd.get("name", sd.get("id", "skill"))))
		list.set_item_metadata(idx, sd.get("id", ""))
		list.set_item_tooltip(idx, str(sd.get("description", "")))
		if active.find(sd.get("id", "")) != -1:
			list.select(idx, false)


func _apply() -> void:
	if skills == null:
		return
	var ids: Array = []
	for i in list.get_item_count():
		if list.is_selected(i):
			ids.append(list.get_item_metadata(i))
	skills.set_active(ids)


func _add() -> void:
	var fd := FileDialog.new()
	fd.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	fd.access = FileDialog.ACCESS_FILESYSTEM
	fd.filters = PackedStringArray(["*.md ; Markdown", "*.json ; JSON", "*.yaml ; YAML", "*.yml ; YAML"])
	add_child(fd)
	fd.popup_centered(Vector2(560, 420))
	fd.file_selected.connect(
		func(p: String) -> void:
			_import_file(p)
			fd.queue_free()
	)


func _import_file(p: String) -> void:
	if not FileAccess.file_exists(p):
		return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null:
		return
	var t := f.get_as_text()
	f.close()
	var cfg := preload("res://addons/godot_agent/agent_config.gd").new()
	var dst := cfg.get_user_config_dir().path_join("skills").path_join(p.get_file())
	var fw := FileAccess.open(dst, FileAccess.WRITE)
	if fw:
		fw.store_string(t)
		fw.close()
	skills.load_all()
	_refresh()


func _open_dir() -> void:
	var cfg := preload("res://addons/godot_agent/agent_config.gd").new()
	var dir := cfg.get_user_config_dir().path_join("skills")
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	if OS.get_name() == "Windows":
		OS.execute("explorer.exe", [dir.replace("/", "\\")])
	else:
		OS.shell_open(dir)
