@tool
extends VBoxContainer
## Right drawer Agent dock: chat, threads, status, tools.

var client: Node
var cfg: RefCounted
var skills: RefCounted

var chat_log: RichTextLabel
var input: LineEdit
var send_btn: Button
var status: Label
var models_btn: Button
var skills_btn: Button
var clear_btn: Button
var tools_btn: Button
var task_status: RichTextLabel
var task_selector: OptionButton
var _history: Array = []
var _current_assistant_reply: String = ""
var _active_task_id := ""
var _active_task_status := ""
var _active_tool_names: Array = []
var _active_agent_role := "Main"

var _proposal_card: PanelContainer
var _proposal_title: Label
var _proposal_scroll: ScrollContainer
var _proposal_desc: RichTextLabel
var _proposal_approve_btn: Button
var _proposal_reject_btn: Button
var _pending_proposal_token := ""

var _auth_card: PanelContainer
var _auth_title: Label
var _auth_desc: Label
var _auth_key_input: LineEdit
var _auth_submit_btn: Button
var _auth_open_models_btn: Button
var _auth_dismiss_btn: Button
var _pending_auth_provider := ""
var _pending_auth_provider_name := ""

var _network_card: PanelContainer
var _network_title: Label
var _network_desc: Label
var _network_retry_btn: Button
var _network_dismiss_btn: Button

func _ready() -> void:
	name = "Agent"
	add_theme_constant_override("separation", 6)
	custom_minimum_size = Vector2(220, 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL

	var top_btn_bar := HBoxContainer.new()
	top_btn_bar.add_theme_constant_override("separation", 4)
	models_btn = Button.new(); models_btn.text = "Models & Keys"; models_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skills_btn = Button.new(); skills_btn.text = "Skills"; skills_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tools_btn = Button.new(); tools_btn.text = "Tools"; tools_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_btn = Button.new(); clear_btn.text = "Clear"; clear_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_btn_bar.add_child(models_btn); top_btn_bar.add_child(skills_btn); top_btn_bar.add_child(tools_btn); top_btn_bar.add_child(clear_btn)
	add_child(top_btn_bar)

	status = Label.new()
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var is_conn := client != null and client.has_method("is_connected_to_agent") and bool(client.is_connected_to_agent())
	status.text = "Connected" if is_conn else "Disconnected"
	status.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6) if is_conn else Color(0.7, 0.7, 0.7))
	add_child(status)

	chat_log = RichTextLabel.new()
	chat_log.scroll_following = true
	chat_log.selection_enabled = true
	chat_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_log.bbcode_enabled = true
	chat_log.meta_clicked.connect(_on_chat_meta_clicked)
	add_child(chat_log)

	_proposal_card = _create_proposal_card()
	_proposal_card.visible = false
	add_child(_proposal_card)

	_auth_card = _create_auth_card()
	_auth_card.visible = false
	add_child(_auth_card)

	_network_card = _create_network_card()
	_network_card.visible = false
	add_child(_network_card)

	var bar := HBoxContainer.new()
	input = LineEdit.new()
	input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	input.placeholder_text = "Ask GodotAgent (or /task <goal>)..."
	send_btn = Button.new(); send_btn.text = "Send"
	bar.add_child(input); bar.add_child(send_btn)
	add_child(bar)

	task_selector = OptionButton.new()
	task_selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	task_selector.tooltip_text = "Select a durable task"
	add_child(task_selector)

	task_status = RichTextLabel.new()
	task_status.custom_minimum_size = Vector2(0, 60)
	task_status.bbcode_enabled = true
	task_status.scroll_following = true
	add_child(task_status)

	models_btn.pressed.connect(_open_models)
	skills_btn.pressed.connect(_open_skills)
	clear_btn.pressed.connect(func(): chat_log.clear(); _history.clear(); _current_assistant_reply = ""; _dismiss_proposal())
	tools_btn.pressed.connect(_show_active_tools)
	send_btn.pressed.connect(_send)
	input.text_submitted.connect(func(_t): _send())
	task_selector.item_selected.connect(func(index: int): _select_task(index))
	client.send({"type": "tasks.list"})

