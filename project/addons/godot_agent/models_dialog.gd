@tool
extends AcceptDialog
## Models & Keys dialog: manage providers, keys, models, test.

var cfg: RefCounted
var client: Node

var provider_list: OptionButton
var model_list: OptionButton
var base_url: LineEdit
var api_key: LineEdit
var model_edit: LineEdit
var test_btn: Button
var models_btn: Button
var status: Label
var streaming: CheckBox
var requires_key: CheckBox
var web_endpoint: LineEdit
var web_api_key: LineEdit
var web_provider: OptionButton
var web_scrape_content: CheckBox
var reasoning_effort: OptionButton
var task_minutes: SpinBox
var task_tool_calls: SpinBox
var task_llm_rounds: SpinBox
var task_timeout: SpinBox
var task_compact_threshold: SpinBox
var _http: HTTPRequest
var _http_mode: String = ""


func _ready() -> void:
	title = "Models & Keys"
	size = Vector2(680, 500)
	min_size = Vector2(640, 460)
	_build_ui()
	_populate()
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_http_completed)
	if client != null and client.has_signal("message"):
		client.message.connect(_on_msg)
	close_requested.connect(queue_free)
	canceled.connect(queue_free)


func _exit_tree() -> void:
	if _http != null:
		_http.cancel_request()
	if client != null and client.has_signal("message") and client.message.is_connected(_on_msg):
		client.message.disconnect(_on_msg)


func _build_ui() -> void:
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	add_child(v)

	var hp := HBoxContainer.new()
	var lp := Label.new()
	lp.text = "Provider:"
	provider_list = OptionButton.new()
	hp.add_child(lp)
	hp.add_child(provider_list)
	v.add_child(hp)

	var hb := HBoxContainer.new()
	var lb := Label.new()
	lb.text = "Base URL:"
	base_url = LineEdit.new()
	base_url.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(lb)
	hb.add_child(base_url)
	v.add_child(hb)

	var hk := HBoxContainer.new()
	var lk := Label.new()
	lk.text = "API Key:"
	api_key = LineEdit.new()
	api_key.secret = true
	api_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hk.add_child(lk)
	hk.add_child(api_key)
	v.add_child(hk)

	var hm := HBoxContainer.new()
	var lm := Label.new()
	lm.text = "Model:"
	model_list = OptionButton.new()
	model_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	model_edit = LineEdit.new()
	model_edit.placeholder_text = "or type model id"
	hm.add_child(lm)
	hm.add_child(model_list)
	hm.add_child(model_edit)
	v.add_child(hm)

	var ho := HBoxContainer.new()
	streaming = CheckBox.new()
	streaming.text = "Streaming"
	requires_key = CheckBox.new()
	requires_key.text = "Requires Key"
	ho.add_child(streaming)
	ho.add_child(requires_key)
	v.add_child(ho)

	var ha := HBoxContainer.new()
	models_btn = Button.new()
	models_btn.text = "Fetch Models"
	test_btn = Button.new()
	test_btn.text = "Test Connection"
	ha.add_child(models_btn)
	ha.add_child(test_btn)
	v.add_child(ha)

	var hr := HBoxContainer.new()
	var lr := Label.new(); lr.text = "Reasoning effort:"
	reasoning_effort = OptionButton.new()
	for effort in ["none", "low", "medium", "high"]:
		reasoning_effort.add_item(effort.capitalize())
		reasoning_effort.set_item_metadata(reasoning_effort.item_count - 1, effort)
	hr.add_child(lr); hr.add_child(reasoning_effort)
	v.add_child(hr)

	var ht := HBoxContainer.new()
	var lt := Label.new(); lt.text = "Task limits (tool calls / LLM rounds, 0 = unlimited):"
	task_minutes = SpinBox.new(); task_minutes.visible = false; task_minutes.value = 0
	task_tool_calls = SpinBox.new(); task_tool_calls.min_value = 0; task_tool_calls.max_value = 10000
	task_llm_rounds = SpinBox.new(); task_llm_rounds.min_value = 0; task_llm_rounds.max_value = 10000
	task_tool_calls.tooltip_text = "0 = Unlimited tool calls"
	task_llm_rounds.tooltip_text = "0 = Unlimited LLM rounds"
	ht.add_child(lt); ht.add_child(task_tool_calls); ht.add_child(task_llm_rounds)
	v.add_child(ht)
	var htc := HBoxContainer.new()
	var ltc := Label.new(); ltc.text = "Task request timeout / compact threshold:"
	task_timeout = SpinBox.new(); task_timeout.min_value = 5; task_timeout.max_value = 3600
	task_compact_threshold = SpinBox.new(); task_compact_threshold.min_value = 1000; task_compact_threshold.max_value = 1000000; task_compact_threshold.step = 1000
	htc.add_child(ltc); htc.add_child(task_timeout); htc.add_child(task_compact_threshold)
	v.add_child(htc)

	var web_title := Label.new()
	web_title.text = "Web search & scraping (Firecrawl / Brave API)"
	v.add_child(web_title)

	var hwp := HBoxContainer.new()
	var lwp := Label.new(); lwp.text = "Engine:"
	web_provider = OptionButton.new()
	web_provider.add_item("Firecrawl v2 (Recommended - Keyless or API Key)")
	web_provider.set_item_metadata(0, "firecrawl")
	web_provider.add_item("Brave Search")
	web_provider.set_item_metadata(1, "brave")
	web_scrape_content = CheckBox.new()
	web_scrape_content.text = "Scrape full markdown content"
	web_scrape_content.button_pressed = true
	hwp.add_child(lwp)
	hwp.add_child(web_provider)
	hwp.add_child(web_scrape_content)
	v.add_child(hwp)

	var hw := HBoxContainer.new()
	web_endpoint = LineEdit.new(); web_endpoint.placeholder_text = "Search endpoint"
	web_endpoint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	web_api_key = LineEdit.new(); web_api_key.placeholder_text = "API key (optional for Firecrawl)"; web_api_key.secret = true
	web_api_key.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hw.add_child(web_endpoint); hw.add_child(web_api_key)
	v.add_child(hw)

	status = Label.new()
	status.autowrap_mode = TextServer.AUTOWRAP_WORD
	v.add_child(status)

	provider_list.item_selected.connect(_on_provider_sel)
	web_provider.item_selected.connect(_on_web_provider_sel)
	model_list.item_selected.connect(_on_model_sel)
	model_edit.text_changed.connect(_on_model_typed)
	models_btn.pressed.connect(_fetch_models)
	test_btn.pressed.connect(_test)
	confirmed.connect(_apply)


