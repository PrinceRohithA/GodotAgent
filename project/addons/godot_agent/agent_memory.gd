@tool
extends RefCounted
## Working memory + project-scoped durable JSONL. Compaction keeps context small.

var goal := ""
var plan_summary := ""
var relevant_files: Array = []
var relevant_nodes: Array = []
var recent_changes: Array = []
var hypotheses: Array = []
var test_results: Array = []
var known_issues: Array = []
var failed_approaches: Array = []
var next_action := ""
var scratch_observations: Array = []
var approx_context_chars := 0
var compaction_threshold_chars := 80000

var _long_term := [] # [{ts,role,content,tags:[]}]

func _init() -> void:
	_load_long_term()

func sync_from_state(state: Dictionary={}) -> void:
	# state passed as dict from loop
	goal = state.get("goal","")
	plan_summary = state.get("plan_summary","")
	recent_changes = state.get("recent_changes",[]).slice(-20)
	hypotheses = state.get("hypotheses",[]).slice(-10)
	test_results = state.get("verifications",[]).slice(-10)
	known_issues = state.get("known_issues",[])
	next_action = state.get("next_action","")

func needs_compaction() -> bool:
	return approx_context_chars >= compaction_threshold_chars

func compact() -> void:
	scratch_observations.clear()
	recent_changes = recent_changes.slice(-10)
	hypotheses = hypotheses.slice(-5)
	test_results = test_results.slice(-5)
	failed_approaches = failed_approaches.slice(-10)
	approx_context_chars = max(0, approx_context_chars/2)

func remember_observation(text: String) -> void:
	scratch_observations.append(text)
	approx_context_chars += text.length()

func note_relevant(files: Array=[], nodes: Array=[]) -> void:
	for f in files:
		if relevant_files.find(f)==-1: relevant_files.append(f)
	for n in nodes:
		if relevant_nodes.find(n)==-1: relevant_nodes.append(n)

func add_long_term(role: String, content: String, tags: Array=[]) -> void:
	_long_term.append({"ts": Time.get_unix_time_from_system(), "role":role, "content":content, "tags":tags})
	if _long_term.size()>500: _long_term.pop_front()
	_save_long_term()

func _lt_path() -> String:
	return "user://godot_agent/memory.jsonl"

func _save_long_term() -> void:
	var p := _lt_path()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(p.get_base_dir()))
	var f := FileAccess.open(p, FileAccess.WRITE)
	if f == null: return
	for e in _long_term:
		f.store_line(JSON.stringify(e))
	f.close()

func _load_long_term() -> void:
	var p := _lt_path()
	if not FileAccess.file_exists(p): return
	var f := FileAccess.open(p, FileAccess.READ)
	if f == null: return
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line.is_empty(): continue
		var j := JSON.parse_string(line)
		if typeof(j)==TYPE_DICTIONARY: _long_term.append(j)
	f.close()

func as_prompt_dict() -> Dictionary:
	return {
		"goal": goal,
		"plan": plan_summary,
		"relevant_files": relevant_files.duplicate(),
		"relevant_nodes": relevant_nodes.duplicate(),
		"recent_changes": recent_changes.duplicate(),
		"hypotheses": hypotheses.duplicate(),
		"test_results": test_results.duplicate(),
		"known_issues": known_issues.duplicate(),
		"failed_approaches": failed_approaches.duplicate(),
		"next_action": next_action,
	}
func long_term_recent(limit: int=20) -> Array:
	var out := _long_term.duplicate()
	out.reverse()
	return out.slice(0,limit)