func _open_models() -> void:
	var d := preload("res://addons/godot_agent/models_dialog.gd").new()
	d.cfg = cfg
	d.client = client
	get_tree().get_root().add_child(d)
	d.popup_centered()

func _open_skills() -> void:
	var d := preload("res://addons/godot_agent/skills_dialog.gd").new()
	d.skills = skills
	get_tree().get_root().add_child(d)
	d.popup_centered()

func _send() -> void:
	var t := input.text.strip_edges()
	if t == "": return
	_dismiss_proposal()
	if t == "/cancel" or t == "/stop":
		_task_command("tasks.cancel")
		_append("[color=#d98][i]Cancelled current task.[/i][/color]\n")
		input.text = ""
		return
	if t == "/pause":
		_task_command("tasks.pause")
		_append("[color=#d98][i]Paused current task.[/i][/color]\n")
		input.text = ""
		return
	if t == "/resume" or t.to_lower() == "resume" or (t.to_lower() == "continue" and _active_task_id != "" and (_active_task_status == "paused" or _active_task_status == "budget_exhausted")):
		_task_command("tasks.resume")
		_append("[color=#7ac][i]Resumed current task.[/i][/color]\n")
		input.text = ""
		return
	if t == "/retry":
		_retry_chat()
		input.text = ""
		return
	if t == "/relogin":
		_show_relogin_card(_pending_auth_provider, _pending_auth_provider_name, "")
		input.text = ""
		return
	if t.begins_with("/login ") or t.begins_with("/key "):
		var new_k := t.substr(t.find(" ") + 1).strip_edges()
		if new_k != "":
			if _auth_key_input != null:
				_auth_key_input.text = new_k
			_submit_relogin_key()
			input.text = ""
			return
	if t.begins_with("/task ") or t.begins_with("/task:") or t.to_lower().begins_with("task:"):
		var goal := t.substr(t.find(" ") + 1).strip_edges() if t.contains(" ") else t.substr(t.find(":") + 1).strip_edges()
		if goal != "":
			_run_task(goal)
			return
	_append("[b]You:[/b] %s\n" % t)
	_history.append({"role":"user","content":t})
	var max_turns := 20
	if cfg != null and cfg.has_method("get_history_limit"):
		max_turns = int(cfg.get_history_limit())
	client.send({"type":"chat","content":t,"history":_history.slice(-max_turns)})
	input.text = ""
	_current_assistant_reply = ""

func _run_task(goal: String = "") -> void:
	if goal == "":
		goal = input.text.strip_edges()
	if goal == "": return
	_dismiss_proposal()
	_append("[b]Task:[/b] %s\n" % goal)
	client.send({"type": "tasks.start", "goal": goal})
	input.text = ""
	_current_assistant_reply = ""

func _task_command(kind: String) -> void:
	if _active_task_id != "": client.send({"type": kind, "task_id": _active_task_id})

func _append(bb: String) -> void:
	chat_log.append_text(bb)
	chat_log.queue_redraw()