func _populate() -> void:
	if cfg == null:
		return
	var d: Dictionary = cfg.data()
	provider_list.clear()
	for id in d.providers:
		var p_v: Variant = d.providers[id]
		var p: Dictionary = p_v if typeof(p_v) == TYPE_DICTIONARY else {}
		provider_list.add_item(str(p.get("name", id)), provider_list.item_count)
		provider_list.set_item_metadata(provider_list.item_count - 1, id)
	var aid := str(d.get("active_provider", "ollama"))
	for i in provider_list.item_count:
		if str(provider_list.get_item_metadata(i)) == aid:
			provider_list.select(i)
			break
	_on_provider_sel(provider_list.selected)


func _on_provider_sel(idx: int) -> void:
	if idx < 0 or cfg == null:
		return
	var id := str(provider_list.get_item_metadata(idx))
	var d: Dictionary = cfg.data()
	var p_v: Variant = d.providers.get(id, {})
	var p: Dictionary = p_v if typeof(p_v) == TYPE_DICTIONARY else {}
	base_url.text = str(p.get("base_url", ""))
	api_key.text = str(p.get("api_key", ""))
	streaming.button_pressed = bool(p.get("streaming", true))
	requires_key.button_pressed = bool(p.get("requires_key", false))
	var am := str(d.get("active_model", ""))
	var web: Dictionary = d.get("web_search", {})
	var agent: Dictionary = d.get("agent", {})
	var selected_effort := str(agent.get("reasoning_effort", "medium" if bool(agent.get("reasoning", false)) else "none"))
	task_minutes.value = int(agent.get("task_max_minutes", 0))
	task_tool_calls.value = int(agent.get("task_max_tool_calls", 0))
	task_llm_rounds.value = int(agent.get("task_max_llm_rounds", 0))
	task_timeout.value = int(agent.get("task_request_timeout_seconds", 120))
	task_compact_threshold.value = int(agent.get("task_auto_compact_threshold", 80000))
	for i in reasoning_effort.item_count:
		if str(reasoning_effort.get_item_metadata(i)) == selected_effort:
			reasoning_effort.select(i)
			break
	var wp := str(web.get("provider", "firecrawl")).to_lower()
	for i in web_provider.item_count:
		if str(web_provider.get_item_metadata(i)) == wp:
			web_provider.select(i)
			break
	web_scrape_content.button_pressed = bool(web.get("scrape_content", true))
	var def_endpoint := "https://api.firecrawl.dev/v2/search" if wp == "firecrawl" else "https://api.search.brave.com/res/v1/web/search"
	web_endpoint.text = str(web.get("endpoint", def_endpoint))
	web_api_key.text = str(web.get("api_key", ""))
	_on_web_provider_sel(web_provider.selected)
	model_list.clear()
	var ctx_len: int = int(cfg.get_model_context_window(am, id)) if cfg != null and cfg.has_method("get_model_context_window") else 32768
	var label: String = (am if am != "" else "(none)") + (" (%s ctx)" % _format_ctx(ctx_len) if ctx_len > 0 and am != "" else "")
	model_list.add_item(label, 0)
	model_list.set_item_metadata(0, am)
	_update_model_plan_ui(am, id)


