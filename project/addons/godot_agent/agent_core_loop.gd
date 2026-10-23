@tool
extends RefCounted
## State helper for a durable Plan -> Execute -> Verify foreground task.
## The server owns asynchronous I/O; this object only owns honest state changes.

var tools_bridge: RefCounted
var memory: RefCounted
var skills: RefCounted
var reasoner: RefCounted
var cfg: RefCounted

var state := {
	"goal": "",
	"plan": [],
	"plan_summary": "",
	"iteration": 0,
	"status": "idle", # planned|running|paused|needs_confirmation|needs_user|succeeded|failed|cancelled|budget_exhausted
	"recent_changes": [],
	"verifications": [],
	"known_issues": [],
	"hypotheses": [],
	"next_action": "",
	"tool_calls": [],
	"final_summary": ""
}
var running := false
var cancel := false

func start(goal: String, plan: Array = []) -> void:
	if running: return
	state.goal = goal
	state.plan = plan
	state.status = "planned"
	state.iteration = 0
	state.tool_calls = []
	if memory != null:
		memory.goal = goal
	running = true
	cancel = false

func stop() -> void:
	running = false
	cancel = true
	state.status = "cancelled"

func pause(reason: String = "Paused by user.") -> Dictionary:
	if running:
		running = false
		state.status = "paused"
		state.known_issues.append(reason)
	return state.duplicate(true)

func resume() -> Dictionary:
	if state.status in ["paused", "needs_confirmation", "needs_user"]:
		state.status = "running"
		running = true
	return state.duplicate(true)

func set_plan(plan: Array, summary: String = "") -> Dictionary:
	state.plan = plan.duplicate(true)
	state.plan_summary = summary
	state.status = "running"
	return state.duplicate(true)

func record_tool_result(tool_name: String, result: Dictionary) -> Dictionary:
	state.tool_calls.append({"tool": tool_name, "ok": bool(result.get("ok", false))})
	if bool(result.get("ok", false)):
		state.recent_changes.append(str(result.get("summary", tool_name)))
	else:
		state.known_issues.append("%s: %s" % [tool_name, str(result.get("error", "failed"))])
	return state.duplicate(true)

func verify(evidence: String, passed: bool) -> Dictionary:
	state.verifications.append({"evidence": evidence, "passed": passed})
	if not passed:
		state.status = "needs_user"
		running = false
	return state.duplicate(true)

func finish(summary: String, succeeded: bool = true) -> Dictionary:
	state.final_summary = summary
	state.status = "succeeded" if succeeded else "failed"
	running = false
	return state.duplicate(true)

func step() -> Dictionary:
	if not running: return {"status": state.status}
	state.iteration += 1
	if memory != null:
		if memory.needs_compaction(): memory.compact()
		memory.sync_from_state(state)
	state.status = "running"
	return {"status": "running", "iteration": state.iteration, "next_action": state.next_action}