func on_msg(m: Dictionary) -> void:
	var typ := str(m.get("type",""))
	match typ:
		"hello":
			var n := int(m.get("tools", 0))
			var mcp := bool(m.get("mcp", false))
			var backend: Dictionary = m.get("backend", {})
			status.text = _status_text(n, mcp, backend)
			_append("[i]Agent ready — %d executable tools%s[/i]\n" % [n, " (MCP ready)" if mcp else " (native tools; MCP offline)"])
		"agent_switch":
			var sw_role := str(m.get("agent", "Main"))
			_active_agent_role = sw_role
			if sw_role == "LevelDesigner":
				_append("\n[color=#34d399][b]▶ Delegated to Level Designer Subagent[/b][/color]\n\n")
			else:
				_append("\n[color=#38bdf8][b]◀ Handover to Main Agent[/b][/color]\n\n")
		"thought":
			var thought_text := str(m.get("text", ""))
			var is_model := str(m.get("source", "")) == "model"
			var th_agent := str(m.get("agent", _active_agent_role))
			var show_thoughts := true
			if cfg != null and cfg.has_method("data"):
				var ui_cfg: Dictionary = cfg.data().get("ui", {})
				show_thoughts = bool(ui_cfg.get("show_thoughts", true))
			if not is_model:
				_append("[color=#888][i]%s[/i][/color]\n" % thought_text)
			elif show_thoughts:
				var clean_thought := thought_text.replace("<think>", "").replace("</think>", "").strip_edges()
				var badge := "[color=#34d399][b]Thinking: [Level Designer][/b][/color] " if th_agent == "LevelDesigner" else "[color=#38bdf8][b]Thinking: [Main Agent][/b][/color] "
				_append("%s\n[color=#9aa0a6][i]%s[/i][/color]\n\n" % [badge, clean_thought])
		"proposal":
			_handle_proposal(m)
		"tool_result":
			var ok := bool(m.get("ok", false))
			var mark := "ok" if ok else "err"
			var detail := str(m.get("preview", "")) if not ok else ""
			if bool(m.get("has_image", false)):
				detail = "📷 " + str(m.get("preview", "Screenshot captured"))
			var res_agent := str(m.get("agent", _active_agent_role))
			var agent_prefix := "[color=#34d399][Level Designer][/color] " if res_agent == "LevelDesigner" else "[color=#38bdf8][Main Agent][/color] "
			_append("%s[color=#6a9][tool %s] %s%s[/color]\n" % [agent_prefix, mark, str(m.get("name","")), ": " + detail if detail != "" else ""])
			if bool(m.get("requires_confirmation", false)):
				_handle_proposal({
					"tool_name": str(m.get("name", "Action")),
					"token": str(m.get("confirmation_token", "")),
					"description": detail,
				})
		"chunk":
			var chunk_text := str(m.get("text",""))
			var ch_agent := str(m.get("agent", _active_agent_role))
			if _current_assistant_reply == "":
				var agent_label := "[color=#34d399][b]Level Designer:[/b][/color] " if ch_agent == "LevelDesigner" else "[color=#38bdf8][b]Assistant:[/b][/color] "
				chat_log.append_text(agent_label)
			_current_assistant_reply += chunk_text
			chat_log.append_text(chunk_text)
		"tools.list":
			var listed_count := int(m.get("count", 0))
			var backend: Dictionary = m.get("backend", {})
			status.text = _status_text(listed_count, bool(m.get("mcp", false)), backend)
			var discovered := int(backend.get("mcp_count", 0))
			var active_mcp := int(backend.get("model_mcp_count", 0))
			_active_tool_names = m.get("names", [])
			var suffix := ""
			if bool(m.get("mcp", false)):
				var pinned := int(backend.get("pinned_mcp_count", 0))
				var on_demand := int(backend.get("on_demand_mcp_count", 0))
				suffix = " · profile=%s · %d pinned + %d optional MCP · %d on-demand" % [str(backend.get("profile", "baseline")), pinned, maxi(0, active_mcp - pinned), on_demand]
			_append("[i]Active model tools (%d)%s. Click Tools to inspect the active list.[/i]\n" % [listed_count, suffix])
		"profile.selected":
			_append("[color=#7ac][i]%s[/i][/color]\n" % str(m.get("text", "MCP profile updated")))
		"model.plan_updated":
			var mod_name := str(m.get("model", ""))
			var ctx_win := int(m.get("context_window", 0))
			var comp_thresh := int(m.get("compact_threshold", 0))
			_append("[color=#7ac][i]Model active: %s · Context: %d tokens (~%d chars threshold)[/i][/color]\n" % [mod_name, ctx_win, comp_thresh])
		"tasks.list":
			var tasks: Array = m.get("tasks", [])
			_update_task_selector(tasks)
			if not tasks.is_empty():
				var selected: Dictionary = tasks[0]
				for task_v in tasks:
					if typeof(task_v) == TYPE_DICTIONARY and str((task_v as Dictionary).get("id", "")) == _active_task_id:
						selected = task_v
						break
				_show_task(selected)
		"tasks.status":
			_show_task(m.get("task", {}))
			client.send({"type": "tasks.list"})
		"network_issue":
			var n_st := str(m.get("status", ""))
			var n_err := str(m.get("error", "Network issue"))
			var attempt := int(m.get("attempt", 1))
			var max_att := int(m.get("max_retries", 3))
			var delay := float(m.get("delay", 1.5))
			if n_st == "retrying":
				_append("[color=#f59e0b][b]⚠️ Network Issue (attempt %d/%d):[/b] %s. Retrying in %.1fs...[/color]\n\n" % [attempt, max_att, n_err, delay])
			elif n_st == "failed":
				_append("[color=#ef4444][b]❌ Network Connection Failed:[/b] %s (exhausted %d retries).[/color]\n" % [n_err, max_att])
				_append("[url=retry_chat][color=#38bdf8][b][ ⟳ Click to Retry LLM Call ][/b][/color][/url]\n\n")
				_show_network_retry_card(n_err)
		"auth_required":
			var a_prov := str(m.get("provider", ""))
			var a_pname := str(m.get("provider_name", a_prov))
			var a_err := str(m.get("error", "Authentication required"))
			_append("[color=#ef4444][b]🔒 Authentication Required for %s:[/b] %s[/color]\n" % [a_pname, a_err])
			_append("[url=relogin][color=#f59e0b][b][ 🔑 Enter API Key / Relogin ][/b][/color][/url]   [url=open_models][color=#38bdf8][b][ ⚙ Open Models & Keys ][/b][/color][/url]\n\n")
			_show_relogin_card(a_prov, a_pname, a_err)
		"auth.updated":
			var u_pname := str(m.get("provider_name", m.get("provider", "")))
			_append("[color=#34d399][b]✓ Authentication updated for %s.[/b] Resuming LLM call...[/color]\n\n" % u_pname)
			_dismiss_relogin_card()
		"done":
			_dismiss_proposal()
			chat_log.append_text("\n\n")
			if _current_assistant_reply.strip_edges() != "" and _current_assistant_reply.strip_edges() != "(empty model response)":
				_history.append({"role": "assistant", "content": _current_assistant_reply})
			_current_assistant_reply = ""
		"pong":
			pass