func _on_web_provider_sel(idx: int) -> void:
	if idx < 0: return
	var p := str(web_provider.get_item_metadata(idx))
	if p == "firecrawl":
		if web_endpoint.text == "" or web_endpoint.text.contains("brave.com"):
			web_endpoint.text = "https://api.firecrawl.dev/v2/search"
		web_api_key.placeholder_text = "API key (optional - keyless works, or fc-...)"
		web_scrape_content.visible = true
	elif p == "brave":
		if web_endpoint.text == "" or web_endpoint.text.contains("firecrawl.dev"):
			web_endpoint.text = "https://api.search.brave.com/res/v1/web/search"
		web_api_key.placeholder_text = "Brave Search API key"
		web_scrape_content.visible = false



func _fetch_models() -> void:
	var idx := provider_list.selected
	if idx < 0:
		status.text = "Please select a provider first."
		return
	var id := str(provider_list.get_item_metadata(idx))
	var raw_base := base_url.text.strip_edges()
	if raw_base.is_empty():
		status.text = "Base URL is required."
		return
	var key := api_key.text.strip_edges()
	if cfg != null:
		cfg.set_api_key(id, key)
		if cfg.has_method("set_provider_base_url"):
			cfg.set_provider_base_url(id, raw_base)
		cfg.set_active(id, _selected_model())

	var d: Dictionary = cfg.data() if cfg != null else {}
	var p_v: Variant = d.get("providers", {}).get(id, {})
	var p: Dictionary = p_v if typeof(p_v) == TYPE_DICTIONARY else {}
	var ep := str(p.get("models_endpoint", "/models"))
	var base := raw_base.rstrip("/")
	var url := base + (ep if ep.begins_with("/") else "/" + ep)

	_http_mode = "models"
	if _http != null:
		_http.cancel_request()
		_http.timeout = 10.0

	var hdrs := PackedStringArray()
	if key != "":
		hdrs.append("Authorization: Bearer %s" % key)
	if id == "openrouter":
		hdrs.append("HTTP-Referer: https://godotengine.org")
		hdrs.append("X-Title: GodotAgent")

	models_btn.disabled = true
	test_btn.disabled = true
	status.text = "Fetching models from %s..." % url

	if _http != null:
		var err := _http.request(url, hdrs, HTTPClient.METHOD_GET)
		if err != OK:
			models_btn.disabled = false
			test_btn.disabled = false
			status.text = "Failed to start request (Godot error %d)" % err
			return

	if client != null and client.has_method("is_connected_to_agent") and client.is_connected_to_agent():
		client.send({"type": "models.list_req", "provider": id})


func _test() -> void:
	var idx := provider_list.selected
	if idx < 0:
		status.text = "Please select a provider first."
		return
	var id := str(provider_list.get_item_metadata(idx))
	var raw_base := base_url.text.strip_edges()
	if raw_base.is_empty():
		status.text = "Base URL is required."
		return
	var key := api_key.text.strip_edges()
	var sm := _selected_model()
	if sm == "":
		status.text = "Please select or type a model ID to test."
		return

	var base := raw_base.rstrip("/")
	var url := base + "/chat/completions"

	_http_mode = "test"
	if _http != null:
		_http.cancel_request()
		_http.timeout = 15.0

	var hdrs := PackedStringArray(["Content-Type: application/json"])
	if key != "":
		hdrs.append("Authorization: Bearer %s" % key)
	if id == "openrouter":
		hdrs.append("HTTP-Referer: https://godotengine.org")
		hdrs.append("X-Title: GodotAgent")

	var sm_lower := sm.to_lower()
	var is_reasoning := (
		sm_lower.begins_with("o1") or sm_lower.begins_with("o3") or sm_lower.begins_with("o4")
		or sm_lower.contains("gpt-5") or sm_lower.contains("gpt-6")
		or sm_lower.contains("reasoning") or sm_lower.contains("reasoner")
		or sm_lower.contains("deepseek-r1") or sm_lower.contains("/r1") or sm_lower.begins_with("r1")
		or sm_lower.contains("qwq") or sm_lower.contains("claude-3-7")
		or sm_lower.contains("thinking")
	)
	var use_completion_tokens := id in ["openai", "openrouter", "groq", "fireworks", "together"] or is_reasoning

	var payload := {
		"model": sm,
		"messages": [{"role": "user", "content": "ping"}],
	}
	if use_completion_tokens:
		payload["max_completion_tokens"] = 150 if is_reasoning else 10
		if is_reasoning:
			if id == "openrouter":
				payload["reasoning"] = {"effort": "low"}
			else:
				payload["reasoning_effort"] = "low"
	else:
		payload["max_tokens"] = 10

	models_btn.disabled = true
	test_btn.disabled = true
	status.text = "Testing connection to %s (%s)..." % [sm, id]

	if _http != null:
		var err := _http.request(url, hdrs, HTTPClient.METHOD_POST, JSON.stringify(payload))
		if err != OK:
			models_btn.disabled = false
			test_btn.disabled = false
			status.text = "Failed to start test request (Godot error %d)" % err


