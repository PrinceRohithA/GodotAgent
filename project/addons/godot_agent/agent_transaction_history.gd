@tool
extends RefCounted
## Agent-owned reversible history.  We never call raw UndoRedo.undo()/redo(),
## which corrupts EditorUndoRedoManager's stacks in Godot 4.7.

var _undo: Array = []
var _redo: Array = []
const MAX_ENTRIES := 100

func record(label: String, undo_call: Callable, redo_call: Callable, meta: Dictionary = {}) -> void:
	_undo.append({"label": label, "undo": undo_call, "redo": redo_call, "meta": meta})
	_redo.clear()
	if _undo.size() > MAX_ENTRIES: _undo.pop_front()

func undo(steps: int = 1) -> Dictionary:
	var done := 0
	while done < maxi(steps, 1) and not _undo.is_empty():
		var entry: Dictionary = _undo.pop_back()
		var err: int = int(entry.undo.call())
		if err != OK:
			_undo.append(entry)
			return {"ok": false, "error": "undo_failed", "undone": done}
		_redo.append(entry)
		done += 1
	return {"ok": true, "undone": done, "can_redo": not _redo.is_empty()}

func redo(steps: int = 1) -> Dictionary:
	var done := 0
	while done < maxi(steps, 1) and not _redo.is_empty():
		var entry: Dictionary = _redo.pop_back()
		var err: int = int(entry.redo.call())
		if err != OK:
			_redo.append(entry)
			return {"ok": false, "error": "redo_failed", "redone": done}
		_undo.append(entry)
		done += 1
	return {"ok": true, "redone": done, "can_undo": not _undo.is_empty()}

func snapshot() -> Dictionary:
	var recent: Array = []
	for entry in _undo.slice(maxi(0, _undo.size() - 20)):
		recent.append(str(entry.get("label", "")))
	return {"undo_depth": _undo.size(), "redo_depth": _redo.size(), "can_undo": not _undo.is_empty(), "can_redo": not _redo.is_empty(), "recent": recent}