func set_connected(c: bool) -> void:
	status.text = "Connected" if c else "Reconnecting..."
	status.add_theme_color_override("font_color", Color(0.4, 0.9, 0.6) if c else Color(0.7, 0.7, 0.7))

func _status_text(total: int, mcp: bool, backend: Dictionary) -> String:
	var native_count := int(backend.get("native_count", total))
	var mcp_count := int(backend.get("mcp_count", 0))
	if mcp:
		var active_mcp := int(backend.get("model_mcp_count", mcp_count))
		return "Connected · %s · %d active (%d native + %d/%d MCP)" % [str(backend.get("profile", "baseline")), total, native_count, active_mcp, mcp_count]
	var unavailable := int(backend.get("mcp_unavailable_intents", 0))
	return "Connected · %d native tools · MCP offline (%d capabilities)" % [native_count, unavailable]

func _show_task(task: Dictionary) -> void:
	if task.is_empty(): return
	_active_task_id = str(task.get("id", ""))
	_active_task_status = str(task.get("status", ""))
	var plan: Array = task.get("plan", [])
	var current := int(task.get("current_step", 0))
	var lines: Array = ["[b]Task:[/b] %s · %s" % [str(task.get("status", "")), str(task.get("goal", ""))]]
	for i in plan.size():
		var step: Variant = plan[i]
		var title := str(step.get("title", step) if typeof(step) == TYPE_DICTIONARY else step)
		lines.append("%s %s" % ["→" if i == current else "•", title])
	var blocker := str(task.get("blocker", ""))
	if blocker != "": lines.append("[color=#d98]Blocker: %s[/color]" % blocker)
	var budget: Dictionary = task.get("budget", {})
	var max_tc := int(budget.get("max_tool_calls", 0))
	var max_llm := int(budget.get("max_llm_rounds", 0))
	var tc_str := "%d/%d" % [int(task.get("tool_calls", 0)), max_tc] if max_tc > 0 else "%d (unlimited)" % int(task.get("tool_calls", 0))
	var llm_str := "%d/%d" % [int(task.get("llm_rounds", 0)), max_llm] if max_llm > 0 else "%d (unlimited)" % int(task.get("llm_rounds", 0))
	lines.append("Progress: %s tool calls · %s LLM rounds" % [tc_str, llm_str])
	var evidence: Array = task.get("evidence", [])
	if not evidence.is_empty(): lines.append("Evidence: " + str((evidence.back() as Dictionary).get("tool", "updated")))
	var token := str(task.get("confirmation_token", ""))
	if token != "": lines.append("[color=#d98]Approval pending: %s — approve using the proposal card.[/color]" % token)
	task_status.text = "\n".join(lines)