func _on_http_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	models_btn.disabled = false
	test_btn.disabled = false
	var idx := provider_list.selected
	var pid := str(provider_list.get_item_metadata(idx)) if idx >= 0 else ""

	if result != HTTPRequest.RESULT_SUCCESS:
		match result:
			HTTPRequest.RESULT_CANT_CONNECT:
				status.text = "Connection refused to %s. Is the model server running?" % base_url.text.strip_edges()
			HTTPRequest.RESULT_TIMEOUT:
				status.text = "Request timed out (10s) connecting to %s" % base_url.text.strip_edges()
			HTTPRequest.RESULT_CANT_RESOLVE:
				status.text = "Cannot resolve hostname in %s" % base_url.text.strip_edges()
			HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
				status.text = "TLS/SSL handshake failed for %s" % base_url.text.strip_edges()
			_:
				status.text = "HTTP request failed (error code %d)" % result
		return

	var body_text := body.get_string_from_utf8().strip_edges()
	var parsed_err := ""
	var j_err: Variant = JSON.parse_string(body_text)
	if typeof(j_err) == TYPE_DICTIONARY:
		var err_dict: Dictionary = j_err
		if err_dict.has("error"):
			var inner: Variant = err_dict["error"]
			if typeof(inner) == TYPE_DICTIONARY:
				parsed_err = str((inner as Dictionary).get("message", ""))
			else:
				parsed_err = str(inner)
	if parsed_err == "" and code != 200 and body_text != "":
		parsed_err = body_text.substr(0, 120)

	if _http_mode == "test":
		if code == 200:
			status.text = "Connection test SUCCESSFUL for model '%s' (%s)!" % [_selected_model(), pid]
		elif code == 401:
			status.text = "Test FAILED (401 Unauthorized): Invalid API key%s" % ((" - " + parsed_err) if parsed_err != "" else "")
		elif code == 404:
			status.text = "Test FAILED (404 Not Found): Endpoint %s not found." % (base_url.text.strip_edges() + "/chat/completions")
		else:
			status.text = "Test FAILED (HTTP %d)%s" % [code, (": " + parsed_err) if parsed_err != "" else ""]
		return

	if code != 200:
		if code == 401:
			status.text = "HTTP 401 Unauthorized: Invalid API key%s" % ((" - " + parsed_err) if parsed_err != "" else "")
		elif code == 404:
			status.text = "HTTP 404 Not Found at %s. Check base URL." % base_url.text.strip_edges()
		else:
			status.text = "HTTP %d error fetching models%s" % [code, (": " + parsed_err) if parsed_err != "" else ""]
		return

	var j: Variant = JSON.parse_string(body_text)
	if typeof(j) != TYPE_DICTIONARY:
		status.text = "Invalid JSON response from model server."
		return
	var d: Dictionary = j
	var arr: Array = []
	if d.has("data") and typeof(d["data"]) == TYPE_ARRAY:
		arr = d["data"]
	elif d.has("models") and typeof(d["models"]) == TYPE_ARRAY:
		arr = d["models"]

	if arr.is_empty():
		status.text = "Connected successfully, but 0 models returned by %s." % pid
		return

	_populate_models_list(arr, pid)
	status.text = "Got %d models from %s" % [arr.size(), pid]


