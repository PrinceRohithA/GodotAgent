@tool
extends RefCounted
## Skills registry: built-in + user skills (md/json/yaml). Composes active system prompts.

const SKILLS_DIR_USER := "GodotAgent/skills"
const SKILLS_DIR_BUILTIN := "res://addons/godot_agent/skills/builtin"

var _skills := {} # id -> dict
var _active := []

func _init() -> void:
	load_all()

func get_user_skills_dir() -> String:
	var cfg := preload("res://addons/godot_agent/agent_config.gd").new()
	var base := cfg.get_user_config_dir()
	return base.path_join("skills")

func load_all() -> void:
	_skills.clear()
	# built-in
	_scan_dir(SKILLS_DIR_BUILTIN, true)
	# user
	_scan_dir(get_user_skills_dir(), false)

func _scan_dir(dir_path: String, builtin: bool) -> void:
	# res:// paths need DirAccess.open; absolute user paths use dir_exists_absolute.
	var is_res := dir_path.begins_with("res://")
	if not is_res and not DirAccess.dir_exists_absolute(dir_path):
		if not builtin:
			DirAccess.make_dir_recursive_absolute(dir_path)
		return
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if not d.current_is_dir() and not f.begins_with("."):
			var lower := f.to_lower()
			if (
				lower.ends_with(".md")
				or lower.ends_with(".json")
				or lower.ends_with(".yaml")
				or lower.ends_with(".yml")
			):
				_load_skill_file(dir_path.path_join(f), builtin)
		f = d.get_next()
	d.list_dir_end()

func _load_skill_file(path: String, builtin: bool) -> void:
	var ext := path.get_extension().to_lower()
	var txt := ""
	if FileAccess.file_exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f: txt = f.get_as_text(); f.close()
	if txt.is_empty(): return
	var skill: Dictionary
	if ext == "json":
		var j := JSON.parse_string(txt)
		if typeof(j)==TYPE_DICTIONARY: skill = j
	elif ext == "yaml" or ext == "yml":
		# minimal yaml frontmatter-ish not needed; accept simple JSON-like rare, but keep simple: treat as md? skip heavy
		# fallback: try json if braces
		if txt.strip_edges().begins_with("{"):
			var j := JSON.parse_string(txt); if typeof(j)==TYPE_DICTIONARY: skill=j
		else:
			skill = _parse_md_skill(txt)
	elif ext == "md":
		skill = _parse_md_skill(txt)
	if skill.is_empty(): return
	if not skill.has("id"): skill["id"] = path.get_file().get_basename()
	skill["builtin"] = builtin
	skill["path"] = path
	_skills[skill["id"]] = skill

func _parse_md_skill(txt: String) -> Dictionary:
	var d := {"id":"","name":"","description":"","system_prompt":"","instructions":[],"tags":[],"enabled":true}
	# frontmatter between --- 
	if txt.begins_with("---"):
		var end := txt.find("---", 3)
		if end > 0:
			var fm := txt.substr(3, end-3)
			# very simple key: value pairs (line-based)
			for line in fm.split("\n"):
				line = line.strip_edges()
				if line.is_empty() or line.begins_with("#"): continue
				var sep := line.find(":")
				if sep < 0: continue
				var k := line.substr(0,sep).strip_edges().to_lower()
				var v := line.substr(sep+1).strip_edges().trim_prefix("\"").trim_suffix("\"")
				match k:
					"id","name","description","author","version": d[k]=v
					"tags": d.tags = v.replace(" ","").split(",")
					"tools_allowed","toolsets": d[k] = v.replace(" ","").split(",")
	# body as system_prompt/instructions
	var body := txt
	if txt.begins_with("---"):
		var end := txt.find("---", 3)
		if end >=0:
			body = txt.substr(end+3).strip_edges()
	d.system_prompt = body
	d.instructions = []
	d.name = d.name if d.name!="" else d.id
	d.description = d.description if d.description!="" else "Custom skill"
	return d

func list_skills() -> Array:
	var arr := []
	for id in _skills:
		arr.append(_skills[id].duplicate(true))
	return arr

func set_active(ids: Array) -> void:
	_active = ids
	_save_active()

func _save_active() -> void:
	var cfg := preload("res://addons/godot_agent/agent_config.gd").new()
	var base := cfg.get_user_config_dir()
	var p := base.path_join("skills_active.json")
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f: f.store_string(JSON.stringify(_active)); f.close()

func _load_active() -> void:
	var cfg := preload("res://addons/godot_agent/agent_config.gd").new()
	var base := cfg.get_user_config_dir()
	var p := base.path_join("skills_active.json")
	if FileAccess.file_exists(p):
		var f := FileAccess.open(p, FileAccess.READ)
		if f: var t=f.get_as_text(); f.close(); var j=JSON.parse_string(t); if typeof(j)==TYPE_ARRAY: _active=j
	elif _active.is_empty():
		_active = ["godot_core"]

func compose_system_prompt(base: String="") -> String:
	_load_active()
	var parts := []
	if base != "": parts.append(base)
	for id in _active:
		if _skills.has(id):
			var s: Dictionary = _skills[id]
			if s.get("system_prompt","")!="":
				parts.append("# Skill: "+s.get("name",id)+"\n"+s.get("system_prompt",""))
	return "\n\n---\n\n".join(parts) if parts.size()>1 else (parts[0] if parts.size()==1 else base)

func get_active_ids() -> Array: return _active
func get_skill(id: String) -> Dictionary: return _skills.get(id, {})