func _update_task_selector(tasks: Array) -> void:
	if task_selector == null: return
	task_selector.clear()
	for task_v in tasks:
		if typeof(task_v) != TYPE_DICTIONARY: continue
		var task: Dictionary = task_v
		var label := "%s · %s" % [str(task.get("status", "")), str(task.get("goal", "")).substr(0, 45)]
		task_selector.add_item(label)
		task_selector.set_item_metadata(task_selector.item_count - 1, str(task.get("id", "")))
		if str(task.get("id", "")) == _active_task_id: task_selector.select(task_selector.item_count - 1)

func _select_task(index: int) -> void:
	if index < 0 or task_selector == null: return
	_active_task_id = str(task_selector.get_item_metadata(index))
	client.send({"type": "tasks.list"})

func _show_active_tools() -> void:
	var dialog := AcceptDialog.new()
	dialog.title = "Active model tools (%d)" % _active_tool_names.size()
	var list := RichTextLabel.new()
	list.bbcode_enabled = false
	list.selection_enabled = true
	list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	list.text = "\n".join(_active_tool_names)
	dialog.add_child(list)
	dialog.confirmed.connect(func() -> void: dialog.queue_free())
	add_child(dialog)
	dialog.popup_centered(Vector2i(560, 560))

func _create_proposal_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.14, 0.16, 0.20, 1.0)
	style.border_color = Color(0.96, 0.77, 0.26, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	_proposal_title = Label.new()
	_proposal_title.text = "⚠️ Proposed Action"
	_proposal_title.add_theme_color_override("font_color", Color(0.96, 0.77, 0.26))
	vbox.add_child(_proposal_title)

	_proposal_scroll = ScrollContainer.new()
	_proposal_scroll.custom_minimum_size = Vector2(0, 100)
	_proposal_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proposal_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_proposal_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO

	_proposal_desc = RichTextLabel.new()
	_proposal_desc.fit_content = true
	_proposal_desc.scroll_active = false
	_proposal_desc.selection_enabled = true
	_proposal_desc.bbcode_enabled = true
	_proposal_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proposal_desc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_proposal_scroll.add_child(_proposal_desc)
	vbox.add_child(_proposal_scroll)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 8)

	_proposal_approve_btn = Button.new()
	_proposal_approve_btn.text = "✓ Approve & Run"
	_proposal_approve_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proposal_approve_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	_proposal_approve_btn.pressed.connect(func() -> void: _approve_action(_pending_proposal_token))
	btn_row.add_child(_proposal_approve_btn)

	_proposal_reject_btn = Button.new()
	_proposal_reject_btn.text = "✕ Reject"
	_proposal_reject_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_proposal_reject_btn.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	_proposal_reject_btn.pressed.connect(func() -> void: _reject_action(_pending_proposal_token))
	btn_row.add_child(_proposal_reject_btn)

	vbox.add_child(btn_row)
	panel.add_child(vbox)
	return panel