func _populate_models_list(models: Array, pid: String) -> void:
	if cfg != null and cfg.has_method("register_models_metadata"):
		cfg.register_models_metadata(models, pid)
	model_list.clear()
	for mm in models:
		var mid := ""
		if typeof(mm) == TYPE_DICTIONARY:
			mid = str((mm as Dictionary).get("id", (mm as Dictionary).get("name", "")))
		else:
			mid = str(mm)
		if mid == "": continue
		var ctx_len: int = int(cfg.get_model_context_window(mid, pid)) if cfg != null and cfg.has_method("get_model_context_window") else 32768
		var label: String = mid + (" (%s ctx)" % _format_ctx(ctx_len) if ctx_len > 0 else "")
		var idx := model_list.item_count
		model_list.add_item(label, idx)
		model_list.set_item_metadata(idx, mid)
	if model_list.item_count > 0:
		_on_model_sel(model_list.selected)


func _format_ctx(tokens: int) -> String:
	if tokens >= 1000000:
		return "%dM" % (tokens / 1000000)
	if tokens >= 1000:
		return "%dk" % (tokens / 1000)
	return "%d" % tokens


func _on_msg(m: Dictionary) -> void:
	if str(m.get("type", "")) != "models.list":
		return
	models_btn.disabled = false
	test_btn.disabled = false
	if m.has("error") and str(m.get("error")) != "":
		var err_code := str(m.get("error"))
		if status.text.begins_with("Fetching models"):
			status.text = "Failed to fetch models from server: %s" % err_code
		return
	var models_v: Variant = m.get("models", [])
	var models: Array = models_v if typeof(models_v) == TYPE_ARRAY else []
	var pid := str(m.get("provider", ""))
	if pid == "" and provider_list != null and provider_list.selected >= 0:
		pid = str(provider_list.get_item_metadata(provider_list.selected))
	if not models.is_empty():
		_populate_models_list(models, pid)
		status.text = "Got %d models from %s" % [models.size(), pid]


func _on_model_sel(idx: int) -> void:
	if idx < 0: return
	var sm := _selected_model()
	var pid := str(provider_list.get_item_metadata(provider_list.selected)) if provider_list.selected >= 0 else ""
	_update_model_plan_ui(sm, pid)


func _on_model_typed(_text: String) -> void:
	var sm := _selected_model()
	var pid := str(provider_list.get_item_metadata(provider_list.selected)) if provider_list.selected >= 0 else ""
	_update_model_plan_ui(sm, pid)


func _update_model_plan_ui(model_id: String, provider_id: String) -> void:
	if model_id == "" or cfg == null or not cfg.has_method("plan_for_model"):
		return
	var plan: Dictionary = cfg.plan_for_model(model_id, provider_id)
	var compact_threshold := int(plan.get("task_auto_compact_threshold", 80000))
	var ctx_win := int(plan.get("context_window_tokens", 32768))
	task_compact_threshold.value = compact_threshold
	status.text = "Model: %s · Context: %s tokens (~%d chars compact threshold)" % [model_id, _format_ctx(ctx_win), compact_threshold]


func _selected_model() -> String:
	if model_edit.text.strip_edges() != "":
		return model_edit.text.strip_edges()
	if model_list.selected >= 0:
		var meta: Variant = model_list.get_item_metadata(model_list.selected)
		if meta != null and str(meta) != "":
			return str(meta)
		return model_list.get_item_text(model_list.selected)
	return ""


func _apply() -> void:
	var idx := provider_list.selected
	if idx < 0 or cfg == null:
		queue_free()
		return
	var id := str(provider_list.get_item_metadata(idx))
	cfg.set_api_key(id, api_key.text)
	if cfg.has_method("set_provider_base_url"):
		cfg.set_provider_base_url(id, base_url.text.strip_edges())
	var sm := _selected_model()
	var plan: Dictionary = cfg.set_active(id, sm)
	cfg.set_agent("streaming", streaming.button_pressed)
	var effort := str(reasoning_effort.get_item_metadata(reasoning_effort.selected)) if reasoning_effort.selected >= 0 else "none"
	cfg.set_agent("reasoning_effort", effort)
	cfg.set_agent("reasoning", effort != "none")
	cfg.set_agent("task_max_minutes", 0)
	cfg.set_agent("task_max_tool_calls", int(task_tool_calls.value))
	cfg.set_agent("task_max_llm_rounds", int(task_llm_rounds.value))
	cfg.set_agent("task_request_timeout_seconds", int(task_timeout.value))
	var wp := str(web_provider.get_item_metadata(web_provider.selected)) if web_provider != null and web_provider.selected >= 0 else "firecrawl"
	var scrape := web_scrape_content.button_pressed if web_scrape_content != null else true
	cfg.set_web_search(web_endpoint.text.strip_edges(), web_api_key.text.strip_edges(), wp, scrape)
	if client != null:
		client.send({
			"type": "models.set_active",
			"provider": id,
			"model": sm,
			"plan": plan,
		})
	queue_free()