func _handle_proposal(m: Dictionary) -> void:
	var tool_name := str(m.get("tool_name", "Action"))
	var desc := str(m.get("description", ""))
	var token := str(m.get("token", ""))
	_pending_proposal_token = token

	_proposal_title.text = "⚠️ Proposed Action: %s" % tool_name
	_proposal_desc.text = "[code]%s[/code]" % desc if desc != "" else "[i]No parameters[/i]"

	var line_count := desc.count("\n") + 1
	var target_h := clampi(line_count * 20 + 20, 48, 160)
	if _proposal_scroll != null:
		_proposal_scroll.custom_minimum_size = Vector2(0, target_h)
		_proposal_scroll.scroll_vertical = 0

	_proposal_card.visible = true

	_append("\n[color=#f5c542][b]⚠️ Action Proposed:[/b][/color] [code]%s[/code]\n" % tool_name)
	if desc != "":
		var lines := desc.split("\n")
		if lines.size() > 15:
			var preview := "\n".join(lines.slice(0, 15))
			_append("[code]%s\n... (%d more lines in proposal card)[/code]\n" % [preview, lines.size() - 15])
		else:
			_append("[code]%s[/code]\n" % desc)
	_append("[url=approve:%s][color=#4ade80][b][ ✓ Approve & Run ][/b][/color][/url]   [url=reject:%s][color=#f87171][b][ ✕ Reject ][/b][/color][/url]\n\n" % [token, token])

func _dismiss_proposal() -> void:
	if _proposal_card != null:
		_proposal_card.visible = false
	_pending_proposal_token = ""

func _approve_action(token: String) -> void:
	if token == "" or client == null: return
	_dismiss_proposal()
	_append("[color=#4ade80][i]✓ Approved action[/i][/color]\n")
	client.send({"type": "action.approve", "token": token})

func _reject_action(token: String) -> void:
	if token == "" or client == null: return
	_dismiss_proposal()
	_append("[color=#f87171][i]✕ Rejected action[/i][/color]\n")
	client.send({"type": "action.reject", "token": token})

func _on_chat_meta_clicked(meta: Variant) -> void:
	var s := str(meta)
	if s.begins_with("approve:"):
		_approve_action(s.trim_prefix("approve:"))
	elif s.begins_with("reject:"):
		_reject_action(s.trim_prefix("reject:"))
	elif s == "retry_chat":
		_retry_chat()
	elif s == "open_models":
		_open_models()
	elif s == "relogin":
		_show_relogin_card(_pending_auth_provider, _pending_auth_provider_name, "")


func _create_auth_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.12, 0.12, 1.0)
	style.border_color = Color(0.95, 0.40, 0.40, 0.95)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	_auth_title = Label.new()
	_auth_title.text = "🔒 Authentication Required"
	_auth_title.add_theme_color_override("font_color", Color(0.95, 0.45, 0.45))
	vbox.add_child(_auth_title)

	_auth_desc = Label.new()
	_auth_desc.text = "Invalid or expired API key. Please update your key to continue."
	_auth_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_auth_desc)

	_auth_key_input = LineEdit.new()
	_auth_key_input.placeholder_text = "Paste new API key here..."
	_auth_key_input.secret = true
	_auth_key_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_key_input.text_submitted.connect(func(_t: String) -> void: _submit_relogin_key())
	vbox.add_child(_auth_key_input)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)

	_auth_submit_btn = Button.new()
	_auth_submit_btn.text = "✓ Submit & Resume"
	_auth_submit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_submit_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.5))
	_auth_submit_btn.pressed.connect(_submit_relogin_key)
	btn_row.add_child(_auth_submit_btn)

	_auth_open_models_btn = Button.new()
	_auth_open_models_btn.text = "⚙ Models & Keys..."
	_auth_open_models_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auth_open_models_btn.pressed.connect(_open_models)
	btn_row.add_child(_auth_open_models_btn)

	_auth_dismiss_btn = Button.new()
	_auth_dismiss_btn.text = "✕ Dismiss"
	_auth_dismiss_btn.pressed.connect(func() -> void: panel.visible = false)
	btn_row.add_child(_auth_dismiss_btn)

	vbox.add_child(btn_row)
	panel.add_child(vbox)
	return panel


func _create_network_card() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.18, 0.15, 0.10, 1.0)
	style.border_color = Color(0.96, 0.60, 0.20, 0.9)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)

	_network_title = Label.new()
	_network_title.text = "⚠️ Network Connection Failed"
	_network_title.add_theme_color_override("font_color", Color(0.96, 0.65, 0.25))
	vbox.add_child(_network_title)

	_network_desc = Label.new()
	_network_desc.text = "Could not contact model server. Check your network or local LLM server."
	_network_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(_network_desc)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)

	_network_retry_btn = Button.new()
	_network_retry_btn.text = "⟳ Retry LLM Call"
	_network_retry_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_network_retry_btn.add_theme_color_override("font_color", Color(0.3, 0.8, 1.0))
	_network_retry_btn.pressed.connect(_retry_chat)
	btn_row.add_child(_network_retry_btn)

	_network_dismiss_btn = Button.new()
	_network_dismiss_btn.text = "✕ Dismiss"
	_network_dismiss_btn.pressed.connect(func() -> void: panel.visible = false)
	btn_row.add_child(_network_dismiss_btn)

	vbox.add_child(btn_row)
	panel.add_child(vbox)
	return panel


func _show_relogin_card(provider_id: String, provider_name: String, error_msg: String) -> void:
	_pending_auth_provider = provider_id
	_pending_auth_provider_name = provider_name if provider_name != "" else provider_id
	if _auth_title != null:
		_auth_title.text = "🔒 Authentication Required: %s" % _pending_auth_provider_name
	if _auth_desc != null and error_msg != "":
		_auth_desc.text = error_msg
	if _auth_key_input != null:
		_auth_key_input.text = ""
		_auth_key_input.placeholder_text = "Enter new API key for %s..." % _pending_auth_provider_name
	if _auth_card != null:
		_auth_card.visible = true
	if _network_card != null:
		_network_card.visible = false


func _dismiss_relogin_card() -> void:
	if _auth_card != null:
		_auth_card.visible = false


func _submit_relogin_key() -> void:
	if _auth_key_input == null or client == null: return
	var k := _auth_key_input.text.strip_edges()
	if k == "": return
	var prov := _pending_auth_provider
	if prov == "" and cfg != null:
		prov = str(cfg.data().get("active_provider", "ollama"))
	if cfg != null and cfg.has_method("set_api_key"):
		cfg.set_api_key(prov, k)
	client.send({"type": "auth.update_key", "provider": prov, "api_key": k})
	_dismiss_relogin_card()


func _show_network_retry_card(error_msg: String) -> void:
	if _network_desc != null and error_msg != "":
		_network_desc.text = error_msg
	if _network_card != null:
		_network_card.visible = true
	if _auth_card != null:
		_auth_card.visible = false


func _dismiss_network_card() -> void:
	if _network_card != null:
		_network_card.visible = false


func _retry_chat() -> void:
	_dismiss_network_card()
	_dismiss_relogin_card()
	if client != null:
		client.send({"type": "chat.retry"})
	_append("[color=#38bdf8][i]⟳ Retrying pending LLM call...[/i][/color]\n")

